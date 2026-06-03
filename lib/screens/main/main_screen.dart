import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/utils/constants.dart';
import '../login/login_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../pos/pos_screen.dart';
import '../inventory/inventory_screen.dart';
import '../balance/balance_screen.dart';
import '../logs/logs_screen.dart';
import '../account/account_screen.dart';
import '../payment_notes/payment_notes_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Size-Freezing Wrapper — locks the child's constraints when it is offstage
// so hidden IndexedStack pages don't re-layout during keyboard animations.
// ─────────────────────────────────────────────────────────────────────────────
class _SizeFreezingWrapper extends StatefulWidget {
  final Widget child;
  final bool isOffstage;

  const _SizeFreezingWrapper({required this.child, required this.isOffstage});

  @override
  State<_SizeFreezingWrapper> createState() => _SizeFreezingWrapperState();
}

class _SizeFreezingWrapperState extends State<_SizeFreezingWrapper> {
  BoxConstraints? _frozenConstraints;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        if (!widget.isOffstage || _frozenConstraints == null) {
          _frozenConstraints = constraints;
        }
        return ConstrainedBox(
          constraints: BoxConstraints.tight(
            Size(_frozenConstraints!.maxWidth, _frozenConstraints!.maxHeight),
          ),
          child: widget.child,
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _NavItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  const _NavItem({required this.label, required this.icon, required this.activeIcon});
}

// ─────────────────────────────────────────────────────────────────────────────
class MainScreen extends StatefulWidget {
  final String username;
  final String userRole;

  const MainScreen({super.key, required this.username, required this.userRole});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  static const List<_NavItem> _navItems = [
    _NavItem(label: 'Dashboard',    icon: Icons.dashboard_outlined,           activeIcon: Icons.dashboard_rounded),
    _NavItem(label: 'Point of Sale',icon: Icons.point_of_sale_outlined,       activeIcon: Icons.point_of_sale_rounded),
    _NavItem(label: 'Products',     icon: Icons.inventory_2_outlined,         activeIcon: Icons.inventory_2_rounded),
    _NavItem(label: 'Balance',      icon: Icons.account_balance_wallet_outlined, activeIcon: Icons.account_balance_wallet_rounded),
    _NavItem(label: 'Logs',         icon: Icons.history_outlined,             activeIcon: Icons.history_rounded),
    _NavItem(label: 'Account',      icon: Icons.person_outline_rounded,       activeIcon: Icons.person_rounded),
    _NavItem(label: 'Pay Notes',    icon: Icons.receipt_long_outlined,        activeIcon: Icons.receipt_long_rounded),
  ];

  final GlobalKey<DashboardScreenState>    _dashboardKey    = GlobalKey<DashboardScreenState>();
  final GlobalKey<POSScreenState>          _posKey          = GlobalKey<POSScreenState>();
  final GlobalKey<InventoryScreenState>    _inventoryKey    = GlobalKey<InventoryScreenState>();
  final GlobalKey<BalanceScreenState>      _balanceKey      = GlobalKey<BalanceScreenState>();
  final GlobalKey<LogsScreenState>         _logsKey         = GlobalKey<LogsScreenState>();
  final GlobalKey<AccountScreenState>      _accountKey      = GlobalKey<AccountScreenState>();
  final GlobalKey<PaymentNotesScreenState> _paymentNotesKey = GlobalKey<PaymentNotesScreenState>();

  List<Widget> _buildPages() {
    return [
      DashboardScreen(key: _dashboardKey, username: widget.username, userRole: widget.userRole),
      POSScreen(key: _posKey, username: widget.username, userRole: widget.userRole, isActive: _selectedIndex == 1),
      InventoryScreen(key: _inventoryKey, userRole: widget.userRole),
      BalanceScreen(key: _balanceKey, userRole: widget.userRole),
      LogsScreen(key: _logsKey, userRole: widget.userRole),
      AccountScreen(key: _accountKey, username: widget.username, userRole: widget.userRole),
      PaymentNotesScreen(key: _paymentNotesKey, userRole: widget.userRole),
    ];
  }

  void _onTabChanged(int index) {
    if (!mounted) return;
    setState(() => _selectedIndex = index);
    _triggerRefresh(index);
  }

  void _triggerRefresh(int index) {
    switch (index) {
      case 0: _dashboardKey.currentState?.refresh();
      case 1: _posKey.currentState?.refresh();
      case 2: _inventoryKey.currentState?.refresh();
      case 3: _balanceKey.currentState?.refresh();
      case 4: _logsKey.currentState?.refresh();
      case 5: _accountKey.currentState?.refresh();
      case 6: _paymentNotesKey.currentState?.refresh();
    }
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Sign Out', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 18, color: cs.onSurface)),
          content: Text('Are you sure you want to sign out?', style: GoogleFonts.inter(fontSize: 14, color: cs.onSurface.withOpacity(0.7))),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false),
                child: Text('Cancel', style: GoogleFonts.inter(color: cs.onSurface.withOpacity(0.6), fontWeight: FontWeight.w600))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), elevation: 0),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text('Sign Out', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            ),
          ],
        );
      },
    );
    if (confirmed == true && mounted) {
      await context.read<AuthProvider>().logout();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
      }
    }
  }

  String get _currentPageTitle => _navItems[_selectedIndex].label;

  String get _roleDisplay {
    switch (widget.userRole.toLowerCase()) {
      case 'admin': return 'Administrator';
      case 'staff': return 'Staff';
      default:      return widget.userRole;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final cs = Theme.of(context).colorScheme;
        final shouldExit = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text('Exit App', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 18, color: cs.onSurface)),
            content: Text('Are you sure you want to exit?',
                style: GoogleFonts.inter(fontSize: 14, color: cs.onSurface.withOpacity(0.7))),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text('Cancel', style: GoogleFonts.inter(color: cs.onSurface.withOpacity(0.6), fontWeight: FontWeight.w600))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), elevation: 0),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text('Exit', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        );
        if (shouldExit == true) SystemNavigator.pop();
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isTablet = constraints.maxWidth >= AppConstants.tabletBreakpoint;
          return isTablet ? _buildTabletLayout() : _buildPhoneLayout();
        },
      ),
    );
  }

  // ── TABLET LAYOUT ──────────────────────────────────────────────────────────
  Widget _buildTabletLayout() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final railBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    final pages = _buildPages();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Row(
        children: [
          // Nav Rail
          Container(
            color: railBg,
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: MediaQuery.sizeOf(context).height),
                child: IntrinsicHeight(
                  child: NavigationRail(
                    backgroundColor: railBg,
                    selectedIndex: _selectedIndex,
                    onDestinationSelected: _onTabChanged,
                    extended: false,
                    minWidth: 80,
                    useIndicator: true,
                    labelType: NavigationRailLabelType.all,
                    leading: _buildRailHeader(isDark, cs),
                    trailing: _buildRailTrailing(isDark, cs),
                    destinations: _navItems.map((item) => NavigationRailDestination(
                      icon: Icon(item.icon),
                      selectedIcon: Icon(item.activeIcon),
                      label: Text(item.label),
                      padding: const EdgeInsets.symmetric(vertical: 2),
                    )).toList(),
                  ),
                ),
              ),
            ),
          ),
          // Divider
          Container(width: 1, color: borderColor),
          // Content
          Expanded(
            child: Column(
              children: [
                _buildTabletTopBar(isDark, cs, borderColor),
                Expanded(
                  child: IndexedStack(
                    index: _selectedIndex,
                    children: pages.asMap().entries.map((e) =>
                      _SizeFreezingWrapper(
                        isOffstage: _selectedIndex != e.key,
                        child: e.value,
                      ),
                    ).toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRailHeader(bool isDark, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
      child: Column(
        children: [
          Container(
            width: 50, height: 50,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [cs.primary, cs.secondary],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: cs.primary.withOpacity(0.30), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: const Icon(Icons.point_of_sale_rounded, color: Colors.white, size: 26),
          ),
          const SizedBox(height: 6),
          Text('ARCHER', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w900, color: cs.primary, letterSpacing: 2)),
          Text('POS', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w600, color: cs.onSurface.withOpacity(0.4), letterSpacing: 2)),
          const SizedBox(height: 12),
          Container(width: 40, height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildRailTrailing(bool isDark, ColorScheme cs) {
    return Expanded(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              const SizedBox(height: 12),
              Tooltip(
                message: 'Sign out (${widget.username})',
                child: InkWell(
                  onTap: _handleLogout,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: 50, height: 50,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDC2626).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.logout_rounded, color: Color(0xFFDC2626), size: 22),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text('Logout', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w600, color: const Color(0xFFDC2626))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabletTopBar(bool isDark, ColorScheme cs, Color borderColor) {
    return Container(
      height: 66,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Row(
        children: [
          Row(children: [
            Icon(Icons.home_outlined, size: 16, color: cs.onSurface.withOpacity(0.4)),
            const SizedBox(width: 6),
            Text('/', style: GoogleFonts.inter(fontSize: 14, color: cs.onSurface.withOpacity(0.4))),
            const SizedBox(width: 6),
            Text(_currentPageTitle, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: cs.onSurface)),
          ]),
          const Spacer(),
          // Dark mode toggle
          Consumer<ThemeProvider>(
            builder: (ctx, tp, _) => Tooltip(
              message: tp.isDarkMode ? 'Switch to Light Mode' : 'Switch to Dark Mode',
              child: InkWell(
                onTap: tp.toggleTheme,
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(tp.isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                          size: 18, color: tp.isDarkMode ? const Color(0xFF60A5FA) : const Color(0xFFD97706)),
                      const SizedBox(width: 6),
                      Text(tp.isDarkMode ? 'Dark' : 'Light',
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600,
                              color: cs.onSurface.withOpacity(0.8))),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          _buildUserChip(isDark: isDark, cs: cs),
        ],
      ),
    );
  }

  // ── PHONE LAYOUT ──────────────────────────────────────────────────────────
  Widget _buildPhoneLayout() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final pages = _buildPages();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: _buildPhoneAppBar(cs),
      body: SafeArea(
        top: false,
        child: IndexedStack(
          index: _selectedIndex,
          children: pages.asMap().entries.map((e) =>
            _SizeFreezingWrapper(
              isOffstage: _selectedIndex != e.key,
              child: e.value,
            ),
          ).toList(),
        ),
      ),
      bottomNavigationBar: _buildBottomNavBar(isDark, cs),
    );
  }

  PreferredSizeWidget _buildPhoneAppBar(ColorScheme cs) {
    return AppBar(
      elevation: 0,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [cs.primary, cs.secondary],
            begin: Alignment.centerLeft, end: Alignment.centerRight,
          ),
        ),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('ARCHER POS', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.5)),
          Text(_currentPageTitle, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w400, color: Colors.white70)),
        ],
      ),
      actions: [
        Consumer<ThemeProvider>(
          builder: (ctx, tp, _) => IconButton(
            icon: Icon(tp.isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded, color: Colors.white),
            onPressed: tp.toggleTheme,
            tooltip: tp.isDarkMode ? 'Light Mode' : 'Dark Mode',
          ),
        ),
        IconButton(icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 22), tooltip: 'Sign out', onPressed: _handleLogout),
      ],
    );
  }

  Widget _buildBottomNavBar(bool isDark, ColorScheme cs) {
    final bg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final border = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: Border(top: BorderSide(color: border)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, -4))],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 68,
          child: Row(
            children: List.generate(_navItems.length, (index) {
              final item = _navItems[index];
              final isSelected = _selectedIndex == index;
              return Expanded(
                child: InkWell(
                  onTap: () => _onTabChanged(index),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(isSelected ? item.activeIcon : item.icon,
                          color: isSelected ? cs.primary : cs.onSurface.withOpacity(0.4), size: 24),
                      const SizedBox(height: 2),
                      Text(_shortLabel(item.label),
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                            color: isSelected ? cs.primary : cs.onSurface.withOpacity(0.4),
                          ),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  String _shortLabel(String label) {
    switch (label) {
      case 'Dashboard':     return 'Home';
      case 'Point of Sale': return 'POS';
      case 'Products':      return 'Products';
      case 'Balance':       return 'Balance';
      case 'Logs':          return 'Logs';
      case 'Account':       return 'Account';
      case 'Pay Notes':     return 'Pay';
      default:              return label;
    }
  }

  Widget _buildUserChip({required bool isDark, required ColorScheme cs}) {
    final bgColor = isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(20)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: cs.primary.withOpacity(0.15),
              child: Text(
                widget.username.isNotEmpty ? widget.username[0].toUpperCase() : '?',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: cs.primary),
              ),
            ),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(widget.username, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: cs.onSurface)),
                Text(_roleDisplay, style: GoogleFonts.inter(fontSize: 10, color: cs.onSurface.withOpacity(0.5))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
