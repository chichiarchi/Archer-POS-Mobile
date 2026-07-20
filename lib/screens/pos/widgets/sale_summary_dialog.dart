import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/utils/formatters.dart';

class SaleSummaryDialog extends StatelessWidget {
  final int saleId;
  final double totalAmount;
  final double amountPaid;
  final double balanceDue;
  final String? customerName;
  final int itemCount;

  const SaleSummaryDialog({
    super.key,
    required this.saleId,
    required this.totalAmount,
    required this.amountPaid,
    required this.balanceDue,
    this.customerName,
    required this.itemCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final change = amountPaid > totalAmount ? amountPaid - totalAmount : 0.0;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      elevation: 24,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Success Icon & Title
            Center(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (change > 0 || balanceDue == 0)
                      ? (isDark ? const Color(0xFF10B981).withValues(alpha: 0.2) : const Color(0xFFD1FAE5))
                      : (isDark ? const Color(0xFFF59E0B).withValues(alpha: 0.2) : const Color(0xFFFEF3C7)),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle_rounded,
                  size: 44,
                  color: (change > 0 || balanceDue == 0)
                      ? (isDark ? const Color(0xFF34D399) : const Color(0xFF059669))
                      : (isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Sale Completed!',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: cs.onSurface,
              ),
            ),
            Text(
              'Receipt #$saleId',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: cs.onSurface.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(height: 20),

            // Hero Change / Balance Display Box
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              decoration: BoxDecoration(
                color: change > 0
                    ? (isDark ? const Color(0xFF10B981).withValues(alpha: 0.15) : const Color(0xFFECFDF5))
                    : balanceDue > 0
                        ? (isDark ? const Color(0xFFEF4444).withValues(alpha: 0.15) : const Color(0xFFFEF2F2))
                        : (isDark ? cs.surfaceContainerHighest : Colors.grey.shade100),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: change > 0
                      ? (isDark ? const Color(0xFF10B981).withValues(alpha: 0.4) : const Color(0xFFA7F3D0))
                      : balanceDue > 0
                          ? (isDark ? const Color(0xFFEF4444).withValues(alpha: 0.4) : const Color(0xFFFCA5A5))
                          : cs.outline.withValues(alpha: 0.2),
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    change > 0
                        ? 'CHANGE DUE TO CUSTOMER'
                        : balanceDue > 0
                            ? 'BALANCE DUE'
                            : 'EXACT PAYMENT RECEIVED',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                      color: change > 0
                          ? (isDark ? const Color(0xFF34D399) : const Color(0xFF059669))
                          : balanceDue > 0
                              ? (isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626))
                              : cs.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 6),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      change > 0
                          ? formatCurrency(change)
                          : balanceDue > 0
                              ? formatCurrency(balanceDue)
                              : formatCurrency(totalAmount),
                      style: GoogleFonts.inter(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        color: change > 0
                            ? (isDark ? const Color(0xFF34D399) : const Color(0xFF059669))
                            : balanceDue > 0
                                ? (isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626))
                                : cs.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Summary Breakdown List
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  _buildSummaryRow(context, 'Total Amount', formatCurrency(totalAmount), isBold: true),
                  const Divider(height: 16),
                  _buildSummaryRow(context, 'Amount Paid', formatCurrency(amountPaid)),
                  if (customerName != null && customerName!.isNotEmpty) ...[
                    const Divider(height: 16),
                    _buildSummaryRow(context, 'Customer', customerName!),
                  ],
                  const Divider(height: 16),
                  _buildSummaryRow(context, 'Items Purchased', '$itemCount item${itemCount > 1 ? 's' : ''}'),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Done Button
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: Text(
                'DONE',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(BuildContext context, String label, String value, {bool isBold = false}) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: cs.onSurface.withValues(alpha: 0.65),
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: GoogleFonts.inter(
              fontSize: isBold ? 15 : 14,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w700,
              color: cs.onSurface,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
