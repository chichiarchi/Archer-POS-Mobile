from PySide6.QtWidgets import (
    QWidget, QVBoxLayout, QHBoxLayout, QPushButton, 
    QLabel, QMessageBox, QCheckBox, QFrame
)
from PySide6.QtCore import Qt
import database

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

    def save_settings(self):
        if self.user_role != "admin":
            QMessageBox.warning(self, "Access Denied", "Only administrators can change system settings.")
            return

        database.set_setting('disable_stock_management', 'true' if self.cb_stock.isChecked() else 'false')
        database.set_setting('disable_expiry_tracking', 'true' if self.cb_expiry.isChecked() else 'false')

        database.log_action("SETTINGS_UPDATE", f"Updated flags: Stock={self.cb_stock.isChecked()}, Expiry={self.cb_expiry.isChecked()}", self.user_role)
        
        QMessageBox.information(self, "Success", "System settings have been updated successfully.")
