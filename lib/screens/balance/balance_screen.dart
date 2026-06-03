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
    final debtorId = debtor['id'] as int;
    final saleId = debtor['sale_id'] as int;
    final customerName = debtor['name'] as String;
    final currentBalance = (debtor['balance_amount'] as num).toDouble();

    final TextEditingController amountController = TextEditingController();
    double paymentAmount = 0.0;
    double change = 0.0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
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
                    color: kPrimaryColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Sale ID: #$saleId',
                  style: GoogleFonts.inter(fontSize: 13, color: kTextSecondary),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: kErrorColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kErrorColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'BALANCE DUE',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: kErrorColor,
                          letterSpacing: 0.8,
                        ),
                      ),
                      Text(
                        formatCurrency(currentBalance),
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          color: kErrorColor,
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
                    prefixIcon: const Icon(Icons.payments_outlined, color: kSuccessColor),
                  ),
                ),
                if (paymentAmount > 0) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: kSuccessColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: kSuccessColor.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          paymentAmount >= currentBalance ? 'CHANGE' : 'NEW BALANCE',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: kSuccessColor,
                          ),
                        ),
                        Text(
                          paymentAmount >= currentBalance 
                              ? formatCurrency(change) 
                              : formatCurrency(currentBalance - paymentAmount),
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color: kSuccessColor,
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
                child: Text('Cancel', style: GoogleFonts.inter(color: kTextSecondary, fontWeight: FontWeight.w600)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () async {
                  if (paymentAmount <= 0) {
                    _showSnackBar('Please enter a valid payment amount.', isError: true);
                    return;
                  }

                  try {
                    final success = await DatabaseHelper.instance.resolveBalance(
                      debtorId,
                      saleId,
                      paymentAmount,
                      currentBalance,
                    );

                    if (success) {
                      await DatabaseHelper.instance.logAction(
                        'BALANCE_RESOLVE',
                        details: 'Resolved balance for sale #$saleId. Customer: $customerName. Paid: ${formatCurrency(paymentAmount)}',
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
    final filteredDebtors = _debtors.where((d) {
      final name = (d['name'] as String? ?? '').toLowerCase();
      final phone = (d['phone'] as String? ?? '').toLowerCase();
      final saleId = (d['sale_id'] as int? ?? '').toString();
      final query = _searchQuery.toLowerCase();
      return name.contains(query) || phone.contains(query) || saleId.contains(query);
    }).toList();

    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Debtor Balances',
          style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 20, color: kTextPrimary),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.white,
            child: TextField(
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search by Customer Name, Phone, or Sale ID...',
                prefixIcon: const Icon(Icons.search, color: kTextSecondary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: kBorderColor),
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
                      const Icon(Icons.assignment_turned_in_outlined, size: 64, color: kTextSecondary),
                      const SizedBox(height: 16),
                      Text(
                        'No outstanding balances found.',
                        style: GoogleFonts.inter(
                          color: kTextSecondary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredDebtors.length,
                  itemBuilder: (ctx, index) {
                    final debtor = filteredDebtors[index];
                    final name = debtor['name'] as String? ?? '';
                    final phone = debtor['phone'] as String? ?? 'No phone';
                    final saleId = debtor['sale_id'] as int? ?? 0;
                    final date = debtor['created_at'] as String? ?? '';
                    final balance = (debtor['balance_amount'] as num?)?.toDouble() ?? 0.0;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                      color: Colors.white,
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
                                        color: kTextPrimary,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    formatCurrency(balance),
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      color: kErrorColor,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.phone, size: 14, color: kTextSecondary),
                                  const SizedBox(width: 4),
                                  Text(
                                    phone,
                                    style: GoogleFonts.inter(fontSize: 13, color: kTextSecondary),
                                  ),
                                  const Spacer(),
                                  Text(
                                    'Sale #$saleId',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: kPrimaryColor,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Date: ${formatDateTime(date)}',
                                    style: GoogleFonts.inter(fontSize: 12, color: kTextSecondary),
                                  ),
                                  Text(
                                    'Tap to resolve',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: kSuccessColor,
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
                ),
    );
  }
}
