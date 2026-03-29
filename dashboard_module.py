from PySide6.QtWidgets import (
    QWidget, QVBoxLayout, QHBoxLayout, QLabel, QTableWidget, QTableWidgetItem, QHeaderView, QFrame, QGridLayout
)
from PySide6.QtCore import Qt
from PySide6.QtGui import QColor, QFont
import database
from datetime import datetime

class DashboardModule(QWidget):
    def __init__(self, user_role="staff"):
        super().__init__()
        self.user_role = user_role
        self.setup_ui()

    def setup_ui(self):
        self.layout_main = QVBoxLayout(self)
        self.layout_main.setContentsMargins(20, 20, 20, 20)
        self.layout_main.setSpacing(20)

        # Welcome Text
        welcome_lbl = QLabel(f"Dashboard - Logged in as: {self.user_role.capitalize()}")
        welcome_lbl.setStyleSheet("font-size: 24px; font-weight: bold; color: #0ea5e9; margin-bottom: 5px;")
        self.layout_main.addWidget(welcome_lbl)

        # Stats Cards Layout
        stats_layout = QHBoxLayout()
        stats_layout.setSpacing(15)

        self.sales_card = self.create_stat_card("Today's Sales (₱)", "₱0.00", "#0ea5e9")
        self.trans_card = self.create_stat_card("Today's Transactions", "0", "#6366f1")
        self.inventory_card = self.create_stat_card("Total Products", "0", "#10b981")
        self.balance_card = self.create_stat_card("Overall Balance (₱)", "₱0.00", "#f59e0b")

        stats_layout.addWidget(self.sales_card["frame"])
        stats_layout.addWidget(self.trans_card["frame"])
        stats_layout.addWidget(self.inventory_card["frame"])
        stats_layout.addWidget(self.balance_card["frame"])

        self.layout_main.addLayout(stats_layout)

        # Expiry Warning Widget
        warning_frame = QFrame()
        warning_frame.setStyleSheet("""
            QFrame {
                background-color: #ffffff;
                border: 1px solid #e5e7eb; 
                border-radius: 12px;
            }
        """)
        warning_layout = QVBoxLayout(warning_frame)
        warning_layout.setContentsMargins(20, 20, 20, 20)

        warning_lbl = QLabel("⚠️ Nearly Expired Items (Within 30 Days)")
        warning_lbl.setStyleSheet("color: #ef4444; font-size: 18px; font-weight: bold; border: none; margin-bottom: 10px;")
        warning_layout.addWidget(warning_lbl)

        self.expiry_table = QTableWidget(0, 3)
        self.expiry_table.setHorizontalHeaderLabels(["Product Name", "Expiry Date", "Stock Remaining"])
        self.expiry_table.horizontalHeader().setSectionResizeMode(0, QHeaderView.Stretch)
        self.expiry_table.setStyleSheet("""
            QTableWidget {
                border: none;
                background-color: #ffffff;
                border-top: 1px solid #e5e7eb;
            }
            QHeaderView::section {
                background-color: #f9fafb;
                border: none;
                padding: 10px;
                font-weight: bold;
            }
        """)
        self.expiry_table.setEditTriggers(QTableWidget.NoEditTriggers)
        warning_layout.addWidget(self.expiry_table)

        self.layout_main.addWidget(warning_frame)
        self.layout_main.addStretch()

        self.load_all()

    def create_stat_card(self, title, value, color):
        frame = QFrame()
        frame.setFixedHeight(120)
        frame.setStyleSheet(f"""
            QFrame {{
                background-color: #ffffff;
                border: 1px solid #e5e7eb;
                border-radius: 12px;
            }}
        """)
        
        # Inner Shadow/Indicator
        layout = QVBoxLayout(frame)
        layout.setContentsMargins(15, 15, 15, 15)
        
        title_lbl = QLabel(title)
        title_lbl.setStyleSheet(f"color: #6b7280; font-size: 13px; font-weight: 600; text-transform: uppercase; border: none;")
        
        val_lbl = QLabel(value)
        val_lbl.setStyleSheet(f"color: {color}; font-size: 26px; font-weight: 800; border: none;")
        
        layout.addWidget(title_lbl)
        layout.addWidget(val_lbl)
        layout.addStretch()
        
        return {"frame": frame, "title_lbl": title_lbl, "val_lbl": val_lbl}

    def load_all(self):
        self.load_stats()
        self.load_expiry_warnings()

    def load_stats(self):
        conn = database.get_connection()
        cursor = conn.cursor()
        
        # Today's date in local (Philippines) format
        today = datetime.now().strftime('%Y-%m-%d')

        # 1. Today's Sales (Total amount sold today in local time)
        # Assuming CURRENT_TIMESTAMP is UTC, we offset by +8 hours for PH time
        cursor.execute("""
            SELECT SUM(total_amount) 
            FROM sales 
            WHERE date(timestamp, '+8 hours') = ?
        """, (today,))
        sales_today = cursor.fetchone()[0] or 0.0
        
        # 2. Today's Transaction Count
        cursor.execute("""
            SELECT COUNT(*) 
            FROM sales 
            WHERE date(timestamp, '+8 hours') = ?
        """, (today,))
        trans_today = cursor.fetchone()[0] or 0
        
        # 3. Total Unique Products
        cursor.execute("SELECT COUNT(*) FROM products")
        total_products = cursor.fetchone()[0] or 0
        
        # 4. Total Outstanding Balance
        cursor.execute("SELECT SUM(balance_amount) FROM debtors")
        total_balance = cursor.fetchone()[0] or 0.0

        conn.close()

        # Update Labels
        self.sales_card["val_lbl"].setText(f"₱{sales_today:,.2f}")
        self.trans_card["val_lbl"].setText(f"{trans_today:,}")
        self.inventory_card["val_lbl"].setText(f"{total_products:,}")
        self.balance_card["val_lbl"].setText(f"₱{total_balance:,.2f}")

    def load_expiry_warnings(self):
        conn = database.get_connection()
        cursor = conn.cursor()

        query = """
            SELECT p.name, i.expiry_date, 
                   SUM(CASE WHEN i.type='IN' THEN i.quantity ELSE -i.quantity END) as batch_qty
            FROM inventory i
            JOIN products p ON i.product_id = p.id
            WHERE i.expiry_date IS NOT NULL 
              AND i.expiry_date <= date('now', '+30 days')
              AND i.expiry_date >= date('now', '-30 days')
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
            item_name.setForeground(QColor("#ef4444"))
            
            item_expiry = QTableWidgetItem(str(expiry))
            item_expiry.setForeground(QColor("#ef4444"))

            item_qty = QTableWidgetItem(f"{int(qty)}")
            item_qty.setForeground(QColor("#ef4444"))
            
            self.expiry_table.setItem(i, 0, item_name)
            self.expiry_table.setItem(i, 1, item_expiry)
            self.expiry_table.setItem(i, 2, item_qty)
