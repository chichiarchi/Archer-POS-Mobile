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
  Map<String, dynamic>? _selectedCustomer;
  bool _isNewCustomer = false;
  double _amountPaid = 0.0;
  double _balanceDue = 0.0;
  double _change = 0.0;

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
    if (_amountPaid <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an amount paid.'),
          backgroundColor: kErrorColor,
        ),
      );
      return;
    }

    int? customerId = _selectedCustomer != null ? _selectedCustomer!['id'] as int? : null;

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
                      color: kTextPrimary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: kTextSecondary),
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
                      'TOTAL DUE',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withOpacity(0.9),
                        letterSpacing: 1.0,
                      ),
                    ),
                    Text(
                      formatCurrency(widget.total),
                      style: GoogleFonts.inter(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
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
                  color: kTextPrimary,
                ),
                decoration: InputDecoration(
                  labelText: 'Amount Paid (Cash)',
                  labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w500),
                  prefixIcon: const Icon(Icons.payments_outlined, color: kPrimaryColor),
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
                        ? kSuccessColor.withOpacity(0.1) 
                        : kErrorColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _amountPaid >= widget.total 
                          ? kSuccessColor.withOpacity(0.3) 
                          : kErrorColor.withOpacity(0.3),
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
                          color: _amountPaid >= widget.total ? kSuccessColor : kErrorColor,
                          letterSpacing: 0.8,
                        ),
                      ),
                      Text(
                        _amountPaid >= widget.total 
                            ? formatCurrency(_change) 
                            : formatCurrency(_balanceDue),
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          color: _amountPaid >= widget.total ? kSuccessColor : kErrorColor,
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
                    const Icon(Icons.account_box, color: kWarningColor),
                    const SizedBox(width: 8),
                    Text(
                      'Customer Info (Required for Balance)',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: kTextPrimary,
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
                if (!_isNewCustomer)
                  DropdownButtonFormField<Map<String, dynamic>>(
                    decoration: InputDecoration(
                      labelText: 'Select Debtor',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.person_search_outlined),
                    ),
                    value: _selectedCustomer,
                    items: _allCustomers.map((c) {
                      return DropdownMenuItem<Map<String, dynamic>>(
                        value: c,
                        child: Text('${c['name']} (${c['phone'] ?? 'No Phone'})'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedCustomer = val;
                      });
                    },
                  )
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
                  backgroundColor: kPrimaryColor,
                  foregroundColor: Colors.white,
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
    return ActionChip(
      label: Text(label),
      onPressed: () => _applyQuickCash(amount),
      backgroundColor: kPrimaryColor.withOpacity(0.05),
      labelStyle: GoogleFonts.inter(
        color: kPrimaryColor,
        fontWeight: FontWeight.w700,
        fontSize: 13,
      ),
      side: const BorderSide(color: kPrimaryColor),
    );
  }
}
