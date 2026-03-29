import sqlite3
import hashlib
import os

DB_NAME = "archer_pos.db"

def get_connection():
    return sqlite3.connect(DB_NAME)

def init_db():
    conn = get_connection()
    cursor = conn.cursor()
    
    # Create Users Table
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT UNIQUE NOT NULL,
            password_hash TEXT NOT NULL,
            salt TEXT NOT NULL,
            role TEXT NOT NULL CHECK(role IN ('admin', 'staff'))
        )
    """)
    
    # Create Products Table
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS products (
            id TEXT PRIMARY KEY, -- Using barcode as ID
            name TEXT NOT NULL,
            price REAL NOT NULL,
            cost_price REAL DEFAULT 0,
            category TEXT
        )
    """)
    
    # Create Inventory Table
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS inventory (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            product_id TEXT NOT NULL,
            quantity REAL NOT NULL,
            expiry_date TEXT,
            type TEXT NOT NULL CHECK(type IN ('IN', 'OUT')),
            timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY(product_id) REFERENCES products(id)
        )
    """)
    
    # Create Customers Table
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS customers (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            address TEXT,
            phone TEXT
        )
    """)
    
    # Create Sales Table
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS sales (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            total_amount REAL NOT NULL,
            amount_paid REAL NOT NULL,
            balance_due REAL NOT NULL,
            customer_id INTEGER,
            timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY(customer_id) REFERENCES customers(id)
        )
    """)

    # Create Debtors Table
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS debtors (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            customer_id INTEGER NOT NULL,
            sale_id INTEGER NOT NULL,
            balance_amount REAL NOT NULL,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY(customer_id) REFERENCES customers(id),
            FOREIGN KEY(sale_id) REFERENCES sales(id)
        )
    """)
    
    # Create Audit Logs Table
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS audit_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            action TEXT NOT NULL,
            details TEXT,
            user_id TEXT NOT NULL,
            timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
        )
    """)
    
    # Add an initial admin user if the table is empty
    cursor.execute("SELECT COUNT(*) FROM users")
    if cursor.fetchone()[0] == 0:
        create_user('admin', 'admin', 'admin')

    # Migrations for new columns if the database existed previously
    try:
        cursor.execute("ALTER TABLE products ADD COLUMN cost_price REAL DEFAULT 0")
    except sqlite3.OperationalError:
        pass  # Column already exists

    conn.commit()
    conn.close()
    
    # Run data retention policy to keep only 90 days of logs
    enforce_data_retention_policy()

def enforce_data_retention_policy():
    """
    Implements the '90-day Rolling Window' policy:
    1. Purge: Deletes audit logs older than 90 days.
    2. Compaction: Runs VACUUM to reclaim disk space.
    """
    conn = get_connection()
    cursor = conn.cursor()
    try:
        # Step 1: Identify and remove records from Day 91 and older
        cursor.execute("DELETE FROM audit_logs WHERE timestamp < date('now', '-90 days')")
        deleted_count = cursor.rowcount
        conn.commit()
        
        # Step 2: Perform Database Compaction to reclaim space on the hard drive
        cursor.execute("VACUUM")
        
    except sqlite3.Error as e:
        print(f"Data Retention Policy Error: {e}")
    finally:
        conn.close()

def hash_password(password, salt=None):
    if salt is None:
        salt = os.urandom(16)
    else:
        if isinstance(salt, str):
            salt = bytes.fromhex(salt)
            
    key = hashlib.pbkdf2_hmac(
        'sha256',
        password.encode('utf-8'),
        salt,
        100000
    )
    return key.hex(), salt.hex()

def create_user(username, password, role):
    conn = get_connection()
    cursor = conn.cursor()
    try:
        password_hash, salt = hash_password(password)
        cursor.execute(
            "INSERT INTO users (username, password_hash, salt, role) VALUES (?, ?, ?, ?)",
            (username, password_hash, salt, role)
        )
        conn.commit()
        return True
    except sqlite3.IntegrityError:
        return False
    finally:
        conn.close()

def verify_login(username, password):
    """
    Returns (user_id, role) if successfully verified, else None
    """
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT id, password_hash, salt, role FROM users WHERE username = ?", (username,))
    row = cursor.fetchone()
    conn.close()
    
    if row is None:
        return None
        
    user_id, stored_hash, stored_salt, role = row
    
    # Verify the password
    computed_hash, _ = hash_password(password, stored_salt)
    
    if computed_hash == stored_hash:
        return user_id, role
    return None

def log_action(action, details=None, user_id="system"):
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute(
        "INSERT INTO audit_logs (action, details, user_id, timestamp) VALUES (?, ?, ?, datetime('now', '+8 hours'))",
        (action, details, user_id)
    )
    conn.commit()
    conn.close()

if __name__ == "__main__":
    init_db()
    print("Database initialized successfully.")
