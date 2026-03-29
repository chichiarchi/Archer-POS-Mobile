import sqlite3
import database
from datetime import datetime, timedelta

def simulate_data_retention():
    print("--- 90-Day Retention Policy Simulation ---")
    
    # 1. Clear existing logs for a clean test environment
    conn = database.get_connection()
    cursor = conn.cursor()
    cursor.execute("DELETE FROM audit_logs;")
    conn.commit()
    print("Pre-simulation: Cleared all existing audit logs.")
    
    # 2. Add test logs with various timestamps
    now = datetime.utcnow()
    logs_to_add = [
        ("LOGIN", "Active log (Today)", "admin", now.strftime('%Y-%m-%d %H:%M:%S')),
        ("SALE", "Active log (30 days ago)", "staff", (now - timedelta(days=30)).strftime('%Y-%m-%d %H:%M:%S')),
        ("VOID", "Active log (89 days ago)", "admin", (now - timedelta(days=89)).strftime('%Y-%m-%d %H:%M:%S')),
        ("DELETE", "Expired log (91 days ago)", "admin", (now - timedelta(days=91)).strftime('%Y-%m-%d %H:%M:%S')),
        ("SYSTEM", "Expired log (120 days ago)", "system", (now - timedelta(days=120)).strftime('%Y-%m-%d %H:%M:%S')),
    ]
    
    print(f"Adding {len(logs_to_add)} test logs...")
    for action, details, user_id, timestamp in logs_to_add:
        cursor.execute(
            "INSERT INTO audit_logs (action, details, user_id, timestamp) VALUES (?, ?, ?, ?)",
            (action, details, user_id, timestamp)
        )
    conn.commit()
    
    # Check current count
    cursor.execute("SELECT COUNT(*) FROM audit_logs")
    count_before = cursor.fetchone()[0]
    print(f"Total logs in database BEFORE cleanup: {count_before}")
    
    # 3. Trigger the Retention Policy
    print("\nTriggering the enforce_data_retention_policy()...")
    conn.close() # Close current connection so the cleanup function can run its own
    database.enforce_data_retention_policy()
    
    # 4. Verify the Results
    conn = database.get_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT COUNT(*), action, details FROM audit_logs")
    count_after, last_action, last_details = cursor.fetchone()
    print(f"Total logs in database AFTER cleanup: {count_after}")
    
    # Get remaining items for confirmation
    cursor.execute("SELECT action, details, timestamp FROM audit_logs")
    remaining_logs = cursor.fetchall()
    
    print("\nRemaining Logs in Database:")
    for action, details, ts in remaining_logs:
        print(f"- {action}: {details} (Date: {ts})")
    
    expected_count = 3 # Today, 30d, 89d
    if count_after == expected_count:
        print("\nSUCCESS: Simulation completed successfully. All expired logs were purged.")
    else:
        print(f"\nWARNING: Simulation returned {count_after} logs, expected {expected_count}.")
    
    conn.close()

if __name__ == "__main__":
    simulate_data_retention()
