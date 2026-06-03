// This is a generated file; do not edit or check into version control.

import 'package:flutter/material.dart';

// App-wide color constants that match the PySide6 desktop version color scheme.
const Color kPrimaryColor = Color(0xFF0072FF);
const Color kSecondaryColor = Color(0xFF00C6FF);
const Color kBackgroundColor = Color(0xFFE8EEF2);
const Color kCardColor = Color(0xFFFFFFFF);
const Color kErrorColor = Color(0xFFEF4444);
const Color kSuccessColor = Color(0xFF10B981);
const Color kWarningColor = Color(0xFFF59E0B);
const Color kTextPrimary = Color(0xFF1E293B);
const Color kTextSecondary = Color(0xFF64748B);
const Color kBorderColor = Color(0xFFCBD5E1);
const Color kDividerColor = Color(0xFFE2E8F0);
const Color kPurpleColor = Color(0xFF6366F1);

// App system info
const String kSystemTitle = 'Archer POS';
const String kMasterRecoveryCode = '10152003';

// Pagination
const int kPageSize = 100;

// Audit log action types
const String kActionPosSale = 'POS_SALE';
const String kActionPosVoidCart = 'POS_VOID_CART';
const String kActionPosDelete = 'POS_DELETE';
const String kActionPosQtyUpdate = 'POS_QTY_UPDATE';
const String kActionPosDiscount = 'POS_DISCOUNT';
const String kActionPosPriceToggle = 'POS_ITEM_PRICE_TOGGLE';
const String kActionPosQuickAdd = 'POS_QUICK_ADD';
const String kActionVoidSale = 'VOID_SALE';
const String kActionBalanceResolve = 'BALANCE_RESOLVE';
const String kActionProductAdded = 'PRODUCT_ADDED';
const String kActionProductUpdated = 'PRODUCT_UPDATED';
const String kActionProductDeleted = 'PRODUCT_DELETED';
const String kActionBundleAdded = 'BUNDLE_ADDED';
const String kActionBundleEdited = 'BUNDLE_EDITED';
const String kActionBundleDeleted = 'BUNDLE_DELETED';
const String kActionPasswordChange = 'PASSWORD_CHANGE';
const String kActionAdminPasswordReset = 'ADMIN_PASSWORD_RESET';
const String kActionSettingsUpdate = 'SETTINGS_UPDATE';
const String kActionPaymentNoteSaved = 'PAYMENT_NOTE_SAVED';
const String kActionPaymentNoteDeleted = 'PAYMENT_NOTE_DELETED';

// Helper classes used by some screens
class AppColors {
  static const Color primary = kPrimaryColor;
  static const Color secondary = kSecondaryColor;
  static const Color background = kBackgroundColor;
  static const Color card = kCardColor;
  static const Color error = kErrorColor;
  static const Color success = kSuccessColor;
  static const Color warning = kWarningColor;
  static const Color textPrimary = kTextPrimary;
  static const Color textSecondary = kTextSecondary;
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color border = kBorderColor;
  static const Color divider = kDividerColor;
  static const Color purple = kPurpleColor;
  static const Color salesBlueTint = Color(0xFFE6F0FF);
  static const Color info = Color(0xFF3B82F6);
}

class AppConstants {
  static const double radiusSM = 6.0;
  static const double radiusMD = 12.0;
  static const double radiusLG = 20.0;
  static const double radiusFull = 9999.0;

  static const double spaceXS = 4.0;
  static const double spaceSM = 8.0;
  static const double spaceMD = 16.0;
  static const double spaceLG = 24.0;

  static const double elevationCard = 2.0;

  // Responsive breakpoints
  static const double phoneBreakpoint = 600.0;   // < 600 = phone
  static const double tabletBreakpoint = 768.0;  // >= 768 = tablet
}

/// Centralised responsive helper — pass a [BoxConstraints] (from LayoutBuilder)
/// or the screen width from MediaQuery.
class Responsive {
  final double width;
  const Responsive(this.width);

  /// Width < 600
  bool get isPhone => width < AppConstants.phoneBreakpoint;

  /// 600 ≤ width < 768  (large phone / small portrait tablet)
  bool get isTabletSm =>
      width >= AppConstants.phoneBreakpoint &&
      width < AppConstants.tabletBreakpoint;

  /// Width >= 768
  bool get isTablet => width >= AppConstants.tabletBreakpoint;

  /// Width >= 1024 (landscape tablet / desktop)
  bool get isLarge => width >= 1024;

  /// Picks a value based on current breakpoint.
  /// [phone] is always required; [tabletSm] falls back to [phone];
  /// [tablet] falls back to [tabletSm] ?? [phone]; [large] falls back to [tablet].
  T pick<T>({
    required T phone,
    T? tabletSm,
    T? tablet,
    T? large,
  }) {
    if (isLarge) return large ?? tablet ?? tabletSm ?? phone;
    if (isTablet) return tablet ?? tabletSm ?? phone;
    if (isTabletSm) return tabletSm ?? phone;
    return phone;
  }
}

