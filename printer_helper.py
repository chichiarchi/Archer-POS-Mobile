import logging
from datetime import datetime
try:
    from escpos.printer import Usb, Network, Dummy
    ESCPOS_AVAILABLE = True
except ImportError:
    ESCPOS_AVAILABLE = False
    logging.warning("python-escpos is not installed. Printer will run in dummy mode.")

class ReceiptPrinter:
    def __init__(self, vendor_id=None, product_id=None, host="127.0.0.1", port=9100):
        self.vendor_id = vendor_id
        self.product_id = product_id
        self.host = host
        self.port = port
        self.printer = None
        self.is_connected = False
        self.connect()

    def connect(self):
        """Attempts to connect to the network or USB thermal printer."""
        if not ESCPOS_AVAILABLE:
            logging.error("escpos library missing. Cannot connect to physical printer.")
            return False

        if self.host:
            try:
                # Try connecting to Network Printer Simulator first
                self.printer = Network(self.host, port=self.port, profile="POS-5890")
                self.is_connected = True
                logging.info(f"Successfully connected to network printer simulator at {self.host}:{self.port}.")
                return True
            except Exception as e:
                logging.warning(f"Failed to connect to network printer at {self.host}:{self.port}. Error: {e}")

        if not self.vendor_id or not self.product_id:
            logging.info("No Vendor/Product ID provided. Running Printer in Dummy Mode.")
            self.printer = Dummy()
            self.is_connected = True
            return True

        try:
            # Connect to USB printer
            self.printer = Usb(self.vendor_id, self.product_id, profile="POS-5890")
            self.is_connected = True
            logging.info(f"Successfully connected to USB printer ({hex(self.vendor_id)}:{hex(self.product_id)}).")
            return True
        except Exception as e:
            self.is_connected = False
            logging.error(f"Failed to connect to USB printer: {e}")
            # Fallback to Dummy printer so app doesn't crash
            self.printer = Dummy() if ESCPOS_AVAILABLE else None
            return False

    def print_receipt(self, receipt_data):
        """
        Prints the receipt. 
        receipt_data should be a dictionary with 'header', 'items', 'total', 'footer'.
        """
        if not self.printer:
            logging.error("No printer instance available to print.")
            return False

        try:
            # Header
            self.printer.set(align='center', bold=True, double_height=True, double_width=True)
            self.printer.text(f"{receipt_data.get('header', 'ARCHER STORE')}\n")
            self.printer.set(align='center', bold=False, double_height=False, double_width=False)
            self.printer.text("Narvacan, Ilocos Sur\n") # Centered by printer.set(align='center')
            self.printer.text("-" * 32 + "\n")
            
            # Sub-header (Date, Sale ID, Cashier)
            current_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            self.printer.set(align='left')
            self.printer.text(f"Date: {current_time}\n")
            if 'sale_id' in receipt_data:
                self.printer.text(f"Sale ID: {receipt_data['sale_id']}\n")
            if 'cashier' in receipt_data:
                self.printer.text(f"Cashier: {receipt_data['cashier']}\n")
            elif 'subheader' in receipt_data:
                 self.printer.text(f"{receipt_data['subheader']}\n")
            self.printer.text("-" * 32 + "\n")
            self.printer.text("Item             Qty       Price\n")
            self.printer.text("-" * 32 + "\n")
                
            # Items
            self.printer.set(align='left')
            for item in receipt_data.get('items', []):
                # Format: Item (16) Qty (3) Price (8) (aligned with Item Qty Price header)
                # "Item             Qty       Price" (16 chars + 13 chars + 3 chars?) wait
                # "Item            " (16) "Qty" (3) "Price" (5)?? wait. 32 chars total.
                # Item (16) + Qty (8) + Price (8) = 32. 
                # Item (16) "          " Qty (3) "    " Price (8)??
                # Let's align Item(17) Qty(5) Price(10)??
                # Mockup row shows P1(2) spaces(15) 1(1) spaces(7) 130.00(6)
                # It seems more like Item Name is left-aligned, Qty is centered/right, Price is right.
                line = f"{item['name'][:16]:<16} {int(item['qty']):>3} {item['price']:>11,.2f}\n"
                self.printer.text(line)

            self.printer.text("-" * 32 + "\n")

            # Totals
            self.printer.set(align='left', bold=True)
            # Use fixed width for label to align with user's mockup
            self.printer.text(f"TOTAL:               Php {receipt_data.get('total', 0):>7,.2f}\n")
            if 'amount_paid' in receipt_data:
                 self.printer.text(f"PAID:                Php {receipt_data['amount_paid']:>7,.2f}\n")
                 if receipt_data['amount_paid'] > receipt_data.get('total', 0):
                     change = receipt_data['amount_paid'] - receipt_data.get('total', 0)
                     self.printer.text(f"CHANGE:              Php {change:>7,.2f}\n")
            if 'balance_due' in receipt_data:
                 if receipt_data['balance_due'] > 0:
                     self.printer.text(f"DUE:                 Php {receipt_data['balance_due']:>7,.2f}\n")

            self.printer.text("\n")

            # Footer
            self.printer.set(align='center', bold=False, double_height=False, double_width=False)
            self.printer.text(f"{receipt_data.get('footer', 'Thank you! Come again!')}\n")
            self.printer.text("Agyamanak unay!\n")
            self.printer.text("-" * 32 + "\n")
            
            # Cut paper if supported
            self.printer.cut()
            return True
            
        except Exception as e:
            logging.error(f"Error during printing receipt: {e}")
            return False

if __name__ == "__main__":
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
