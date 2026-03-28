import logging
try:
    from escpos.printer import Usb, Dummy
    ESCPOS_AVAILABLE = True
except ImportError:
    ESCPOS_AVAILABLE = False
    logging.warning("python-escpos is not installed. Printer will run in dummy mode.")

class ReceiptPrinter:
    def __init__(self, vendor_id=None, product_id=None):
        self.vendor_id = vendor_id
        self.product_id = product_id
        self.printer = None
        self.is_connected = False
        self.connect()

    def connect(self):
        """Attempts to connect to the USB thermal printer."""
        if not ESCPOS_AVAILABLE:
            logging.error("escpos library missing. Cannot connect to physical printer.")
            return False

        if not self.vendor_id or not self.product_id:
            logging.info("No Vendor/Product ID provided. Running Printer in Dummy Mode.")
            self.printer = Dummy()
            self.is_connected = True
            return True

        try:
            # Connect to USB printer
            self.printer = Usb(self.vendor_id, self.product_id, profile="POS-5890")
            self.is_connected = True
            logging.info(f"Successfully connected to printer ({hex(self.vendor_id)}:{hex(self.product_id)}).")
            return True
        except Exception as e:
            self.is_connected = False
            logging.error(f"Failed to connect to printer: {e}")
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
            self.printer.text(f"{receipt_data.get('header', 'ARCHER POS')}\n")
            self.printer.set(align='center', normal_text=True)
            self.printer.text("-" * 32 + "\n")
            
            # Sub-header (Date, Cashier, etc.)
            if 'subheader' in receipt_data:
                self.printer.set(align='left')
                self.printer.text(f"{receipt_data['subheader']}\n")
                self.printer.text("-" * 32 + "\n")
                
            # Items
            self.printer.set(align='left')
            for item in receipt_data.get('items', []):
                # Format: Name (xQty)  Price
                line = f"{item['name'][:16]:<16} x{item['qty']:<3} ₱{item['price']:>7,.2f}\n"
                self.printer.text(line)

            self.printer.text("-" * 32 + "\n")

            # Totals
            self.printer.set(align='right', bold=True)
            self.printer.text(f"TOTAL: ₱{receipt_data.get('total', 0):,.2f}\n")
            if 'amount_paid' in receipt_data:
                 self.printer.text(f"PAID:  ₱{receipt_data['amount_paid']:,.2f}\n")
                 if receipt_data['amount_paid'] > receipt_data.get('total', 0):
                     change = receipt_data['amount_paid'] - receipt_data.get('total', 0)
                     self.printer.text(f"CHNG:  ₱{change:,.2f}\n")
            if 'balance_due' in receipt_data:
                 if receipt_data['balance_due'] > 0:
                     self.printer.text(f"DUE:   ₱{receipt_data['balance_due']:,.2f}\n")

            self.printer.text("\n")

            # Footer
            self.printer.set(align='center', normal_text=True)
            self.printer.text(f"{receipt_data.get('footer', 'Thank you for your purchase!')}\n")
            
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
        'header': 'ARCHER MEGA STORE',
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
