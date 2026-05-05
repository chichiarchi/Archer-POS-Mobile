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

        # Tab for Stock In / Out / Edit
        top_layout = QHBoxLayout()

        self.btn_stock_in = QPushButton("Stock In (Ctrl+I)")
        self.btn_stock_in.setMinimumHeight(45)
        self.btn_stock_in.setStyleSheet("font-size: 14px; font-weight: bold;")
        self.btn_stock_in.clicked.connect(self.show_stock_in_dialog)
        QShortcut(QKeySequence("Ctrl+I"), self).activated.connect(self.show_stock_in_dialog)
        top_layout.addWidget(self.btn_stock_in)

        self.btn_stock_out = QPushButton("Stock Out (Ctrl+O)")
        self.btn_stock_out.setMinimumHeight(45)
        self.btn_stock_out.setStyleSheet("font-size: 14px; font-weight: bold;")
        self.btn_stock_out.clicked.connect(self.show_stock_out_dialog)
        QShortcut(QKeySequence("Ctrl+O"), self).activated.connect(self.show_stock_out_dialog)
        top_layout.addWidget(self.btn_stock_out)

        self.btn_edit_product = QPushButton("Edit Product (Ctrl+E)")
        self.btn_edit_product.setMinimumHeight(45)
        self.btn_edit_product.setStyleSheet("font-size: 14px; font-weight: bold;")
        self.btn_edit_product.clicked.connect(self.show_edit_dialog)
        QShortcut(QKeySequence("Ctrl+E"), self).activated.connect(self.show_edit_dialog)
        top_layout.addWidget(self.btn_edit_product)

        self.btn_stock_adj = QPushButton("Stock Adjustment (Ctrl+A)")
        self.btn_stock_adj.setMinimumHeight(45)
        self.btn_stock_adj.setStyleSheet("font-size: 14px; font-weight: bold;")
        self.btn_stock_adj.clicked.connect(self.show_adjustment_dialog)
        QShortcut(QKeySequence("Ctrl+A"), self).activated.connect(self.show_adjustment_dialog)
        top_layout.addWidget(self.btn_stock_adj)

        self.btn_delete_product = QPushButton("Delete Product (Del)")
        self.btn_delete_product.setMinimumHeight(45)
        self.btn_delete_product.setStyleSheet("font-size: 14px; font-weight: bold; color: #ef4444;")
        self.btn_delete_product.clicked.connect(self.delete_product)
        QShortcut(QKeySequence(Qt.Key_Delete), self).activated.connect(self.delete_product)
        top_layout.addWidget(self.btn_delete_product)

        layout.addLayout(top_layout)
         # Search Bar
        search_layout = QHBoxLayout()
        search_layout.addWidget(QLabel("Search Stock:"))
        self.search_input = QLineEdit()
        self.search_input.setMinimumHeight(45)
        self.search_input.setStyleSheet("font-size: 16px; padding: 5px;")
        self.search_input.setPlaceholderText("Enter Barcode or Product Name...")
        self.search_input.textChanged.connect(self.on_search_changed)
        self.search_input.returnPressed.connect(self.check_not_found_on_enter)
        search_layout.addWidget(self.search_input)
        layout.addLayout(search_layout)

        # Inventory Table
        self.inventory_table = QTableWidget(0, 5)
        self.inventory_table.setHorizontalHeaderLabels(["Barcode", "Name", "Price", "Total Stock", "Category"])
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
        QShortcut(QKeySequence("Ctrl+R"), self).activated.connect(self.refresh_all)
        layout.addWidget(self.btn_refresh)

        self.load_inventory()

    def load_inventory(self):
        # Update UI state based on settings
        self.btn_stock_in.setText("Add/Update Item (Ctrl+I)" if database.is_stock_management_disabled() else "Stock In (Ctrl+I)")
        self.btn_stock_out.setVisible(not database.is_stock_management_disabled())
        self.btn_stock_adj.setVisible(not database.is_stock_management_disabled())
        self.inventory_table.setColumnHidden(3, database.is_stock_management_disabled())
        
        search_text = self.search_input.text().strip()
        conn = database.get_connection()
        cursor = conn.cursor()
        
        query = """
            SELECT id, name, price, current_stock, category
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
            self.inventory_table.setItem(i, 3, QTableWidgetItem(f"{int(row[3])}"))
            self.inventory_table.setItem(i, 4, QTableWidgetItem(str(row[4]) if row[4] else "N/A"))

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
            self.current_page -= 0
            self.current_page -= 1
            self.load_inventory()

    def refresh_all(self):
        self.current_page = 0
        self.load_inventory()

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
                    INSERT INTO products (id, name, price, category)
                    VALUES (?, ?, ?, ?)
                """, (data["barcode"], data["name"], data["sell_price"], data["category"]))
            else:
                # Update product prices/name
                cursor.execute("""
                    UPDATE products SET name=?, price=?, category=?
                    WHERE id=?
                """, (data["name"], data["sell_price"], data["category"], data["barcode"]))

            # Insert into inventory - Only if stock management is enabled
            if not database.is_stock_management_disabled():
                cursor.execute("""
                    INSERT INTO inventory (product_id, quantity, expiry_date, type, timestamp)
                    VALUES (?, ?, ?, 'IN', datetime('now', '+8 hours'))
                """, (data["barcode"], data["qty"], data["expiry"]))

                # Update stock cache (Issue #1 fix)
                cursor.execute("UPDATE products SET current_stock = current_stock + ? WHERE id = ?", (data["qty"], data["barcode"]))
            
            # Log action
            log_msg = f"Received {data['qty']}x of {data['name']} (Barcode: {data['barcode']})" if not database.is_stock_management_disabled() else f"Added/Updated product '{data['name']}' (Barcode: {data['barcode']})"
            cursor.execute(
                "INSERT INTO audit_logs (action, details, user_id, timestamp) VALUES (?, ?, ?, datetime('now', '+8 hours'))",
                ("STOCK_IN", log_msg, self.user_role)
            )

            conn.commit()
            conn.close()
            self.load_inventory()

    def show_stock_out_dialog(self):
        if self.user_role != "admin":
            QMessageBox.warning(self, "Access Denied", "Only Admin can perform manual Stock Out.")
            return

        barcode, ok = QInputDialog.getText(self, "Stock Out", "Enter Product Barcode:")
        if ok and barcode:
            qty, ok_qty = QInputDialog.getInt(self, "Quantity", "Enter Quantity to Remove (Spoilage/Damage):", 1, 1, 100000)
            if ok_qty:
                conn = database.get_connection()
                cursor = conn.cursor()
                cursor.execute("SELECT id FROM products WHERE id=?", (barcode,))
                if cursor.fetchone():
                    cursor.execute("""
                        INSERT INTO inventory (product_id, quantity, type, timestamp)
                        VALUES (?, ?, 'OUT', datetime('now', '+8 hours'))
                    """, (barcode, qty))
                    
                    # Update stock cache
                    cursor.execute("UPDATE products SET current_stock = current_stock - ? WHERE id = ?", (qty, barcode))
                    
                    # Log action
                    cursor.execute(
                        "INSERT INTO audit_logs (action, details, user_id, timestamp) VALUES (?, ?, ?, datetime('now', '+8 hours'))",
                        ("STOCK_OUT", f"Removed {qty}x of barcode {barcode} manually", self.user_role)
                    )

                    conn.commit()
                    conn.close()
                    QMessageBox.information(self, "Success", "Stock removed manually.")
                self.load_inventory()

    def show_adjustment_dialog(self):
        if self.user_role != "admin":
            QMessageBox.warning(self, "Access Denied", "Only Admin can perform Physical Stock Adjustments.")
            return

        barcode, ok = QInputDialog.getText(self, "Physical Reconciliation", "Enter Product Barcode:")
        if not ok or not barcode:
            return

        conn = database.get_connection()
        cursor = conn.cursor()
        
        # Get Current System Stock (Optimized to prevent freezing - Issue #1 fix)
        cursor.execute("""
            SELECT name, current_stock
            FROM products
            WHERE id = ?
        """, (barcode,))
        result = cursor.fetchone()
        
        if not result:
            QMessageBox.warning(self, "Not Found", "Product barcode not found in database.")
            conn.close()
            return
            
        p_name, system_stock = result
        
        # Ask for Physical Count
        physical_count, ok_p = QInputDialog.getInt(
            self, "Physical Reconciliation", 
            f"Product: {p_name}\nSystem Shows: {int(system_stock)}\n\nEnter Actual Physical Count Found:", 
            int(system_stock), 0, 100000
        )
        
        if ok_p:
            # Ask for Reason
            reasons = ["Initial count error", "Missed Delivery Entry", "Spoilage/Damage Not Recorded", "Found extra stock", "Other"]
            reason, ok_r = QInputDialog.getItem(self, "Adjustment Reason", "Select Reason for Discrepancy:", reasons, 0, False)
            
            if ok_r:
                adjustment_qty = physical_count - system_stock
                adj_type = 'IN' if adjustment_qty > 0 else 'OUT'
                
                cursor.execute("""
                    INSERT INTO inventory (product_id, quantity, type, timestamp)
                    VALUES (?, ?, ?, datetime('now', '+8 hours'))
                """, (barcode, abs(adjustment_qty), adj_type))
                
                # Update stock cache
                cursor.execute("UPDATE products SET current_stock = ? WHERE id = ?", (int(physical_count), barcode))
                
                # Log action
                cursor.execute(
                    "INSERT INTO audit_logs (action, details, user_id, timestamp) VALUES (?, ?, ?, datetime('now', '+8 hours'))",
                    ("STOCK_ADJUSTMENT", f"Adjusted {p_name} by {adjustment_qty:+} units to match physical count of {physical_count}. Reason: {reason}", self.user_role)
                )

                conn.commit()
                conn.close()
                
                QMessageBox.information(self, "Success", f"Stock adjusted. New levels set to {int(physical_count)}.")
        
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
        category = self.inventory_table.item(current_row, 3).text()
        
        # Get price for confirmation
        conn = database.get_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT price FROM products WHERE id=?", (barcode,))
        row = cursor.fetchone()
        price = row[0] if row else 0.0
        conn.close()

        confirmation_text = (
            f"Are you sure you want to completely delete this product?\n\n"
            f"DETAILS:\n"
            f"• Name: {product_name}\n"
            f"• Barcode: {barcode}\n"
            f"• Price: ₱{price:,.2f}\n"
            f"• Category: {category}\n\n"
            f"This will permanently delete the product and ALL its historical inventory tracking data."
        )

        reply = QMessageBox.question(
            self, "Confirm Deletion", 
            confirmation_text,
            QMessageBox.Yes | QMessageBox.No, QMessageBox.No
        )
                                     
        if reply == QMessageBox.Yes:
            conn = database.get_connection()
            cursor = conn.cursor()
            cursor.execute("DELETE FROM inventory WHERE product_id=?", (barcode,))
            cursor.execute("DELETE FROM products WHERE id=?", (barcode,))
            conn.commit()
            conn.close()
            
            database.log_action("PRODUCT_DELETED", f"Deleted product: {product_name} (Barcode: {barcode})", self.user_role)
            
            QMessageBox.information(self, "Success", f"Product '{product_name}' has been deleted from the database.")
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
            # If it's a barcode (numbers mostly) or explicitly searched
            reply = QMessageBox.question(
                self, "Product Not Found", 
                f"Barcode '{barcode}' is not in the database.\nWould you like to add it now?",
                QMessageBox.Yes | QMessageBox.No, QMessageBox.Yes
            )
            if reply == QMessageBox.Yes:
                self.show_stock_in_dialog_with_barcode(barcode)

    def show_stock_in_dialog_with_barcode(self, barcode):
        if self.user_role != "admin":
            QMessageBox.warning(self, "Access Denied", "Only Admin can add products.")
            return

        dialog = StockInDialog(self)
        dialog.inp_barcode.setText(barcode)
        if dialog.exec():
            # Use the existing save logic
            data = dialog.get_data()
            conn = database.get_connection()
            cursor = conn.cursor()
            
            cursor.execute("SELECT id FROM products WHERE id=?", (data["barcode"],))
            if cursor.fetchone() is None:
                cursor.execute("""
                    INSERT INTO products (id, name, price, category)
                    VALUES (?, ?, ?, ?)
                """, (data["barcode"], data["name"], data["sell_price"], data["category"]))
            else:
                cursor.execute("""
                    UPDATE products SET name=?, price=?, category=?
                    WHERE id=?
                """, (data["name"], data["sell_price"], data["category"], data["barcode"]))

            if not database.is_stock_management_disabled():
                cursor.execute("""
                    INSERT INTO inventory (product_id, quantity, type, timestamp)
                    VALUES (?, ?, 'IN', datetime('now', '+8 hours'))
                """, (data["barcode"], data["qty"]))
                cursor.execute("UPDATE products SET current_stock = current_stock + ? WHERE id = ?", (data["qty"], data["barcode"]))
            
            conn.commit()
            conn.close()
            self.load_inventory()




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
        self.inp_sell = QLineEdit()
        self.inp_category = QLineEdit()
        self.inp_expiry = QDateEdit()
        self.inp_expiry.setDate(QDate.currentDate().addDays(365))
        self.inp_expiry.setCalendarPopup(True)

        form.addRow("Barcode / ID:", self.inp_barcode)
        form.addRow("Product Name:", self.inp_name)
        form.addRow("Category:", self.inp_category)
        form.addRow("Quantity:", self.inp_qty)
        
        if database.is_stock_management_disabled():
            self.inp_qty.setVisible(False)
            form.labelForField(self.inp_qty).setVisible(False)
        form.addRow("Selling Price (₱):", self.inp_sell)
        
        self.expiry_row_idx = form.rowCount()
        form.addRow("Expiry Date:", self.inp_expiry)
        
        if database.is_expiry_tracking_disabled():
            self.inp_expiry.setVisible(False)
            form.labelForField(self.inp_expiry).setVisible(False)

        layout.addLayout(form)

        btn_save = QPushButton("Save Items" if not database.is_stock_management_disabled() else "Save Product")
        btn_save.clicked.connect(self.accept)
        layout.addWidget(btn_save)

    def check_existing_product(self, barcode):
        barcode = barcode.strip()
        if not barcode:
            # Clear fields if barcode is empty
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
        else:
            # Clear fields if no match is found
            self.inp_name.clear()
            self.inp_category.clear()
            self.inp_sell.clear()

    def get_data(self):
        return {
            "barcode": self.inp_barcode.text().strip(),
            "name": self.inp_name.text().strip() or "Unnamed",
            "category": self.inp_category.text().strip() or "General",
            "qty": int(self.inp_qty.text().strip() or 0),
            "sell_price": float(self.inp_sell.text().strip() or 0.0),
            "expiry": self.inp_expiry.date().toString(Qt.ISODate)
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
        self.inp_sell = QLineEdit(str(sell_price if sell_price else 0.0))

        form.addRow("Barcode / ID:", QLabel(self.barcode))
        form.addRow("Product Name:", self.inp_name)
        form.addRow("Category:", self.inp_category)
        form.addRow("Selling Price (₱):", self.inp_sell)

        layout.addLayout(form)

        btn_save = QPushButton("Save Changes")
        btn_save.clicked.connect(self.accept)
        layout.addWidget(btn_save)

    def get_data(self):
        return {
            "name": self.inp_name.text().strip() or "Unnamed",
            "category": self.inp_category.text().strip() or "General",
            "sell_price": float(self.inp_sell.text().strip() or 0.0),
        }
