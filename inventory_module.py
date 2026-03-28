from PySide6.QtWidgets import (
    QWidget, QVBoxLayout, QHBoxLayout, QLineEdit, QPushButton, 
    QTableWidget, QTableWidgetItem, QLabel, QMessageBox, QDialog, QFormLayout, QDateEdit, QHeaderView, QInputDialog
)
from PySide6.QtCore import Qt, QDate
from PySide6.QtGui import QShortcut, QKeySequence
import database

class InventoryModule(QWidget):
    def __init__(self, user_role="staff"):
        super().__init__()
        self.user_role = user_role
        self.setup_ui()

    def setup_ui(self):
        layout = QVBoxLayout(self)

        # Tab for Stock In / Out / Edit
        top_layout = QHBoxLayout()

        self.btn_stock_in = QPushButton("Stock In (Ctrl+I)")
        self.btn_stock_in.clicked.connect(self.show_stock_in_dialog)
        QShortcut(QKeySequence("Ctrl+I"), self).activated.connect(self.show_stock_in_dialog)
        top_layout.addWidget(self.btn_stock_in)

        self.btn_stock_out = QPushButton("Stock Out (Ctrl+O)")
        self.btn_stock_out.clicked.connect(self.show_stock_out_dialog)
        QShortcut(QKeySequence("Ctrl+O"), self).activated.connect(self.show_stock_out_dialog)
        top_layout.addWidget(self.btn_stock_out)

        self.btn_edit_product = QPushButton("Edit Product (Ctrl+E)")
        self.btn_edit_product.clicked.connect(self.show_edit_dialog)
        QShortcut(QKeySequence("Ctrl+E"), self).activated.connect(self.show_edit_dialog)
        top_layout.addWidget(self.btn_edit_product)

        layout.addLayout(top_layout)

        # Search Bar
        search_layout = QHBoxLayout()
        search_layout.addWidget(QLabel("Search Stock:"))
        self.search_input = QLineEdit()
        self.search_input.setPlaceholderText("Enter Barcode or Product Name...")
        self.search_input.textChanged.connect(self.load_inventory)
        search_layout.addWidget(self.search_input)
        layout.addLayout(search_layout)

        # Inventory Table
        self.inventory_table = QTableWidget(0, 5)
        self.inventory_table.setHorizontalHeaderLabels(["Barcode", "Name", "Total Stock", "Category", "Cost Price"])
        self.inventory_table.horizontalHeader().setSectionResizeMode(1, QHeaderView.Stretch)
        self.inventory_table.setEditTriggers(QTableWidget.NoEditTriggers)
        layout.addWidget(self.inventory_table)

        self.btn_refresh = QPushButton("Refresh Inventory (Ctrl+R)")
        self.btn_refresh.clicked.connect(self.load_inventory)
        QShortcut(QKeySequence("Ctrl+R"), self).activated.connect(self.load_inventory)
        layout.addWidget(self.btn_refresh)

        self.load_inventory()

    def load_inventory(self):
        search_text = self.search_input.text().strip()
        conn = database.get_connection()
        cursor = conn.cursor()
        
        query = """
            SELECT p.id, p.name, 
                   COALESCE(SUM(CASE WHEN i.type='IN' THEN i.quantity ELSE -i.quantity END), 0) as total_stock,
                   p.category, p.cost_price
            FROM products p
            LEFT JOIN inventory i ON p.id = i.product_id
        """
        
        params = ()
        if search_text:
            query += " WHERE p.id LIKE ? OR p.name LIKE ?"
            like_val = f"%{search_text}%"
            params = (like_val, like_val)
            
        query += " GROUP BY p.id"
            
        cursor.execute(query, params)
        rows = cursor.fetchall()
        conn.close()

        self.inventory_table.setRowCount(0)
        for i, row in enumerate(rows):
            self.inventory_table.insertRow(i)
            self.inventory_table.setItem(i, 0, QTableWidgetItem(str(row[0])))
            self.inventory_table.setItem(i, 1, QTableWidgetItem(str(row[1])))
            self.inventory_table.setItem(i, 2, QTableWidgetItem(f"{int(row[2])}"))
            self.inventory_table.setItem(i, 3, QTableWidgetItem(str(row[3]) if row[3] else "N/A"))
            self.inventory_table.setItem(i, 4, QTableWidgetItem(f"₱{row[4]:,.2f}" if row[4] else "₱0.00"))

    def show_stock_in_dialog(self):
        if self.user_role != "admin":
            QMessageBox.warning(self, "Access Denied", "Only Admin can perform Stock In.")
            return

        dialog = StockInDialog(self)
        if dialog.exec():
            data = dialog.get_data()
            conn = database.get_connection()
            cursor = conn.cursor()
            
            # Check if product exists
            cursor.execute("SELECT id FROM products WHERE id=?", (data["barcode"],))
            if cursor.fetchone() is None:
                # Insert product
                cursor.execute("""
                    INSERT INTO products (id, name, price, cost_price, category)
                    VALUES (?, ?, ?, ?, ?)
                """, (data["barcode"], data["name"], data["sell_price"], data["cost_price"], data["category"]))
            else:
                # Update product prices/name
                cursor.execute("""
                    UPDATE products SET name=?, price=?, cost_price=?, category=?
                    WHERE id=?
                """, (data["name"], data["sell_price"], data["cost_price"], data["category"], data["barcode"]))

            # Insert into inventory
            cursor.execute("""
                INSERT INTO inventory (product_id, quantity, expiry_date, type)
                VALUES (?, ?, ?, 'IN')
            """, (data["barcode"], data["qty"], data["expiry"]))

            conn.commit()
            conn.close()
            
            # Log action
            database.log_action("STOCK_IN", f"Received {data['qty']}x of {data['name']} (Barcode: {data['barcode']})", self.user_role)
            
            self.load_inventory()

    def show_stock_out_dialog(self):
        if self.user_role != "admin":
            QMessageBox.warning(self, "Access Denied", "Only Admin can perform manual Stock Out.")
            return

        barcode, ok = QInputDialog.getText(self, "Stock Out", "Enter Product Barcode:")
        if ok and barcode:
            qty, ok_qty = QInputDialog.getDouble(self, "Quantity", "Enter Quantity to Remove (Spoilage/Damage):", 1.0, 0.1, 100000)
            if ok_qty:
                conn = database.get_connection()
                cursor = conn.cursor()
                cursor.execute("SELECT id FROM products WHERE id=?", (barcode,))
                if cursor.fetchone():
                    cursor.execute("""
                        INSERT INTO inventory (product_id, quantity, type)
                        VALUES (?, ?, 'OUT')
                    """, (barcode, qty))
                    conn.commit()
                    database.log_action("STOCK_OUT", f"Removed {qty}x of barcode {barcode} manually", self.user_role)
                    QMessageBox.information(self, "Success", "Stock removed manually.")
                else:
                    QMessageBox.warning(self, "Error", "Product not found.")
                conn.close()
                self.load_inventory()

    def show_edit_dialog(self):
        if self.user_role != "admin":
            QMessageBox.warning(self, "Access Denied", "Only Admin can edit products.")
            return
            
        current_row = self.inventory_table.currentRow()
        if current_row < 0:
            QMessageBox.warning(self, "Selection Required", "Please select a product from the table first.")
            return
            
        barcode = self.inventory_table.item(current_row, 0).text()
        
        conn = database.get_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT name, category, cost_price, price FROM products WHERE id=?", (barcode,))
        product = cursor.fetchone()
        conn.close()
        
        if not product:
            return
            
        dialog = EditProductDialog(barcode, product, self)
        if dialog.exec():
            data = dialog.get_data()
            conn = database.get_connection()
            cursor = conn.cursor()
            cursor.execute("""
                UPDATE products SET name=?, category=?, cost_price=?, price=?
                WHERE id=?
            """, (data["name"], data["category"], data["cost_price"], data["sell_price"], barcode))
            conn.commit()
            conn.close()
            
            # Log action
            database.log_action("PRODUCT_EDIT", f"Updated product '{data['name']}' (Barcode: {barcode}) details", self.user_role)
            
            self.load_inventory()
            QMessageBox.information(self, "Success", "Product updated successfully.")


class StockInDialog(QDialog):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setWindowTitle("Stock In")
        self.setup_ui()

    def setup_ui(self):
        layout = QVBoxLayout(self)
        form = QFormLayout()

        self.inp_barcode = QLineEdit()
        self.inp_barcode.textChanged.connect(self.check_existing_product)
        self.inp_name = QLineEdit()
        self.inp_qty = QLineEdit()
        self.inp_cost = QLineEdit()
        self.inp_sell = QLineEdit()
        self.inp_category = QLineEdit()
        self.inp_expiry = QDateEdit()
        self.inp_expiry.setDate(QDate.currentDate().addDays(365))
        self.inp_expiry.setCalendarPopup(True)

        form.addRow("Barcode / ID:", self.inp_barcode)
        form.addRow("Product Name:", self.inp_name)
        form.addRow("Category:", self.inp_category)
        form.addRow("Quantity:", self.inp_qty)
        form.addRow("Cost Price (₱):", self.inp_cost)
        form.addRow("Selling Price (₱):", self.inp_sell)
        form.addRow("Expiry Date:", self.inp_expiry)

        layout.addLayout(form)

        btn_save = QPushButton("Save Items")
        btn_save.clicked.connect(self.accept)
        layout.addWidget(btn_save)

    def check_existing_product(self, barcode):
        barcode = barcode.strip()
        if not barcode:
            return
            
        conn = database.get_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT name, category, cost_price, price FROM products WHERE id=?", (barcode,))
        product = cursor.fetchone()
        conn.close()
        
        if product:
            self.inp_name.setText(product[0])
            self.inp_category.setText(product[1] if product[1] else "")
            self.inp_cost.setText(str(product[2] if product[2] else 0.0))
            self.inp_sell.setText(str(product[3] if product[3] else 0.0))

    def get_data(self):
        return {
            "barcode": self.inp_barcode.text().strip(),
            "name": self.inp_name.text().strip() or "Unnamed",
            "category": self.inp_category.text().strip() or "General",
            "qty": float(self.inp_qty.text().strip() or 0.0),
            "cost_price": float(self.inp_cost.text().strip() or 0.0),
            "sell_price": float(self.inp_sell.text().strip() or 0.0),
            "expiry": self.inp_expiry.date().toString(Qt.ISODate)
        }


class EditProductDialog(QDialog):
    def __init__(self, barcode, product_data, parent=None):
        super().__init__(parent)
        self.setWindowTitle("Edit Product")
        self.barcode = barcode
        self.product_data = product_data # (name, category, cost_price, price)
        self.setup_ui()

    def setup_ui(self):
        layout = QVBoxLayout(self)
        form = QFormLayout()

        name, category, cost_price, sell_price = self.product_data

        self.inp_name = QLineEdit(name)
        self.inp_category = QLineEdit(category if category else "")
        self.inp_cost = QLineEdit(str(cost_price if cost_price else 0.0))
        self.inp_sell = QLineEdit(str(sell_price if sell_price else 0.0))

        form.addRow("Barcode / ID:", QLabel(self.barcode))
        form.addRow("Product Name:", self.inp_name)
        form.addRow("Category:", self.inp_category)
        form.addRow("Cost Price (₱):", self.inp_cost)
        form.addRow("Selling Price (₱):", self.inp_sell)

        layout.addLayout(form)

        btn_save = QPushButton("Save Changes")
        btn_save.clicked.connect(self.accept)
        layout.addWidget(btn_save)

    def get_data(self):
        return {
            "name": self.inp_name.text().strip() or "Unnamed",
            "category": self.inp_category.text().strip() or "General",
            "cost_price": float(self.inp_cost.text().strip() or 0.0),
            "sell_price": float(self.inp_sell.text().strip() or 0.0),
        }
