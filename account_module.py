from PySide6.QtWidgets import (
    QWidget, QVBoxLayout, QHBoxLayout, QPushButton, 
    QLabel, QMessageBox, QLineEdit, QFrame, QScrollArea
)
from PySide6.QtCore import Qt, Signal
from PySide6.QtGui import QIcon
import database

class AccountModule(QWidget):
    logout_requested = Signal()

    def __init__(self, username):
        super().__init__()
        self.username = username
        self.setup_ui()

    def setup_ui(self):
        # Main layout for the module
        main_layout = QVBoxLayout(self)
        main_layout.setContentsMargins(0, 0, 0, 0)
        main_layout.setSpacing(0)

        # Scroll Area
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setStyleSheet("QScrollArea { border: none; background-color: transparent; }")
        
        container = QWidget()
        container.setStyleSheet("background-color: transparent;")
        layout = QVBoxLayout(container)
        layout.setContentsMargins(40, 40, 40, 40)
        layout.setSpacing(30)

        # Header Section
        header_layout = QVBoxLayout()
        title = QLabel("Account Settings")
        title.setStyleSheet("""
            font-size: 28px; 
            font-weight: 800; 
            color: #1E293B; 
            letter-spacing: -0.5px;
        """)
        header_layout.addWidget(title)
        
        subtitle = QLabel("Manage your personal profile and security preferences")
        subtitle.setStyleSheet("font-size: 14px; color: #64748B; margin-top: -5px;")
        header_layout.addWidget(subtitle)
        layout.addLayout(header_layout)

        # Content Layout (Centered for better look on large screens)
        content_wrapper = QHBoxLayout()
        content_container = QVBoxLayout()
        content_container.setSpacing(25)

        # Profile Card
        profile_card = QFrame()
        profile_card.setObjectName("card")
        profile_card.setStyleSheet("""
            QFrame#card {
                background-color: #FFFFFF;
                border: 1px solid #E2E8F0;
                border-radius: 16px;
                padding: 24px;
            }
        """)
        profile_layout = QVBoxLayout(profile_card)

        profile_title = QLabel("User Profile")
        profile_title.setStyleSheet("font-size: 18px; font-weight: 700; color: #1E293B; margin-bottom: 10px;")
        profile_layout.addWidget(profile_title)

        user_info_layout = QHBoxLayout()
        user_icon = QLabel("👤")
        user_icon.setStyleSheet("font-size: 32px; background-color: #F1F5F9; border-radius: 20px; padding: 10px;")
        user_info_layout.addWidget(user_icon)
        
        user_details = QVBoxLayout()
        user_name_lbl = QLabel(self.username)
        user_name_lbl.setStyleSheet("font-size: 18px; font-weight: 600; color: #0F172A;")
        user_details.addWidget(user_name_lbl)
        
        role_lbl = QLabel("System User") # Could be dynamic if needed
        role_lbl.setStyleSheet("font-size: 13px; color: #64748B; text-transform: uppercase; letter-spacing: 1px;")
        user_details.addWidget(role_lbl)
        
        user_info_layout.addLayout(user_details)
        user_info_layout.addStretch()
        profile_layout.addLayout(user_info_layout)
        
        content_container.addWidget(profile_card)

        # Logout Button Section
        logout_btn = QPushButton("Logout from System")
        logout_btn.setCursor(Qt.PointingHandCursor)
        logout_btn.setStyleSheet("""
            QPushButton {
                background-color: #EF4444;
                color: white;
                font-size: 15px;
                font-weight: 700;
                padding: 14px;
                border: none;
                border-radius: 8px;
            }
            QPushButton:hover {
                background-color: #DC2626;
            }
            QPushButton:pressed {
                background-color: #B91C1C;
            }
        """)
        logout_btn.clicked.connect(self.logout_requested.emit)
        content_container.addWidget(logout_btn)

        # Password Change Section
        pwd_container = QFrame()
        pwd_container.setObjectName("card")
        pwd_container.setStyleSheet("""
            QFrame#card {
                background-color: #FFFFFF;
                border: 1px solid #E2E8F0;
                border-radius: 16px;
                padding: 24px;
            }
            QLabel {
                font-size: 14px;
                color: #475569;
                font-weight: 600;
                margin-bottom: 4px;
            }
            QLineEdit {
                background-color: #F8FAFC;
                border: 1px solid #CBD5E1;
                border-radius: 8px;
                padding: 12px;
                font-size: 14px;
                margin-bottom: 16px;
            }
            QLineEdit:focus {
                border: 2px solid #0072FF;
                background-color: #FFFFFF;
            }
        """)
        pwd_layout = QVBoxLayout(pwd_container)
        
        pwd_title = QLabel("Security & Password")
        pwd_title.setStyleSheet("font-size: 18px; font-weight: 700; color: #1E293B; margin-bottom: 15px;")
        pwd_layout.addWidget(pwd_title)

        pwd_layout.addWidget(QLabel("Current Password"))
        self.current_pwd = QLineEdit()
        self.current_pwd.setPlaceholderText("Enter current password")
        self.current_pwd.setEchoMode(QLineEdit.Password)
        pwd_layout.addWidget(self.current_pwd)

        pwd_layout.addWidget(QLabel("New Password"))
        self.new_pwd = QLineEdit()
        self.new_pwd.setPlaceholderText("Enter new password")
        self.new_pwd.setEchoMode(QLineEdit.Password)
        pwd_layout.addWidget(self.new_pwd)

        pwd_layout.addWidget(QLabel("Confirm New Password"))
        self.confirm_pwd = QLineEdit()
        self.confirm_pwd.setPlaceholderText("Confirm new password")
        self.confirm_pwd.setEchoMode(QLineEdit.Password)
        pwd_layout.addWidget(self.confirm_pwd)

        self.btn_update_pwd = QPushButton("Update Password")
        self.btn_update_pwd.setCursor(Qt.PointingHandCursor)
        self.btn_update_pwd.setStyleSheet("""
            QPushButton {
                background-color: qlineargradient(spread:pad, x1:0, y1:0, x2:1, y2:0, stop:0 #0072FF, stop:1 #00C6FF);
                color: white;
                font-size: 15px;
                font-weight: 700;
                padding: 14px;
                border: none;
                border-radius: 8px;
                margin-top: 10px;
            }
            QPushButton:hover {
                background-color: qlineargradient(spread:pad, x1:0, y1:0, x2:1, y2:0, stop:0 #0056D2, stop:1 #00B4F0);
            }
            QPushButton:pressed {
                padding-top: 15px;
                background-color: #0056D2;
            }
        """)
        self.btn_update_pwd.clicked.connect(self.update_password)
        pwd_layout.addWidget(self.btn_update_pwd)

        content_container.addWidget(pwd_container)
        
        # Add stretch to keep cards at the top
        content_container.addStretch()
        
        content_wrapper.addLayout(content_container)
        content_wrapper.addStretch() # Push everything to the left
        
        layout.addLayout(content_wrapper)
        layout.addStretch()

        scroll.setWidget(container)
        main_layout.addWidget(scroll)

    def update_password(self):
        current_pwd = self.current_pwd.text().strip()
        new_pwd = self.new_pwd.text().strip()
        confirm_pwd = self.confirm_pwd.text().strip()

        if not current_pwd or not new_pwd or not confirm_pwd:
            QMessageBox.warning(self, "Validation Error", "All password fields must be filled.")
            return

        if new_pwd != confirm_pwd:
            QMessageBox.warning(self, "Validation Error", "The new passwords do not match. Please try again.")
            return

        if len(new_pwd) < 6:
            QMessageBox.warning(self, "Validation Error", "The new password must be at least 6 characters long.")
            return

        # Verify current password
        user_data = database.verify_login(self.username, current_pwd)
        if not user_data:
            QMessageBox.critical(self, "Security Error", "The current password you entered is incorrect.")
            return

        # Update password
        if database.update_user_password(self.username, new_pwd):
            QMessageBox.information(self, "Success", "Your password has been updated successfully.")
            self.current_pwd.clear()
            self.new_pwd.clear()
            self.confirm_pwd.clear()
            database.log_action("PASSWORD_CHANGE", f"User '{self.username}' updated their password.", self.username)
        else:
            QMessageBox.critical(self, "System Error", "An error occurred while updating the password. Please try again later.")
