import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/database/database_helper.dart';
import '../../core/utils/constants.dart';
import '../../core/utils/formatters.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DashboardScreen
// ─────────────────────────────────────────────────────────────────────────────

class DashboardScreen extends StatefulWidget {
  final String username;
  final String userRole;

  const DashboardScreen({
    super.key,
    required this.username,
    required this.userRole,
  });

  @override
  State<DashboardScreen> createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  // ── State ──────────────────────────────────────────────────────────────────
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic> _stats = {
    'sales_today': 0.0,
    'transactions_today': 0,
    'total_products': 0,
    'total_balance': 0.0,
  };

  // ── Clock ──────────────────────────────────────────────────────────────────
  late String _currentTime;
  late String _currentDate;
  Timer? _clockTimer;

  // ── Animation controllers ──────────────────────────────────────────────────
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  // Number counter animations
  late AnimationController _counterController;
  late Animation<double> _salesTodayAnim;
  late Animation<double> _transactionsAnim;
  late Animation<double> _productsAnim;
  late Animation<double> _balanceAnim;

  double _prevSalesToday = 0;
  double _prevTransactions = 0;
  double _prevProducts = 0;
  double _prevBalance = 0;

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _initClock();
    _initAnimations();
    _loadStats();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  /// Public method — called by MainScreen when this tab comes into focus.
  void refresh() {
    _loadStats();
  }

  void _initClock() {
    _updateClock();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) _updateClock();
    });
  }

  void _updateClock() {
    final now = DateTime.now();
    setState(() {
      _currentTime = DateFormat('hh:mm:ss a').format(now);
      _currentDate = DateFormat('EEEE, MMMM d, y').format(now);
    });
  }

  void _initAnimations() {
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _counterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));

    _salesTodayAnim = Tween<double>(begin: 0, end: 0).animate(_counterController);
    _transactionsAnim = Tween<double>(begin: 0, end: 0).animate(_counterController);
    _productsAnim = Tween<double>(begin: 0, end: 0).animate(_counterController);
    _balanceAnim = Tween<double>(begin: 0, end: 0).animate(_counterController);
  }

  Future<void> _loadStats() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final stats = await DatabaseHelper.instance.getDashboardStats();
      if (!mounted) return;

      // Animate counters from previous → new values
      final newSales = (stats['sales_today'] as num?)?.toDouble() ?? 0.0;
      final newTx = (stats['transactions_today'] as num?)?.toDouble() ?? 0.0;
      final newProducts = (stats['total_products'] as num?)?.toDouble() ?? 0.0;
      final newBalance = (stats['total_balance'] as num?)?.toDouble() ?? 0.0;

      setState(() {
        _stats = stats;
        _isLoading = false;
      });

      // Reset & rebuild counter animations with new targets
      _counterController.reset();
      _salesTodayAnim = Tween<double>(
        begin: _prevSalesToday,
        end: newSales,
      ).animate(CurvedAnimation(
        parent: _counterController,
        curve: Curves.easeOutCubic,
      ));
      _transactionsAnim = Tween<double>(
        begin: _prevTransactions,
        end: newTx,
      ).animate(CurvedAnimation(
        parent: _counterController,
        curve: Curves.easeOutCubic,
      ));
      _productsAnim = Tween<double>(
        begin: _prevProducts,
        end: newProducts,
      ).animate(CurvedAnimation(
        parent: _counterController,
        curve: Curves.easeOutCubic,
      ));
      _balanceAnim = Tween<double>(
        begin: _prevBalance,
        end: newBalance,
      ).animate(CurvedAnimation(
        parent: _counterController,
        curve: Curves.easeOutCubic,
      ));

      _counterController.forward();
      _fadeController.forward(from: 0);
      _slideController.forward(from: 0);

      // Store for next animation cycle
      _prevSalesToday = newSales;
      _prevTransactions = newTx;
      _prevProducts = newProducts;
      _prevBalance = newBalance;
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Failed to load dashboard data. Please try again.';
      });
    }
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _fadeController.dispose();
    _slideController.dispose();
    _counterController.dispose();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width >= AppConstants.tabletBreakpoint;

    return Scaffold(
      backgroundColor: const Color(0xFFEEF2F7),
      body: RefreshIndicator(
        onRefresh: _loadStats,
        color: AppColors.primary,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── Header banner ──
            SliverToBoxAdapter(child: _buildHeader(isTablet)),

            // ── Loading / Error ──
            if (_isLoading)
              const SliverToBoxAdapter(child: _LoadingOverlay())
            else if (_error != null)
              SliverToBoxAdapter(child: _buildError())
            else ...[
              // ── Stat cards ──
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  isTablet ? 24 : 16,
                  isTablet ? 24 : 16,
                  isTablet ? 24 : 16,
                  isTablet ? 8 : 4,
                ),
                sliver: isTablet
                    ? _buildTabletCards()
                    : _buildPhoneCards(),
              ),

              // ── Welcome section ──
              SliverToBoxAdapter(
                child: _buildWelcomeSection(isTablet),
              ),

              // ── Quick stats row ──
              SliverToBoxAdapter(
                child: _buildQuickInfoRow(isTablet),
              ),

              // ── Bottom padding ──
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader(bool isTablet) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0072FF), Color(0xFF00C6FF)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? 28 : 20,
            vertical: isTablet ? 28 : 22,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left — logo + greeting
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: isTablet ? 46 : 38,
                          height: isTablet ? 46 : 38,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.point_of_sale_rounded,
                            color: Colors.white,
                            size: isTablet ? 26 : 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Archer POS',
                          style: GoogleFonts.inter(
                            fontSize: isTablet ? 22 : 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Dashboard Overview',
                      style: GoogleFonts.inter(
                        fontSize: isTablet ? 28 : 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.5,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _currentDate,
                      style: GoogleFonts.inter(
                        fontSize: isTablet ? 14 : 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withOpacity(0.85),
                      ),
                    ),
                  ],
                ),
              ),

              // Right — clock + refresh
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Refresh button
                  GestureDetector(
                    onTap: _loadStats,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.refresh_rounded,
                          color: Colors.white, size: 20),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Live clock
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.access_time_rounded,
                            color: Colors.white, size: 15),
                        const SizedBox(width: 6),
                        Text(
                          _currentTime,
                          style: GoogleFonts.inter(
                            fontSize: isTablet ? 16 : 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.5,
                            fontFeatures: const [
                              FontFeature('tnum'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Role badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      widget.userRole.toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Stat Cards — Phone (2×2 grid) ─────────────────────────────────────────────
  Widget _buildPhoneCards() {
    return SliverGrid(
      delegate: SliverChildListDelegate([
        _buildStatCard(config: _cardConfigs[0], animValue: _salesTodayAnim),
        _buildStatCard(config: _cardConfigs[1], animValue: _transactionsAnim),
        _buildStatCard(config: _cardConfigs[2], animValue: _productsAnim),
        _buildStatCard(config: _cardConfigs[3], animValue: _balanceAnim),
      ]),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        // Use FittedBox inside cards so we don't need to hard-code aspect ratio;
        // 1.45 is comfortable for most phone widths.
        childAspectRatio: (MediaQuery.of(context).size.width - 16 * 2 - 12) / 2 / 120,
      ),
    );
  }

  // ── Stat Cards — Tablet (1×4 horizontal row) ──────────────────────────────────────────────
  Widget _buildTabletCards() {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    return SliverGrid(
      delegate: SliverChildListDelegate([
        _buildStatCard(config: _cardConfigs[0], animValue: _salesTodayAnim),
        _buildStatCard(config: _cardConfigs[1], animValue: _transactionsAnim),
        _buildStatCard(config: _cardConfigs[2], animValue: _productsAnim),
        _buildStatCard(config: _cardConfigs[3], animValue: _balanceAnim),
      ]),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        // Adapt aspect ratio: wide/short in landscape (1.7), taller in portrait (1.05) to prevent overflow
        childAspectRatio: isLandscape ? 1.7 : 1.05,
      ),
    );
  }

  // ── Individual stat card ───────────────────────────────────────────────────
  Widget _buildStatCard({
    required _StatCardConfig config,
    required Animation<double> animValue,
  }) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: AnimatedBuilder(
          animation: animValue,
          builder: (context, _) {
            final isTablet =
                MediaQuery.of(context).size.width >= AppConstants.tabletBreakpoint;
            final displayValue = config.isCurrency
                ? Formatters.currency(animValue.value)
                : animValue.value.toInt().toString();

            return _StatCard(
              config: config,
              displayValue: displayValue,
              isTablet: isTablet,
            );
          },
        ),
      ),
    );
  }

  // ── Welcome section ────────────────────────────────────────────────────────
  Widget _buildWelcomeSection(bool isTablet) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          isTablet ? 24 : 16,
          isTablet ? 16 : 12,
          isTablet ? 24 : 16,
          0,
        ),
        child: Container(
          padding: EdgeInsets.all(isTablet ? 24 : 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0072FF).withOpacity(0.06),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              // Avatar
              Container(
                width: isTablet ? 60 : 50,
                height: isTablet ? 60 : 50,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0072FF), Color(0xFF00C6FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    widget.username.isNotEmpty
                        ? widget.username[0].toUpperCase()
                        : 'U',
                    style: GoogleFonts.inter(
                      fontSize: isTablet ? 26 : 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back,',
                      style: GoogleFonts.inter(
                        fontSize: isTablet ? 13 : 12,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF94A3B8),
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.username,
                      style: GoogleFonts.inter(
                        fontSize: isTablet ? 22 : 18,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1E293B),
                        letterSpacing: -0.3,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'System online · ${widget.userRole}',
                          style: GoogleFonts.inter(
                            fontSize: isTablet ? 12 : 11,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Decorative icon
              Icon(
                widget.userRole.toLowerCase() == 'admin'
                    ? Icons.admin_panel_settings_rounded
                    : Icons.badge_rounded,
                size: isTablet ? 36 : 30,
                color: AppColors.primary.withOpacity(0.15),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Quick info row (summary tiles) ─────────────────────────────────────────────────────
  Widget _buildQuickInfoRow(bool isTablet) {
    final salesToday = ((_stats['sales_today'] as num?)?.toDouble() ?? 0.0);
    final transactions = ((_stats['transactions_today'] as num?)?.toInt() ?? 0);
    final avgTicket = transactions > 0 ? salesToday / transactions : 0.0;
    final products = ((_stats['total_products'] as num?)?.toInt() ?? 0);

    return FadeTransition(
      opacity: _fadeAnim,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          isTablet ? 24 : 16,
          12,
          isTablet ? 24 : 16,
          0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 10, left: 2),
              child: Text(
                'TODAY\'S SUMMARY',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF94A3B8),
                  letterSpacing: 1.4,
                ),
              ),
            ),
            // LayoutBuilder makes tiles resize gracefully on narrow screens
            LayoutBuilder(
              builder: (context, constraints) {
                if (!isTablet) {
                  // On phone, stack in a 2-column + 1 full-width row to prevent text clipping
                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      SizedBox(
                        width: (constraints.maxWidth - 10) / 2,
                        child: _buildInfoTile(
                          icon: Icons.receipt_long_rounded,
                          iconColor: const Color(0xFF6366F1),
                          bgColor: const Color(0xFFEDE9FE),
                          label: 'Avg. Ticket',
                          value: Formatters.currency(avgTicket),
                          isTablet: isTablet,
                        ),
                      ),
                      SizedBox(
                        width: (constraints.maxWidth - 10) / 2,
                        child: _buildInfoTile(
                          icon: Icons.inventory_2_rounded,
                          iconColor: const Color(0xFF10B981),
                          bgColor: const Color(0xFFD1FAE5),
                          label: 'Products Listed',
                          value: '$products items',
                          isTablet: isTablet,
                        ),
                      ),
                      SizedBox(
                        width: constraints.maxWidth,
                        child: _buildInfoTile(
                          icon: Icons.today_rounded,
                          iconColor: const Color(0xFFF59E0B),
                          bgColor: const Color(0xFFFEF3C7),
                          label: 'Date',
                          value: DateFormat('MMMM d, yyyy').format(DateTime.now()),
                          isTablet: isTablet,
                        ),
                      ),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(
                      child: _buildInfoTile(
                        icon: Icons.receipt_long_rounded,
                        iconColor: const Color(0xFF6366F1),
                        bgColor: const Color(0xFFEDE9FE),
                        label: 'Avg. Ticket',
                        value: Formatters.currency(avgTicket),
                        isTablet: isTablet,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildInfoTile(
                        icon: Icons.inventory_2_rounded,
                        iconColor: const Color(0xFF10B981),
                        bgColor: const Color(0xFFD1FAE5),
                        label: 'Products Listed',
                        value: '$products items',
                        isTablet: isTablet,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildInfoTile(
                        icon: Icons.today_rounded,
                        iconColor: const Color(0xFFF59E0B),
                        bgColor: const Color(0xFFFEF3C7),
                        label: 'Date',
                        value: DateFormat('MMM d').format(DateTime.now()),
                        isTablet: isTablet,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildInfoTile({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String label,
    required String value,
    required bool isTablet,
  }) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 14 : 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: isTablet ? 36 : 30,
            height: isTablet ? 36 : 30,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: iconColor, size: isTablet ? 20 : 16),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: isTablet ? 10 : 9,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF94A3B8),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: isTablet ? 14 : 12,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1E293B),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ── Error widget ───────────────────────────────────────────────────────────
  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.error_outline_rounded,
                color: Color(0xFFEF4444), size: 36),
          ),
          const SizedBox(height: 16),
          Text(
            'Oops, something went wrong!',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _error ?? '',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(0xFF64748B),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _loadStats,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  // ── Card config list ───────────────────────────────────────────────────────
  List<_StatCardConfig> get _cardConfigs => [
        _StatCardConfig(
          title: 'TODAY\'S SALES',
          icon: Icons.payments_rounded,
          gradientColors: const [Color(0xFF0072FF), Color(0xFF338FFF)],
          accentColor: const Color(0xFF0072FF),
          isCurrency: true,
          prefix: '₱',
          trend: '+12%',
          trendUp: true,
        ),
        _StatCardConfig(
          title: 'TRANSACTIONS',
          icon: Icons.shopping_cart_rounded,
          gradientColors: const [Color(0xFF6366F1), Color(0xFF8B5CF6)],
          accentColor: const Color(0xFF6366F1),
          isCurrency: false,
          trend: '+5',
          trendUp: true,
        ),
        _StatCardConfig(
          title: 'TOTAL PRODUCTS',
          icon: Icons.inventory_2_rounded,
          gradientColors: const [Color(0xFF10B981), Color(0xFF34D399)],
          accentColor: const Color(0xFF10B981),
          isCurrency: false,
          trend: 'Active',
          trendUp: true,
        ),
        _StatCardConfig(
          title: 'OVERALL BALANCE',
          icon: Icons.account_balance_wallet_rounded,
          gradientColors: const [Color(0xFFF59E0B), Color(0xFFFBBF24)],
          accentColor: const Color(0xFFF59E0B),
          isCurrency: true,
          prefix: '₱',
          trend: 'Pending',
          trendUp: false,
        ),
      ];
}

// ─────────────────────────────────────────────────────────────────────────────
// _StatCard — individual stat card widget
// ─────────────────────────────────────────────────────────────────────────────

class _StatCardConfig {
  final String title;
  final IconData icon;
  final List<Color> gradientColors;
  final Color accentColor;
  final bool isCurrency;
  final String? prefix;
  final String? trend;
  final bool trendUp;

  const _StatCardConfig({
    required this.title,
    required this.icon,
    required this.gradientColors,
    required this.accentColor,
    required this.isCurrency,
    this.prefix,
    this.trend,
    required this.trendUp,
  });
}

class _StatCard extends StatelessWidget {
  final _StatCardConfig config;
  final String displayValue;
  final bool isTablet;

  const _StatCard({
    required this.config,
    required this.displayValue,
    required this.isTablet,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: config.accentColor.withOpacity(0.12),
            blurRadius: 18,
            offset: const Offset(0, 6),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            // Top accent bar
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: config.gradientColors),
                ),
              ),
            ),

            // Decorative background circle
            Positioned(
              right: -18,
              bottom: -18,
              child: Container(
                width: isTablet ? 90 : 72,
                height: isTablet ? 90 : 72,
                decoration: BoxDecoration(
                  color: config.accentColor.withOpacity(0.07),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              right: isTablet ? 8 : 4,
              bottom: isTablet ? 8 : 4,
              child: Container(
                width: isTablet ? 52 : 40,
                height: isTablet ? 52 : 40,
                decoration: BoxDecoration(
                  color: config.accentColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
              ),
            ),

            // Content
            Padding(
              padding: EdgeInsets.fromLTRB(
                isTablet ? 14 : 14,
                isTablet ? 14 : 14,
                isTablet ? 12 : 12,
                isTablet ? 10 : 12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Top row — icon + trend
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Icon badge
                      Container(
                        width: isTablet ? 42 : 34,
                        height: isTablet ? 42 : 34,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: config.gradientColors,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: config.accentColor.withOpacity(0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Icon(
                          config.icon,
                          color: Colors.white,
                          size: isTablet ? 22 : 17,
                        ),
                      ),

                      // Trend badge
                      if (config.trend != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: config.trendUp
                                ? const Color(0xFFD1FAE5)
                                : const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                config.trendUp
                                    ? Icons.trending_up_rounded
                                    : Icons.schedule_rounded,
                                size: 10,
                                color: config.trendUp
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFFF59E0B),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                config.trend!,
                                style: GoogleFonts.inter(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: config.trendUp
                                      ? const Color(0xFF065F46)
                                      : const Color(0xFF92400E),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),

                  // Bottom — label + value
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        config.title,
                        style: GoogleFonts.inter(
                          fontSize: isTablet ? 10 : 9,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF94A3B8),
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 3),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          displayValue,
                          style: GoogleFonts.inter(
                            fontSize: isTablet ? 26 : 20,
                            fontWeight: FontWeight.w900,
                            color: config.accentColor,
                            letterSpacing: -0.5,
                            fontFeatures: const [FontFeature('tnum')],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _LoadingOverlay
// ─────────────────────────────────────────────────────────────────────────────

class _LoadingOverlay extends StatelessWidget {
  const _LoadingOverlay();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 80),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
              backgroundColor: AppColors.primary.withOpacity(0.1),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading dashboard…',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}
