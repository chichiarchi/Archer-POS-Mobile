from PySide6.QtWidgets import (
    QWidget, QVBoxLayout, QHBoxLayout, QLabel, QTableWidget, QTableWidgetItem, QHeaderView, QFrame
)
from PySide6.QtCore import Qt
from PySide6.QtGui import QColor
import database

class DashboardModule(QWidget):
    def __init__(self, user_role="staff"):
        super().__init__()
        self.user_role = user_role
        self.setup_ui()

    def setup_ui(self):
        layout = QVBoxLayout(self)

        # Welcome Text
        welcome_lbl = QLabel(f"Dashboard - Logged in as: {self.user_role.capitalize()}")
        welcome_lbl.setStyleSheet("font-size: 24px; font-weight: bold; color: #0ea5e9; margin-bottom: 20px;")
        layout.addWidget(welcome_lbl)

        # Expiry Warning Widget
        warning_frame = QFrame()
        warning_frame.setStyleSheet("""
            QFrame {
                background-color: #ffffff;
                border: 2px solid #ef4444; 
                border-radius: 8px;
            }
        """)
        warning_layout = QVBoxLayout(warning_frame)

        warning_lbl = QLabel("⚠️ Nearly Expired Items (Within 30 Days)")
        warning_lbl.setStyleSheet("color: #ef4444; font-size: 18px; font-weight: bold; border: none;")
        warning_layout.addWidget(warning_lbl)

        self.expiry_table = QTableWidget(0, 3)
        self.expiry_table.setHorizontalHeaderLabels(["Product Name", "Expiry Date", "Stock Remaining"])
        self.expiry_table.horizontalHeader().setSectionResizeMode(0, QHeaderView.Stretch)
        self.expiry_table.setStyleSheet("border: none; background-color: #ffffff;")
        self.expiry_table.setEditTriggers(QTableWidget.NoEditTriggers)
        warning_layout.addWidget(self.expiry_table)

        layout.addWidget(warning_frame)
        layout.addStretch()

        self.load_expiry_warnings()

    def load_expiry_warnings(self):
        conn = database.get_connection()
        cursor = conn.cursor()

        # Get items expiring within 30 days and their total remaining stock across in-outs
        # We need to link inventory batches with expiry dates, but for simplicity we assume each stock IN is a batch with an expiry.
        # SQLite date() function helps with dates.
        query = """
            SELECT p.name, i.expiry_date, 
                   SUM(CASE WHEN i.type='IN' THEN i.quantity ELSE -i.quantity END) as batch_qty
            FROM inventory i
            JOIN products p ON i.product_id = p.id
            WHERE i.expiry_date IS NOT NULL 
              AND i.expiry_date <= date('now', '+30 days')
              AND i.expiry_date >= date('now', '-30 days') -- to catch currently expiring
            GROUP BY p.id, i.expiry_date
            HAVING batch_qty > 0
            ORDER BY i.expiry_date ASC
        """
        cursor.execute(query)
        rows = cursor.fetchall()
        conn.close()

        self.expiry_table.setRowCount(0)
        for i, row in enumerate(rows):
            name, expiry, qty = row
            self.expiry_table.insertRow(i)
            
            item_name = QTableWidgetItem(name)
            item_name.setForeground(QColor("#ef4444")) # Red Highlight
            
            item_expiry = QTableWidgetItem(str(expiry))
            item_expiry.setForeground(QColor("#ef4444"))

            item_qty = QTableWidgetItem(f"{int(qty)}")
            item_qty.setForeground(QColor("#ef4444"))
            
            self.expiry_table.setItem(i, 0, item_name)
            self.expiry_table.setItem(i, 1, item_expiry)
            self.expiry_table.setItem(i, 2, item_qty)
