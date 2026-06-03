import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'core/database/database_helper.dart';
import 'core/providers/auth_provider.dart';
import 'core/providers/cart_provider.dart';
import 'core/providers/theme_provider.dart';
import 'screens/login/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await DatabaseHelper.instance.database;

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const ArcherPOSApp(),
    ),
  );
}

class ArcherPOSApp extends StatelessWidget {
  const ArcherPOSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return MaterialApp(
          title: 'Archer POS',
          debugShowCheckedModeBanner: false,
          themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          theme: _buildLightTheme(),
          darkTheme: _buildDarkTheme(),
          home: const LoginScreen(),
        );
      },
    );
  }

  // ── Light Theme ─────────────────────────────────────────────────────────────
  ThemeData _buildLightTheme() {
    final base = ThemeData.light(useMaterial3: false);
    return base.copyWith(
      colorScheme: const ColorScheme.light(
        primary:    Color(0xFF1A56DB),
        secondary:  Color(0xFF0EA5E9),
        surface:    Color(0xFFFFFFFF),
        error:      Color(0xFFDC2626),
        onPrimary:  Colors.white,
        onSecondary: Colors.white,
        onSurface:  Color(0xFF0F172A),
        onError:    Colors.white,
      ),
      scaffoldBackgroundColor: const Color(0xFFF1F5F9),
      textTheme: GoogleFonts.interTextTheme(base.textTheme).copyWith(
        displayLarge:  GoogleFonts.inter(fontSize: 34, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A)),
        headlineLarge: GoogleFonts.inter(fontSize: 26, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
        headlineMedium: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
        titleLarge:    GoogleFonts.inter(fontSize: 19, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
        bodyLarge:     GoogleFonts.inter(fontSize: 16, color: const Color(0xFF0F172A)),
        bodyMedium:    GoogleFonts.inter(fontSize: 15, color: const Color(0xFF475569)),
        labelLarge:    GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A),
        ),
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1A56DB),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF1A56DB), width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 15),
        labelStyle: GoogleFonts.inter(color: const Color(0xFF475569), fontSize: 15),
      ),
      dividerTheme: const DividerThemeData(color: Color(0xFFE2E8F0), thickness: 1),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? const Color(0xFF1A56DB) : Colors.white),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? const Color(0xFF1A56DB).withOpacity(0.4) : const Color(0xFFCBD5E1)),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: Color(0xFF1A56DB),
        unselectedItemColor: Color(0xFF94A3B8),
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: Colors.white,
        selectedIconTheme: const IconThemeData(color: Color(0xFF1A56DB)),
        unselectedIconTheme: const IconThemeData(color: Color(0xFF94A3B8)),
        selectedLabelTextStyle: GoogleFonts.inter(color: const Color(0xFF1A56DB), fontWeight: FontWeight.w700, fontSize: 11),
        unselectedLabelTextStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 11),
        indicatorColor: const Color(0xFFDBEAFE),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: const Color(0xFF0F172A),
        ),
        contentTextStyle: GoogleFonts.inter(
          fontSize: 15,
          color: const Color(0xFF475569),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        modalBackgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
    );
  }

  // ── Dark Theme ──────────────────────────────────────────────────────────────
  ThemeData _buildDarkTheme() {
    final base = ThemeData.dark(useMaterial3: false);
    return base.copyWith(
      colorScheme: const ColorScheme.dark(
        primary:     Color(0xFF60A5FA),
        secondary:   Color(0xFF38BDF8),
        surface:     Color(0xFF1E293B),
        error:       Color(0xFFF87171),
        onPrimary:   Color(0xFF0F172A),
        onSecondary: Color(0xFF0F172A),
        onSurface:   Color(0xFFF1F5F9),
        onError:     Color(0xFF0F172A),
      ),
      scaffoldBackgroundColor: const Color(0xFF0F172A),
      textTheme: GoogleFonts.interTextTheme(base.textTheme).copyWith(
        displayLarge:  GoogleFonts.inter(fontSize: 34, fontWeight: FontWeight.w900, color: const Color(0xFFF1F5F9)),
        headlineLarge: GoogleFonts.inter(fontSize: 26, fontWeight: FontWeight.w800, color: const Color(0xFFF1F5F9)),
        headlineMedium: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700, color: const Color(0xFFF1F5F9)),
        titleLarge:    GoogleFonts.inter(fontSize: 19, fontWeight: FontWeight.w600, color: const Color(0xFFF1F5F9)),
        bodyLarge:     GoogleFonts.inter(fontSize: 16, color: const Color(0xFFF1F5F9)),
        bodyMedium:    GoogleFonts.inter(fontSize: 15, color: const Color(0xFF94A3B8)),
        labelLarge:    GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: const Color(0xFFF1F5F9)),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: const Color(0xFFF1F5F9),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20, fontWeight: FontWeight.w700, color: const Color(0xFFF1F5F9),
        ),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFF334155)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF60A5FA),
          foregroundColor: const Color(0xFF0F172A),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1E293B),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF334155)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF334155)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF60A5FA), width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 15),
        labelStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 15),
      ),
      dividerTheme: const DividerThemeData(color: Color(0xFF334155), thickness: 1),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? const Color(0xFF60A5FA) : const Color(0xFF475569)),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? const Color(0xFF60A5FA).withOpacity(0.4) : const Color(0xFF334155)),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF1E293B),
        selectedItemColor: Color(0xFF60A5FA),
        unselectedItemColor: Color(0xFF64748B),
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: const Color(0xFF1E293B),
        selectedIconTheme: const IconThemeData(color: Color(0xFF60A5FA)),
        unselectedIconTheme: const IconThemeData(color: Color(0xFF64748B)),
        selectedLabelTextStyle: GoogleFonts.inter(color: const Color(0xFF60A5FA), fontWeight: FontWeight.w700, fontSize: 11),
        unselectedLabelTextStyle: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 11),
        indicatorColor: const Color(0xFF1E3A5F),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF334155), width: 1),
        ),
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: const Color(0xFFF1F5F9),
        ),
        contentTextStyle: GoogleFonts.inter(
          fontSize: 15,
          color: const Color(0xFF94A3B8),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Color(0xFF1E293B),
        modalBackgroundColor: Color(0xFF1E293B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          side: BorderSide(color: Color(0xFF334155), width: 1),
        ),
      ),
    );
  }
}
