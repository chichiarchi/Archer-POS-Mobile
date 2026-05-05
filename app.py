import sys
import os
from PySide6.QtWidgets import QApplication, QMainWindow, QTabWidget, QVBoxLayout, QWidget
from PySide6.QtGui import QShortcut, QKeySequence, QIcon
import database
from pos_module import POSModule
from inventory_module import InventoryModule
from dashboard_module import DashboardModule
from balance_module import BalanceModule
from logs_module import LogsModule
from settings_module import SettingsModule

def resource_path(relative_path):
    """ Get absolute path to resource, works for dev and for PyInstaller """
    try:
        base_path = sys._MEIPASS
    except Exception:
        base_path = os.path.abspath(".")
    return os.path.join(base_path, relative_path)

class ArcherPOS(QMainWindow):
    def __init__(self, user_role="staff"):
        super().__init__()
        self.user_role = user_role
        self.setWindowTitle("Archer POS v2 - Dashboard") 
        self.setWindowIcon(QIcon(resource_path("archer_logo.png")))
        self.showMaximized()
        self.setup_ui()

    def setup_ui(self):
        # Modern Light Theme for Main Window
        self.setStyleSheet("""
            QMainWindow {
                background-color: #E8EEF2;
            }
            QWidget {
                background-color: #E8EEF2;
                color: #2B3A4A;
                font-family: 'Segoe UI', 'Inter', sans-serif;
            }
            QTabWidget::pane {
                border: 1px solid #CFD8DC;
                border-top: 3px solid #00C6FF;
                background-color: #FFFFFF;
                border-radius: 8px;
            }
            QTabBar::tab {
                background-color: #DDE4EA;
                color: #5C6B79;
                padding: 12px 24px;
                margin-right: 4px;
                border-top-left-radius: 8px;
                border-top-right-radius: 8px;
                font-weight: 600;
                font-size: 14px;
                border: 1px solid #CFD8DC;
                border-bottom: none;
            }
            QTabBar::tab:selected {
                background-color: #FFFFFF;
                color: #0072FF;
                border-color: #CFD8DC;
                border-top: 3px solid #00C6FF;
            }
            QTabBar::tab:hover:!selected {
                background-color: #E6ECF1;
                color: #0072FF;
            }
            QTableWidget {
                background-color: #FFFFFF;
                alternate-background-color: #F8FAFC;
                gridline-color: #E2E8F0;
                border: 1px solid #E2E8F0;
                border-radius: 8px;
                color: #2D3748;
                font-size: 14px;
            }
            QTableView::item {
                padding: 5px;
            }
            QTableView::item:selected {
                background-color: #E1F5FE;
                color: #005F99;
            }
            QHeaderView::section {
                background-color: #F1F5F9;
                color: #4A5568;
                padding: 10px;
                border: none;
                border-bottom: 2px solid #CBD5E1;
                border-right: 1px solid #F1F5F9;
                font-weight: 700;
                font-size: 13px;
                text-transform: uppercase;
            }
            QLineEdit {
                background-color: #FFFFFF;
                border: 1px solid #CBD5E1;
                border-radius: 6px;
                padding: 10px 14px;
                color: #2D3748;
                font-size: 14px;
            }
            QDateEdit, QDoubleSpinBox {
                background-color: #FFFFFF;
                border: 1px solid #CBD5E1;
                border-radius: 6px;
                padding: 4px 34px 4px 8px; /* Leave space on the right for buttons */
                color: #2D3748;
                font-size: 14px;
                min-height: 28px;
            }
            QDoubleSpinBox::up-button, QDateEdit::up-button {
                subcontrol-origin: border;
                subcontrol-position: top right;
                width: 26px;
                border-left: 1px solid #CBD5E1;
                border-bottom: 1px solid #CBD5E1;
                background-color: #F8FAFC;
                border-top-right-radius: 6px;
            }
            QDoubleSpinBox::down-button, QDateEdit::down-button {
                subcontrol-origin: border;
                subcontrol-position: bottom right;
                width: 26px;
                border-left: 1px solid #CBD5E1;
                background-color: #F8FAFC;
                border-bottom-right-radius: 6px;
            }
            QDoubleSpinBox::up-button:hover, QDateEdit::up-button:hover, QDoubleSpinBox::down-button:hover, QDateEdit::down-button:hover {
                background-color: #E2E8F0;
            }
            QDoubleSpinBox::up-arrow, QDateEdit::up-arrow {
                image: url(up_arrow.svg);
                width: 12px;
                height: 12px;
            }
            QDoubleSpinBox::down-arrow, QDateEdit::down-arrow {
                image: url(down_arrow.svg);
                width: 12px;
                height: 12px;
            }
            QLineEdit:focus, QDateEdit:focus, QDoubleSpinBox:focus {
                border: 2px solid #00C6FF;
                background-color: #FFFFFF;
            }
            QPushButton {
                background-color: #FFFFFF;
                color: #4A5568;
                border: 1px solid #CBD5E1;
                border-radius: 6px;
                padding: 10px 18px;
                font-weight: 600;
                font-size: 13px;
                letter-spacing: 0.5px;
            }
            QPushButton:hover {
                background-color: #F0F9FF;
                border: 1px solid #00C6FF;
                color: #0072FF;
            }
            QPushButton:pressed {
                background-color: #E0F2FE;
            }
            /* Custom Scrollbar */
            QScrollBar:vertical {
                border: none;
                background: #E8EEF2;
                width: 8px;
                margin: 0px 0px 0px 0px;
                border-radius: 4px;
            }
            QScrollBar::handle:vertical {
                background: #CBD5E1;
                min-height: 20px;
                border-radius: 4px;
            }
            QScrollBar::handle:vertical:hover {
                background: #94A3B8;
            }
        """)

        # Central widget and layout
        central_widget = QWidget()
        layout = QVBoxLayout(central_widget)
        
        # Tabs
        self.tabs = QTabWidget()
        self.tabs.setStyleSheet("""
            QTabBar::tab {
                height: 50px;
                width: 180px;
                font-size: 15px;
                font-weight: bold;
            }
        """)
        layout.addWidget(self.tabs)

        # Tab 1: Dashboard
        self.dashboard_tab = DashboardModule(self.user_role)
        self.tabs.addTab(self.dashboard_tab, QIcon(resource_path("archer_logo.png")), "Dashboard (F1)")

        # Tab 2: POS
        self.pos_tab = POSModule(self.user_role)
        self.tabs.addTab(self.pos_tab, QIcon(resource_path("archer_logo.png")), "Point of Sale (F2)")

        # Tab 3: Inventory
        self.inventory_tab = InventoryModule(self.user_role)
        self.tabs.addTab(self.inventory_tab, QIcon(resource_path("archer_logo.png")), "Product Manager (F3)")

        # Tab 4: Balance
        self.balance_tab = BalanceModule(self.user_role)
        self.tabs.addTab(self.balance_tab, QIcon(resource_path("archer_logo.png")), "Balance Manager (F5)")

        # Tab 5: Data Logs
        self.logs_tab = LogsModule(self.user_role)
        self.tabs.addTab(self.logs_tab, QIcon(resource_path("archer_logo.png")), "Data Logs (F6)")

        # # Tab 6: Settings
        # self.settings_tab = SettingsModule(self.user_role)
        # self.tabs.addTab(self.settings_tab, "Settings (F7)")

        # Keyboard shortcuts for Tabs
        QShortcut(QKeySequence("F1"), self).activated.connect(lambda: self.tabs.setCurrentIndex(0))
        QShortcut(QKeySequence("F2"), self).activated.connect(lambda: self.tabs.setCurrentIndex(1))
        QShortcut(QKeySequence("F3"), self).activated.connect(lambda: self.tabs.setCurrentIndex(2))
        QShortcut(QKeySequence("F5"), self).activated.connect(lambda: self.tabs.setCurrentIndex(3))
        QShortcut(QKeySequence("F6"), self).activated.connect(lambda: self.tabs.setCurrentIndex(4))
        QShortcut(QKeySequence("F7"), self).activated.connect(lambda: self.tabs.setCurrentIndex(5))
        
        # Update dashboard elements every time user clicks tabs (Refresh warnings)
        self.tabs.currentChanged.connect(self.on_tab_change)

        self.setCentralWidget(central_widget)

    def on_tab_change(self, index):
        # Refresh Data dynamically if needed
        if index == 0:
            self.dashboard_tab.load_all()
        elif index == 1:
            self.pos_tab.refresh_completer()
            self.pos_tab.search_input.setFocus()
        elif index == 2:
            self.inventory_tab.load_inventory()
        elif index == 3:
            self.balance_tab.load_balances()
        elif index == 4:
            self.logs_tab.reset_dates()
            self.logs_tab.load_logs()

if __name__ == "__main__":
    database.init_db()
    app = QApplication(sys.argv)
    
    # Import and show the login window first
    from login import LoginWindow
    login_window = LoginWindow()
    login_window.show()
    
    sys.exit(app.exec())
