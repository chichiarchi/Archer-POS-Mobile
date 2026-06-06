import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/utils/constants.dart';
import '../../../core/utils/formatters.dart';

class CheckoutDialog extends StatefulWidget {
  final double total;
  final String userRole;
  final String username;

  const CheckoutDialog({
    super.key,
    required this.total,
    required this.userRole,
    required this.username,
  });

  @override
  State<CheckoutDialog> createState() => _CheckoutDialogState();
}

class _CheckoutDialogState extends State<CheckoutDialog> {
  final TextEditingController _cashController = TextEditingController();
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _customerPhoneController = TextEditingController();
  final TextEditingController _customerAddressController = TextEditingController();
  
  List<Map<String, dynamic>> _allCustomers = [];
  int? _selectedCustomerId;
  bool _isNewCustomer = false;
  double _amountPaid = 0.0;
  double _balanceDue = 0.0;
  double _change = 0.0;
  double _existingDebtorDebt = 0.0;

  @override
  void initState() {
    super.initState();
    _cashController.addListener(_onCashChanged);
    _loadCustomers();
  }

  @override
  void dispose() {
    _cashController.dispose();
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _customerAddressController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomers() async {
    final list = await DatabaseHelper.instance.getCustomers();
    setState(() {
      _allCustomers = list;
    });
  }

  void _onCashChanged() {
    final cash = parseAmount(_cashController.text);
    setState(() {
      _amountPaid = cash;
      if (cash >= widget.total) {
        _change = cash - widget.total;
        _balanceDue = 0.0;
      } else {
        _change = 0.0;
        _balanceDue = widget.total - cash;
      }
    });
  }

  void _applyQuickCash(double amount) {
    setState(() {
      _cashController.text = amount.toStringAsFixed(2);
      _cashController.selection = TextSelection.fromPosition(
        TextPosition(offset: _cashController.text.length),
      );
    });
  }

  Future<void> _onConfirm() async {
    if (_amountPaid < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid amount paid.'),
          backgroundColor: kErrorColor,
        ),
      );
      return;
    }

    int? customerId = _selectedCustomerId;

    if (_balanceDue > 0) {
      if (_isNewCustomer) {
        if (_customerNameController.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Customer Name is required for balance sales.'),
              backgroundColor: kErrorColor,
            ),
          );
          return;
        }
        // Save new customer
        customerId = await DatabaseHelper.instance.insertCustomer({
          'name': _customerNameController.text.trim(),
          'phone': _customerPhoneController.text.trim(),
          'address': _customerAddressController.text.trim(),
        });
      } else if (customerId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select or create a customer for balance due.'),
            backgroundColor: kErrorColor,
          ),
        );
        return;
      }
    }

    Navigator.of(context).pop({
      'amount_paid': _amountPaid,
      'balance_due': _balanceDue,
      'customer_id': customerId,
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 24,
      backgroundColor: cardBg,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Checkout',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: cs.onSurface.withOpacity(0.6)),
                    onPressed: () => Navigator.of(context).pop(),
                  )
                ],
              ),
              const Divider(height: 24),
              
              // Total Section
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [kPrimaryColor, kSecondaryColor],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'TOTAL',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withOpacity(0.9),
                        letterSpacing: 1.0,
                      ),
                    ),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          formatCurrency(widget.total),
                          style: GoogleFonts.inter(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Cash Input
              TextField(
                controller: _cashController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
                decoration: InputDecoration(
                  labelText: 'Amount Paid (Cash)',
                  labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w500),
                  prefixIcon: Icon(Icons.payments_outlined, color: cs.primary),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => _cashController.clear(),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Quick Cash Buttons
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildQuickCashButton(widget.total, 'Exact'),
                  if (widget.total < 50) _buildQuickCashButton(50, '₱50'),
                  if (widget.total < 100) _buildQuickCashButton(100, '₱100'),
                  if (widget.total < 200) _buildQuickCashButton(200, '₱200'),
                  if (widget.total < 500) _buildQuickCashButton(500, '₱500'),
                  if (widget.total < 1000) _buildQuickCashButton(1000, '₱1000'),
                  _buildQuickCashButton((widget.total / 100).ceil() * 100.0, 'Round UP'),
                ],
              ),
              const SizedBox(height: 20),

              // Reactive Change / Balance Due Display
              if (_amountPaid > 0)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _amountPaid >= widget.total 
                        ? (isDark ? const Color(0xFF10B981).withOpacity(0.15) : const Color(0xFFD1FAE5)) 
                        : (isDark ? const Color(0xFFEF4444).withOpacity(0.15) : const Color(0xFFFEF2F2)),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _amountPaid >= widget.total 
                          ? (isDark ? const Color(0xFF10B981).withOpacity(0.4) : const Color(0xFFA7F3D0)) 
                          : (isDark ? const Color(0xFFEF4444).withOpacity(0.4) : const Color(0xFFFCA5A5)),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _amountPaid >= widget.total ? 'CHANGE' : 'BALANCE DUE',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: _amountPaid >= widget.total 
                              ? (isDark ? const Color(0xFF34D399) : const Color(0xFF059669)) 
                              : (isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626)),
                          letterSpacing: 0.8,
                        ),
                      ),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            _amountPaid >= widget.total 
                                ? formatCurrency(_change) 
                                : formatCurrency(_balanceDue),
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              color: _amountPaid >= widget.total 
                                  ? (isDark ? const Color(0xFF34D399) : const Color(0xFF059669)) 
                                  : (isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626)),
                            ),
                            maxLines: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Customer Section (Debtor info needed if balance due)
              if (_balanceDue > 0) ...[
                const SizedBox(height: 24),
                Row(
                  children: [
                    Icon(Icons.account_box, color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706)),
                    const SizedBox(width: 8),
                    Text(
                      'Customer Info (Required for Balance)',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Select Existing'),
                        selected: !_isNewCustomer,
                        onSelected: (val) {
                          setState(() {
                            _isNewCustomer = false;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Add New Customer'),
                        selected: _isNewCustomer,
                        onSelected: (val) {
                          setState(() {
                            _isNewCustomer = true;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (!_isNewCustomer) ...[
                  DropdownButtonFormField<int>(
                    decoration: InputDecoration(
                      labelText: 'Select Debtor',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.person_search_outlined),
                    ),
                    value: _selectedCustomerId,
                    items: _allCustomers.map((c) {
                      final id = c['id'] as int;
                      final phone = c['phone']?.toString().trim() ?? '';
                      final displayText = phone.isNotEmpty ? '${c['name']} - $phone' : '${c['name']}';
                      return DropdownMenuItem<int>(
                        value: id,
                        child: Text(displayText),
                      );
                    }).toList(),
                    onChanged: (val) async {
                      double debt = 0.0;
                      if (val != null) {
                        debt = await DatabaseHelper.instance.getCustomerTotalDebt(val);
                      }
                      setState(() {
                        _selectedCustomerId = val;
                        _existingDebtorDebt = debt;
                      });
                    },
                  ),
                  if (_selectedCustomerId != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cs.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: cs.primary.withOpacity(0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Current Outstanding Debt:',
                                style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: cs.onSurface.withOpacity(0.6), fontSize: 13),
                              ),
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    formatCurrency(_existingDebtorDebt),
                                    style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: cs.error, fontSize: 14),
                                    maxLines: 1,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_balanceDue > 0) ...[
                            const Divider(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'New Total Debt:',
                                  style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: cs.onSurface, fontSize: 13),
                                ),
                                Flexible(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      formatCurrency(_existingDebtorDebt + _balanceDue),
                                      style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: cs.error, fontSize: 15),
                                      maxLines: 1,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ]
                else ...[
                  TextField(
                    controller: _customerNameController,
                    decoration: InputDecoration(
                      labelText: 'Customer Name *',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _customerPhoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Phone Number (Optional)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _customerAddressController,
                    decoration: InputDecoration(
                      labelText: 'Address (Optional)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ],

              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _onConfirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'CONFIRM PAYMENT',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickCashButton(double amount, String label) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return ActionChip(
      label: Text(label),
      onPressed: () => _applyQuickCash(amount),
      backgroundColor: cs.primary.withOpacity(0.08),
      labelStyle: GoogleFonts.inter(
        color: cs.primary,
        fontWeight: FontWeight.w700,
        fontSize: 13,
      ),
      side: BorderSide(color: cs.primary),
    );
  }
}
