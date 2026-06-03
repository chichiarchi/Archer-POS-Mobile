import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/database/database_helper.dart';
import '../../core/utils/constants.dart';
import '../../core/utils/formatters.dart';

class PaymentNotesScreen extends StatefulWidget {
  final String userRole;
  final String username;

  const PaymentNotesScreen({
    super.key,
    required this.userRole,
    this.username = 'system',
  });

  @override
  State<PaymentNotesScreen> createState() => PaymentNotesScreenState();
}

class PaymentNotesScreenState extends State<PaymentNotesScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _recipientController = TextEditingController();
  final TextEditingController _purposeController = TextEditingController();
  
  DateTime _paymentDate = DateTime.now();
  DateTime _historyFrom = DateTime.now().subtract(const Duration(days: 7));
  DateTime _historyTo = DateTime.now();
  
  List<Map<String, dynamic>> _notesList = [];
  List<String> _recipientSuggestions = [];
  bool _isLoading = false;
  bool _isFormExpanded = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadNotes();
    _loadSuggestions();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _recipientController.dispose();
    _purposeController.dispose();
    super.dispose();
  }

  void refresh() {
    _loadNotes();
    _loadSuggestions();
  }

  Future<void> _loadNotes() async {
    setState(() => _isLoading = true);
    try {
      final dfStr = DateFormat('yyyy-MM-dd').format(_historyFrom);
      final dtStr = DateFormat('yyyy-MM-dd').format(_historyTo);
      final list = await DatabaseHelper.instance.getPaymentNotes(dateFrom: dfStr, dateTo: dtStr);
      setState(() {
        _notesList = list;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Error loading payment notes: $e', isError: true);
    }
  }

  Future<void> _loadSuggestions() async {
    try {
      final list = await DatabaseHelper.instance.getDistinctRecipients();
      setState(() {
        _recipientSuggestions = list;
      });
    } catch (_) {}
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

  void _clearForm() {
    _amountController.clear();
    _recipientController.clear();
    _purposeController.clear();
    setState(() {
      _paymentDate = DateTime.now();
    });
  }

  Future<void> _saveNote() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    final recipient = _recipientController.text.trim();
    final purpose = _purposeController.text.trim().isEmpty ? null : _purposeController.text.trim();
    
    final selectedDate = _paymentDate;
    final now = DateTime.now();
    final timestamp = '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

    try {
      await DatabaseHelper.instance.addPaymentNote(amount, recipient, purpose, timestamp);
      await DatabaseHelper.instance.logAction(
        'PAYMENT_NOTE_SAVED',
        details: 'Payout of ${formatCurrency(amount)} to $recipient',
        userId: widget.username,
      );

      _showSnackBar('Payment note saved! 💵');
      _clearForm();
      _loadNotes();
      _loadSuggestions();
    } catch (e) {
      _showSnackBar('Error saving note: $e', isError: true);
    }
  }

  Future<bool> _verifyAdminPermission() async {
    if (widget.userRole == 'admin' || widget.userRole == 'owner') return true;

    final passwordController = TextEditingController();
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
                'Please enter the master recovery code or an admin password to delete this payout record.',
                style: GoogleFonts.inter(fontSize: 13, color: kTextSecondary),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
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
                final input = passwordController.text.trim();
                if (input == kMasterRecoveryCode) {
                  verified = true;
                  Navigator.of(ctx).pop();
                  return;
                }

                // Verify admin login
                final db = await DatabaseHelper.instance.database;
                final admins = await db.query('users', where: 'role = ?', whereArgs: ['admin']);
                for (final admin in admins) {
                  final adminUser = admin['username'] as String;
                  final verifiedUser = await DatabaseHelper.instance.verifyLogin(adminUser, input);
                  if (verifiedUser != null) {
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

  Future<void> _deleteNote(int id, double amount, String recipient) async {
    final verify = await _verifyAdminPermission();
    if (!verify) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Payout Record', style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
        content: Text('Are you sure you want to delete the payout of ${formatCurrency(amount)} to $recipient?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kErrorColor),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await DatabaseHelper.instance.deletePaymentNote(id);
        await DatabaseHelper.instance.logAction(
          'PAYMENT_NOTE_DELETED',
          details: 'Deleted payout of ${formatCurrency(amount)} to $recipient',
          userId: widget.username,
        );

        _showSnackBar('Payment note deleted.');
        _loadNotes();
      } catch (e) {
        _showSnackBar('Error deleting note: $e', isError: true);
      }
    }
  }

  Future<void> _selectPaymentDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _paymentDate,
      firstDate: DateTime(2025),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _paymentDate = picked;
      });
    }
  }

  Future<void> _selectHistoryRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2025),
      lastDate: DateTime(2030),
      initialDateRange: DateTimeRange(start: _historyFrom, end: _historyTo),
    );
    if (picked != null) {
      setState(() {
        _historyFrom = picked.start;
        _historyTo = picked.end;
      });
      _loadNotes();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, outerConstraints) {
        final isTablet = outerConstraints.maxWidth >= 768;
        final isLandscape =
            MediaQuery.of(context).orientation == Orientation.landscape;
        // Show side-by-side either on tablet OR landscape phone (width >= 600)
        final useSideBySide = isTablet || (isLandscape && outerConstraints.maxWidth >= 600);

        final filteredNotes = _notesList.where((n) {
          final recipient = (n['recipient'] as String? ?? '').toLowerCase();
          final purpose = (n['purpose'] as String? ?? '').toLowerCase();
          final query = _searchQuery.toLowerCase();
          return recipient.contains(query) || purpose.contains(query);
        }).toList();

        double totalPayout = 0.0;
        for (final n in filteredNotes) {
          totalPayout += (n['amount'] as num?)?.toDouble() ?? 0.0;
        }

        // ──────────────────────── Form Widget ────────────────────────
        Widget buildForm() {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: Colors.white,
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Record Cash Outflow',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16, color: kTextPrimary),
                    ),
                    if (!useSideBySide)
                  IconButton(
                        icon: Icon(_isFormExpanded ? Icons.expand_less : Icons.expand_more),
                        onPressed: () => setState(() => _isFormExpanded = !_isFormExpanded),
                      ),
                  ],
                ),
                  if (useSideBySide || _isFormExpanded) ...[
                  const Divider(height: 24),
                  // Recipient
                  Autocomplete<String>(
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                        return const Iterable<String>.empty();
                      }
                      return _recipientSuggestions.where((option) {
                        return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                      });
                    },
                    onSelected: (selection) {
                      _recipientController.text = selection;
                    },
                    fieldViewBuilder: (ctx, ctrl, focusNode, onFieldSubmitted) {
                      // Synchronize Autocomplete controller with our state controller
                      ctrl.addListener(() {
                        if (_recipientController.text != ctrl.text) {
                          _recipientController.text = ctrl.text;
                        }
                      });
                      _recipientController.addListener(() {
                        if (ctrl.text != _recipientController.text) {
                          ctrl.text = _recipientController.text;
                        }
                      });

                      return TextFormField(
                        controller: ctrl,
                        focusNode: focusNode,
                        decoration: InputDecoration(
                          labelText: 'Payee / Recipient *',
                          prefixIcon: const Icon(Icons.person_outline),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                      );
                    },
                  ),
                  const SizedBox(height: 12),

                  // Amount
                  TextFormField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Amount (₱) *',
                      prefixIcon: const Icon(Icons.payments_outlined, color: kErrorColor),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Required';
                      final a = double.tryParse(val);
                      if (a == null || a <= 0) return 'Must be greater than 0';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // Purpose
                  TextFormField(
                    controller: _purposeController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Notes / Purpose',
                      prefixIcon: const Icon(Icons.sticky_note_2_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Date Selector
                  ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: kBorderColor),
                    ),
                    leading: const Icon(Icons.calendar_today, color: kPrimaryColor),
                    title: Text(
                      'Payment Date: ${DateFormat('MMM dd, yyyy').format(_paymentDate)}',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    trailing: const Icon(Icons.edit, size: 16),
                    onTap: _selectPaymentDate,
                  ),
                  const SizedBox(height: 20),

                  // Actions
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: _clearForm,
                          child: const Text('Clear'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kPrimaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: _saveNote,
                          child: Text('Save Note', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

        // ──────────────────────── History Column ────────────────────────
        Widget buildHistory() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Filter & Summary Header
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: Colors.white,
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Range: ${DateFormat('MMM dd').format(_historyFrom)} - ${DateFormat('MMM dd').format(_historyTo)}',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: kTextPrimary),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.date_range, size: 16),
                        label: const Text('Filter Date'),
                        onPressed: _selectHistoryRange,
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Cash Outflow:',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: kTextSecondary),
                      ),
                      Text(
                        formatCurrency(totalPayout),
                        style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 18, color: kErrorColor),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Search Field
          TextField(
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: InputDecoration(
              hintText: 'Search past payouts by payee or notes...',
              prefixIcon: const Icon(Icons.search),
              fillColor: Colors.white,
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // History List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredNotes.isEmpty
                    ? Center(
                        child: Text(
                          'No cash outflows recorded in this range.',
                          style: GoogleFonts.inter(color: kTextSecondary),
                        ),
                      )
                    : ListView.builder(
                        itemCount: filteredNotes.length,
                        itemBuilder: (ctx, index) {
                          final note = filteredNotes[index];
                          final id = note['id'] as int;
                          final amount = (note['amount'] as num?)?.toDouble() ?? 0.0;
                          final recipient = note['recipient'] as String? ?? '';
                          final purpose = note['purpose'] as String? ?? 'No purpose details';
                          final timestamp = note['timestamp'] as String? ?? '';

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            color: Colors.white,
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: kErrorColor.withOpacity(0.1),
                                child: const Icon(Icons.trending_down, color: kErrorColor),
                              ),
                              title: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      recipient,
                                      style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: kTextPrimary),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    formatCurrency(amount),
                                    style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: kErrorColor),
                                  ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(
                                    purpose,
                                    style: GoogleFonts.inter(color: kTextSecondary, fontSize: 13),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    formatDateTime(timestamp),
                                    style: GoogleFonts.inter(fontSize: 11, color: kTextSecondary, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline, color: kTextSecondary),
                                onPressed: () => _deleteNote(id, amount, recipient),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      );
    }

        // ──────────────────────── Adaptive Layout ────────────────────────
        return Scaffold(
          backgroundColor: kBackgroundColor,
          appBar: AppBar(
            title: Text(
              'Payout Manager',
              style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 20, color: kTextPrimary),
            ),
            backgroundColor: Colors.white,
            elevation: 0,
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: useSideBySide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Form Column — percentage-based width clamped between 260-340px
                      SizedBox(
                        width: (outerConstraints.maxWidth * 0.32).clamp(260.0, 340.0),
                        child: SingleChildScrollView(child: buildForm()),
                      ),
                      const SizedBox(width: 20),
                      // History Column
                      Expanded(child: buildHistory()),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      buildForm(),
                      const SizedBox(height: 16),
                      Expanded(child: buildHistory()),
                    ],
                  ),
          ),
        );
      },
    );
  }
}
