import 'package:intl/intl.dart';

/// Format a number as Philippine Peso currency: ₱1,234.56
String formatCurrency(double amount) {
  final formatter = NumberFormat('#,##0.00', 'en_PH');
  return '₱${formatter.format(amount)}';
}

/// Format a DB timestamp string as 'Jun 02, 2026'
String formatDate(String timestamp) {
  try {
    final dt = DateTime.parse(timestamp.replaceAll(' ', 'T'));
    return DateFormat('MMM dd, yyyy').format(dt);
  } catch (_) {
    return timestamp;
  }
}

/// Format a DB timestamp string as 'Jun 02, 2026 02:30 PM'
String formatDateTime(String timestamp) {
  try {
    final dt = DateTime.parse(timestamp.replaceAll(' ', 'T'));
    return DateFormat('MMM dd, yyyy hh:mm a').format(dt);
  } catch (_) {
    return timestamp;
  }
}

/// Parse a formatted amount string (e.g. '₱1,234.56') to double
double parseAmount(String text) {
  final clean = text.replaceAll('₱', '').replaceAll(',', '').trim();
  return double.tryParse(clean) ?? 0.0;
}

/// Format raw input text (possibly with decimal point) with thousand separators
String formatInputWithCommas(String text) {
  if (text.isEmpty) return '';
  final clean = text.replaceAll(',', '');
  final parts = clean.split('.');
  if (parts.isEmpty) return '';

  final intPart = int.tryParse(parts[0]);
  if (intPart == null && parts[0].isNotEmpty) return text;

  final formatter = NumberFormat('#,##0', 'en_PH');
  final formattedInt = parts[0].isEmpty ? '' : formatter.format(intPart ?? 0);

  if (parts.length > 1) {
    return '$formattedInt.${parts[1]}';
  }
  return formattedInt;
}

/// Get current Philippines time (UTC+8) formatted for DB storage
String nowPHTimestamp() {
  final now = DateTime.now().toUtc().add(const Duration(hours: 8));
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
      '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
}

/// Get current date in PH time as 'YYYY-MM-DD'
String todayPHDate() {
  final now = DateTime.now().toUtc().add(const Duration(hours: 8));
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}

class Formatters {
  static String currency(double amount) => formatCurrency(amount);
  static String date(String timestamp) => formatDate(timestamp);
  static String dateTime(String timestamp) => formatDateTime(timestamp);
  static double amount(String text) => parseAmount(text);
}

