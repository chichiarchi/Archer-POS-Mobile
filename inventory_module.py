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
        self.current_page = 0
        self.page_size = 100
        self.setup_ui()

    def setup_ui(self):
        layout = QVBoxLayout(self)

        # Action Buttons
        top_layout = QHBoxLayout()

        self.btn_add_product = QPushButton("Add Product (Ctrl+I)")
        self.btn_add_product.setMinimumHeight(45)
        self.btn_add_product.setStyleSheet("font-size: 14px; font-weight: bold;")
        self.btn_add_product.clicked.connect(self.show_add_product_dialog)
        QShortcut(QKeySequence("Ctrl+I"), self, context=Qt.WidgetWithChildrenShortcut).activated.connect(self.show_add_product_dialog)
        top_layout.addWidget(self.btn_add_product)

        self.btn_edit_product = QPushButton("Edit Product (Ctrl+E)")
        self.btn_edit_product.setMinimumHeight(45)
        self.btn_edit_product.setStyleSheet("font-size: 14px; font-weight: bold;")
        self.btn_edit_product.clicked.connect(self.show_edit_dialog)
        QShortcut(QKeySequence("Ctrl+E"), self, context=Qt.WidgetWithChildrenShortcut).activated.connect(self.show_edit_dialog)
        top_layout.addWidget(self.btn_edit_product)

        self.btn_delete_product = QPushButton("Delete Product (Del)")
        self.btn_delete_product.setMinimumHeight(45)
        self.btn_delete_product.setStyleSheet("font-size: 14px; font-weight: bold; color: #ef4444;")
        self.btn_delete_product.clicked.connect(self.delete_product)
        QShortcut(QKeySequence(Qt.Key_Delete), self, context=Qt.WidgetWithChildrenShortcut).activated.connect(self.delete_product)
        top_layout.addWidget(self.btn_delete_product)

        layout.addLayout(top_layout)

        # Search Bar
        search_layout = QHBoxLayout()
        search_layout.addWidget(QLabel("Search Product:"))
        self.search_input = QLineEdit()
        self.search_input.setMinimumHeight(45)
        self.search_input.setStyleSheet("font-size: 16px; padding: 5px;")
        self.search_input.setPlaceholderText("Enter Barcode or Product Name...")
        self.search_input.textChanged.connect(self.on_search_changed)
        self.search_input.returnPressed.connect(self.check_not_found_on_enter)
        search_layout.addWidget(self.search_input)
        layout.addLayout(search_layout)

        # Product Table
        self.inventory_table = QTableWidget(0, 4)
        self.inventory_table.setHorizontalHeaderLabels(["Barcode", "Name", "Price", "Category"])
        self.inventory_table.horizontalHeader().setSectionResizeMode(1, QHeaderView.Stretch)
        self.inventory_table.setEditTriggers(QTableWidget.NoEditTriggers)
        self.inventory_table.setStyleSheet("font-size: 15px;")
        self.inventory_table.horizontalHeader().setStyleSheet("font-size: 15px; font-weight: bold;")
        self.inventory_table.verticalHeader().setDefaultSectionSize(35)
        layout.addWidget(self.inventory_table)

        # Pagination Controls
        pagination_layout = QHBoxLayout()
        self.btn_prev = QPushButton("Previous 100")
        self.btn_prev.clicked.connect(self.prev_page)
        self.btn_prev.setEnabled(False)
        
        self.page_label = QLabel("Page 1")
        self.page_label.setAlignment(Qt.AlignCenter)
        self.page_label.setStyleSheet("font-weight: bold; font-size: 14px;")
        
        self.btn_next = QPushButton("Next 100")
        self.btn_next.clicked.connect(self.next_page)
        
        pagination_layout.addWidget(self.btn_prev)
        pagination_layout.addStretch()
        pagination_layout.addWidget(self.page_label)
        pagination_layout.addStretch()
        pagination_layout.addWidget(self.btn_next)
        layout.addLayout(pagination_layout)

        self.btn_refresh = QPushButton("Refresh (Ctrl+R)")
        self.btn_refresh.clicked.connect(self.refresh_all)
        QShortcut(QKeySequence("Ctrl+R"), self, context=Qt.WidgetWithChildrenShortcut).activated.connect(self.refresh_all)
        layout.addWidget(self.btn_refresh)

        self.load_inventory()

    def load_inventory(self):
        search_text = self.search_input.text().strip()
        conn = database.get_connection()
        cursor = conn.cursor()
        
        query = """
            SELECT id, name, price, category
            FROM products
        """
        
        params = ()
        if search_text:
            query += " WHERE id LIKE ? OR name LIKE ?"
            like_val = f"%{search_text}%"
            params = (like_val, like_val)
            
        query += f" LIMIT {self.page_size} OFFSET {self.current_page * self.page_size}"
            
        cursor.execute(query, params)
        rows = cursor.fetchall()
        
        # Check if there's a next page
        cursor.execute(f"SELECT COUNT(*) FROM products {'WHERE id LIKE ? OR name LIKE ?' if search_text else ''}", params)
        total_count = cursor.fetchone()[0]
        
        conn.close()

        self.inventory_table.setRowCount(0)
        for i, row in enumerate(rows):
            self.inventory_table.insertRow(i)
            self.inventory_table.setItem(i, 0, QTableWidgetItem(str(row[0])))
            self.inventory_table.setItem(i, 1, QTableWidgetItem(str(row[1])))
            self.inventory_table.setItem(i, 2, QTableWidgetItem(f"₱{row[2]:,.2f}"))
            self.inventory_table.setItem(i, 3, QTableWidgetItem(str(row[3]) if row[3] else "N/A"))

        # Update Pagination UI
        self.page_label.setText(f"Page {self.current_page + 1} (Showing {len(rows)} of {total_count} items)")
        self.btn_prev.setEnabled(self.current_page > 0)
        self.btn_next.setEnabled((self.current_page + 1) * self.page_size < total_count)

    def on_search_changed(self):
        self.current_page = 0
        self.load_inventory()

    def next_page(self):
        self.current_page += 1
        self.load_inventory()

    def prev_page(self):
        if self.current_page > 0:
            self.current_page -= 1
            self.load_inventory()

    def refresh_all(self):
        self.current_page = 0
        self.load_inventory()

    def show_add_product_dialog(self):
        if self.user_role != "admin":
            QMessageBox.warning(self, "Access Denied", "Only Admin can add new products.")
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
                    INSERT INTO products (id, name, price, category)
                    VALUES (?, ?, ?, ?)
                """, (data["barcode"], data["name"], data["sell_price"], data["category"]))
                action = "PRODUCT_ADDED"
                log_msg = f"Added product '{data['name']}' (Barcode: {data['barcode']})"
            else:
                # Update product details
                cursor.execute("""
                    UPDATE products SET name=?, price=?, category=?
                    WHERE id=?
                """, (data["name"], data["sell_price"], data["category"], data["barcode"]))
                action = "PRODUCT_UPDATED"
                log_msg = f"Updated product details for '{data['name']}' (Barcode: {data['barcode']})"

            # Log action
            database.log_action(action, log_msg, self.user_role)

            conn.commit()
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
        cursor.execute("SELECT name, category, price FROM products WHERE id=?", (barcode,))
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
                UPDATE products SET name=?, category=?, price=?
                WHERE id=?
            """, (data["name"], data["category"], data["sell_price"], barcode))
            conn.commit()
            conn.close()
            
            # Log action
            database.log_action("PRODUCT_EDIT", f"Updated product '{data['name']}' (Barcode: {barcode}) details", self.user_role)
            
            self.load_inventory()
            QMessageBox.information(self, "Success", "Product updated successfully.")

    def delete_product(self):
        if self.user_role != "admin":
            QMessageBox.warning(self, "Access Denied", "Only Admin can delete products.")
            return
            
        current_row = self.inventory_table.currentRow()
        if current_row < 0:
            QMessageBox.warning(self, "Selection Required", "Please select a product from the table first.")
            return
            
        barcode = self.inventory_table.item(current_row, 0).text()
        product_name = self.inventory_table.item(current_row, 1).text()
        
        confirmation_text = (
            f"Are you sure you want to completely delete this product?\n\n"
            f"DETAILS:\n"
            f"• Name: {product_name}\n"
            f"• Barcode: {barcode}\n\n"
            f"This will permanently remove the product from the database."
        )

        reply = QMessageBox.question(
            self, "Confirm Deletion", 
            confirmation_text,
            QMessageBox.Yes | QMessageBox.No, QMessageBox.No
        )
                                     
        if reply == QMessageBox.Yes:
            conn = database.get_connection()
            cursor = conn.cursor()
            cursor.execute("DELETE FROM products WHERE id=?", (barcode,))
            conn.commit()
            conn.close()
            
            database.log_action("PRODUCT_DELETED", f"Deleted product: {product_name} (Barcode: {barcode})", self.user_role)
            
            QMessageBox.information(self, "Success", f"Product '{product_name}' has been deleted.")
            self.load_inventory()

    def check_not_found_on_enter(self):
        barcode = self.search_input.text().strip()
        if not barcode:
            return
            
        conn = database.get_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT id FROM products WHERE id=?", (barcode,))
        exists = cursor.fetchone()
        conn.close()
        
        if not exists:
            reply = QMessageBox.question(
                self, "Product Not Found", 
                f"Barcode '{barcode}' is not in the database.\nWould you like to add it now?",
                QMessageBox.Yes | QMessageBox.No, QMessageBox.Yes
            )
            if reply == QMessageBox.Yes:
                self.show_add_product_dialog_with_barcode(barcode)

    def show_add_product_dialog_with_barcode(self, barcode):
        if self.user_role != "admin":
            QMessageBox.warning(self, "Access Denied", "Only Admin can add products.")
            return

        dialog = StockInDialog(self)
        dialog.inp_barcode.setText(barcode)
        if dialog.exec():
            data = dialog.get_data()
            conn = database.get_connection()
            cursor = conn.cursor()
            
            cursor.execute("INSERT INTO products (id, name, price, category) VALUES (?, ?, ?, ?)", 
                           (data["barcode"], data["name"], data["sell_price"], data["category"]))
            
            conn.commit()
            conn.close()
            self.load_inventory()


class StockInDialog(QDialog):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setWindowTitle("Product Details")
        self.setup_ui()

    def setup_ui(self):
        layout = QVBoxLayout(self)
        form = QFormLayout()

        self.inp_barcode = QLineEdit()
        self.inp_barcode.textChanged.connect(self.check_existing_product)
        self.inp_name = QLineEdit()
        self.inp_sell = QLineEdit()
        self.inp_sell.textEdited.connect(self.format_cash_input)
        self.inp_category = QLineEdit()

        form.addRow("Barcode / ID:", self.inp_barcode)
        form.addRow("Product Name:", self.inp_name)
        form.addRow("Category:", self.inp_category)
        form.addRow("Selling Price (₱):", self.inp_sell)

        layout.addLayout(form)

        btn_save = QPushButton("Save Product")
        btn_save.clicked.connect(self.accept)
        layout.addWidget(btn_save)

    def format_cash_input(self, text):
        line_edit = self.sender()
        if not isinstance(line_edit, QLineEdit): return
        pos = line_edit.cursorPosition()
        old_text = line_edit.text()
        raw_val = text.replace(',', '')
        if not raw_val: return
        try:
            if '.' in raw_val:
                parts = raw_val.split('.')
                whole, decimal = parts[0], ".".join(parts[1:])
                formatted = (f"{int(whole):,}" if whole else "0") + "." + decimal
            else:
                formatted = f"{int(raw_val):,}"
            if formatted != old_text:
                line_edit.setText(formatted)
                new_pos = pos + (len(formatted) - len(old_text))
                line_edit.setCursorPosition(max(0, new_pos))
        except ValueError: pass

    def check_existing_product(self, barcode):
        barcode = barcode.strip()
        if not barcode:
            self.inp_name.clear()
            self.inp_category.clear()
            self.inp_sell.clear()
            return
            
        conn = database.get_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT name, category, price FROM products WHERE id=?", (barcode,))
        product = cursor.fetchone()
        conn.close()
        
        if product:
            self.inp_name.setText(product[0])
            self.inp_category.setText(product[1] if product[1] else "")
            self.inp_sell.setText(str(product[2] if product[2] else 0.0))

    def get_data(self):
        return {
            "barcode": self.inp_barcode.text().strip(),
            "name": self.inp_name.text().strip() or "Unnamed",
            "category": self.inp_category.text().strip() or "General",
            "sell_price": float(self.inp_sell.text().replace(',', '').strip() or 0.0)
        }


class EditProductDialog(QDialog):
    def __init__(self, barcode, product_data, parent=None):
        super().__init__(parent)
        self.setWindowTitle("Edit Product")
        self.barcode = barcode
        self.product_data = product_data # (name, category, price)
        self.setup_ui()

    def setup_ui(self):
        layout = QVBoxLayout(self)
        form = QFormLayout()

        name, category, sell_price = self.product_data

        self.inp_name = QLineEdit(name)
        self.inp_category = QLineEdit(category if category else "")
        self.inp_sell = QLineEdit(f"{sell_price:,.2f}")
        self.inp_sell.textEdited.connect(self.format_cash_input)

        form.addRow("Barcode / ID:", QLabel(self.barcode))
        form.addRow("Product Name:", self.inp_name)
        form.addRow("Category:", self.inp_category)
        form.addRow("Selling Price (₱):", self.inp_sell)

        layout.addLayout(form)

        btn_save = QPushButton("Save Changes")
        btn_save.clicked.connect(self.accept)
        layout.addWidget(btn_save)

    def format_cash_input(self, text):
        line_edit = self.sender()
        if not isinstance(line_edit, QLineEdit): return
        pos = line_edit.cursorPosition()
        old_text = line_edit.text()
        raw_val = text.replace(',', '')
        if not raw_val: return
        try:
            if '.' in raw_val:
                parts = raw_val.split('.')
                whole, decimal = parts[0], ".".join(parts[1:])
                formatted = (f"{int(whole):,}" if whole else "0") + "." + decimal
            else:
                formatted = f"{int(raw_val):,}"
            if formatted != old_text:
                line_edit.setText(formatted)
                new_pos = pos + (len(formatted) - len(old_text))
                line_edit.setCursorPosition(max(0, new_pos))
        except ValueError: pass

    def get_data(self):
        return {
            "name": self.inp_name.text().strip() or "Unnamed",
            "category": self.inp_category.text().strip() or "General",
            "sell_price": float(self.inp_sell.text().replace(',', '').strip() or 0.0),
        }
