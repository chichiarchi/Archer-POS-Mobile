import sys
from PySide6.QtWidgets import (
    QApplication, QWidget, QVBoxLayout, QHBoxLayout, 
    QLabel, QLineEdit, QPushButton, QMessageBox, QFrame, QGraphicsDropShadowEffect
)
from PySide6.QtCore import Qt
from PySide6.QtGui import QFont, QColor

import database

class LoginWindow(QWidget):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Archer POS v2 - Login")
        self.setFixedSize(400, 500)
        self.setup_ui()
        
    def setup_ui(self):
        # Apply Light Theme with Sky Blue
        self.setStyleSheet("""
            QWidget {
                background-color: #E8EEF2;
                color: #2B3A4A;
                font-family: 'Segoe UI', 'Inter', sans-serif;
            }
            QLabel {
                font-size: 14px;
            }
            QLineEdit {
                background-color: #FFFFFF;
                border: 1px solid #CBD5E1;
                border-radius: 8px;
                padding: 12px;
                font-size: 15px;
                color: #2D3748;
            }
            QLineEdit:focus {
                border: 2px solid #00C6FF;
            }
            QPushButton {
                background-color: qlineargradient(spread:pad, x1:0, y1:0, x2:1, y2:0, stop:0 #00C6FF, stop:1 #0072FF);
                color: #FFFFFF;
                border: none;
                border-radius: 8px;
                padding: 14px;
                font-size: 16px;
                font-weight: 800;
                letter-spacing: 1px;
            }
            QPushButton:hover {
                background-color: qlineargradient(spread:pad, x1:0, y1:0, x2:1, y2:0, stop:0 #00E5FF, stop:1 #0088FF);
            }
            QPushButton:pressed {
                background-color: qlineargradient(spread:pad, x1:0, y1:0, x2:1, y2:0, stop:0 #0099CC, stop:1 #0055CC);
            }
        """)

        layout = QVBoxLayout(self)
        layout.setContentsMargins(40, 40, 40, 40)
        layout.setSpacing(20)

        # Title Label
        title_label = QLabel("ARCHER POS")
        title_label.setAlignment(Qt.AlignCenter)
        title_font = QFont("Segoe UI", 24, QFont.Bold)
        title_label.setFont(title_font)
        title_label.setStyleSheet("color: #0072FF; margin-bottom: 20px; font-weight: 900;")
        layout.addWidget(title_label)
        
        # Subtitle
        subtitle_label = QLabel("Sign in to continue")
        subtitle_label.setAlignment(Qt.AlignCenter)
        subtitle_label.setStyleSheet("color: #6c757d; margin-bottom: 20px;")
        layout.addWidget(subtitle_label)

        # Username Input
        self.username_input = QLineEdit()
        self.username_input.setPlaceholderText("Username")
        layout.addWidget(self.username_input)

        # Password Input
        self.password_input = QLineEdit()
        self.password_input.setPlaceholderText("Password")
        self.password_input.setEchoMode(QLineEdit.Password)
        layout.addWidget(self.password_input)

        layout.addStretch()

        # Login Button
        self.login_btn = QPushButton("Login")
        self.login_btn.clicked.connect(self.handle_login)
        layout.addWidget(self.login_btn)
        
        # Enable Enter key to login
        self.password_input.returnPressed.connect(self.login_btn.click)

    def handle_login(self):
        username = self.username_input.text().strip()
        password = self.password_input.text().strip()
        
        if not username or not password:
            QMessageBox.warning(self, "Error", "Please enter both username and password.")
            return

        user_data = database.verify_login(username, password)
        
        if user_data:
            user_id, role = user_data
            QMessageBox.information(self, "Success", f"Logged in as {role.capitalize()}!")
            self.open_main_window(role)
        else:
            QMessageBox.critical(self, "Error", "Invalid username or password.")
            
    def open_main_window(self, role):
        # Hide the login window and show the main POS interface
        # In a real app, we would launch the main window here.
        # For now, we print role and just close.
        print(f"Logged in successfully. Role: {role}")
        
        from app import ArcherPOS
        self.main_window = ArcherPOS(role)
        self.main_window.show()
        self.close()

if __name__ == "__main__":
    database.init_db()  # Ensure DB is initialized
    app = QApplication(sys.argv)
    window = LoginWindow()
    window.show()
    sys.exit(app.exec())
