from PySide6.QtWidgets import (
    QWidget, QVBoxLayout, QHBoxLayout, QLineEdit, QPushButton, 
    QTableWidget, QTableWidgetItem, QLabel, QMessageBox, QDialog, QFormLayout, QDateEdit, QHeaderView, QInputDialog,
    QDoubleSpinBox
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

        self.btn_manage_bundles = QPushButton("Manage Bundles (Ctrl+B)")
        self.btn_manage_bundles.setMinimumHeight(45)
        self.btn_manage_bundles.setStyleSheet("font-size: 14px; font-weight: bold; color: #0f766e;")
        self.btn_manage_bundles.clicked.connect(self.show_manage_bundles_dialog)
        QShortcut(QKeySequence("Ctrl+B"), self, context=Qt.WidgetWithChildrenShortcut).activated.connect(self.show_manage_bundles_dialog)
        top_layout.addWidget(self.btn_manage_bundles)

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
            try:
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

                conn.commit()
                # Log action AFTER successful commit
                database.log_action(action, log_msg, self.user_role)
            except Exception as e:
                conn.rollback()
                QMessageBox.critical(self, "Database Error", f"Failed to save product: {e}")
            finally:
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
        product = None
        try:
            cursor.execute("SELECT name, category, price FROM products WHERE id=?", (barcode,))
            product = cursor.fetchone()
        except Exception as e:
            QMessageBox.critical(self, "Database Error", f"Failed to fetch product details: {e}")
        finally:
            conn.close()
        
        if not product:
            return
            
        dialog = EditProductDialog(barcode, product, self)
        if dialog.exec():
            data = dialog.get_data()
            conn = database.get_connection()
            try:
                cursor = conn.cursor()
                cursor.execute("""
                    UPDATE products SET name=?, category=?, price=?
                    WHERE id=?
                """, (data["name"], data["category"], data["sell_price"], barcode))
                conn.commit()
                # Log action
                database.log_action("PRODUCT_EDIT", f"Updated product '{data['name']}' (Barcode: {barcode}) details", self.user_role)
                QMessageBox.information(self, "Success", "Product updated successfully.")
            except Exception as e:
                conn.rollback()
                QMessageBox.critical(self, "Database Error", f"Failed to update product details: {e}")
            finally:
                conn.close()
            
            self.load_inventory()

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
            try:
                cursor = conn.cursor()
                cursor.execute("DELETE FROM products WHERE id=?", (barcode,))
                conn.commit()
                # Log action
                database.log_action("PRODUCT_DELETED", f"Deleted product: {product_name} (Barcode: {barcode})", self.user_role)
                QMessageBox.information(self, "Success", f"Product '{product_name}' has been deleted.")
            except Exception as e:
                conn.rollback()
                QMessageBox.critical(self, "Database Error", f"Failed to delete product: {e}")
            finally:
                conn.close()
            
            self.load_inventory()

    def check_not_found_on_enter(self):
        barcode = self.search_input.text().strip()
        if not barcode:
            return
            
        conn = database.get_connection()
        cursor = conn.cursor()
        exists = None
        try:
            cursor.execute("SELECT id FROM products WHERE id=?", (barcode,))
            exists = cursor.fetchone()
        except Exception as e:
            QMessageBox.critical(self, "Database Error", f"Failed to search barcode: {e}")
        finally:
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
            try:
                cursor = conn.cursor()
                cursor.execute("INSERT INTO products (id, name, price, category) VALUES (?, ?, ?, ?)", 
                               (data["barcode"], data["name"], data["sell_price"], data["category"]))
                conn.commit()
            except Exception as e:
                conn.rollback()
                QMessageBox.critical(self, "Database Error", f"Failed to save product: {e}")
            finally:
                conn.close()
            self.load_inventory()

    def show_manage_bundles_dialog(self):
        if self.user_role != "admin":
            QMessageBox.warning(self, "Access Denied", "Only Admin can manage product bundles.")
            return
            
        current_row = self.inventory_table.currentRow()
        if current_row < 0:
            QMessageBox.warning(self, "Selection Required", "Please select a product from the table first.")
            return
            
        barcode = self.inventory_table.item(current_row, 0).text()
        product_name = self.inventory_table.item(current_row, 1).text()
        
        dialog = ManageBundlesDialog(barcode, product_name, self)
        dialog.exec()


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
        btn_save.setAutoDefault(False)
        btn_save.setDefault(False)
        btn_save.clicked.connect(self.accept)
        layout.addWidget(btn_save)

    def keyPressEvent(self, event):
        if event.key() in (Qt.Key_Return, Qt.Key_Enter):
            event.ignore()
            return
        super().keyPressEvent(event)

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
        btn_save.setAutoDefault(False)
        btn_save.setDefault(False)
        btn_save.clicked.connect(self.accept)
        layout.addWidget(btn_save)

    def keyPressEvent(self, event):
        if event.key() in (Qt.Key_Return, Qt.Key_Enter):
            event.ignore()
            return
        super().keyPressEvent(event)

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


class ManageBundlesDialog(QDialog):
    def __init__(self, product_id, product_name, parent=None):
        super().__init__(parent)
        self.setWindowTitle(f"Manage Bundles for: {product_name}")
        self.setMinimumSize(500, 400)
        self.product_id = product_id
        self.product_name = product_name
        self.setup_ui()
        self.load_bundles()

    def setup_ui(self):
        layout = QVBoxLayout(self)
        
        lbl_header = QLabel(f"Configure packaging options/bundles for barcode:\n{self.product_id}")
        lbl_header.setStyleSheet("font-weight: bold; font-size: 14px; color: #1E293B; margin-bottom: 10px;")
        layout.addWidget(lbl_header)
        
        # Table of existing bundles
        self.table = QTableWidget(0, 4)
        self.table.setHorizontalHeaderLabels(["ID", "Bundle Name", "Quantity (pcs)", "Price (₱)"])
        self.table.horizontalHeader().setSectionResizeMode(1, QHeaderView.Stretch)
        self.table.setEditTriggers(QTableWidget.NoEditTriggers)
        self.table.setSelectionBehavior(QTableWidget.SelectRows)
        self.table.setSelectionMode(QTableWidget.SingleSelection)
        layout.addWidget(self.table)
        
        # Add new bundle form
        form_layout = QHBoxLayout()
        
        self.inp_name = QLineEdit()
        self.inp_name.setPlaceholderText("e.g. 15pcs Bundle")
        
        self.inp_qty = QDoubleSpinBox()
        self.inp_qty.setRange(1.0, 9999.0)
        self.inp_qty.setValue(15.0)
        self.inp_qty.setDecimals(1)
        
        self.inp_price = QLineEdit()
        self.inp_price.setPlaceholderText("Price ₱")
        self.inp_price.textEdited.connect(self.format_cash_input)
        
        btn_add = QPushButton("Add Bundle")
        btn_add.setStyleSheet("background-color: #0f766e; color: white; font-weight: bold; padding: 8px 12px;")
        btn_add.clicked.connect(self.add_bundle)
        
        form_layout.addWidget(QLabel("Name:"))
        form_layout.addWidget(self.inp_name)
        form_layout.addWidget(QLabel("Qty:"))
        form_layout.addWidget(self.inp_qty)
        form_layout.addWidget(QLabel("Price:"))
        form_layout.addWidget(self.inp_price)
        form_layout.addWidget(btn_add)
        layout.addLayout(form_layout)
        
        # Actions layout
        actions_layout = QHBoxLayout()
        btn_delete = QPushButton("Delete Selected")
        btn_delete.setStyleSheet("background-color: #ef4444; color: white; font-weight: bold; padding: 8px 12px;")
        btn_delete.clicked.connect(self.delete_bundle)
        actions_layout.addWidget(btn_delete)
        
        actions_layout.addStretch()
        
        btn_close = QPushButton("Close")
        btn_close.clicked.connect(self.accept)
        actions_layout.addWidget(btn_close)
        
        layout.addLayout(actions_layout)

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
                whole = parts[0]
                decimal = ".".join(parts[1:])
                formatted = (f"{int(whole):,}" if whole else "0") + "." + decimal
            else:
                formatted = f"{int(raw_val):,}"
            if formatted != old_text:
                line_edit.setText(formatted)
                new_pos = pos + (len(formatted) - len(old_text))
                line_edit.setCursorPosition(max(0, new_pos))
        except ValueError:
            pass

    def load_bundles(self):
        self.table.setRowCount(0)
        conn = database.get_connection()
        cursor = conn.cursor()
        try:
            cursor.execute("SELECT id, bundle_name, quantity, price FROM product_bundles WHERE product_id=?", (self.product_id,))
            rows = cursor.fetchall()
            for i, row in enumerate(rows):
                self.table.insertRow(i)
                self.table.setItem(i, 0, QTableWidgetItem(str(row[0])))
                self.table.setItem(i, 1, QTableWidgetItem(str(row[1])))
                self.table.setItem(i, 2, QTableWidgetItem(f"{row[2]:g}"))
                self.table.setItem(i, 3, QTableWidgetItem(f"₱{row[3]:,.2f}"))
        finally:
            conn.close()

    def add_bundle(self):
        name = self.inp_name.text().strip()
        qty = self.inp_qty.value()
        price_str = self.inp_price.text().replace(',', '').strip()
        
        if not name:
            QMessageBox.warning(self, "Input Error", "Please enter a bundle name.")
            return
        try:
            price = float(price_str)
        except ValueError:
            QMessageBox.warning(self, "Input Error", "Please enter a valid price.")
            return
            
        conn = database.get_connection()
        try:
            cursor = conn.cursor()
            cursor.execute("""
                INSERT INTO product_bundles (product_id, bundle_name, quantity, price)
                VALUES (?, ?, ?, ?)
            """, (self.product_id, name, qty, price))
            conn.commit()
            database.log_action("BUNDLE_ADDED", f"Added bundle '{name}' ({qty} pcs at ₱{price:,.2f}) for product '{self.product_name}'", "admin")
            self.inp_name.clear()
            self.inp_price.clear()
            self.load_bundles()
        except Exception as e:
            conn.rollback()
            QMessageBox.critical(self, "Database Error", f"Failed to save bundle: {e}")
        finally:
            conn.close()

    def delete_bundle(self):
        row = self.table.currentRow()
        if row < 0:
            QMessageBox.warning(self, "Selection Required", "Please select a bundle to delete.")
            return
        bundle_id = self.table.item(row, 0).text()
        bundle_name = self.table.item(row, 1).text()
        
        reply = QMessageBox.question(self, "Confirm Delete", f"Delete bundle '{bundle_name}'?", QMessageBox.Yes | QMessageBox.No, QMessageBox.No)
        if reply == QMessageBox.Yes:
            conn = database.get_connection()
            try:
                cursor = conn.cursor()
                cursor.execute("DELETE FROM product_bundles WHERE id=?", (bundle_id,))
                conn.commit()
                database.log_action("BUNDLE_DELETED", f"Deleted bundle '{bundle_name}' for product '{self.product_name}'", "admin")
                self.load_bundles()
            except Exception as e:
                conn.rollback()
                QMessageBox.critical(self, "Database Error", f"Failed to delete bundle: {e}")
            finally:
                conn.close()
