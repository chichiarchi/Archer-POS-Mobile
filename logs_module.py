from PySide6.QtWidgets import (
    QWidget, QVBoxLayout, QTableWidget, QTableWidgetItem, QHeaderView, 
    QPushButton, QHBoxLayout, QLabel, QDateEdit, QMessageBox, QDialog
)
from PySide6.QtCore import Qt, QDate
from PySide6.QtGui import QShortcut, QKeySequence
import database
from printer_helper import ReceiptPrinter

class ReceiptPreviewDialog(QDialog):
    def __init__(self, receipt_data, parent=None):
        super().__init__(parent)
        self.setWindowTitle(f"Receipt Preview - Sale #{receipt_data['sale_id']}")
        self.setMinimumWidth(450)
        self.setMinimumHeight(600)
        self.receipt_data = receipt_data
        self.setup_ui()

    def setup_ui(self):
        layout = QVBoxLayout(self)
        layout.setContentsMargins(20, 20, 20, 20)
        layout.setSpacing(15)

        # "Receipt" Styled Container
        receipt_container = QWidget()
        receipt_container.setStyleSheet("""
            QWidget {
                background-color: #FFFFFF;
                border: 2px solid #E2E8F0;
                border-radius: 8px;
            }
        """)
        receipt_layout = QVBoxLayout(receipt_container)
        
        header_lbl = QLabel(self.receipt_data['header'])
        header_lbl.setAlignment(Qt.AlignCenter)
        header_lbl.setStyleSheet("font-size: 20px; font-weight: 900; color: #1E293B; border: none;")
        receipt_layout.addWidget(header_lbl)

        info_lbl = QLabel(f"Sale ID: {self.receipt_data['sale_id']}\nCashier: {self.receipt_data['cashier']}")
        info_lbl.setStyleSheet("font-size: 13px; color: #64748B; border: none;")
        receipt_layout.addWidget(info_lbl)

        # Items Table
        items_table = QTableWidget(len(self.receipt_data['items']), 3)
        items_table.setHorizontalHeaderLabels(["Item", "Qty", "Price"])
        items_table.horizontalHeader().setSectionResizeMode(0, QHeaderView.Stretch)
        items_table.verticalHeader().setVisible(False)
        items_table.setEditTriggers(QTableWidget.NoEditTriggers)
        items_table.setStyleSheet("border: none; background-color: transparent;")
        
        for i, item in enumerate(self.receipt_data['items']):
            items_table.setItem(i, 0, QTableWidgetItem(item['name']))
            items_table.setItem(i, 1, QTableWidgetItem(str(int(item['qty']))))
            items_table.setItem(i, 2, QTableWidgetItem(f"₱{item['price']:,.2f}"))

        receipt_layout.addWidget(items_table)

        # Totals
        totals_layout = QVBoxLayout()
        totals_layout.setSpacing(5)
        
        def add_total_line(label, value, is_bold=False):
            line = QHBoxLayout()
            lbl = QLabel(label)
            val = QLabel(f"₱{value:,.2f}")
            if is_bold:
                lbl.setStyleSheet("font-weight: bold; font-size: 16px; border: none;")
                val.setStyleSheet("font-weight: bold; font-size: 16px; border: none; color: #0072FF;")
            else:
                lbl.setStyleSheet("border: none;")
                val.setStyleSheet("border: none;")
            line.addWidget(lbl)
            line.addStretch()
            line.addWidget(val)
            totals_layout.addLayout(line)

        add_total_line("Total Amount:", self.receipt_data['total'], True)
        add_total_line("Amount Paid:", self.receipt_data['amount_paid'])
        if self.receipt_data['balance_due'] > 0:
            add_total_line("Balance Due:", self.receipt_data['balance_due'])
        
        receipt_layout.addLayout(totals_layout)
        layout.addWidget(receipt_container)

        # Buttons
        btn_layout = QHBoxLayout()
        self.btn_print = QPushButton("Print Receipt")
        self.btn_print.setMinimumHeight(50)
        self.btn_print.setStyleSheet("""
            background-color: #0072FF;
            color: white;
            font-weight: bold;
            font-size: 16px;
            border-radius: 6px;
        """)
        self.btn_print.clicked.connect(self.accept)
        
        self.btn_cancel = QPushButton("Close")
        self.btn_cancel.setMinimumHeight(50)
        self.btn_cancel.setStyleSheet("font-size: 16px;")
        self.btn_cancel.clicked.connect(self.reject)
        
        btn_layout.addWidget(self.btn_cancel)
        btn_layout.addWidget(self.btn_print)
        layout.addLayout(btn_layout)

class LogsModule(QWidget):
    def __init__(self, user_role="staff"):
        super().__init__()
        self.user_role = user_role
        self.setup_ui()

    def setup_ui(self):
        layout = QVBoxLayout(self)
        
        # Actions
        top_layout = QHBoxLayout()
        
        # Date Filters
        top_layout.addWidget(QLabel("From:"))
        self.date_from = QDateEdit()
        self.date_from.setCalendarPopup(True)
        self.date_from.setDate(QDate.currentDate().addDays(-7)) # Default to last 7 days
        self.date_from.dateChanged.connect(self.update_date_limits)
        top_layout.addWidget(self.date_from)
        
        top_layout.addWidget(QLabel("To:"))
        self.date_to = QDateEdit()
        self.date_to.setCalendarPopup(True)
        self.date_to.setDate(QDate.currentDate())
        self.date_to.setMinimumDate(self.date_from.date())
        self.date_to.dateChanged.connect(self.update_date_limits)
        top_layout.addWidget(self.date_to)
        
        # Initial set of limits
        self.date_from.setMaximumDate(self.date_to.date())

        self.btn_refresh = QPushButton("Refresh Logs (Ctrl+R)")
        self.btn_refresh.clicked.connect(self.load_logs)
        QShortcut(QKeySequence("Ctrl+R"), self).activated.connect(self.load_logs)
        top_layout.addWidget(self.btn_refresh)
        
        self.btn_reprint = QPushButton("Reprint Receipt (Ctrl+P)")
        self.btn_reprint.clicked.connect(self.reprint_receipt)
        QShortcut(QKeySequence("Ctrl+P"), self).activated.connect(self.reprint_receipt)
        top_layout.addWidget(self.btn_reprint)
        
        top_layout.addStretch()
        layout.addLayout(top_layout)

        # Logs Table
        self.logs_table = QTableWidget(0, 4)
        self.logs_table.setHorizontalHeaderLabels(["Timestamp", "User Role", "Action", "Details"])
        self.logs_table.horizontalHeader().setSectionResizeMode(3, QHeaderView.Stretch)
        self.logs_table.setEditTriggers(QTableWidget.NoEditTriggers)
        layout.addWidget(self.logs_table)

        self.load_logs()

    def reset_dates(self):
        # Reset to Today
        today = QDate.currentDate()
        # To avoid mutual constraint blocking, reset To first if we were moving to past, 
        # but since we move to Today, setting both to today is safer.
        self.date_from.setMaximumDate(today.addDays(3650)) # Temporarily lift
        self.date_to.setMinimumDate(today.addDays(-3650)) # Temporarily lift
        
        self.date_from.setDate(today)
        self.date_to.setDate(today)
        self.update_date_limits()

    def update_date_limits(self):
        # Mutual constraints
        self.date_to.setMinimumDate(self.date_from.date())
        self.date_from.setMaximumDate(self.date_to.date())
        # Re-fetch logs based on new range
        self.load_logs()

    def load_logs(self):
        date_from_str = self.date_from.date().toString("yyyy-MM-dd")
        date_to_str = self.date_to.date().toString("yyyy-MM-dd")

        conn = database.get_connection()
        cursor = conn.cursor()
        cursor.execute("""
            SELECT timestamp, user_id, action, details 
            FROM audit_logs 
            WHERE DATE(timestamp) BETWEEN ? AND ?
            ORDER BY id DESC 
            LIMIT 500
        """, (date_from_str, date_to_str))
        rows = cursor.fetchall()
        conn.close()

        self.logs_table.setRowCount(0)
        for i, row in enumerate(rows):
            self.logs_table.insertRow(i)
            self.logs_table.setItem(i, 0, QTableWidgetItem(str(row[0])))
            self.logs_table.setItem(i, 1, QTableWidgetItem(str(row[1])))
            
            # Format action name (replace underscores with spaces)
            action_text = str(row[2]).replace('_', ' ') if row[2] else ""
            self.logs_table.setItem(i, 2, QTableWidgetItem(action_text))
            
            self.logs_table.setItem(i, 3, QTableWidgetItem(str(row[3]) if row[3] else ""))

    def reprint_receipt(self):
        current_row = self.logs_table.currentRow()
        if current_row < 0:
            QMessageBox.warning(self, "Selection Required", "Please select a sale log entry first.")
            return

        # Check if it's a POS_SALE
        action = self.logs_table.item(current_row, 2).text()
        if action != "POS SALE":
            QMessageBox.warning(self, "Invalid Selection", "Reprinting is only available for Sales.")
            return

        details = self.logs_table.item(current_row, 3).text()
        # Parse Sale ID from "Sale #123 - ..."
        try:
            if "Sale #" in details:
                sale_id_str = details.split("Sale #")[1].split(" ")[0].strip()
                sale_id = int(sale_id_str)
            else:
                raise ValueError("Sale ID not found in details")
        except Exception as e:
            QMessageBox.critical(self, "Error", f"Could not determine Sale ID from logs: {e}")
            return

        # Fetch Sale and Items from database
        conn = database.get_connection()
        cursor = conn.cursor()
        
        # Get Sale details
        cursor.execute("SELECT total_amount, amount_paid, balance_due, timestamp FROM sales WHERE id = ?", (sale_id,))
        sale = cursor.fetchone()
        if not sale:
            conn.close()
            QMessageBox.critical(self, "Error", f"Sale #{sale_id} not found in database.")
            return
        
        total, paid, due, timestamp = sale
        
        # Get Items
        cursor.execute("SELECT product_name, quantity, price FROM sale_items WHERE sale_id = ?", (sale_id,))
        items_rows = cursor.fetchall()
        conn.close()

        if not items_rows:
            QMessageBox.information(self, "No Items Found", f"No detailed item data found for Sale #{sale_id}. Only transactions recorded after this update will have detailed item logs.")
            # We can still print a summary receipt if they want, but usually users want the items.
            return

        # Prepare receipt data
        receipt_data = {
            'header': 'ARCHER STORE (REPRINT)',
            'cashier': self.user_role.capitalize(),
            'sale_id': sale_id,
            'items': [{'name': row[0], 'qty': row[1], 'price': row[2]} for row in items_rows],
            'total': total,
            'amount_paid': paid,
            'balance_due': due,
            'footer': f'Reprinted on: {QDate.currentDate().toString("yyyy-MM-dd")}'
        }

        # Show Preview Dialog
        preview = ReceiptPreviewDialog(receipt_data, self)
        if preview.exec():
            printer = ReceiptPrinter()
            # Rely on print_receipt() to handle connection/reconnection
            success = printer.print_receipt(receipt_data)
            if success:
                QMessageBox.information(self, "Success", "Receipt reprinted successfully.")
            else:
                QMessageBox.warning(self, "Printer Error", "Printer Not Detected or Failed to Print.\nPlease check settings and connections.")
