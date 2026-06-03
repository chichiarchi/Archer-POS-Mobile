import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/database/database_helper.dart';
import '../../core/utils/constants.dart';
import '../../core/utils/formatters.dart';

class LogsScreen extends StatefulWidget {
  final String userRole;
  final String username;

  const LogsScreen({
    super.key,
    required this.userRole,
    this.username = 'system',
  });

  @override
  State<LogsScreen> createState() => LogsScreenState();
}

class LogsScreenState extends State<LogsScreen> {
  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = false;
  DateTime _dateFrom = DateTime.now();
  DateTime _dateTo = DateTime.now();
  int _currentPage = 0;
  static const int _pageSize = 100;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  void refresh() {
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final dfStr = DateFormat('yyyy-MM-dd').format(_dateFrom);
      final dtStr = DateFormat('yyyy-MM-dd').format(_dateTo);
      
      // Load logs from DB using filter.
      final allLogs = await DatabaseHelper.instance.getLogs(dateFrom: dfStr, dateTo: dtStr);
      
      if (mounted) {
        setState(() {
          _logs = allLogs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('Error loading logs: $e', isError: true);
      }
    }
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.inter(color: Colors.white)),
        backgroundColor: isError ? kErrorColor : kSuccessColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _selectDateRange() async {
    final pickedRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2025),
      lastDate: DateTime(2030),
      initialDateRange: DateTimeRange(start: _dateFrom, end: _dateTo),
    );

    if (pickedRange != null) {
      setState(() {
        _dateFrom = pickedRange.start;
        _dateTo = pickedRange.end;
        _currentPage = 0;
      });
      _loadLogs();
    }
  }

  int _extractSaleId(String details) {
    // Parse "Sale #123" or similar.
    final exp = RegExp(r'#(\d+)');
    final match = exp.firstMatch(details);
    if (match != null) {
      return int.tryParse(match.group(1) ?? '') ?? 0;
    }
    return 0;
  }

  Future<bool> _verifyAdminPermission() async {
    if (widget.userRole == 'admin' || widget.userRole == 'owner') return true;

    // Prompt for admin credentials or master recovery code
    final textController = TextEditingController();
    bool obscureText = true;
    bool verified = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Admin Verification Required', style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Please enter the master recovery code or an admin password to complete this action.',
                style: GoogleFonts.inter(fontSize: 13, color: kTextSecondary),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: textController,
                obscureText: obscureText,
                decoration: InputDecoration(
                  labelText: 'Master Code or Admin Password',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  suffixIcon: IconButton(
                    icon: Icon(obscureText ? Icons.visibility_off : Icons.visibility),
                    onPressed: () {
                      setDialogState(() {
                        obscureText = !obscureText;
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Cancel', style: GoogleFonts.inter(color: kTextSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor),
              onPressed: () async {
                final input = textController.text.trim();
                if (input == kMasterRecoveryCode) {
                  verified = true;
                  Navigator.of(ctx).pop();
                  return;
                }
                
                // Try to verify against all admin users
                final db = await DatabaseHelper.instance.database;
                final admins = await db.query('users', where: 'role = ?', whereArgs: ['admin']);
                for (final admin in admins) {
                  final username = admin['username'] as String;
                  final successUser = await DatabaseHelper.instance.verifyLogin(username, input);
                  if (successUser != null) {
                    verified = true;
                    break;
                  }
                }

                if (verified) {
                  Navigator.of(ctx).pop();
                } else {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Invalid code or admin password.'), backgroundColor: kErrorColor),
                  );
                }
              },
              child: Text('Verify', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );

    return verified;
  }

  Future<void> _handleRowTap(Map<String, dynamic> log) async {
    final action = log['action'] as String;
    if (action != 'POS_SALE' && action != 'VOID_SALE') return;

    final saleId = _extractSaleId(log['details'] as String? ?? '');
    if (saleId == 0) return;

    // Load sale details
    final db = await DatabaseHelper.instance.database;
    final sales = await db.query('sales', where: 'id = ?', whereArgs: [saleId]);
    if (sales.isEmpty) {
      _showSnackBar('Sale records not found for ID #$saleId.', isError: true);
      return;
    }

    final sale = sales.first;
    final items = await DatabaseHelper.instance.getSaleItems(saleId);
    final payments = await DatabaseHelper.instance.getSalePayments(saleId);
    final customerName = await () async {
      final custId = sale['customer_id'] as int?;
      if (custId != null) {
        final c = await DatabaseHelper.instance.getCustomerById(custId);
        return c?['name'] as String?;
      }
      return null;
    }();

    if (!mounted) return;

    // Show Receipt Preview bottom sheet
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final total = (sale['total_amount'] as num).toDouble();
        final paid = (sale['amount_paid'] as num).toDouble();
        final balance = (sale['balance_due'] as num).toDouble();
        final change = paid > total ? paid - total : 0.0;
        final voided = (sale['voided'] as int? ?? 0) == 1;

        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          expand: false,
          builder: (ctx2, scrollController) => Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Receipt Preview',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 18),
                    ),
                    if (voided)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: kErrorColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: kErrorColor),
                        ),
                        child: Text(
                          'VOIDED',
                          style: GoogleFonts.inter(color: kErrorColor, fontWeight: FontWeight.w800, fontSize: 11),
                        ),
                      ),
                  ],
                ),
                const Divider(height: 24),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    children: [
                      Center(
                        child: Text(
                          kSystemTitle.toUpperCase(),
                          style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 22, color: kPrimaryColor),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text('Sale ID: #$saleId', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                      Text('Date: ${formatDateTime(sale['timestamp'] as String)}'),
                      if (customerName != null) Text('Customer: $customerName'),
                      const Divider(height: 24),
                      Text('ITEMS:', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13, color: kTextSecondary)),
                      const SizedBox(height: 8),
                      ...items.map((item) {
                        final qty = (item['quantity'] as num).toDouble();
                        final price = (item['price'] as num).toDouble();
                        final sub = qty * price;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text('${item['product_name']} (x$qty)'),
                              ),
                              Text(formatCurrency(sub)),
                            ],
                          ),
                        );
                      }),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('TOTAL DUE:', style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
                          Text(formatCurrency(total), style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 18, color: kPrimaryColor)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Amount Paid:'),
                          Text(formatCurrency(paid)),
                        ],
                      ),
                      if (balance > 0)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Balance Due:', style: GoogleFonts.inter(color: kErrorColor, fontWeight: FontWeight.w700)),
                            Text(formatCurrency(balance), style: GoogleFonts.inter(color: kErrorColor, fontWeight: FontWeight.w700)),
                          ],
                        )
                      else
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Change:'),
                            Text(formatCurrency(change)),
                          ],
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (!voided)
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: kErrorColor,
                            side: const BorderSide(color: kErrorColor),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: () async {
                            final verify = await _verifyAdminPermission();
                            if (verify) {
                              final success = await DatabaseHelper.instance.voidSale(saleId, widget.username);
                              if (success) {
                                await DatabaseHelper.instance.logAction(
                                  kActionVoidSale,
                                  details: 'Voided sale #$saleId',
                                  userId: widget.username,
                                );
                                Navigator.of(ctx).pop();
                                _showSnackBar('Sale #$saleId voided successfully!');
                                _loadLogs();
                              } else {
                                _showSnackBar('Failed to void sale.', isError: true);
                              }
                            }
                          },
                          icon: const Icon(Icons.block, size: 18),
                          label: Text('VOID SALE', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                        ),
                      ),
                    if (!voided) const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPrimaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          _showSnackBar('Sent receipt details to thermal printer! 🖨️');
                        },
                        icon: const Icon(Icons.print, size: 18),
                        label: Text('REPRINT RECEIPT', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Paginate logs
    final startIndex = _currentPage * _pageSize;
    final endIndex = (startIndex + _pageSize).clamp(0, _logs.length);
    final paginatedLogs = _logs.sublist(startIndex, endIndex);

    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        title: Text(
          'System Activity Logs',
          style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 20, color: kTextPrimary),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range, color: kPrimaryColor),
            onPressed: _selectDateRange,
            tooltip: 'Filter Date Range',
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: kPrimaryColor),
            onPressed: _loadLogs,
            tooltip: 'Refresh Logs',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Range: ${DateFormat('MMM dd, yyyy').format(_dateFrom)} - ${DateFormat('MMM dd, yyyy').format(_dateTo)}',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: kTextSecondary),
                ),
                Text(
                  'Total logs: ${_logs.length}',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: kPrimaryColor),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _logs.isEmpty
                    ? Center(
                        child: Text(
                          'No audit logs found for this date range.',
                          style: GoogleFonts.inter(color: kTextSecondary),
                        ),
                      )
                    : ListView.builder(
                        itemCount: paginatedLogs.length,
                        itemBuilder: (ctx, index) {
                          final log = paginatedLogs[index];
                          final action = log['action'] as String? ?? '';
                          final user = log['user_id'] as String? ?? log['username'] as String? ?? 'system';
                          final details = log['details'] as String? ?? '';
                          final timestamp = log['timestamp'] as String? ?? '';

                          Color actionColor = kPrimaryColor;
                          IconData actionIcon = Icons.info_outline;

                          if (action.contains('SALE')) {
                            actionColor = kSuccessColor;
                            actionIcon = Icons.point_of_sale;
                          } else if (action.contains('VOID')) {
                            actionColor = kErrorColor;
                            actionIcon = Icons.block;
                          } else if (action.contains('PRODUCT')) {
                            actionColor = Colors.orange;
                            actionIcon = Icons.inventory;
                          } else if (action.contains('PASSWORD') || action.contains('LOGIN')) {
                            actionColor = Colors.purple;
                            actionIcon = Icons.security;
                          }

                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            child: ListTile(
                              onTap: () => _handleRowTap(log),
                              leading: CircleAvatar(
                                backgroundColor: actionColor.withOpacity(0.1),
                                child: Icon(actionIcon, color: actionColor),
                              ),
                              title: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    action,
                                    style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13, color: actionColor),
                                  ),
                                  Text(
                                    formatDateTime(timestamp),
                                    style: GoogleFonts.inter(fontSize: 11, color: kTextSecondary),
                                  ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(
                                    details,
                                    style: GoogleFonts.inter(color: kTextPrimary, fontSize: 13, fontWeight: FontWeight.w500),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'User: $user',
                                    style: GoogleFonts.inter(fontSize: 11, color: kTextSecondary, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                              trailing: (action == 'POS_SALE' || action == 'VOID_SALE')
                                  ? const Icon(Icons.receipt, color: kTextSecondary)
                                  : null,
                            ),
                          );
                        },
                      ),
          ),
          if (_logs.length > _pageSize)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              color: Colors.white,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios, size: 16),
                    onPressed: _currentPage > 0
                        ? () {
                            setState(() {
                              _currentPage--;
                            });
                          }
                        : null,
                  ),
                  Text(
                    'Page ${_currentPage + 1} of ${(_logs.length / _pageSize).ceil()}',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_ios, size: 16),
                    onPressed: (_currentPage + 1) * _pageSize < _logs.length
                        ? () {
                            setState(() {
                              _currentPage++;
                            });
                          }
                        : null,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
