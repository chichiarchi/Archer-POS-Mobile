import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/database/database_helper.dart';
import '../main/main_screen.dart';

// ---------------------------------------------------------------------------
// LoginScreen
// ---------------------------------------------------------------------------
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  // ── Controllers ──────────────────────────────────────────────────────────
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // ── State ─────────────────────────────────────────────────────────────────
  bool _obscurePassword = true;
  bool _isLoading = false;

  // ── Animation ─────────────────────────────────────────────────────────────
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  // ── Gradient colours ──────────────────────────────────────────────────────
  static const Color _primaryBlue = Color(0xFF0072FF);
  static const Color _secondaryBlue = Color(0xFF00C6FF);

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  void _showSnackBar(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
        ),
        backgroundColor: isError ? const Color(0xFFEF4444) : _primaryBlue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ── Login logic ───────────────────────────────────────────────────────────
  Future<void> _handleLogin() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    setState(() => _isLoading = true);

    final auth = context.read<AuthProvider>();
    final success = await auth.login(username, password);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      final role = auth.role ?? 'staff';
      final loggedUser = auth.username ?? username;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 400),
          pageBuilder: (_, __, ___) =>
              MainScreen(username: loggedUser, userRole: role),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
        ),
      );
    } else {
      _showSnackBar(auth.error ?? 'Invalid username or password.');
    }
  }

  // ── Forgot Password flow ───────────────────────────────────────────────────
  Future<void> _handleForgotPassword() async {
    // Step 1: Ask for admin username
    final adminUsername = await _promptText(
      title: 'Forgot Password',
      hint: 'Enter admin username',
      label: 'Admin Username',
      icon: Icons.person_outline,
    );
    if (adminUsername == null || adminUsername.isEmpty) return;

    // Step 2: Verify the user exists and is admin role
    final user =
        await DatabaseHelper.instance.getUserByUsername(adminUsername.trim());

    if (!mounted) return;
    if (user == null || user['role'] != 'admin') {
      _showSnackBar('No admin account found with that username.');
      return;
    }

    // Step 3: Ask for master code
    final masterCode = await _promptText(
      title: 'Master Code',
      hint: 'Enter master code',
      label: 'Master Code',
      icon: Icons.lock_outline,
      obscure: true,
    );
    if (masterCode == null || masterCode.isEmpty) return;

    if (masterCode.trim() != '10152003') {
      if (!mounted) return;
      _showSnackBar('Incorrect master code.');
      return;
    }

    // Step 4: New password
    final newPassword = await _promptText(
      title: 'New Password',
      hint: 'Enter new password',
      label: 'New Password',
      icon: Icons.lock_reset_outlined,
      obscure: true,
    );
    if (newPassword == null || newPassword.isEmpty) return;
    if (newPassword.length < 4) {
      if (!mounted) return;
      _showSnackBar('Password must be at least 4 characters.');
      return;
    }

    // Step 5: Confirm password
    final confirmPassword = await _promptText(
      title: 'Confirm Password',
      hint: 'Re-enter new password',
      label: 'Confirm Password',
      icon: Icons.lock_outline,
      obscure: true,
    );
    if (confirmPassword == null || confirmPassword.isEmpty) return;

    if (newPassword != confirmPassword) {
      if (!mounted) return;
      _showSnackBar('Passwords do not match.');
      return;
    }

    // Step 6: Update password
    final ok = await DatabaseHelper.instance
        .updatePassword(adminUsername.trim(), newPassword);

    if (!mounted) return;
    if (ok) {
      await DatabaseHelper.instance.logAction(
        'PASSWORD_RESET',
        details: 'Admin password reset via master code for user: $adminUsername',
        userId: adminUsername.trim(),
      );
      _showSnackBar('Password updated successfully!', isError: false);
    } else {
      _showSnackBar('Failed to update password. Please try again.');
    }
  }

  /// Generic single-field input dialog. Returns entered text or null if cancelled.
  Future<String?> _promptText({
    required String title,
    required String hint,
    required String label,
    required IconData icon,
    bool obscure = false,
  }) async {
    final controller = TextEditingController();
    bool localObscure = obscure;

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: Text(
                title,
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: const Color(0xFF1E293B)),
              ),
              content: TextField(
                controller: controller,
                obscureText: localObscure,
                autofocus: true,
                style: GoogleFonts.inter(fontSize: 15),
                decoration: InputDecoration(
                  labelText: label,
                  hintText: hint,
                  prefixIcon: Icon(icon, color: _primaryBlue),
                  suffixIcon: obscure
                      ? IconButton(
                          icon: Icon(
                            localObscure
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: const Color(0xFF94A3B8),
                          ),
                          onPressed: () => setDialogState(
                              () => localObscure = !localObscure),
                        )
                      : null,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: _primaryBlue, width: 2),
                  ),
                ),
                onSubmitted: (_) => Navigator.of(ctx).pop(controller.text),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(null),
                  child: Text('Cancel',
                      style: GoogleFonts.inter(
                          color: const Color(0xFF64748B),
                          fontWeight: FontWeight.w600)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryBlue,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(controller.text),
                  child: Text('Continue',
                      style: GoogleFonts.inter(
                          color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width >= 768;
    final isLargePhone = size.width >= 400;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0072FF),
              Color(0xFF00C6FF),
              Color(0xFFE8EEF2),
            ],
            stops: [0.0, 0.4, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 0 : (isLargePhone ? 24 : 16),
                vertical: 24,
              ),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(maxWidth: isTablet ? 460 : double.infinity),
                    child: _buildCard(isLargePhone),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard([bool isLargePhone = true]) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0072FF).withOpacity(0.18),
            blurRadius: 40,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isLargePhone ? 36 : 20,
        vertical: 36,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Logo ──────────────────────────────────────────────────
            _buildLogo(),
            const SizedBox(height: 20),

            // ── Title ─────────────────────────────────────────────────
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [_primaryBlue, _secondaryBlue],
              ).createShader(bounds),
              child: Text(
                'ARCHER POS',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Colors.white, // masked by shader
                  letterSpacing: 3,
                ),
              ),
            ),
            const SizedBox(height: 6),

            // ── Subtitle ──────────────────────────────────────────────
            Text(
              'Sign in to continue',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFF94A3B8),
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 32),

            // ── Username Field ─────────────────────────────────────────
            TextFormField(
              controller: _usernameController,
              textInputAction: TextInputAction.next,
              keyboardType: TextInputType.text,
              style: GoogleFonts.inter(fontSize: 15),
              decoration: InputDecoration(
                labelText: 'Username',
                hintText: 'Enter your username',
                prefixIcon: const Icon(Icons.person_outline,
                    color: _primaryBlue),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: _primaryBlue, width: 2),
                ),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Please enter your username';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // ── Password Field ─────────────────────────────────────────
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              style: GoogleFonts.inter(fontSize: 15),
              onFieldSubmitted: (_) => _isLoading ? null : _handleLogin(),
              decoration: InputDecoration(
                labelText: 'Password',
                hintText: 'Enter your password',
                prefixIcon:
                    const Icon(Icons.lock_outline, color: _primaryBlue),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: const Color(0xFF94A3B8),
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: _primaryBlue, width: 2),
                ),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) {
                  return 'Please enter your password';
                }
                return null;
              },
            ),
            const SizedBox(height: 28),

            // ── Login Button ───────────────────────────────────────────
            _buildLoginButton(),
            const SizedBox(height: 16),

            // ── Forgot Password ────────────────────────────────────────
            Center(
              child: TextButton(
                onPressed: _isLoading ? null : _handleForgotPassword,
                style: TextButton.styleFrom(
                  foregroundColor: _primaryBlue,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                ),
                child: Text(
                  'Forgot Password?',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _primaryBlue,
                    decoration: TextDecoration.underline,
                    decorationColor: _primaryBlue,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // ── Version footer ─────────────────────────────────────────
            Text(
              'Archer POS v2.0.0',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: const Color(0xFFCBD5E1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Center(
      child: Container(
        width: 88,
        height: 88,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_primaryBlue, _secondaryBlue],
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: _primaryBlue.withOpacity(0.35),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Icon(
          Icons.point_of_sale_rounded,
          color: Colors.white,
          size: 46,
        ),
      ),
    );
  }

  Widget _buildLoginButton() {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        gradient: _isLoading
            ? null
            : const LinearGradient(
                colors: [_primaryBlue, _secondaryBlue],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
        color: _isLoading ? const Color(0xFFCBD5E1) : null,
        borderRadius: BorderRadius.circular(12),
        boxShadow: _isLoading
            ? null
            : [
                BoxShadow(
                  color: _primaryBlue.withOpacity(0.40),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: _isLoading ? null : _handleLogin,
          borderRadius: BorderRadius.circular(12),
          child: Center(
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    'Sign In',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
