import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  static Database? _database;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'archer_pos.db');

    return await openDatabase(
      path,
      version: 3,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT UNIQUE NOT NULL,
        password_hash TEXT NOT NULL,
        salt TEXT NOT NULL,
        role TEXT NOT NULL CHECK(role IN ('admin', 'staff'))
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS products (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        price REAL NOT NULL,
        wholesale_price REAL DEFAULT 0.0,
        cost REAL DEFAULT 0.0,
        category TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS product_bundles (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id TEXT NOT NULL,
        bundle_name TEXT NOT NULL,
        quantity REAL NOT NULL,
        price REAL NOT NULL,
        wholesale_price REAL DEFAULT 0.0,
        cost REAL DEFAULT 0.0,
        FOREIGN KEY(product_id) REFERENCES products(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        address TEXT,
        phone TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS sales (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        total_amount REAL NOT NULL,
        amount_paid REAL NOT NULL,
        balance_due REAL NOT NULL,
        customer_id INTEGER,
        voided INTEGER DEFAULT 0,
        timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(customer_id) REFERENCES customers(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS sale_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_id INTEGER NOT NULL,
        product_id TEXT NOT NULL,
        product_name TEXT NOT NULL,
        quantity REAL NOT NULL,
        price REAL NOT NULL,
        FOREIGN KEY(sale_id) REFERENCES sales(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS debtors (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_id INTEGER NOT NULL,
        sale_id INTEGER NOT NULL,
        balance_amount REAL NOT NULL,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(customer_id) REFERENCES customers(id),
        FOREIGN KEY(sale_id) REFERENCES sales(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS audit_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        action TEXT NOT NULL,
        details TEXT,
        user_id TEXT NOT NULL,
        timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS settings (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS payment_notes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount REAL NOT NULL,
        recipient TEXT NOT NULL,
        purpose TEXT,
        timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS parked_sales (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        label TEXT,
        cart_data TEXT NOT NULL,
        total REAL NOT NULL,
        timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS sale_payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_id INTEGER NOT NULL,
        payment_method TEXT NOT NULL,
        amount REAL NOT NULL,
        timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(sale_id) REFERENCES sales(id)
      )
    ''');

    // Create default admin user
    final result = await _hashPassword('admin');
    await db.insert('users', {
      'username': 'admin',
      'password_hash': result['hash'],
      'salt': result['salt'],
      'role': 'admin',
    });
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle migrations
    if (oldVersion < 2) {
      try {
        await db.execute('ALTER TABLE products ADD COLUMN cost REAL DEFAULT 0.0');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE product_bundles ADD COLUMN cost REAL DEFAULT 0.0');
      } catch (_) {}
    }
  }

  // ────────────── PASSWORD HASHING ──────────────
  static String _generateSalt() {
    final random = DateTime.now().microsecondsSinceEpoch.toString();
    return md5.convert(utf8.encode(random)).toString();
  }

  static Future<Map<String, String>> _hashPassword(String password, [String? salt]) async {
    final s = salt ?? _generateSalt();
    final key = sha256.convert(utf8.encode('$s:$password')).toString();
    return {'hash': key, 'salt': s};
  }

  // ────────────── AUTHENTICATION ──────────────
  Future<Map<String, dynamic>?> verifyLogin(String username, String password) async {
    final db = await database;
    final rows = await db.query(
      'users',
      where: 'username = ?',
      whereArgs: [username],
    );
    if (rows.isEmpty) return null;

    final user = rows.first;
    final result = await _hashPassword(password, user['salt'] as String);
    if (result['hash'] == user['password_hash']) {
      return {'id': user['id'], 'role': user['role'], 'username': user['username']};
    }
    return null;
  }

  Future<bool> createUser(String username, String password, String role) async {
    final db = await database;
    try {
      final result = await _hashPassword(password);
      await db.insert('users', {
        'username': username,
        'password_hash': result['hash'],
        'salt': result['salt'],
        'role': role,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updatePassword(String username, String newPassword) async {
    final db = await database;
    final result = await _hashPassword(newPassword);
    final count = await db.update(
      'users',
      {'password_hash': result['hash'], 'salt': result['salt']},
      where: 'username = ?',
      whereArgs: [username],
    );
    return count > 0;
  }

  Future<Map<String, dynamic>?> getUserByUsername(String username) async {
    final db = await database;
    final rows = await db.query('users', where: 'username = ?', whereArgs: [username]);
    return rows.isEmpty ? null : rows.first;
  }

  Future<List<Map<String, dynamic>>> getAllUsers() async {
    final db = await database;
    return await db.query('users', orderBy: 'username ASC');
  }

  Future<bool> deleteUser(int userId) async {
    final db = await database;
    final count = await db.delete('users', where: 'id = ?', whereArgs: [userId]);
    return count > 0;
  }

  // ────────────── PRODUCTS ──────────────
  Future<List<Map<String, dynamic>>> getProducts({String? search, int limit = 100, int offset = 0}) async {
    final db = await database;
    if (search != null && search.isNotEmpty) {
      final like = '%$search%';
      return await db.rawQuery('''
        SELECT p.*, 
          CASE WHEN EXISTS (SELECT 1 FROM product_bundles WHERE product_id = p.id) 
               THEN 1 ELSE 0 END as has_bundle
        FROM products p
        WHERE p.id LIKE ? OR p.name LIKE ?
        ORDER BY p.name ASC
        LIMIT ? OFFSET ?
      ''', [like, like, limit, offset]);
    }
    return await db.rawQuery('''
      SELECT p.*, 
        CASE WHEN EXISTS (SELECT 1 FROM product_bundles WHERE product_id = p.id) 
             THEN 1 ELSE 0 END as has_bundle
      FROM products p
      ORDER BY p.name ASC
      LIMIT ? OFFSET ?
    ''', [limit, offset]);
  }

  Future<int> getProductCount({String? search}) async {
    final db = await database;
    if (search != null && search.isNotEmpty) {
      final like = '%$search%';
      final result = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM products WHERE id LIKE ? OR name LIKE ?',
        [like, like],
      );
      return (result.first['cnt'] as int?) ?? 0;
    }
    final result = await db.rawQuery('SELECT COUNT(*) as cnt FROM products');
    return (result.first['cnt'] as int?) ?? 0;
  }

  Future<Map<String, dynamic>?> getProductById(String id) async {
    final db = await database;
    final rows = await db.query('products', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : rows.first;
  }

  Future<bool> insertProduct(Map<String, dynamic> product) async {
    final db = await database;
    try {
      await db.insert('products', product, conflictAlgorithm: ConflictAlgorithm.abort);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateProduct(String id, Map<String, dynamic> product) async {
    final db = await database;
    final count = await db.update('products', product, where: 'id = ?', whereArgs: [id]);
    return count > 0;
  }

  Future<bool> deleteProduct(String id) async {
    final db = await database;
    final count = await db.delete('products', where: 'id = ?', whereArgs: [id]);
    return count > 0;
  }

  // ────────────── BUNDLES ──────────────
  Future<List<Map<String, dynamic>>> getBundlesForProduct(String productId) async {
    final db = await database;
    return await db.query('product_bundles', where: 'product_id = ?', whereArgs: [productId]);
  }

  Future<bool> insertBundle(Map<String, dynamic> bundle) async {
    final db = await database;
    try {
      await db.insert('product_bundles', bundle);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateBundle(int id, Map<String, dynamic> bundle) async {
    final db = await database;
    final count = await db.update('product_bundles', bundle, where: 'id = ?', whereArgs: [id]);
    return count > 0;
  }

  Future<bool> deleteBundle(int id) async {
    final db = await database;
    final count = await db.delete('product_bundles', where: 'id = ?', whereArgs: [id]);
    return count > 0;
  }

  // ────────────── CUSTOMERS ──────────────
  Future<List<Map<String, dynamic>>> getCustomers({String? search}) async {
    final db = await database;
    if (search != null && search.isNotEmpty) {
      final like = '%$search%';
      return await db.query('customers',
          where: 'name LIKE ? OR phone LIKE ?', whereArgs: [like, like], orderBy: 'name ASC');
    }
    return await db.query('customers', orderBy: 'name ASC');
  }

  Future<int> insertCustomer(Map<String, dynamic> customer) async {
    final db = await database;
    return await db.insert('customers', customer);
  }

  Future<Map<String, dynamic>?> getCustomerById(int id) async {
    final db = await database;
    final rows = await db.query('customers', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : rows.first;
  }

  // ────────────── SALES ──────────────
  Future<int> createSale({
    required double totalAmount,
    required double amountPaid,
    required double balanceDue,
    int? customerId,
    required List<Map<String, dynamic>> items,
    List<Map<String, dynamic>>? payments,
  }) async {
    final db = await database;
    return await db.transaction((txn) async {
      // Get local time offset (+8 hours for Philippines)
      final now = DateTime.now().toUtc().add(const Duration(hours: 8));
      final timestamp = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

      final saleId = await txn.insert('sales', {
        'total_amount': totalAmount,
        'amount_paid': amountPaid,
        'balance_due': balanceDue,
        'customer_id': customerId,
        'voided': 0,
        'timestamp': timestamp,
      });

      for (final item in items) {
        await txn.insert('sale_items', {
          'sale_id': saleId,
          'product_id': item['product_id'],
          'product_name': item['product_name'],
          'quantity': item['quantity'],
          'price': item['price'],
        });
      }

      if (payments != null) {
        for (final payment in payments) {
          await txn.insert('sale_payments', {
            'sale_id': saleId,
            'payment_method': payment['method'],
            'amount': payment['amount'],
            'timestamp': timestamp,
          });
        }
      }

      // Create debtor record if balance due
      if (balanceDue > 0 && customerId != null) {
        await txn.insert('debtors', {
          'customer_id': customerId,
          'sale_id': saleId,
          'balance_amount': balanceDue,
          'created_at': timestamp,
        });
      }

      return saleId;
    });
  }

  Future<bool> voidSale(int saleId, String userId) async {
    final db = await database;
    final count = await db.update(
      'sales',
      {'voided': 1},
      where: 'id = ?',
      whereArgs: [saleId],
    );
    return count > 0;
  }

  Future<List<Map<String, dynamic>>> getSales({
    String? dateFrom,
    String? dateTo,
    bool includeVoided = false,
    int limit = 100,
    int offset = 0,
  }) async {
    final db = await database;
    String whereClause = includeVoided ? '1=1' : 'voided = 0';
    final List<dynamic> args = [];

    if (dateFrom != null && dateTo != null) {
      whereClause += ' AND DATE(timestamp) BETWEEN ? AND ?';
      args.addAll([dateFrom, dateTo]);
    }

    return await db.rawQuery('''
      SELECT s.*, c.name as customer_name
      FROM sales s
      LEFT JOIN customers c ON s.customer_id = c.id
      WHERE $whereClause
      ORDER BY s.timestamp DESC
      LIMIT ? OFFSET ?
    ''', [...args, limit, offset]);
  }

  Future<List<Map<String, dynamic>>> getSaleItems(int saleId) async {
    final db = await database;
    return await db.query('sale_items', where: 'sale_id = ?', whereArgs: [saleId]);
  }

  Future<List<Map<String, dynamic>>> getSalePayments(int saleId) async {
    final db = await database;
    return await db.query('sale_payments', where: 'sale_id = ?', whereArgs: [saleId]);
  }

  // ────────────── DASHBOARD STATS ──────────────
  Future<Map<String, dynamic>> getDashboardStats() async {
    final db = await database;
    final now = DateTime.now().toUtc().add(const Duration(hours: 8));
    final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final salesResult = await db.rawQuery(
      "SELECT SUM(total_amount) as total, COUNT(*) as count FROM sales WHERE DATE(timestamp) = ? AND voided = 0",
      [today],
    );
    final productCount = await db.rawQuery('SELECT COUNT(*) as cnt FROM products');
    final balanceResult = await db.rawQuery('SELECT SUM(balance_amount) as total FROM debtors');

    return {
      'sales_today': (salesResult.first['total'] as num?)?.toDouble() ?? 0.0,
      'transactions_today': (salesResult.first['count'] as int?) ?? 0,
      'total_products': (productCount.first['cnt'] as int?) ?? 0,
      'total_balance': (balanceResult.first['total'] as num?)?.toDouble() ?? 0.0,
    };
  }

  // ────────────── DEBTORS / BALANCE ──────────────
  Future<List<Map<String, dynamic>>> getDebtors() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT d.id, c.name, c.phone, d.sale_id, d.created_at, d.balance_amount
      FROM debtors d
      JOIN customers c ON d.customer_id = c.id
      WHERE d.balance_amount > 0
      ORDER BY d.created_at DESC
    ''');
  }

  Future<bool> resolveBalance(int debtorId, int saleId, double paymentAmount, double currentBalance) async {
    final db = await database;
    final newBalance = (currentBalance - paymentAmount).clamp(0.0, double.infinity);
    final actualPayment = paymentAmount > currentBalance ? currentBalance : paymentAmount;

    await db.transaction((txn) async {
      await txn.update('debtors', {'balance_amount': newBalance},
          where: 'id = ?', whereArgs: [debtorId]);

      final sales = await txn.query('sales', where: 'id = ?', whereArgs: [saleId]);
      if (sales.isNotEmpty) {
        final sale = sales.first;
        final newPaid = (sale['amount_paid'] as num).toDouble() + actualPayment;
        await txn.update(
          'sales',
          {'amount_paid': newPaid, 'balance_due': newBalance},
          where: 'id = ?',
          whereArgs: [saleId],
        );
      }
    });
    return true;
  }

  // ────────────── AUDIT LOGS ──────────────
  Future<void> logAction(String action, {String? details, String userId = 'system'}) async {
    final db = await database;
    final now = DateTime.now().toUtc().add(const Duration(hours: 8));
    final timestamp = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    
    await db.insert('audit_logs', {
      'action': action,
      'details': details,
      'user_id': userId,
      'timestamp': timestamp,
    });
  }

  Future<List<Map<String, dynamic>>> getLogs({String? dateFrom, String? dateTo}) async {
    final db = await database;
    if (dateFrom != null && dateTo != null) {
      return await db.rawQuery(
        "SELECT * FROM audit_logs WHERE DATE(timestamp) BETWEEN ? AND ? ORDER BY timestamp DESC",
        [dateFrom, dateTo],
      );
    }
    return await db.query('audit_logs', orderBy: 'timestamp DESC', limit: 500);
  }

  Future<void> enforceDataRetention() async {
    final db = await database;
    await db.delete('audit_logs',
        where: "timestamp < date('now', '-90 days')");
  }

  // ────────────── SETTINGS ──────────────
  Future<String?> getSetting(String key) async {
    final db = await database;
    final rows = await db.query('settings', where: 'key = ?', whereArgs: [key]);
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert('settings', {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ────────────── PAYMENT NOTES ──────────────
  Future<List<Map<String, dynamic>>> getPaymentNotes({String? dateFrom, String? dateTo}) async {
    final db = await database;
    if (dateFrom != null && dateTo != null) {
      return await db.rawQuery(
        "SELECT * FROM payment_notes WHERE DATE(timestamp) BETWEEN ? AND ? ORDER BY timestamp DESC",
        [dateFrom, dateTo],
      );
    }
    return await db.query('payment_notes', orderBy: 'timestamp DESC');
  }

  Future<void> addPaymentNote(double amount, String recipient, String? purpose, String? timestamp) async {
    final db = await database;
    final ts = timestamp ?? () {
      final now = DateTime.now().toUtc().add(const Duration(hours: 8));
      return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    }();
    
    await db.insert('payment_notes', {
      'amount': amount,
      'recipient': recipient,
      'purpose': purpose,
      'timestamp': ts,
    });
  }

  Future<void> deletePaymentNote(int id) async {
    final db = await database;
    await db.delete('payment_notes', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<String>> getDistinctRecipients() async {
    final db = await database;
    final rows = await db.rawQuery('SELECT DISTINCT recipient FROM payment_notes ORDER BY recipient ASC');
    return rows.map((r) => r['recipient'] as String).toList();
  }

  // ────────────── PARKED SALES ──────────────
  Future<List<Map<String, dynamic>>> getParkedSales() async {
    final db = await database;
    return await db.query('parked_sales', orderBy: 'timestamp DESC');
  }

  Future<int> parkSale(String? label, String cartData, double total) async {
    final db = await database;
    final now = DateTime.now().toUtc().add(const Duration(hours: 8));
    final timestamp = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    return await db.insert('parked_sales', {
      'label': label,
      'cart_data': cartData,
      'total': total,
      'timestamp': timestamp,
    });
  }

  Future<void> deleteParkedSale(int id) async {
    final db = await database;
    await db.delete('parked_sales', where: 'id = ?', whereArgs: [id]);
  }
}
