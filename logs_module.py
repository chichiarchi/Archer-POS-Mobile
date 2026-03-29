from PySide6.QtWidgets import (
    QWidget, QVBoxLayout, QTableWidget, QTableWidgetItem, QHeaderView, 
    QPushButton, QHBoxLayout, QLabel, QDateEdit
)
from PySide6.QtCore import Qt, QDate
from PySide6.QtGui import QShortcut, QKeySequence
import database

class LogsModule(QWidget):
    def __init__(self, user_role="staff"):
        super().__init__()
        self.user_role = user_role
        self.setup_ui()

    def setup_ui(self):
        layout = QVBoxLayout(self)
        
        # Actions
        top_layout = QHBoxLayout()
        
        # Date Filters
        top_layout.addWidget(QLabel("From:"))
        self.date_from = QDateEdit()
        self.date_from.setCalendarPopup(True)
        self.date_from.setDate(QDate.currentDate())
        self.date_from.dateChanged.connect(self.load_logs)
        top_layout.addWidget(self.date_from)
        
        top_layout.addWidget(QLabel("To:"))
        self.date_to = QDateEdit()
        self.date_to.setCalendarPopup(True)
        self.date_to.setDate(QDate.currentDate())
        self.date_to.dateChanged.connect(self.load_logs)
        top_layout.addWidget(self.date_to)

        self.btn_refresh = QPushButton("Refresh Logs (Ctrl+R)")
        self.btn_refresh.clicked.connect(self.load_logs)
        QShortcut(QKeySequence("Ctrl+R"), self).activated.connect(self.load_logs)
        top_layout.addWidget(self.btn_refresh)
        
        top_layout.addStretch()
        layout.addLayout(top_layout)

        # Logs Table
        self.logs_table = QTableWidget(0, 4)
        self.logs_table.setHorizontalHeaderLabels(["Timestamp", "User Role", "Action", "Details"])
        self.logs_table.horizontalHeader().setSectionResizeMode(3, QHeaderView.Stretch)
        self.logs_table.setEditTriggers(QTableWidget.NoEditTriggers)
        layout.addWidget(self.logs_table)

        self.load_logs()

    def load_logs(self):
        date_from_str = self.date_from.date().toString("yyyy-MM-dd")
        date_to_str = self.date_to.date().toString("yyyy-MM-dd")

        conn = database.get_connection()
        cursor = conn.cursor()
        cursor.execute("""
            SELECT timestamp, user_id, action, details 
            FROM audit_logs 
            WHERE DATE(timestamp) BETWEEN ? AND ?
            ORDER BY id DESC 
            LIMIT 500
        """, (date_from_str, date_to_str))
        rows = cursor.fetchall()
        conn.close()

        self.logs_table.setRowCount(0)
        for i, row in enumerate(rows):
            self.logs_table.insertRow(i)
            self.logs_table.setItem(i, 0, QTableWidgetItem(str(row[0])))
            self.logs_table.setItem(i, 1, QTableWidgetItem(str(row[1])))
            self.logs_table.setItem(i, 2, QTableWidgetItem(str(row[2])))
            self.logs_table.setItem(i, 3, QTableWidgetItem(str(row[3]) if row[3] else ""))
