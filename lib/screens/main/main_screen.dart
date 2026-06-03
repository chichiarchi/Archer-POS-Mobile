import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/utils/constants.dart';
import '../login/login_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../pos/pos_screen.dart';
import '../inventory/inventory_screen.dart';
import '../balance/balance_screen.dart';
import '../logs/logs_screen.dart';
import '../account/account_screen.dart';
import '../payment_notes/payment_notes_screen.dart';

// ---------------------------------------------------------------------------
// Simple data class for each navigation destination
// ---------------------------------------------------------------------------
class _NavItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;

  const _NavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });
}

// ---------------------------------------------------------------------------
// MainScreen — adaptive navigation shell (tablet = NavigationRail,
//              phone = BottomNavigationBar)
// ---------------------------------------------------------------------------
class MainScreen extends StatefulWidget {
  final String username;
  final String userRole;

  const MainScreen({
    super.key,
    required this.username,
    required this.userRole,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  // ── State ─────────────────────────────────────────────────────────────────
  int _selectedIndex = 0;

  // ── Theme colours ─────────────────────────────────────────────────────────
  static const Color _primaryBlue = Color(0xFF0072FF);
  static const Color _secondaryBlue = Color(0xFF00C6FF);

  // ── Navigation metadata ──────────────────────────────────────────────────
  static const List<_NavItem> _navItems = [
    _NavItem(
      label: 'Dashboard',
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard_rounded,
    ),
    _NavItem(
      label: 'Point of Sale',
      icon: Icons.point_of_sale_outlined,
      activeIcon: Icons.point_of_sale_rounded,
    ),
    _NavItem(
      label: 'Products',
      icon: Icons.inventory_2_outlined,
      activeIcon: Icons.inventory_2_rounded,
    ),
    _NavItem(
      label: 'Balance',
      icon: Icons.account_balance_wallet_outlined,
      activeIcon: Icons.account_balance_wallet_rounded,
    ),
    _NavItem(
      label: 'Logs',
      icon: Icons.history_outlined,
      activeIcon: Icons.history_rounded,
    ),
    _NavItem(
      label: 'Account',
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
    ),
    _NavItem(
      label: 'Pay Notes',
      icon: Icons.receipt_long_outlined,
      activeIcon: Icons.receipt_long_rounded,
    ),
  ];

  // ── GlobalKeys for refresh ────────────────────────────────────────────────
  final GlobalKey<DashboardScreenState> _dashboardKey =
      GlobalKey<DashboardScreenState>();
  final GlobalKey<POSScreenState> _posKey =
      GlobalKey<POSScreenState>();
  final GlobalKey<InventoryScreenState> _inventoryKey =
      GlobalKey<InventoryScreenState>();
  final GlobalKey<BalanceScreenState> _balanceKey =
      GlobalKey<BalanceScreenState>();
  final GlobalKey<LogsScreenState> _logsKey = GlobalKey<LogsScreenState>();
  final GlobalKey<AccountScreenState> _accountKey =
      GlobalKey<AccountScreenState>();
  final GlobalKey<PaymentNotesScreenState> _paymentNotesKey =
      GlobalKey<PaymentNotesScreenState>();

  // ── Page widgets (built once, preserved in IndexedStack) ──────────────────
  late final List<Widget> _pages;

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _pages = [
      DashboardScreen(
        key: _dashboardKey,
        username: widget.username,
        userRole: widget.userRole,
      ),
      POSScreen(
        key: _posKey,
        username: widget.username,
        userRole: widget.userRole,
      ),
      InventoryScreen(
        key: _inventoryKey,
        userRole: widget.userRole,
      ),
      BalanceScreen(
        key: _balanceKey,
        userRole: widget.userRole,
      ),
      LogsScreen(
        key: _logsKey,
        userRole: widget.userRole,
      ),
      AccountScreen(
        key: _accountKey,
        username: widget.username,
        userRole: widget.userRole,
      ),
      PaymentNotesScreen(
        key: _paymentNotesKey,
        userRole: widget.userRole,
      ),
    ];
  }

  // ── Tab change ────────────────────────────────────────────────────────────
  void _onTabChanged(int index) {
    if (!mounted) return;
    setState(() => _selectedIndex = index);
    _triggerRefresh(index);
  }

  /// Calls refresh() on the newly active screen if it exposes one.
  void _triggerRefresh(int index) {
    switch (index) {
      case 0:
        _dashboardKey.currentState?.refresh();
      case 1:
        _posKey.currentState?.refresh();
      case 2:
        _inventoryKey.currentState?.refresh();
      case 3:
        _balanceKey.currentState?.refresh();
      case 4:
        _logsKey.currentState?.refresh();
      case 5:
        _accountKey.currentState?.refresh();
      case 6:
        _paymentNotesKey.currentState?.refresh();
      default:
        break;
    }
  }

  // ── Logout ────────────────────────────────────────────────────────────────
  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Sign Out',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: const Color(0xFF1E293B),
          ),
        ),
        content: Text(
          'Are you sure you want to sign out?',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: const Color(0xFF475569),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                color: const Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Sign Out',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await context.read<AuthProvider>().logout();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  // ── Derived getters ───────────────────────────────────────────────────────
  String get _currentPageTitle => _navItems[_selectedIndex].label;

  String get _roleDisplay {
    switch (widget.userRole.toLowerCase()) {
      case 'admin':
        return 'Administrator';
      case 'staff':
        return 'Staff';
      default:
        return widget.userRole;
    }
  }

  // ── Build root ────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth >= AppConstants.tabletBreakpoint;
        return isTablet ? _buildTabletLayout() : _buildPhoneLayout();
      },
    );
  }

  // ===========================================================================
  // TABLET LAYOUT — NavigationRail
  // ===========================================================================
  Widget _buildTabletLayout() {
    return Scaffold(
      backgroundColor: const Color(0xFFE8EEF2),
      body: Row(
        children: [
          // ── Navigation Rail ──────────────────────────────────────────
          _buildNavigationRail(),

          // ── Divider ──────────────────────────────────────────────────
          Container(width: 1, color: const Color(0xFFE2E8F0)),

          // ── Content area ─────────────────────────────────────────────
          Expanded(
            child: Column(
              children: [
                _buildTabletTopBar(),
                Expanded(
                  child: IndexedStack(
                    index: _selectedIndex,
                    children: _pages,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The NavigationRail widget for tablet layout.
  Widget _buildNavigationRail() {
    return Container(
      color: Colors.white,
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height,
          ),
          child: IntrinsicHeight(
            child: NavigationRail(
              backgroundColor: Colors.white,
              selectedIndex: _selectedIndex,
              onDestinationSelected: _onTabChanged,
              extended: false,
              minWidth: 72,
              useIndicator: true,
              indicatorColor: const Color(0xFFE0F2FE),
              labelType: NavigationRailLabelType.all,
              selectedIconTheme: const IconThemeData(color: _primaryBlue, size: 22),
              unselectedIconTheme:
                  const IconThemeData(color: Color(0xFF94A3B8), size: 20),
              selectedLabelTextStyle: GoogleFonts.inter(
                color: _primaryBlue,
                fontWeight: FontWeight.w700,
                fontSize: 9,
              ),
              unselectedLabelTextStyle: GoogleFonts.inter(
                color: const Color(0xFF94A3B8),
                fontSize: 9,
              ),
              leading: _buildRailHeader(),
              trailing: _buildRailTrailing(),
              destinations: _navItems
                  .map(
                    (item) => NavigationRailDestination(
                      icon: Icon(item.icon),
                      selectedIcon: Icon(item.activeIcon),
                      label: Text(item.label),
                      padding: const EdgeInsets.symmetric(vertical: 2),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ),
    );
  }

  /// App icon + branding pinned at the top of the NavigationRail.
  Widget _buildRailHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
      child: Column(
        children: [
          // App gradient icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_primaryBlue, _secondaryBlue],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: _primaryBlue.withOpacity(0.30),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.point_of_sale_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'ARCHER',
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              color: _primaryBlue,
              letterSpacing: 2,
            ),
          ),
          Text(
            'POS',
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF94A3B8),
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 1,
            color: const Color(0xFFE2E8F0),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  /// Logout button pinned at the bottom of the NavigationRail.
  Widget _buildRailTrailing() {
    return Expanded(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 1,
                color: const Color(0xFFE2E8F0),
              ),
              const SizedBox(height: 12),
              Tooltip(
                message: 'Sign out (${widget.username})',
                child: InkWell(
                  onTap: _handleLogout,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.logout_rounded,
                      color: Color(0xFFEF4444),
                      size: 22,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Logout',
                style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFEF4444),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Slim top bar shown above the content area in tablet layout.
  Widget _buildTabletTopBar() {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      child: Row(
        children: [
          // Current page breadcrumb
          Row(
            children: [
              const Icon(Icons.home_outlined,
                  size: 16, color: Color(0xFF94A3B8)),
              const SizedBox(width: 6),
              Text(
                '/',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                _currentPageTitle,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const Spacer(),
          // User info chip
          _buildUserChip(),
        ],
      ),
    );
  }

  // ===========================================================================
  // PHONE LAYOUT — BottomNavigationBar
  // ===========================================================================
  Widget _buildPhoneLayout() {
    return Scaffold(
      backgroundColor: const Color(0xFFE8EEF2),
      appBar: _buildPhoneAppBar(),
      body: SafeArea(
        top: false,
        child: IndexedStack(
          index: _selectedIndex,
          children: _pages,
        ),
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  PreferredSizeWidget _buildPhoneAppBar() {
    return AppBar(
      elevation: 0,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_primaryBlue, _secondaryBlue],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        ),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'ARCHER POS',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 1.5,
            ),
          ),
          Text(
            _currentPageTitle,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: Colors.white70,
            ),
          ),
        ],
      ),
      actions: [
        // User badge
        _buildUserChip(light: true),
        // Logout button
        IconButton(
          icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 22),
          tooltip: 'Sign out',
          onPressed: _handleLogout,
        ),
      ],
    );
  }

  Widget _buildBottomNavBar() {
    // 7 items are too many for a standard BottomNavigationBar on small phones.
    // We use a compact scrollable row to avoid label truncation and overflow.
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 60,
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
                      Icon(
                        isSelected ? item.activeIcon : item.icon,
                        color: isSelected
                            ? _primaryBlue
                            : const Color(0xFF94A3B8),
                        size: 20,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        // Shorten labels that are too long for 7-item nav
                        _shortLabel(item.label),
                        style: GoogleFonts.inter(
                          fontSize: 8,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w400,
                          color: isSelected
                              ? _primaryBlue
                              : const Color(0xFF94A3B8),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
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
    // Compact labels so 7 items fit without overflow
    switch (label) {
      case 'Dashboard':
        return 'Home';
      case 'Point of Sale':
        return 'POS';
      case 'Products':
        return 'Products';
      case 'Balance':
        return 'Balance';
      case 'Logs':
        return 'Logs';
      case 'Account':
        return 'Account';
      case 'Pay Notes':
        return 'Pay';
      default:
        return label;
    }
  }

  // ===========================================================================
  // Shared widgets
  // ===========================================================================

  /// User chip — shows avatar initial, username and role.
  /// [light] = true for use on dark (gradient) AppBar background.
  Widget _buildUserChip({bool light = false}) {
    final bgColor = light
        ? Colors.white.withOpacity(0.18)
        : const Color(0xFFF1F5F9);
    final nameColor = light ? Colors.white : const Color(0xFF1E293B);
    final roleColor = light ? Colors.white70 : const Color(0xFF64748B);
    final avatarBg = light
        ? Colors.white.withOpacity(0.30)
        : const Color(0xFFE0F2FE);
    final avatarTextColor = light ? Colors.white : _primaryBlue;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Avatar circle
            CircleAvatar(
              radius: 14,
              backgroundColor: avatarBg,
              child: Text(
                widget.username.isNotEmpty
                    ? widget.username[0].toUpperCase()
                    : '?',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: avatarTextColor,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.username,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: nameColor,
                  ),
                ),
                Text(
                  _roleDisplay,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: roleColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
