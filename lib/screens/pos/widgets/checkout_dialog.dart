import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/utils/constants.dart';
import '../../../core/utils/formatters.dart';
import 'numeric_keypad.dart';

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
  bool _isNewCustomer = true;
  double _amountPaid = 0.0;
  double _balanceDue = 0.0;
  double _change = 0.0;
  double _existingDebtorDebt = 0.0;

  @override
  void initState() {
    super.initState();
    _cashController.addListener(_onCashChanged);
    _customerNameController.addListener(() => setState(() {}));
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
      final formatted = formatInputWithCommas(amount.toStringAsFixed(2));
      _cashController.text = formatted;
      _cashController.selection = TextSelection.fromPosition(
        TextPosition(offset: _cashController.text.length),
      );
    });
  }

  Future<void> _onConfirm() async {
    if (_cashController.text.trim().isEmpty || _amountPaid < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter the payment amount.'),
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

    if (!mounted) return;

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

    final mediaQuery = MediaQuery.of(context);
    final isLandscape = mediaQuery.orientation == Orientation.landscape;
    final isTablet = mediaQuery.size.shortestSide >= 600;
    final useSideBySide = isTablet && isLandscape;

    Widget buildFormContent() {
      return Column(
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
                icon: Icon(Icons.close, color: cs.onSurface.withValues(alpha: 0.6)),
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
                    color: Colors.white.withValues(alpha: 0.9),
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
            readOnly: true,
            showCursor: true,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
            decoration: InputDecoration(
              labelText: _cashController.text.trim().isEmpty
                  ? 'Amount Paid (Cash) * (Required)'
                  : 'Amount Paid (Cash)',
              labelStyle: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: _cashController.text.trim().isEmpty ? cs.error : null,
              ),
              errorText: _cashController.text.trim().isEmpty
                  ? 'Payment amount is required'
                  : null,
              prefixIcon: Icon(
                Icons.payments_outlined,
                color: _cashController.text.trim().isEmpty ? cs.error : cs.primary,
              ),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () => _cashController.clear(),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: _cashController.text.trim().isEmpty ? cs.error : cs.outline,
                  width: _cashController.text.trim().isEmpty ? 1.5 : 1.0,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: _cashController.text.trim().isEmpty ? cs.error : cs.primary,
                  width: 2.0,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Quick Cash Buttons (Philippine Peso Denomination Predictions)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _getPhilippinePaymentSuggestions(widget.total)
                .map((s) => _buildQuickCashButton(s.amount, s.label))
                .toList(),
          ),
          const SizedBox(height: 20),

          // Reactive Change / Balance Due Display
          if (_cashController.text.trim().isNotEmpty)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _amountPaid >= widget.total 
                    ? (isDark ? const Color(0xFF10B981).withValues(alpha: 0.15) : const Color(0xFFD1FAE5)) 
                    : (isDark ? const Color(0xFFEF4444).withValues(alpha: 0.15) : const Color(0xFFFEF2F2)),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _amountPaid >= widget.total 
                      ? (isDark ? const Color(0xFF10B981).withValues(alpha: 0.4) : const Color(0xFFA7F3D0)) 
                      : (isDark ? const Color(0xFFEF4444).withValues(alpha: 0.4) : const Color(0xFFFCA5A5)),
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
            // ── Segmented toggle: Add New | Select Existing ──
            Container(
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.outline.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  _buildToggleSegment(
                    label: 'Add New',
                    icon: Icons.person_add_alt_1_rounded,
                    selected: _isNewCustomer,
                    isFirst: true,
                    onTap: () => setState(() => _isNewCustomer = true),
                  ),
                  _buildToggleSegment(
                    label: 'Select Existing',
                    icon: Icons.manage_accounts_rounded,
                    selected: !_isNewCustomer,
                    isFirst: false,
                    onTap: () => setState(() => _isNewCustomer = false),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (!_isNewCustomer) ...[
              DropdownButtonFormField<int>(
                decoration: InputDecoration(
                  labelText: _selectedCustomerId == null ? 'Select Debtor * (Required)' : 'Select Debtor *',
                  labelStyle: TextStyle(
                    color: _selectedCustomerId == null ? cs.error : null,
                    fontWeight: FontWeight.w600,
                  ),
                  errorText: _selectedCustomerId == null ? 'Please select a debtor for balance sales' : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: _selectedCustomerId == null ? cs.error : cs.outline,
                      width: _selectedCustomerId == null ? 1.5 : 1.0,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: _selectedCustomerId == null ? cs.error : cs.primary,
                      width: 2.0,
                    ),
                  ),
                  prefixIcon: Icon(
                    Icons.person_search_outlined,
                    color: _selectedCustomerId == null ? cs.error : null,
                  ),
                ),
                initialValue: _selectedCustomerId,
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
                    color: cs.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: cs.primary.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Current Outstanding Debt:',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: cs.onSurface.withValues(alpha: 0.6), fontSize: 13),
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
                  labelText: _customerNameController.text.trim().isEmpty
                      ? 'Customer Name * (Required)'
                      : 'Customer Name *',
                  labelStyle: TextStyle(
                    color: _customerNameController.text.trim().isEmpty ? cs.error : null,
                    fontWeight: FontWeight.w600,
                  ),
                  errorText: _customerNameController.text.trim().isEmpty
                      ? 'Customer Name is required for balance sales'
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: _customerNameController.text.trim().isEmpty ? cs.error : cs.outline,
                      width: _customerNameController.text.trim().isEmpty ? 1.5 : 1.0,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: _customerNameController.text.trim().isEmpty ? cs.error : cs.primary,
                      width: 2.0,
                    ),
                  ),
                  prefixIcon: Icon(
                    Icons.person_outline,
                    color: _customerNameController.text.trim().isEmpty ? cs.error : null,
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
      );
    }

    // Build the numpad panel (shared between layouts)
    final numpadPanel = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Enter Cash Paid',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: cs.onSurface.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 16),
        NumericKeypad(
          controller: _cashController,
          onSubmit: _onConfirm,
          isDecimal: true,
          formatAsThousands: true,
        ),
      ],
    );

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 24,
      backgroundColor: cardBg,
      child: Container(
        constraints: BoxConstraints(maxWidth: useSideBySide ? 850 : 500),
        padding: const EdgeInsets.all(24),
        child: useSideBySide
            // ── Tablet landscape: fixed-height container, only form scrolls ──
            ? ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 560),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left: form column is the only scrollable area
                    Expanded(
                      flex: 5,
                      child: SingleChildScrollView(
                        child: buildFormContent(),
                      ),
                    ),
                    const SizedBox(width: 24),
                    // Right: numpad pinned to top, completely independent of form height
                    Expanded(
                      flex: 4,
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: numpadPanel,
                      ),
                    ),
                  ],
                ),
              )
            // ── Phone / portrait: simple single-column scroll ──
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    buildFormContent(),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 12),
                    Text(
                      'Enter Cash Paid',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface.withValues(alpha: 0.8),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    NumericKeypad(
                      controller: _cashController,
                      onSubmit: _onConfirm,
                      isDecimal: true,
                      formatAsThousands: true,
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
    final isExact = label.startsWith('Exact');
    final isRoundUp = label.startsWith('Round UP');

    return ActionChip(
      label: Text(label),
      onPressed: () => _applyQuickCash(amount),
      backgroundColor: (isExact || isRoundUp) ? cs.primary.withValues(alpha: 0.15) : cs.primary.withValues(alpha: 0.08),
      labelStyle: GoogleFonts.inter(
        color: cs.primary,
        fontWeight: (isExact || isRoundUp) ? FontWeight.w800 : FontWeight.w700,
        fontSize: 13,
      ),
      side: BorderSide(color: cs.primary.withValues(alpha: (isExact || isRoundUp) ? 0.9 : 0.4), width: (isExact || isRoundUp) ? 1.5 : 1.0),
    );
  }

  Widget _buildToggleSegment({
    required String label,
    required IconData icon,
    required bool selected,
    required bool isFirst,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final activeBg = cs.primary;
    final activeFg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final inactiveFg = cs.onSurface.withValues(alpha: 0.65);

    return Expanded(
      child: Material(
        color: selected ? activeBg : Colors.transparent,
        borderRadius: BorderRadius.horizontal(
          left: isFirst ? const Radius.circular(11) : Radius.zero,
          right: !isFirst ? const Radius.circular(11) : Radius.zero,
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.horizontal(
            left: isFirst ? const Radius.circular(11) : Radius.zero,
            right: !isFirst ? const Radius.circular(11) : Radius.zero,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: selected ? activeFg : inactiveFg,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected ? activeFg : inactiveFg,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PaymentSuggestion {
  final double amount;
  final String label;

  _PaymentSuggestion(this.amount, this.label);
}

List<_PaymentSuggestion> _getPhilippinePaymentSuggestions(double total) {
  if (total <= 0) return [];

  final List<_PaymentSuggestion> suggestions = [];
  final Set<double> addedAmounts = {};

  void add(double amount, String label, {bool forceAdd = false}) {
    final rounded = (amount * 100).roundToDouble() / 100;
    if (rounded >= total && (forceAdd || !addedAmounts.contains(rounded))) {
      addedAmounts.add(rounded);
      suggestions.add(_PaymentSuggestion(rounded, label));
    }
  }

  // 1. Exact Amount
  add(total, 'Exact (${formatCurrency(total)})');

  // 2. Round UP Button (Always guaranteed)
  double roundUpAmt = (total / 100).ceil() * 100.0;
  if (roundUpAmt <= total) {
    roundUpAmt = total + 100.0;
  }
  add(roundUpAmt, 'Round UP', forceAdd: true);

  // Single PH standard banknotes: 20, 50, 100, 200, 500, 1000
  final List<double> bills = [20, 50, 100, 200, 500, 1000];

  // 3. Single bill values > total
  for (final b in bills) {
    if (b > total) {
      add(b, '₱${b.toInt()}');
    }
  }

  // 4. Multiples of 50, 100, 200, 500, 1000
  if (total < 1000) {
    final next50 = (total / 50).ceil() * 50.0;
    if (next50 > total) add(next50, '₱${next50.toInt()}');

    final next100 = (total / 100).ceil() * 100.0;
    if (next100 > total) add(next100, '₱${next100.toInt()}');

    final next200 = (total / 200).ceil() * 200.0;
    if (next200 > total) add(next200, '₱${next200.toInt()}');

    final next500 = (total / 500).ceil() * 500.0;
    if (next500 > total) add(next500, '₱${next500.toInt()}');
  }

  final next1000 = (total / 1000).ceil() * 1000.0;
  if (next1000 > total) {
    add(next1000, '₱${next1000.toInt()}');
  } else if (next1000 == total && total >= 1000) {
    add(total + 1000, '₱${(total + 1000).toInt()}');
  }

  // 5. Smart Philippine "Pambarya" (Coin & small bill additions for clean change)
  final remainder10 = total % 10;
  final remainder50 = total % 50;

  if (remainder10 > 0 && total < 1000) {
    final next5 = (total / 5).ceil() * 5.0;
    if (next5 > total) add(next5, '₱${next5.toInt()}');

    final next10 = (total / 10).ceil() * 10.0;
    if (next10 > total) add(next10, '₱${next10.toInt()}');
  }

  if (remainder50 > 0) {
    double baseBill = 0;
    if (total < 200) {
      baseBill = 200;
    } else if (total < 500) {
      baseBill = 500;
    } else if (total < 1000) {
      baseBill = 1000;
    }
    if (baseBill > 0) {
      final dagdag = baseBill + remainder50;
      if (dagdag > total) {
        add(dagdag, '₱${dagdag.toInt()}');
      }
    }
  }

  // Sort by amount ascending
  suggestions.sort((a, b) => a.amount.compareTo(b.amount));

  if (suggestions.length > 7) {
    return suggestions.sublist(0, 7);
  }

  return suggestions;
}
