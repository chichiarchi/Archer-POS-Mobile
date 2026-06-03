import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/utils/constants.dart';
import '../../../core/utils/formatters.dart';

class ParkRecallDialog extends StatefulWidget {
  final List<Map<String, dynamic>> parkedSales;
  final Function(Map<String, dynamic>) onRecall;

  const ParkRecallDialog({
    super.key,
    required this.parkedSales,
    required this.onRecall,
  });

  @override
  State<ParkRecallDialog> createState() => _ParkRecallDialogState();
}

class _ParkRecallDialogState extends State<ParkRecallDialog> {
  late List<Map<String, dynamic>> _sales;

  @override
  void initState() {
    super.initState();
    _sales = List.from(widget.parkedSales);
  }

  Future<void> _deleteSale(int id, int index) async {
    await DatabaseHelper.instance.deleteParkedSale(id);
    setState(() {
      _sales.removeAt(index);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Parked sale deleted.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 450, maxHeight: 500),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recall Parked Sale',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: kTextPrimary,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: kTextSecondary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(height: 24),
            if (_sales.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.pause_presentation_outlined, size: 48, color: kTextSecondary),
                      const SizedBox(height: 12),
                      Text(
                        'No parked sales found.',
                        style: GoogleFonts.inter(
                          color: kTextSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _sales.length,
                  separatorBuilder: (ctx, idx) => const Divider(),
                  itemBuilder: (ctx, index) {
                    final sale = _sales[index];
                    final label = sale['label'] as String? ?? 'No label';
                    final total = (sale['total'] as num?)?.toDouble() ?? 0.0;
                    final timestamp = sale['timestamp'] as String? ?? '';
                    final id = sale['id'] as int;

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        label,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          color: kTextPrimary,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            formatDateTime(timestamp),
                            style: GoogleFonts.inter(fontSize: 12, color: kTextSecondary),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Total: ${formatCurrency(total)}',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: kPrimaryColor,
                            ),
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: kErrorColor),
                            onPressed: () => _deleteSale(id, index),
                          ),
                          const SizedBox(width: 4),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kPrimaryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () => widget.onRecall(sale),
                            child: Text(
                              'Recall',
                              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
