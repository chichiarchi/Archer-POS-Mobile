import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/database/database_helper.dart';
import '../../core/utils/constants.dart';
import '../../core/utils/formatters.dart';

class BalanceScreen extends StatefulWidget {
  final String userRole;
  final String username;

  const BalanceScreen({
    super.key,
    required this.userRole,
    this.username = 'system',
  });

  @override
  State<BalanceScreen> createState() => BalanceScreenState();
}

class BalanceScreenState extends State<BalanceScreen> {
  List<Map<String, dynamic>> _debtors = [];
  bool _isLoading = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadBalances();
  }

  void refresh() {
    _loadBalances();
  }

  Future<void> _loadBalances() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final list = await DatabaseHelper.instance.getDebtors();
      if (mounted) {
        setState(() {
          _debtors = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('Error loading balances: $e', isError: true);
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

  void _resolveBalance(Map<String, dynamic> debtor) {
    final customerId = debtor['customer_id'] as int;
    final customerName = debtor['name'] as String;
    final currentBalance = (debtor['balance_amount'] as num).toDouble();
    final salesCount = debtor['sales_count'] as int? ?? 1;

    final TextEditingController amountController = TextEditingController();
    double paymentAmount = 0.0;
    double change = 0.0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final theme = Theme.of(context);
          final cs = theme.colorScheme;
          final isDark = theme.brightness == Brightness.dark;
          final successColor = isDark ? const Color(0xFF34D399) : const Color(0xFF059669);

          amountController.addListener(() {
            final amt = parseAmount(amountController.text);
            setDialogState(() {
              paymentAmount = amt;
              change = amt > currentBalance ? amt - currentBalance : 0.0;
            });
          });

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(
              'Resolve Balance',
              style: GoogleFonts.inter(fontWeight: FontWeight.w800),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  customerName,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: cs.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Unpaid Transactions: $salesCount',
                  style: GoogleFonts.inter(fontSize: 13, color: cs.onSurface.withOpacity(0.6)),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cs.error.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: cs.error.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'TOTAL BALANCE DUE',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: cs.error,
                          letterSpacing: 0.8,
                        ),
                      ),
                      Text(
                        formatCurrency(currentBalance),
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          color: cs.error,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: amountController,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Payment Amount (₱) *',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: Icon(Icons.payments_outlined, color: successColor),
                  ),
                ),
                if (paymentAmount > 0) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: successColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: successColor.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          paymentAmount >= currentBalance ? 'CHANGE' : 'NEW BALANCE',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: successColor,
                          ),
                        ),
                        Text(
                          paymentAmount >= currentBalance 
                              ? formatCurrency(change) 
                              : formatCurrency(currentBalance - paymentAmount),
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color: successColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text('Cancel', style: GoogleFonts.inter(color: cs.onSurface.withOpacity(0.6), fontWeight: FontWeight.w600)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () async {
                  if (paymentAmount <= 0) {
                    _showSnackBar('Please enter a valid payment amount.', isError: true);
                    return;
                  }

                  try {
                    final success = await DatabaseHelper.instance.resolveCustomerBalance(
                      customerId,
                      paymentAmount,
                    );

                    if (success) {
                      await DatabaseHelper.instance.logAction(
                        'BALANCE_RESOLVE',
                        details: 'Resolved balance. Customer: $customerName. Paid: ${formatCurrency(paymentAmount)}',
                        userId: widget.username,
                      );
                      Navigator.of(ctx).pop();
                      _showSnackBar(
                        paymentAmount >= currentBalance
                            ? 'Balance resolved fully! Change: ${formatCurrency(change)}'
                            : 'Partial payment received. Remaining balance: ${formatCurrency(currentBalance - paymentAmount)}',
                      );
                      _loadBalances();
                    } else {
                      _showSnackBar('Failed to update balance.', isError: true);
                    }
                  } catch (e) {
                    _showSnackBar('Error resolving balance: $e', isError: true);
                  }
                },
                child: Text('Confirm', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final successColor = isDark ? const Color(0xFF34D399) : const Color(0xFF059669);

    final filteredDebtors = _debtors.where((d) {
      final name = (d['name'] as String? ?? '').toLowerCase();
      final phone = (d['phone'] as String? ?? '').toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query) || phone.contains(query);
    }).toList();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Debtor Balances',
          style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 20, color: cs.onSurface),
        ),
        backgroundColor: cs.surface,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(68),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            color: cs.surface,
            child: TextField(
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search by Customer Name or Phone...',
                prefixIcon: Icon(Icons.search, color: cs.onSurface.withOpacity(0.6)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : filteredDebtors.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.assignment_turned_in_outlined, size: 64, color: cs.onSurface.withOpacity(0.4)),
                      const SizedBox(height: 16),
                      Text(
                        'No outstanding balances found.',
                        style: GoogleFonts.inter(
                          color: cs.onSurface.withOpacity(0.6),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final isTablet = constraints.maxWidth >= 768;
                    Widget listWidget = ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredDebtors.length,
                      itemBuilder: (ctx, index) {
                        final debtor = filteredDebtors[index];
                        final name = debtor['name'] as String? ?? '';
                        final phone = debtor['phone'] as String? ?? 'No phone';
                        final salesCount = debtor['sales_count'] as int? ?? 0;
                        final date = debtor['created_at'] as String? ?? '';
                        final balance = (debtor['balance_amount'] as num?)?.toDouble() ?? 0.0;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                          ),
                          elevation: 0,
                          color: cs.surface,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => _resolveBalance(debtor),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          name,
                                          style: GoogleFonts.inter(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                            color: cs.onSurface,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        formatCurrency(balance),
                                        style: GoogleFonts.inter(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w900,
                                          color: cs.error,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(Icons.phone, size: 14, color: cs.onSurface.withOpacity(0.6)),
                                      const SizedBox(width: 4),
                                      Text(
                                        phone,
                                        style: GoogleFonts.inter(fontSize: 13, color: cs.onSurface.withOpacity(0.6)),
                                      ),
                                      const Spacer(),
                                      Text(
                                        '$salesCount unpaid sale${salesCount == 1 ? "" : "s"}',
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: cs.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Last Activity: ${formatDateTime(date)}',
                                        style: GoogleFonts.inter(fontSize: 12, color: cs.onSurface.withOpacity(0.5)),
                                      ),
                                      Text(
                                        'Tap to resolve',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: successColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                    // On tablets, center the list with a max-width constraint
                    if (isTablet) {
                      return Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 700),
                          child: listWidget,
                        ),
                      );
                    }
                    return listWidget;
                  },
                ),
    );
  }
}
