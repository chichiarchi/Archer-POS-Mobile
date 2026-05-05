from PySide6.QtWidgets import (
    QWidget, QVBoxLayout, QTableWidget, QTableWidgetItem, QHeaderView, 
    QPushButton, QHBoxLayout, QMessageBox, QInputDialog, QLabel,
    QDialog, QFormLayout, QLineEdit
)
from PySide6.QtGui import QShortcut, QKeySequence, QFont
from PySide6.QtCore import Qt
import database

class BalanceModule(QWidget):
    def __init__(self, user_role="staff"):
        super().__init__()
        self.user_role = user_role
        self.setup_ui()

    def setup_ui(self):
        layout = QVBoxLayout(self)

        top_layout = QHBoxLayout()
        self.btn_resolve = QPushButton("Resolve Balance (Ctrl+B)")
        self.btn_resolve.setMinimumHeight(50)
        self.btn_resolve.setStyleSheet("font-size: 18px; font-weight: bold; background-color: #0072FF; color: white; border-radius: 8px; padding: 0 20px;")
        self.btn_resolve.clicked.connect(self.resolve_balance)
        QShortcut(QKeySequence("Ctrl+B"), self).activated.connect(self.resolve_balance)
        top_layout.addWidget(self.btn_resolve)

        self.btn_refresh = QPushButton("Refresh List (F5)")
        self.btn_refresh.setMinimumHeight(50)
        self.btn_refresh.setStyleSheet("font-size: 18px; font-weight: bold; background-color: #64748B; color: white; border-radius: 8px; padding: 0 20px;")
        self.btn_refresh.clicked.connect(self.load_balances)
        QShortcut(QKeySequence("F5"), self).activated.connect(self.load_balances)
        top_layout.addWidget(self.btn_refresh)
        
        top_layout.addStretch()
        layout.addLayout(top_layout)

        # Table
        self.balance_table = QTableWidget(0, 6)
        self.balance_table.setHorizontalHeaderLabels([      
            "Debtor ID", "Customer Name", "Phone", "Sale ID", "Balance Date", "Balance Due"
        ])
        self.balance_table.horizontalHeader().setSectionResizeMode(1, QHeaderView.Stretch)
        self.balance_table.setEditTriggers(QTableWidget.NoEditTriggers)
        self.balance_table.setStyleSheet("font-size: 16px;")
        self.balance_table.horizontalHeader().setStyleSheet("font-size: 16px; font-weight: bold;")
        self.balance_table.verticalHeader().setDefaultSectionSize(50)
        layout.addWidget(self.balance_table)

        self.load_balances()

    def load_balances(self):
        conn = database.get_connection()
        cursor = conn.cursor()
        cursor.execute("""
            SELECT d.id, c.name, c.phone, d.sale_id, d.created_at, d.balance_amount
            FROM debtors d
            JOIN customers c ON d.customer_id = c.id
            WHERE d.balance_amount > 0
            ORDER BY d.created_at DESC
        """)
        rows = cursor.fetchall()
        conn.close()

        self.balance_table.setRowCount(0)
        for i, row in enumerate(rows):
            self.balance_table.insertRow(i)
            
            # Debtor ID
            self.balance_table.setItem(i, 0, QTableWidgetItem(str(row[0])))
            
            # Name
            name_item = QTableWidgetItem(str(row[1]))
            name_item.setFont(self.get_bold_font(16))
            self.balance_table.setItem(i, 1, name_item)
            
            # Phone
            self.balance_table.setItem(i, 2, QTableWidgetItem(str(row[2]) if row[2] else ""))
            
            # Sale ID
            self.balance_table.setItem(i, 3, QTableWidgetItem(str(row[3])))
            
            # Date
            self.balance_table.setItem(i, 4, QTableWidgetItem(str(row[4])))
            
            # Format currency - LARGE and BOLD
            item_bal = QTableWidgetItem(f"₱{row[5]:,.2f}")
            item_bal.setFont(self.get_bold_font(18))
            item_bal.setForeground(Qt.red)
            item_bal.setTextAlignment(Qt.AlignRight | Qt.AlignVCenter)
            self.balance_table.setItem(i, 5, item_bal)

    def get_bold_font(self, size):
        font = QFont()
        font.setPointSize(size)
        font.setBold(True)
        return font

    def resolve_balance(self):
        row = self.balance_table.currentRow()
        if row < 0:
            QMessageBox.warning(self, "Selection Required", "Please select a balance record to resolve.")
            return

        debtor_id = int(self.balance_table.item(row, 0).text())
        cust_name = self.balance_table.item(row, 1).text()
        current_bal_str = self.balance_table.item(row, 5).text().replace("₱", "").replace(",", "")
        current_bal = float(current_bal_str)
        sale_id = int(self.balance_table.item(row, 3).text())

        dialog = ResolveBalanceDialog(cust_name, current_bal, self)
        if dialog.exec():
            amount = dialog.get_amount()
            if amount > 0:
                new_bal = current_bal - amount

                conn = database.get_connection()
                cursor = conn.cursor()
                
                # Update debtors table
                cursor.execute("UPDATE debtors SET balance_amount = ? WHERE id = ?", (new_bal, debtor_id))

                # Update sales table directly linking to this sale
                cursor.execute("SELECT amount_paid FROM sales WHERE id=?", (sale_id,))
                sale = cursor.fetchone()
                if sale:
                    new_paid = sale[0] + amount
                    cursor.execute("""
                        UPDATE sales SET amount_paid = ?, balance_due = ? WHERE id = ?
                    """, (new_paid, new_bal, sale_id))

                conn.commit()
                conn.close()

                # Logging
                database.log_action("BALANCE_RESOLVE", f"Collected ₱{amount:,.2f} from {cust_name} (Debt ID: {debtor_id}). Remaining: ₱{new_bal:,.2f}", self.user_role)

                # BIG SUCCESS MESSAGE
                msg = f"Payment Successful!\nRemaining Balance: ₱{new_bal:,.2f}"
                success_box = QMessageBox(self)
                success_box.setWindowTitle("Success")
                success_box.setText(msg)
                success_box.setStyleSheet("""
                    QMessageBox { background-color: #F0FDF4; }
                    QLabel { font-size: 24px; font-weight: bold; color: #10B981; padding: 20px; }
                    QPushButton { background-color: #10B981; color: white; font-size: 18px; padding: 10px 20px; border-radius: 5px; }
                """)
                success_box.exec()
                
                self.load_balances()

class ResolveBalanceDialog(QDialog):
    def __init__(self, cust_name, current_bal, parent=None):
        super().__init__(parent)
        self.setWindowTitle("Resolve Balance")
        self.setMinimumWidth(500)
        self.current_bal = current_bal
        self.setup_ui(cust_name, current_bal)

    def setup_ui(self, name, balance):
        layout = QVBoxLayout(self)
        layout.setSpacing(20)
        layout.setContentsMargins(30, 30, 30, 30)
        
        title = QLabel(f"Payment for: {name}")
        title.setStyleSheet("font-size: 26px; font-weight: 900; color: #0072FF;")
        layout.addWidget(title)
        
        bal_container = QWidget()
        bal_container.setStyleSheet("background-color: #FEF2F2; border-radius: 12px; padding: 20px;")
        bal_layout = QVBoxLayout(bal_container)
        
        bal_title = QLabel("Current Balance Due:")
        bal_title.setStyleSheet("font-size: 16px; color: #991B1B; font-weight: bold;")
        bal_layout.addWidget(bal_title)
        
        bal_val = QLabel(f"₱{balance:,.2f}")
        bal_val.setStyleSheet("font-size: 42px; font-weight: 900; color: #DC2626;")
        bal_layout.addWidget(bal_val)
        
        layout.addWidget(bal_container)
        
        form = QFormLayout()
        form.setSpacing(15)
        
        self.amount_input = QLineEdit(f"{balance:.2f}")
        self.amount_input.setMinimumHeight(70)
        self.amount_input.setStyleSheet("""
            font-size: 36px; 
            font-weight: bold; 
            color: #1E293B; 
            border: 2px solid #CBD5E1; 
            border-radius: 10px;
            padding: 10px;
        """)
        
        lbl_pay = QLabel("Enter Payment (₱):")
        lbl_pay.setStyleSheet("font-size: 20px; font-weight: bold; color: #475569;")
        form.addRow(lbl_pay, self.amount_input)
        layout.addLayout(form)
        
        self.btn_confirm = QPushButton("Confirm Payment (Enter)")
        self.btn_confirm.setMinimumHeight(70)
        self.btn_confirm.setStyleSheet("""
            QPushButton {
                background-color: #10B981;
                color: white;
                font-size: 24px;
                font-weight: bold;
                border-radius: 12px;
            }
            QPushButton:hover { background-color: #059669; }
            QPushButton:pressed { background-color: #047857; }
        """)
        self.btn_confirm.clicked.connect(self.accept)
        self.btn_confirm.setDefault(True)
        layout.addWidget(self.btn_confirm)

    def get_amount(self):
        try:
            return float(self.amount_input.text())
        except ValueError:
            return 0.0
