import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/database/database_helper.dart';
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

  Future<void> _deleteSale(int id, int index, String label) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final cs = theme.colorScheme;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Delete Parked Sale',
            style: GoogleFonts.inter(fontWeight: FontWeight.w800),
          ),
          content: Text(
            'Are you sure you want to delete the parked sale "$label"? This action cannot be undone.',
            style: GoogleFonts.inter(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: cs.error,
                foregroundColor: cs.onError,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(
                'Delete',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await DatabaseHelper.instance.deleteParkedSale(id);
      if (!mounted) return;
      setState(() {
        _sales.removeAt(index);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Parked sale deleted.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 450,
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
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
                    color: cs.onSurface,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: cs.onSurface.withValues(alpha: 0.6)),
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
                      Icon(Icons.pause_presentation_outlined, size: 48, color: cs.onSurface.withValues(alpha: 0.4)),
                      const SizedBox(height: 12),
                      Text(
                        'No parked sales found.',
                        style: GoogleFonts.inter(
                          color: cs.onSurface.withValues(alpha: 0.6),
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
                          color: cs.onSurface,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            formatDateTime(timestamp),
                            style: GoogleFonts.inter(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.55)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Total: ${formatCurrency(total)}',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: cs.primary,
                            ),
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.delete_outline, color: cs.error),
                            onPressed: () => _deleteSale(id, index, label),
                          ),
                          const SizedBox(width: 4),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: cs.primary,
                              foregroundColor: cs.onPrimary,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
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
