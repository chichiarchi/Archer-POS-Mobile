import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/utils/formatters.dart';

class NumericKeypad extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback? onSubmit;
  final bool isDecimal;
  final bool formatAsThousands;
  final VoidCallback? onChange;

  const NumericKeypad({
    super.key,
    required this.controller,
    this.onSubmit,
    this.isDecimal = true,
    this.formatAsThousands = false,
    this.onChange,
  });

  void _onKeyPress(String value) {
    final text = controller.text;
    final selection = controller.selection;

    // Determine start and end of selection
    int start = selection.isValid ? selection.start : text.length;
    int end = selection.isValid ? selection.end : text.length;

    // Safeguard range
    if (start < 0) start = 0;
    if (end < 0) end = 0;
    if (start > text.length) start = text.length;
    if (end > text.length) end = text.length;

    String newRawText;

    if (value == 'BACKSPACE') {
      if (start == end) {
        if (start > 0) {
          // Delete character before cursor
          newRawText = text.substring(0, start - 1) + text.substring(end);
          start = start - 1;
        } else {
          return;
        }
      } else {
        // Delete selection
        newRawText = text.substring(0, start) + text.substring(end);
      }
      end = start;
    } else if (value == 'CLEAR') {
      newRawText = '';
      start = 0;
      end = 0;
    } else {
      // Decimal check
      if (value == '.') {
        final cleanText = text.replaceAll(',', '');
        if (cleanText.contains('.')) {
          return; // Allow only one decimal point
        }
        if (start == 0 || cleanText.isEmpty) {
          value = '0.';
        }
      }

      newRawText = text.substring(0, start) + value + text.substring(end);
      start = start + value.length;
      end = start;
    }

    // Process thousands formatting if enabled
    if (formatAsThousands) {
      // Format the new text
      final formatted = formatInputWithCommas(newRawText);
      controller.text = formatted;

      // Adjust cursor position to match format changes
      int commaDiff = formatted.length - newRawText.length;
      int newCursorPos = (start + commaDiff).clamp(0, formatted.length);
      controller.selection = TextSelection.collapsed(offset: newCursorPos);
    } else {
      controller.text = newRawText;
      controller.selection = TextSelection.collapsed(offset: start);
    }

    if (onChange != null) {
      onChange!();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final btnBgColor = isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9);
    final specialBtnBgColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    final textColor = cs.onSurface;

    Widget buildButton(String label, {String? actionValue, IconData? icon, bool isSpecial = false}) {
      final val = actionValue ?? label;
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.all(4.0),
          child: Material(
            color: isSpecial ? specialBtnBgColor : btnBgColor,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () => _onKeyPress(val),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 54,
                alignment: Alignment.center,
                child: icon != null
                    ? Icon(icon, color: textColor, size: 24)
                    : Text(
                        label,
                        style: GoogleFonts.inter(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            buildButton('1'),
            buildButton('2'),
            buildButton('3'),
          ],
        ),
        Row(
          children: [
            buildButton('4'),
            buildButton('5'),
            buildButton('6'),
          ],
        ),
        Row(
          children: [
            buildButton('7'),
            buildButton('8'),
            buildButton('9'),
          ],
        ),
        Row(
          children: [
            isDecimal
                ? buildButton('.')
                : buildButton('C', actionValue: 'CLEAR', isSpecial: true),
            buildButton('0'),
            buildButton('⌫', actionValue: 'BACKSPACE', icon: Icons.backspace_outlined, isSpecial: true),
          ],
        ),
        if (isDecimal)
          Row(
            children: [
              buildButton('CLEAR', actionValue: 'CLEAR', isSpecial: true),
              if (onSubmit != null)
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Material(
                      color: cs.primary,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: onSubmit,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          height: 54,
                          alignment: Alignment.center,
                          child: Text(
                            'OK',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: isDark ? const Color(0xFF0F172A) : Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
