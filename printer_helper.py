import logging
import os
from datetime import datetime
import database

try:
    import win32print
    import win32ui
    import win32con
    WIN32_AVAILABLE = True
except ImportError:
    WIN32_AVAILABLE = False
    logging.warning("pywin32 is not installed.")

class ReceiptPrinter:
    _instance = None

    def __new__(cls, *args, **kwargs):
        if not cls._instance:
            cls._instance = super(ReceiptPrinter, cls).__new__(cls)
            cls._instance._initialized = False
        return cls._instance

    def __init__(self, printer_name=None):
        if self._initialized:
            return
        
        saved_name = database.get_setting('printer_name')
        self.printer_name = printer_name or saved_name
        self.is_connected = False
        self.last_error = ""
        self.connect()
        self._initialized = True

    def connect(self):
        """Attempts to find the thermal printer in Windows Spooler."""
        if not WIN32_AVAILABLE:
            return False

        try:
            if not self.printer_name:
                # Auto-discover
                printers = win32print.EnumPrinters(win32print.PRINTER_ENUM_LOCAL | win32print.PRINTER_ENUM_CONNECTIONS)
                for flags, description, name, comment in printers:
                    n = name.lower()
                    if any(x in n for x in ["pdf", "xps", "onenote", "fax", "webex", "snagit", "send to", "print to"]):
                        continue
                    if any(x in n for x in ["pos", "thermal", "58", "xp-", "xprinter", "receipt"]):
                        self.printer_name = name
                        break
                
                if not self.printer_name:
                    try:
                        default_printer = win32print.GetDefaultPrinter()
                        if not any(x in default_printer.lower() for x in ["pdf", "xps", "onenote", "fax"]):
                            self.printer_name = default_printer
                    except:
                        pass
                
                if not self.printer_name:
                    for flags, description, name, comment in printers:
                        n = name.lower()
                        if not any(x in n for x in ["pdf", "xps", "onenote", "fax", "webex", "snagit", "send to", "print to"]):
                            self.printer_name = name
                            break

            if self.printer_name:
                # Test connection and close handle immediately
                hprinter = win32print.OpenPrinter(self.printer_name)
                win32print.ClosePrinter(hprinter)
                self.is_connected = True
                return True
            else:
                self.is_connected = False
                self.last_error = "No valid printer found. Please go to System Settings -> Printer Settings, select your printer from the dropdown, and click 'Set as System Printer'."
                return False

        except Exception as e:
            self.last_error = str(e)
            logging.error(f"Failed to connect to Windows printer: {e}")
            self.is_connected = False
            return False

    def print_receipt(self, receipt_data):
        """
        Prints the receipt using GDI (Graphics Device Interface).
        This works on ALL Windows printers by 'drawing' the text.
        """
        if not WIN32_AVAILABLE:
            return False

        if not self.is_connected or not self.printer_name:
            self.connect()
            if not self.is_connected:
                return False

        # Advanced Status Check & Queue Purging
        try:
            hprinter = win32print.OpenPrinter(self.printer_name)

            printer_info = win32print.GetPrinter(hprinter, 2)
            status = printer_info['Status']

            paper_out = (status & win32print.PRINTER_STATUS_PAPER_OUT)
            offline = (status & win32print.PRINTER_STATUS_OFFLINE) or (status & win32print.PRINTER_STATUS_NOT_AVAILABLE) or (status & win32print.PRINTER_STATUS_ERROR)

            # Manually delete stuck jobs in the spooler to prevent "pile up"
            # Using EnumJobs and SetJob avoids the "Access Denied" error that SetPrinter(PURGE) causes for non-admins
            jobs = win32print.EnumJobs(hprinter, 0, -1, 1)
            if jobs:
                for job in jobs:
                    try:
                        win32print.SetJob(hprinter, job['JobId'], 0, None, win32print.JOB_CONTROL_DELETE)
                    except Exception as e:
                        logging.warning(f"Could not delete job {job['JobId']}: {e}")
                
                # If there were jobs stuck in the queue, the printer is likely offline or jammed
                offline = True

            win32print.ClosePrinter(hprinter)

            # Warning: Generic 58mm thermal drivers often do not report status properly to Windows.
            if paper_out:
                self.last_error = "Printer is OUT OF PAPER. Please insert a new roll."
                return False
            if offline:
                self.last_error = "Printer is OFFLINE, TURNED OFF, or BUSY. Please power it on before printing."
                return False

        except Exception as e:
            self.last_error = f"Failed to verify printer status: {e}"
            return False

        try:
            # Create a Device Context (DC) for the printer
            hdc = win32ui.CreateDC()
            hdc.CreatePrinterDC(self.printer_name)
            
            # Start the print job
            hdc.StartDoc("Archer POS Receipt")
            hdc.StartPage()
            
            # Use a monospaced font for alignment
            font_size = 28 # Height for legibility
            char_width = 11 # 32 chars * 11 width = 352 dots (fits 384 dot 58mm paper)
            font = win32ui.CreateFont({
                "name": "Consolas",
                "height": font_size,
                "width": char_width,
                "weight": 400,
            })
            hdc.SelectObject(font)
            
            # Use a bold font for the header
            font_bold = win32ui.CreateFont({
                "name": "Consolas",
                "height": int(font_size * 1.5),
                "width": int(char_width * 1.5),
                "weight": 800,
            })

            y = 20 # Vertical position
            
            # Top Banner
            hdc.SelectObject(font)
            hdc.TextOut(0, y, "SALES SUMMARY/CUSTOMER COPY ONLY")
            y += font_size
            hdc.TextOut(0, y, "-" * 32)
            y += font_size
            
            # 1. Header (Centered approx)
            hdc.SelectObject(font_bold)
            hdc.TextOut(20, y, receipt_data.get('header', 'ARCHER STORE'))
            y += int(font_size * 1.8)
            
            hdc.SelectObject(font)
            hdc.TextOut(10, y, " Narvacan, Ilocos Sur ")
            y += font_size
            hdc.TextOut(0, y, "-" * 32)
            y += font_size
            
            # 2. Sub-header
            current_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            hdc.TextOut(0, y, f"Date: {current_time}")
            y += font_size
            hdc.TextOut(0, y, "-" * 32)
            y += font_size
            
            # 3. Items Header
            hdc.TextOut(0, y, "Item             Qty      Price")
            y += font_size
            hdc.TextOut(0, y, "-" * 32)
            y += font_size
                
            # 4. Items
            for item in receipt_data.get('items', []):
                full_name = item['name']
                for term in [" (Wholesale)", " (Retail)", " (Wholesales)", " (Retails)", " (wholesale)", " (retail)", " (wholesales)", " (retails)", "(Wholesale)", "(Retail)"]:
                    full_name = full_name.replace(term, "")
                full_name = full_name.strip()
                qty_val = item['qty']
                qty = str(int(qty_val))
                total_item_price = item['price'] * qty_val
                price = f"{total_item_price:,.2f}"
                
                # Split the name into 16-character chunks for wrapping
                chunks = [full_name[i:i+16] for i in range(0, len(full_name), 16)]
                if not chunks:
                    chunks = [""]
                
                # First line includes the first chunk of the name, qty, and price
                first_line = f"{chunks[0]:<16} {qty:>3} {price:>10}"
                hdc.TextOut(0, y, first_line)
                y += font_size
                
                # Subsequent lines print remaining chunks under the name column
                for chunk in chunks[1:]:
                    hdc.TextOut(0, y, chunk)
                    y += font_size

            hdc.TextOut(0, y, "-" * 32)
            y += font_size

            # 5. Totals
            font_total = win32ui.CreateFont({
                "name": "Consolas",
                "height": int(font_size * 1.2),
                "width": int(char_width * 1.2),
                "weight": 700,
            })
            hdc.SelectObject(font_total)
            hdc.TextOut(0, y, f"TOTAL:        Php {receipt_data.get('total', 0):>7,.2f}")
            y += int(font_size * 1.2)
            
            y += font_size

            # 6. Footer
            hdc.TextOut(0, y, receipt_data.get('footer', 'Thank you! Come again!'))
            y += font_size
            hdc.TextOut(0, y, "Agyamanak unay!")
            y += font_size
            
            # Non-official receipt disclaimer
            y += int(font_size * 0.5)
            hdc.TextOut(0, y, "THIS IS NOT AN OFFICIAL RECEIPT")
            y += font_size
            
            hdc.TextOut(0, y, "-" * 32)
            y += font_size
            
            # Feed paper
            y += font_size * 5
            hdc.TextOut(0, y, " ")

            # Finish
            hdc.EndPage()
            hdc.EndDoc()
            hdc.DeleteDC()

            return True
            
        except Exception as e:
            self.last_error = str(e)
            logging.error(f"GDI Print Error: {e}")
            return False

    def reconnect(self):
        self._initialized = False
        self.connect()
        self._initialized = True
        return self.is_connected

if __name__ == "__main__":
    printer = ReceiptPrinter()
    print(f"Detected Printer: {printer.printer_name}")
    # Test printing helper without crashing
    printer = ReceiptPrinter() # No IDs provided -> Dummy fallback
    test_receipt = {
        'header': 'ARCHER STORE',
        'subheader': 'Date: 2026-03-28\nCashier: admin',
        'items': [
            {'name': 'Apple', 'qty': 2, 'price': 3.50},
            {'name': 'Banana', 'qty': 5, 'price': 1.25}
        ],
        'total': 8.25,
        'amount_paid': 10.00,
        'balance_due': 0.00,
        'footer': 'Please come again!'
    }
    success = printer.print_receipt(test_receipt)
    if success:
        print("Test receipt processed successfully (Dummy or Physical).")
