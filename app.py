import sys
from PySide6.QtWidgets import QApplication, QMainWindow, QTabWidget, QVBoxLayout, QWidget
from PySide6.QtGui import QShortcut, QKeySequence
import database
from pos_module import POSModule
from inventory_module import InventoryModule
from dashboard_module import DashboardModule
from balance_module import BalanceModule
from logs_module import LogsModule

class ArcherPOS(QMainWindow):
    def __init__(self, user_role="staff"):
        super().__init__()
        self.user_role = user_role
        self.setWindowTitle("Archer POS v2 - Dashboard")
        self.resize(1000, 700)
        self.setup_ui()

    def setup_ui(self):
        # Modern Light Theme for Main Window
        self.setStyleSheet("""
            QMainWindow {
                background-color: #f8f9fa;
            }
            QWidget {
                background-color: #f8f9fa;
                color: #333333;
                font-family: 'Segoe UI', Arial, sans-serif;
            }
            QTabWidget::pane {
                border-top: 2px solid #0ea5e9;
                background-color: #ffffff;
            }
            QTabBar::tab {
                background-color: #e9ecef;
                color: #495057;
                padding: 10px 20px;
                margin-right: 2px;
                border-top-left-radius: 4px;
                border-top-right-radius: 4px;
                font-weight: bold;
                font-size: 14px;
                border: 1px solid #ced4da;
                border-bottom: none;
            }
            QTabBar::tab:selected {
                background-color: #0ea5e9;
                color: #ffffff;
                border-color: #0ea5e9;
            }
            QTabBar::tab:hover:!selected {
                background-color: #dee2e6;
            }
            QTableWidget {
                background-color: #ffffff;
                alternate-background-color: #f8f9fa;
                gridline-color: #dee2e6;
                border: 1px solid #ced4da;
                color: #333333;
            }
            QHeaderView::section {
                background-color: #e9ecef;
                color: #495057;
                padding: 5px;
                border: 1px solid #ced4da;
                font-weight: bold;
            }
            QLineEdit, QDateEdit {
                background-color: #ffffff;
                border: 1px solid #ced4da;
                border-radius: 4px;
                padding: 6px;
                color: #333333;
            }
            QLineEdit:focus, QDateEdit:focus {
                border: 2px solid #0ea5e9;
            }
            QPushButton {
                background-color: #ffffff;
                color: #333333;
                border: 1px solid #ced4da;
                border-radius: 6px;
                padding: 8px 16px;
                font-weight: bold;
            }
            QPushButton:hover {
                background-color: #e9ecef;
                border: 1px solid #0ea5e9;
            }
        """)

        # Central widget and layout
        central_widget = QWidget()
        layout = QVBoxLayout(central_widget)
        
        # Tabs
        self.tabs = QTabWidget()
        layout.addWidget(self.tabs)

        # Tab 1: Dashboard
        self.dashboard_tab = DashboardModule(self.user_role)
        self.tabs.addTab(self.dashboard_tab, "Dashboard (F1)")

        # Tab 2: POS
        self.pos_tab = POSModule(self.user_role)
        self.tabs.addTab(self.pos_tab, "Point of Sale (F2)")

        # Tab 3: Inventory
        self.inventory_tab = InventoryModule(self.user_role)
        self.tabs.addTab(self.inventory_tab, "Stock Manager (F3)")

        # Tab 4: Balance
        self.balance_tab = BalanceModule(self.user_role)
        self.tabs.addTab(self.balance_tab, "Balance Manager (F5)")

        # Tab 5: Data Logs
        self.logs_tab = LogsModule(self.user_role)
        self.tabs.addTab(self.logs_tab, "Data Logs (F6)")

        # Keyboard shortcuts for Tabs
        QShortcut(QKeySequence("F1"), self).activated.connect(lambda: self.tabs.setCurrentIndex(0))
        QShortcut(QKeySequence("F2"), self).activated.connect(lambda: self.tabs.setCurrentIndex(1))
        QShortcut(QKeySequence("F3"), self).activated.connect(lambda: self.tabs.setCurrentIndex(2))
        QShortcut(QKeySequence("F5"), self).activated.connect(lambda: self.tabs.setCurrentIndex(3))
        QShortcut(QKeySequence("F6"), self).activated.connect(lambda: self.tabs.setCurrentIndex(4))
        
        # Update dashboard elements every time user clicks tabs (Refresh warnings)
        self.tabs.currentChanged.connect(self.on_tab_change)

        self.setCentralWidget(central_widget)

    def on_tab_change(self, index):
        # Refresh Data dynamically if needed
        if index == 0:
            self.dashboard_tab.load_all()
        elif index == 1:
            self.pos_tab.search_input.setFocus()
        elif index == 2:
            self.inventory_tab.load_inventory()
        elif index == 3:
            self.balance_tab.load_balances()
        elif index == 4:
            self.logs_tab.load_logs()

if __name__ == "__main__":
    database.init_db()
    app = QApplication(sys.argv)
    
    # Import and show the login window first
    from login import LoginWindow
    login_window = LoginWindow()
    login_window.show()
    
    sys.exit(app.exec())
