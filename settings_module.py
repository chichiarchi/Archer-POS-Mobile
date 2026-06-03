from PySide6.QtWidgets import (
    QWidget, QVBoxLayout, QHBoxLayout, QPushButton, 
    QLabel, QMessageBox, QCheckBox, QFrame, QComboBox,
    QLineEdit, QFileDialog
)
from PySide6.QtCore import Qt
from PySide6.QtGui import QPixmap
import database
import win32print
import os
import shutil

class SettingsModule(QWidget):
    def __init__(self, user_role="staff"):
        super().__init__()
        self.user_role = user_role
        self.setup_ui()


    def setup_ui(self):
        layout = QVBoxLayout(self)
        layout.setContentsMargins(40, 40, 40, 40)
        layout.setSpacing(20)

        title = QLabel("System Settings")
        title.setStyleSheet("font-size: 24px; font-weight: bold; color: #0072FF; margin-bottom: 10px;")
        layout.addWidget(title)

        # Container for settings
        container = QFrame()
        container.setStyleSheet("""
            QFrame {
                background-color: #FFFFFF;
                border: 1px solid #E2E8F0;
                border-radius: 12px;
                padding: 20px;
            }
            QLabel {
                background-color: transparent;
                border: none;
            }
        """)
        container_layout = QVBoxLayout(container)

        # Stock Management Toggle
        self.cb_stock = QCheckBox("Disable Global Stock Management (Forced)")
        self.cb_stock.setStyleSheet("font-size: 16px; font-weight: 500; padding: 10px; color: #94A3B8;")
        self.cb_stock.setChecked(True)
        self.cb_stock.setEnabled(False)
        container_layout.addWidget(self.cb_stock)

        stock_desc = QLabel("If enabled, the system will stop deducting stock during sales and tracking inventory movements. \nOnly prices and item details will remain functional.")
        stock_desc.setStyleSheet("color: #64748B; font-size: 13px; margin-left: 35px; margin-bottom: 20px;")
        stock_desc.setWordWrap(True)
        container_layout.addWidget(stock_desc)

        # Expiry Tracking Toggle
        self.cb_expiry = QCheckBox("Disable Global Expiry Tracking (Forced)")
        self.cb_expiry.setStyleSheet("font-size: 16px; font-weight: 500; padding: 10px; color: #94A3B8;")
        self.cb_expiry.setChecked(True)
        self.cb_expiry.setEnabled(False)
        container_layout.addWidget(self.cb_expiry)

        expiry_desc = QLabel("If enabled, expiry date fields will be hidden across the system and expiry alerts will be disabled.")
        expiry_desc.setStyleSheet("color: #64748B; font-size: 13px; margin-left: 35px; margin-bottom: 20px;")
        expiry_desc.setWordWrap(True)
        container_layout.addWidget(expiry_desc)

        layout.addWidget(container)

        # Printer Settings
        printer_container = QFrame()
        printer_container.setStyleSheet("""
            QFrame {
                background-color: #FFFFFF;
                border: 1px solid #E2E8F0;
                border-radius: 12px;
                padding: 20px;
            }
        """)
        printer_layout = QVBoxLayout(printer_container)
        
        printer_title = QLabel("Printer Settings (58mm Thermal)")
        printer_title.setStyleSheet("font-size: 16px; font-weight: bold; color: #1E293B;")
        printer_layout.addWidget(printer_title)
        
        from printer_helper import ReceiptPrinter
        self.printer_tester = ReceiptPrinter()
        
        status_text = "Connected" if self.printer_tester.is_connected else "Not Detected"
        status_color = "#10B981" if self.printer_tester.is_connected else "#EF4444"
        
        self.lbl_printer_status = QLabel(f"Status: {status_text}")
        self.lbl_printer_status.setStyleSheet(f"color: {status_color}; font-size: 14px; font-weight: bold; margin-bottom: 10px;")
        printer_layout.addWidget(self.lbl_printer_status)
        
        # Printer Selection Dropdown
        sel_layout = QHBoxLayout()
        sel_layout.addWidget(QLabel("Selected Printer:"))
        self.combo_printers = QComboBox()
        self.combo_printers.setMinimumWidth(250)
        
        # List all Windows Printers
        printers = win32print.EnumPrinters(win32print.PRINTER_ENUM_LOCAL | win32print.PRINTER_ENUM_CONNECTIONS)
        printer_names = [p[2] for p in printers]
        self.combo_printers.addItems(printer_names)
        
        # Set current printer in combo
        if self.printer_tester.printer_name in printer_names:
            self.combo_printers.setCurrentText(self.printer_tester.printer_name)
            
        sel_layout.addWidget(self.combo_printers)
        printer_layout.addLayout(sel_layout)
        
        self.btn_set_printer = QPushButton("Set as System Printer")
        self.btn_set_printer.setStyleSheet("""
            QPushButton {
                background-color: #0072FF;
                color: white;
                padding: 8px;
                font-weight: bold;
                margin-top: 5px;
            }
        """)
        self.btn_set_printer.clicked.connect(self.set_manual_printer)
        printer_layout.addWidget(self.btn_set_printer)
        
        self.btn_reconnect_printer = QPushButton("Reconnect Printer")
        self.btn_reconnect_printer.setStyleSheet("""
            QPushButton {
                background-color: #F1F5F9;
                color: #475569;
                border: 1px solid #CBD5E1;
                padding: 8px;
                margin-bottom: 5px;
            }
            QPushButton:hover { background-color: #E2E8F0; }
        """)
        self.btn_reconnect_printer.clicked.connect(self.reconnect_printer)
        printer_layout.addWidget(self.btn_reconnect_printer)
        
        self.btn_test_print = QPushButton("Run Test Print")
        self.btn_test_print.setStyleSheet("""
            QPushButton {
                background-color: #F1F5F9;
                color: #475569;
                border: 1px solid #CBD5E1;
                padding: 8px;
            }
            QPushButton:hover { background-color: #E2E8F0; }
        """)
        self.btn_test_print.clicked.connect(self.run_test_print)
        printer_layout.addWidget(self.btn_test_print)
        
        layout.addWidget(printer_container)

        # Save Button
        self.btn_save = QPushButton("Save Settings")
        self.btn_save.setStyleSheet("""
            QPushButton {
                background-color: #0072FF;
                color: white;
                font-size: 16px;
                font-weight: bold;
                padding: 12px;
                border-radius: 8px;
            }
            QPushButton:hover {
                background-color: #0056b3;
            }
        """)
        self.btn_save.clicked.connect(self.save_settings)
        layout.addWidget(self.btn_save)

        layout.addStretch()

    def run_test_print(self):
        test_data = {
            'header': 'PRINTER TEST',
            'items': [
                {'name': 'Test Item 1', 'qty': 1, 'price': 100.00},
                {'name': 'Test Item 2', 'qty': 2, 'price': 50.00}
            ],
            'total': 200.00,
            'amount_paid': 200.00,
            'footer': 'Printer is working!'
        }
        
        if self.printer_tester.is_connected:
            success = self.printer_tester.print_receipt(test_data)
            if success:
                QMessageBox.information(self, "Success", "Test receipt sent to printer.")
            else:
                QMessageBox.warning(self, "Failed", "Failed to print test receipt. Check connections.")
        else:
            QMessageBox.warning(self, "Not Connected", "No printer detected. Please check USB cable.")

    def reconnect_printer(self):
        success = self.printer_tester.reconnect()
        status_text = "Connected" if success else "Not Detected"
        status_color = "#10B981" if success else "#EF4444"
        self.lbl_printer_status.setText(f"Status: {status_text}")
        self.lbl_printer_status.setStyleSheet(f"color: {status_color}; font-size: 14px; font-weight: bold; margin-bottom: 10px;")
        if success:
            QMessageBox.information(self, "Success", "Printer re-connected successfully.")
        else:
            QMessageBox.warning(self, "Failed", "Printer still not detected.")

    def set_manual_printer(self):
        new_printer = self.combo_printers.currentText()
        self.printer_tester.printer_name = new_printer
        self.printer_tester.is_connected = True
        database.set_setting('printer_name', new_printer)
        
        status_text = "Connected"
        status_color = "#10B981"
        self.lbl_printer_status.setText(f"Status: {status_text}")
        self.lbl_printer_status.setStyleSheet(f"color: {status_color}; font-size: 14px; font-weight: bold; margin-bottom: 10px;")
        
        QMessageBox.information(self, "Success", f"System will now use: {new_printer}")

    def save_settings(self):
        if self.user_role != "admin":
            QMessageBox.warning(self, "Access Denied", "Only administrators can change system settings.")
            return

        database.set_setting('disable_stock_management', 'true' if self.cb_stock.isChecked() else 'false')
        database.set_setting('disable_expiry_tracking', 'true' if self.cb_expiry.isChecked() else 'false')

        database.log_action("SETTINGS_UPDATE", f"Updated flags: Stock={self.cb_stock.isChecked()}, Expiry={self.cb_expiry.isChecked()}", self.user_role)
        
        QMessageBox.information(self, "Success", "System settings have been updated successfully.")
