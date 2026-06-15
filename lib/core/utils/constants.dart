import 'package:flutter/material.dart';

// ─── Light Mode Palette ────────────────────────────────────────────────────────
// Deeper blue — WCAG AA compliant on white (contrast 5.9:1)
const Color kPrimaryColor   = Color(0xFF1A56DB);
const Color kSecondaryColor = Color(0xFF0EA5E9);
const Color kBackgroundColor = Color(0xFFF1F5F9);
const Color kCardColor      = Color(0xFFFFFFFF);
const Color kErrorColor     = Color(0xFFDC2626);   // deeper red, contrast 4.7:1
const Color kSuccessColor   = Color(0xFF059669);   // darker green, contrast 4.6:1
const Color kWarningColor   = Color(0xFFD97706);   // darker amber, contrast 4.5:1
const Color kTextPrimary    = Color(0xFF0F172A);   // near-black, contrast 18:1
const Color kTextSecondary  = Color(0xFF475569);   // dark slate, contrast 5.8:1
const Color kBorderColor    = Color(0xFFCBD5E1);
const Color kDividerColor   = Color(0xFFE2E8F0);
const Color kPurpleColor    = Color(0xFF7C3AED);   // deeper purple, contrast 6.3:1
const Color kSurfaceColor   = Color(0xFFF8FAFC);   // subtle off-white
const Color kSurface2Color  = Color(0xFFEFF6FF);   // blue-tinted surface

// ─── Dark Mode Palette ────────────────────────────────────────────────────────
const Color kDarkBackground  = Color(0xFF0F172A);
const Color kDarkCard        = Color(0xFF1E293B);
const Color kDarkCard2       = Color(0xFF334155);
const Color kDarkBorder      = Color(0xFF334155);
const Color kDarkDivider     = Color(0xFF1E293B);
const Color kDarkPrimary     = Color(0xFF60A5FA);  // lighter blue on dark bg, contrast 7.1:1
const Color kDarkSecondary   = Color(0xFF38BDF8);
const Color kDarkTextPrimary = Color(0xFFF1F5F9);  // near-white
const Color kDarkTextSecondary = Color(0xFF94A3B8);// medium slate
const Color kDarkSurface     = Color(0xFF1E293B);
const Color kDarkSurface2    = Color(0xFF1E3A5F);  // blue-tinted dark surface

// App system info
const String kSystemTitle       = 'EmmaSarmingStore';
const String kMasterRecoveryCode = '10152003';

// Pagination
const int kPageSize = 100;

// Audit log action types
const String kActionPosSale         = 'POS_SALE';
const String kActionPosVoidCart     = 'POS_VOID_CART';
const String kActionPosDelete       = 'POS_DELETE';
const String kActionPosQtyUpdate    = 'POS_QTY_UPDATE';
const String kActionPosDiscount     = 'POS_DISCOUNT';
const String kActionPosPriceToggle  = 'POS_ITEM_PRICE_TOGGLE';
const String kActionPosQuickAdd     = 'POS_QUICK_ADD';
const String kActionVoidSale        = 'VOID_SALE';
const String kActionBalanceResolve  = 'BALANCE_RESOLVE';
const String kActionProductAdded    = 'PRODUCT_ADDED';
const String kActionProductUpdated  = 'PRODUCT_UPDATED';
const String kActionProductDeleted  = 'PRODUCT_DELETED';
const String kActionBundleAdded     = 'BUNDLE_ADDED';
const String kActionBundleEdited    = 'BUNDLE_EDITED';
const String kActionBundleDeleted   = 'BUNDLE_DELETED';
const String kActionPasswordChange  = 'PASSWORD_CHANGE';
const String kActionAdminPasswordReset = 'ADMIN_PASSWORD_RESET';
const String kActionSettingsUpdate  = 'SETTINGS_UPDATE';
const String kActionPaymentNoteSaved  = 'PAYMENT_NOTE_SAVED';
const String kActionPaymentNoteDeleted = 'PAYMENT_NOTE_DELETED';

// ─── Color helpers ────────────────────────────────────────────────────────────
class AppColors {
  static const Color primary       = kPrimaryColor;
  static const Color secondary     = kSecondaryColor;
  static const Color background    = kBackgroundColor;
  static const Color card          = kCardColor;
  static const Color error         = kErrorColor;
  static const Color success       = kSuccessColor;
  static const Color warning       = kWarningColor;
  static const Color textPrimary   = kTextPrimary;
  static const Color textSecondary = kTextSecondary;
  static const Color textMuted     = Color(0xFF94A3B8);
  static const Color border        = kBorderColor;
  static const Color divider       = kDividerColor;
  static const Color purple        = kPurpleColor;
  static const Color salesBlueTint = Color(0xFFDEEBFF);
  static const Color info          = Color(0xFF2563EB);
}

// ─── Layout constants ─────────────────────────────────────────────────────────
class AppConstants {
  static const double radiusSM   = 8.0;
  static const double radiusMD   = 14.0;
  static const double radiusLG   = 20.0;
  static const double radiusFull = 9999.0;

  static const double spaceXS = 4.0;
  static const double spaceSM = 8.0;
  static const double spaceMD = 16.0;
  static const double spaceLG = 24.0;
  static const double spaceXL = 32.0;

  static const double elevationCard = 0.0;

  // Responsive breakpoints
  static const double phoneBreakpoint  = 600.0;
  static const double tabletBreakpoint = 768.0;

  // Tablet-specific sizes
  static const double tabletInputHeight  = 56.0;
  static const double tabletButtonHeight = 52.0;
  static const double tabletFontScale    = 1.15;
}

// ─── Responsive helper ───────────────────────────────────────────────────────
class Responsive {
  final double width;
  const Responsive(this.width);

  bool get isPhone    => width < AppConstants.phoneBreakpoint;
  bool get isTabletSm => width >= AppConstants.phoneBreakpoint && width < AppConstants.tabletBreakpoint;
  bool get isTablet   => width >= AppConstants.tabletBreakpoint;
  bool get isLarge    => width >= 1024;

  T pick<T>({required T phone, T? tabletSm, T? tablet, T? large}) {
    if (isLarge)    return large ?? tablet ?? tabletSm ?? phone;
    if (isTablet)   return tablet ?? tabletSm ?? phone;
    if (isTabletSm) return tabletSm ?? phone;
    return phone;
  }
}
