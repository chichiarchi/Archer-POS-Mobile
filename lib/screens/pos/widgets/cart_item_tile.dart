import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/providers/cart_provider.dart';
import '../../../core/utils/constants.dart';
import '../../../core/utils/formatters.dart';
import 'numeric_keypad.dart';

/// A single cart item row, adapts between phone and tablet layouts.
class CartItemTile extends StatefulWidget {
  final CartItem item;
  final int index;
  final String userRole;
  final String username;
  final bool isTablet;
  final VoidCallback onDelete;
  final Function(double) onQtyChanged;
  final Function(double) onDiscount;
  final VoidCallback onTogglePricing;

  const CartItemTile({
    super.key,
    required this.item,
    required this.index,
    required this.userRole,
    required this.username,
    this.isTablet = false,
    required this.onDelete,
    required this.onQtyChanged,
    required this.onDiscount,
    required this.onTogglePricing,
  });

  @override
  State<CartItemTile> createState() => _CartItemTileState();
}

class _CartItemTileState extends State<CartItemTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _flashController;

  @override
  void initState() {
    super.initState();
    _flashController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _flashController.dispose();
    super.dispose();
  }

  // ─────────────────────────── helpers ────────────────────────────────────────

  void _flash() {
    _flashController.forward(from: 0.0);
  }

  void _increment() {
    HapticFeedback.lightImpact();
    final newQty = _roundQty(widget.item.quantity + 1);
    widget.onQtyChanged(newQty);
    _flash();
  }

  void _decrement() {
    HapticFeedback.lightImpact();
    final newQty = _roundQty(widget.item.quantity - 1);
    if (newQty < 0.1) {
      _confirmDelete();
      return;
    }
    widget.onQtyChanged(newQty);
    _flash();
  }

  double _roundQty(double qty) {
    // Keep up to 3 decimal places to avoid floating-point noise.
    return double.parse(qty.toStringAsFixed(3));
  }

  String _formatQty(double qty) {
    if (qty == qty.truncateToDouble()) {
      return qty.toStringAsFixed(0);
    }
    return qty.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '');
  }

  // ─────────────────────────── dialogs ────────────────────────────────────────

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        ),
        title: Text(
          'Remove Item',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Remove "${widget.item.name}" from the cart?',
          style: GoogleFonts.inter(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true) widget.onDelete();
  }

  Future<void> _showChangeQtyDialog() async {
    final controller =
        TextEditingController(text: _formatQty(widget.item.quantity));
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        ),
        title: Text(
          'Change Quantity',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              readOnly: true,
              showCursor: true,
              decoration: InputDecoration(
                labelText: 'Quantity',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppConstants.radiusSM),
                ),
              ),
            ),
            const SizedBox(height: 16),
            NumericKeypad(
              controller: controller,
              isDecimal: true,
              onSubmit: () {
                final v = double.tryParse(controller.text);
                if (v != null && v >= 0.1) {
                  Navigator.pop(ctx, v);
                } else {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text('Minimum quantity is 0.1'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusSM),
              ),
            ),
            onPressed: () {
              final v = double.tryParse(controller.text);
              if (v != null && v >= 0.1) {
                Navigator.pop(ctx, v);
              } else {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('Minimum quantity is 0.1'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            child: const Text('Set'),
          ),
        ],
      ),
    );
    if (result != null) {
      widget.onQtyChanged(result);
      _flash();
    }
  }

  Future<void> _showDiscountDialog() async {
    final controller =
        TextEditingController(text: widget.item.price.toStringAsFixed(2));
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        ),
        title: Text(
          'Apply Discount',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Current price: ${formatCurrency(widget.item.price)}',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: AppConstants.spaceSM),
              TextField(
                controller: controller,
                readOnly: true,
                showCursor: true,
                decoration: InputDecoration(
                  labelText: 'New Unit Price',
                  prefixText: '₱ ',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppConstants.radiusSM),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              NumericKeypad(
                controller: controller,
                isDecimal: true,
                onSubmit: () {
                  final v = double.tryParse(controller.text);
                  if (v != null && v >= 0) {
                    Navigator.pop(ctx, v);
                  } else {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                        content: Text('Enter a valid price (≥ 0)'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusSM),
              ),
            ),
            onPressed: () {
              final v = double.tryParse(controller.text);
              if (v != null && v >= 0) {
                Navigator.pop(ctx, v);
              } else {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('Enter a valid price (≥ 0)'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    if (result != null) widget.onDiscount(result);
  }

  Future<void> _showLongPressMenu() async {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final choice = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppConstants.radiusLG),
        ),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.dividerColor,
                borderRadius: BorderRadius.circular(AppConstants.radiusFull),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spaceMD,
                  vertical: AppConstants.spaceSM),
              child: Text(
                widget.item.name,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading:
                  const Icon(Icons.edit_outlined, color: AppColors.primary),
              title: Text('Change Qty',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
              onTap: () => Navigator.pop(ctx, 'qty'),
            ),
            ListTile(
              leading: const Icon(Icons.local_offer_outlined,
                  color: AppColors.warning),
              title: Text('Apply Discount',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
              subtitle: widget.item.manuallyDiscounted
                  ? Text('Currently discounted',
                      style: GoogleFonts.inter(
                          fontSize: 11, color: AppColors.warning))
                  : null,
              onTap: () => Navigator.pop(ctx, 'discount'),
            ),
            ListTile(
              leading: Icon(
                Icons.swap_horiz_rounded,
                color: widget.item.pricingMode == 'retail'
                    ? AppColors.info
                    : AppColors.warning,
              ),
              title: Text('Toggle Pricing',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
              subtitle: Text(
                'Switch to ${widget.item.pricingMode == 'retail' ? 'Wholesale' : 'Retail'}',
                style:
                    GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
              ),
              onTap: () => Navigator.pop(ctx, 'pricing'),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.error),
              title: Text('Delete',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w500, color: AppColors.error)),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
            const SizedBox(height: AppConstants.spaceSM),
          ],
        ),
      ),
    );

    switch (choice) {
      case 'qty':
        await _showChangeQtyDialog();
        break;
      case 'discount':
        await _showDiscountDialog();
        break;
      case 'pricing':
        widget.onTogglePricing();
        break;
      case 'delete':
        await _confirmDelete();
        break;
    }
  }

  // ─────────────────────────── pricing badge ───────────────────────────────────

  Widget _pricingBadge({bool compact = false}) {
    final isRetail = widget.item.pricingMode == 'retail';
    final color = isRetail ? AppColors.primary : const Color(0xFFF97316);
    final label = isRetail ? 'RETAIL' : 'WHOLESALE';

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppConstants.radiusFull),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 0.8),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: compact ? 10 : 12,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  // ─────────────────────────── qty controls ────────────────────────────────────

  Widget _qtyControls({bool compact = false}) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final btnSize = compact ? 28.0 : 36.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CircleIconButton(
          icon: Icons.remove,
          size: btnSize,
          onTap: _decrement,
          backgroundColor:
              isDark ? const Color(0xFF334155) : AppColors.background,
          iconColor: cs.onSurface,
        ),
        GestureDetector(
          onTap: _showChangeQtyDialog,
          child: Container(
            constraints: BoxConstraints(minWidth: compact ? 32 : 44),
            padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 8),
            child: Text(
              _formatQty(widget.item.quantity),
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: compact ? 14 : 17,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
          ),
        ),
        _CircleIconButton(
          icon: Icons.add,
          size: btnSize,
          onTap: _increment,
          backgroundColor: cs.primary.withValues(alpha: 0.12),
          iconColor: cs.primary,
        ),
      ],
    );
  }

  // ─────────────────────────── PHONE layout ────────────────────────────────────

  Widget _phoneLayout() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    return AnimatedBuilder(
      animation: _flashController,
      builder: (context, child) {
        final flashColor = Color.lerp(
          cs.primary.withValues(alpha: isDark ? 0.35 : 0.15),
          Colors.transparent,
          _flashController.value,
        );
        return Card(
          color: Color.alphaBlend(
            flashColor ?? Colors.transparent,
            isDark ? const Color(0xFF1E293B) : Colors.white,
          ),
          elevation: AppConstants.elevationCard,
          margin: const EdgeInsets.symmetric(
              horizontal: AppConstants.spaceSM, vertical: AppConstants.spaceXS),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusMD),
            side: BorderSide(
                color: cs.onSurface.withValues(alpha: 0.12), width: 0.8),
          ),
          child: child,
        );
      },
      child: InkWell(
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        onLongPress: _showLongPressMenu,
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.spaceMD),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.item.name,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        if (widget.item.barcode.isNotEmpty)
                          Text(
                            widget.item.barcode,
                            style: GoogleFonts.inter(
                                fontSize: 11,
                                color: cs.onSurface.withValues(alpha: 0.45)),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppConstants.spaceSM),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        formatCurrency(widget.item.subtotal),
                        style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: cs.primary),
                        maxLines: 1,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppConstants.spaceSM),
              Row(
                children: [
                  _pricingBadge(),
                  const SizedBox(width: AppConstants.spaceSM),
                  if (widget.item.manuallyDiscounted)
                    const Padding(
                      padding: EdgeInsets.only(right: 6),
                      child: Icon(Icons.local_offer,
                          size: 13, color: AppColors.warning),
                    ),
                  Text(
                    '${formatCurrency(widget.item.price)} / unit',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        color: cs.onSurface.withValues(alpha: 0.5)),
                  ),
                ],
              ),
              const SizedBox(height: AppConstants.spaceSM),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _qtyControls(),
                  IconButton(
                    onPressed: _confirmDelete,
                    icon: const Icon(Icons.delete_outline),
                    color: AppColors.error,
                    iconSize: 20,
                    tooltip: 'Remove',
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────── TABLET layout ───────────────────────────────────

  Widget _tabletLayout() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    return AnimatedBuilder(
      animation: _flashController,
      builder: (context, child) {
        final flashColor = Color.lerp(
          cs.primary.withValues(alpha: isDark ? 0.35 : 0.15),
          Colors.transparent,
          _flashController.value,
        );
        return InkWell(
          onLongPress: _showLongPressMenu,
          child: Container(
            padding: const EdgeInsets.only(
              left: AppConstants.spaceMD,
              right: 24,
              top: 16,
              bottom: 16,
            ),
            decoration: BoxDecoration(
              color: Color.alphaBlend(
                flashColor ?? Colors.transparent,
                isDark ? const Color(0xFF1E293B) : Colors.white,
              ),
              border: Border(
                  bottom: BorderSide(
                      color: cs.onSurface.withValues(alpha: 0.1), width: 0.8)),
            ),
            child: Row(
              children: [
                Expanded(
                    flex: 8,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.item.name,
                          style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: cs.onSurface),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            _pricingBadge(compact: true),
                            if (widget.item.barcode.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Text(
                                widget.item.barcode,
                                style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color:
                                        cs.onSurface.withValues(alpha: 0.45)),
                              ),
                            ],
                          ],
                        ),
                      ],
                    )),
                // Price (flex 4)
                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          formatCurrency(widget.item.price),
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface.withValues(alpha: 0.65),
                          ),
                          maxLines: 1,
                        ),
                      ),
                      if (widget.item.manuallyDiscounted)
                        const Icon(Icons.local_offer,
                            size: 13, color: AppColors.warning),
                    ],
                  ),
                ),
                Expanded(
                    flex: 5,
                    child: Center(child: _qtyControls(compact: false))),
                Expanded(
                  flex: 5,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      formatCurrency(widget.item.subtotal),
                      textAlign: TextAlign.end,
                      style: GoogleFonts.inter(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: cs.primary),
                      maxLines: 1,
                    ),
                  ),
                ),
                // Actions (flex 4)
                Expanded(
                  flex: 4,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _SmallIconButton(
                        icon: Icons.local_offer_outlined,
                        color: AppColors.warning,
                        tooltip: 'Discount',
                        onTap: _showDiscountDialog,
                      ),
                      const SizedBox(width: 8),
                      _SmallIconButton(
                        icon: Icons.delete_outline,
                        color: AppColors.error,
                        tooltip: 'Remove',
                        onTap: _confirmDelete,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─────────────────────────── build ──────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return widget.isTablet ? _tabletLayout() : _phoneLayout();
  }
}

// ─────────────────────────── helper widgets ─────────────────────────────────

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final double size;
  final VoidCallback onTap;
  final Color backgroundColor;
  final Color iconColor;

  const _CircleIconButton({
    required this.icon,
    required this.size,
    required this.onTap,
    required this.backgroundColor,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: size * 0.5, color: iconColor),
      ),
    );
  }
}

class _SmallIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _SmallIconButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 22, color: color),
        ),
      ),
    );
  }
}
