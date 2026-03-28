from PySide6.QtWidgets import (
    QWidget, QVBoxLayout, QTableWidget, QTableWidgetItem, QHeaderView, 
    QPushButton, QHBoxLayout, QMessageBox, QInputDialog, QLabel
)
from PySide6.QtGui import QShortcut, QKeySequence
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
        self.btn_resolve.clicked.connect(self.resolve_balance)
        QShortcut(QKeySequence("Ctrl+B"), self).activated.connect(self.resolve_balance)
        top_layout.addWidget(self.btn_resolve)

        self.btn_refresh = QPushButton("Refresh List (F5)")
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
            self.balance_table.setItem(i, 0, QTableWidgetItem(str(row[0])))
            self.balance_table.setItem(i, 1, QTableWidgetItem(str(row[1])))
            self.balance_table.setItem(i, 2, QTableWidgetItem(str(row[2]) if row[2] else ""))
            self.balance_table.setItem(i, 3, QTableWidgetItem(str(row[3])))
            self.balance_table.setItem(i, 4, QTableWidgetItem(str(row[4])))
            
            # Format currency
            item_bal = QTableWidgetItem(f"₱{row[5]:,.2f}")
            item_bal.setForeground(Qt.red)
            self.balance_table.setItem(i, 5, item_bal)

    def resolve_balance(self):
        row = self.balance_table.currentRow()
        if row < 0:
            QMessageBox.warning(self, "Selection Required", "Please select a balance record to resolve.")
            return

        debtor_id = int(self.balance_table.item(row, 0).text())
        cust_name = self.balance_table.item(row, 1).text()
        current_bal_str = self.balance_table.item(row, 5).text().replace("₱", "")
        current_bal = float(current_bal_str)
        sale_id = int(self.balance_table.item(row, 3).text())

        amount, ok = QInputDialog.getDouble(
            self, "Resolve Balance", 
            f"Enter payment amount for {cust_name}:\nCurrent Balance: ₱{current_bal:,.2f}",
            current_bal, 0.01, current_bal
        )

        if ok and amount > 0:
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

            QMessageBox.information(self, "Success", f"Payment logically registered. Remaining Balance: ₱{new_bal:,.2f}")
            self.load_balances()
