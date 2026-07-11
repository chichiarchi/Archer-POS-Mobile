import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/database/database_helper.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/utils/constants.dart';
import '../../core/utils/r2_sync_service.dart';

class AccountScreen extends StatefulWidget {
  final String username;
  final String userRole;

  const AccountScreen({
    super.key,
    required this.username,
    required this.userRole,
  });

  @override
  State<AccountScreen> createState() => AccountScreenState();
}

class AccountScreenState extends State<AccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _currentPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  // R2 Sync state and controllers
  final TextEditingController _r2AccountIdController = TextEditingController();
  final TextEditingController _r2AccessKeyController = TextEditingController();
  final TextEditingController _r2SecretKeyController = TextEditingController();
  final TextEditingController _r2BucketController = TextEditingController();
  final TextEditingController _r2FileNameController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  // R2 states
  bool _r2AutoSync = true;
  String _r2LastSync = 'Never';
  bool _obscureR2Secret = true;
  bool _isR2Syncing = false;
  bool _isSavingR2 = false;
  bool _cameraBarcodeEnabled = true;

  List<Map<String, dynamic>> _users = [];
  bool _loadingUsers = false;

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _loadR2Settings();
  }

  Future<void> _loadR2Settings() async {
    final accountId = await DatabaseHelper.instance.getSetting(R2SyncService.keyAccountId);
    final accessKey = await DatabaseHelper.instance.getSetting(R2SyncService.keyAccessKeyId);
    final secretKey = await DatabaseHelper.instance.getSetting(R2SyncService.keySecretAccessKey);
    final bucket = await DatabaseHelper.instance.getSetting(R2SyncService.keyBucketName);
    final fileName = await DatabaseHelper.instance.getSetting(R2SyncService.keyFileName);
    final autoSync = await DatabaseHelper.instance.getSetting(R2SyncService.keyAutoSync);
    final lastSync = await DatabaseHelper.instance.getSetting(R2SyncService.keyLastSyncDate);
    final camVal = await DatabaseHelper.instance.getSetting('camera_barcode_enabled');

    if (mounted) {
      setState(() {
        _r2AccountIdController.text = accountId ?? '';
        _r2AccessKeyController.text = accessKey ?? '';
        _r2SecretKeyController.text = secretKey ?? '';
        _r2BucketController.text = bucket ?? R2SyncService.defaultBucket;
        _r2FileNameController.text = fileName ?? R2SyncService.defaultFileName;
        _r2AutoSync = autoSync != 'false';
        _r2LastSync = lastSync ?? 'Never';
        _cameraBarcodeEnabled = camVal != 'false';
      });
    }
  }

  Future<void> _saveR2Settings() async {
    setState(() => _isSavingR2 = true);
    try {
      await DatabaseHelper.instance.setSetting(R2SyncService.keyAccountId, _r2AccountIdController.text.trim());
      await DatabaseHelper.instance.setSetting(R2SyncService.keyAccessKeyId, _r2AccessKeyController.text.trim());
      await DatabaseHelper.instance.setSetting(R2SyncService.keySecretAccessKey, _r2SecretKeyController.text.trim());
      await DatabaseHelper.instance.setSetting(R2SyncService.keyBucketName, _r2BucketController.text.trim());
      await DatabaseHelper.instance.setSetting(R2SyncService.keyFileName, _r2FileNameController.text.trim());
      await DatabaseHelper.instance.setSetting(R2SyncService.keyAutoSync, _r2AutoSync.toString());
      
      _showSnackBar('R2 configurations saved successfully!');
    } catch (e) {
      _showSnackBar('Failed to save configuration: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSavingR2 = false);
    }
  }

  Future<void> _runR2Sync() async {
    // Save current configuration first if admin
    if (widget.userRole.toLowerCase() == 'admin') {
      await DatabaseHelper.instance.setSetting(R2SyncService.keyAccountId, _r2AccountIdController.text.trim());
      await DatabaseHelper.instance.setSetting(R2SyncService.keyAccessKeyId, _r2AccessKeyController.text.trim());
      await DatabaseHelper.instance.setSetting(R2SyncService.keySecretAccessKey, _r2SecretKeyController.text.trim());
      await DatabaseHelper.instance.setSetting(R2SyncService.keyBucketName, _r2BucketController.text.trim());
      await DatabaseHelper.instance.setSetting(R2SyncService.keyFileName, _r2FileNameController.text.trim());
      await DatabaseHelper.instance.setSetting(R2SyncService.keyAutoSync, _r2AutoSync.toString());
    }

    setState(() => _isR2Syncing = true);
    
    final result = await R2SyncService.instance.performSync();
    
    if (mounted) {
      setState(() => _isR2Syncing = false);
      if (result['success'] == true) {
        _showSnackBar(result['message'] as String);
        final lastSync = await DatabaseHelper.instance.getSetting(R2SyncService.keyLastSyncDate);
        setState(() {
          _r2LastSync = lastSync ?? 'Never';
        });
      } else {
        _showSnackBar(result['message'] as String, isError: true);
      }
    }
  }



  Future<void> _loadUsers() async {
    if (widget.userRole.toLowerCase() != 'admin') return;
    setState(() => _loadingUsers = true);
    try {
      final list = await DatabaseHelper.instance.getAllUsers();
      setState(() {
        _users = list;
        _loadingUsers = false;
      });
    } catch (e) {
      setState(() => _loadingUsers = false);
      _showSnackBar('Error loading users: $e', isError: true);
    }
  }

  void _showAddUserDialog() {
    final nameController = TextEditingController();
    final passController = TextEditingController();
    String role = 'staff';
    
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Add New User', style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Username *',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password *',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: role,
                decoration: InputDecoration(
                  labelText: 'Role',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: const [
                  DropdownMenuItem(value: 'staff', child: Text('Staff Cashier')),
                  DropdownMenuItem(value: 'admin', child: Text('Administrator')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setDialogState(() {
                      role = val;
                    });
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Cancel', style: GoogleFonts.inter(color: kTextSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                final uname = nameController.text.trim();
                final pwd = passController.text;
                if (uname.isEmpty || pwd.isEmpty) {
                  _showSnackBar('Please fill in all fields.', isError: true);
                  return;
                }
                final success = await DatabaseHelper.instance.createUser(uname, pwd, role);
                if (success) {
                  await DatabaseHelper.instance.logAction(
                    'USER_CREATE',
                    details: 'Admin ${widget.username} created user account: $uname ($role)',
                    userId: widget.username,
                  );
                  Navigator.of(ctx).pop();
                  _showSnackBar('User account created successfully! 🎉');
                  _loadUsers();
                } else {
                  _showSnackBar('Username already exists or creation failed.', isError: true);
                }
              },
              child: Text('Create', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteUser(int userId, String uname) async {
    if (uname == widget.username) {
      _showSnackBar('You cannot delete your own account.', isError: true);
      return;
    }
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete User', style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
        content: Text('Are you sure you want to delete user "$uname"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: GoogleFonts.inter(color: kTextSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kErrorColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Delete', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      final success = await DatabaseHelper.instance.deleteUser(userId);
      if (success) {
        await DatabaseHelper.instance.logAction(
          'USER_DELETE',
          details: 'Admin ${widget.username} deleted user account: $uname',
          userId: widget.username,
        );
        _showSnackBar('User account deleted successfully.');
        _loadUsers();
      } else {
        _showSnackBar('Failed to delete user.', isError: true);
      }
    }
  }

  void _showChangeUserPasswordDialog(String uname) {
    final passController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Change Password for $uname', style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
        content: TextField(
          controller: passController,
          obscureText: true,
          decoration: InputDecoration(
            labelText: 'New Password *',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: GoogleFonts.inter(color: kTextSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              final pwd = passController.text;
              if (pwd.length < 6) {
                _showSnackBar('Password must be at least 6 characters.', isError: true);
                return;
              }
              final success = await DatabaseHelper.instance.updatePassword(uname, pwd);
              if (success) {
                await DatabaseHelper.instance.logAction(
                  'USER_PASSWORD_RESET',
                  details: 'Admin ${widget.username} reset password for user: $uname',
                  userId: widget.username,
                );
                Navigator.of(ctx).pop();
                _showSnackBar('Password updated successfully! 🎉');
              } else {
                _showSnackBar('Failed to update password.', isError: true);
              }
            },
            child: Text('Update', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _r2AccountIdController.dispose();
    _r2AccessKeyController.dispose();
    _r2SecretKeyController.dispose();
    _r2BucketController.dispose();
    _r2FileNameController.dispose();
    super.dispose();
  }

  void refresh() {
    _clearFields();
    _loadUsers();
  }

  void _clearFields() {
    _currentPasswordController.clear();
    _newPasswordController.clear();
    _confirmPasswordController.clear();
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.inter(color: Colors.white)),
        backgroundColor: isError ? kErrorColor : kSuccessColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _updatePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final currentPassword = _currentPasswordController.text;
      final newPassword = _newPasswordController.text;

      // 1. Verify current password
      final user = await DatabaseHelper.instance.verifyLogin(widget.username, currentPassword);
      if (user == null) {
        setState(() => _isLoading = false);
        _showSnackBar('Current password is incorrect.', isError: true);
        return;
      }

      // 2. Update password in database
      final success = await DatabaseHelper.instance.updatePassword(widget.username, newPassword);

      if (success) {
        // 3. Log the password change action
        await DatabaseHelper.instance.logAction(
          'PASSWORD_CHANGE',
          details: 'User ${widget.username} changed their password.',
          userId: widget.username,
        );

        _clearFields();
        setState(() => _isLoading = false);
        _showSnackBar('Password updated successfully! 🎉');
      } else {
        setState(() => _isLoading = false);
        _showSnackBar('Failed to update password.', isError: true);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Error updating password: $e', isError: true);
    }
  }

  Future<void> _handleSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Sign Out',
          style: GoogleFonts.inter(fontWeight: FontWeight.w800),
        ),
        content: Text(
          'Are you sure you want to sign out?',
          style: GoogleFonts.inter(color: kTextSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: GoogleFonts.inter(color: kTextSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kErrorColor),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Sign Out', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await context.read<AuthProvider>().logout();
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    }
  }

  Future<void> _importDatabase() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );

      if (result != null && result.files.single.path != null) {
        final selectedPath = result.files.single.path!;

        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text('Import Products Only', style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
            content: Text(
              'Are you sure you want to import products from this file? Your existing sales logs, cashiers, and configurations will NOT be changed.',
              style: GoogleFonts.inter(color: kTextSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text('Cancel', style: GoogleFonts.inter(color: kTextSecondary)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text('Import', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        );

        if (confirmed == true) {
          setState(() => _isLoading = true);

          // Import products only
          await DatabaseHelper.instance.importProductsFromExternalDb(selectedPath);

          setState(() => _isLoading = false);
          _showSnackBar('Products imported successfully! 🎉');
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Failed to import products: $e', isError: true);
    }
  }

  Future<void> _exportDatabase() async {
    try {
      final dbPath = await getDatabasesPath();
      final sourcePath = p.join(dbPath, 'archer_pos.db');
      final sourceFile = File(sourcePath);

      if (!await sourceFile.exists()) {
        _showSnackBar('Database file does not exist.', isError: true);
        return;
      }

      if (Platform.isAndroid) {
        // Use native Android MediaStore channel to save directly to local Downloads folder
        const platformChannel = MethodChannel('com.example.archer_pos/file_export');
        final timestamp = DateTime.now().toIso8601String().replaceAll(RegExp(r'[-:T.]'), '_').substring(0, 15);
        final fileName = 'archer_pos_backup_$timestamp.db';
        
        setState(() => _isLoading = true);
        final bool? success = await platformChannel.invokeMethod<bool>('exportToDownloads', {
          'sourcePath': sourcePath,
          'fileName': fileName,
        });
        setState(() => _isLoading = false);

        if (success == true) {
          _showSnackBar('Database exported successfully to local storage (Downloads)! 📂');
        } else {
          _showSnackBar('Failed to export database to local storage.', isError: true);
        }
      } else {
        // Fallback for non-Android platforms
        final bytes = await sourceFile.readAsBytes();
        final outputFile = await FilePicker.platform.saveFile(
          dialogTitle: 'Select location to save database backup:',
          fileName: 'archer_pos_backup.db',
          bytes: bytes,
        );

        if (outputFile != null) {
          _showSnackBar('Database exported successfully! 🎉');
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      _showSnackBar('Failed to export database: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final roleDisplay = widget.userRole.toLowerCase() == 'admin' ? 'Administrator' : 'Staff Cashier';
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final sectionTitleStyle = GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w800, color: cs.onSurface);
    final sectionSubStyle = GoogleFonts.inter(fontSize: 14, color: cs.onSurface.withOpacity(0.6));

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'My Account Settings',
          style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 22, color: cs.onSurface),
        ),
        backgroundColor: cardColor,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isPhone = constraints.maxWidth < 600;
          return SingleChildScrollView(
            padding: EdgeInsets.all(isPhone ? 14 : 24),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 580),
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Profile Information Card
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: cardBorder)),
                  elevation: 0,
                  color: cardColor,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 38,
                          backgroundColor: cs.primary.withOpacity(0.12),
                          child: Icon(Icons.person, size: 42, color: cs.primary),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.username.toUpperCase(),
                                style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900, color: cs.onSurface),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: cs.primary.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  roleDisplay,
                                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: cs.primary),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Change Password Form Card
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: cardBorder)),
                  elevation: 0,
                  color: cardColor,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Change Account Password', style: sectionTitleStyle),
                          const SizedBox(height: 4),
                          Text('Keep your account secure by periodically updating your credentials.', style: sectionSubStyle),
                          const Divider(height: 32),
                          TextFormField(
                            controller: _currentPasswordController,
                            obscureText: _obscureCurrent,
                            decoration: InputDecoration(
                              labelText: 'Current Password *',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(_obscureCurrent ? Icons.visibility_off : Icons.visibility),
                                onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
                              ),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            validator: (val) {
                              if (val == null || val.isEmpty) return 'Current password is required.';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _newPasswordController,
                            obscureText: _obscureNew,
                            decoration: InputDecoration(
                              labelText: 'New Password *',
                              prefixIcon: const Icon(Icons.lock_reset_outlined),
                              suffixIcon: IconButton(
                                icon: Icon(_obscureNew ? Icons.visibility_off : Icons.visibility),
                                onPressed: () => setState(() => _obscureNew = !_obscureNew),
                              ),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            validator: (val) {
                              if (val == null || val.isEmpty) return 'New password is required.';
                              if (val.length < 6) return 'Password must be at least 6 characters.';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: _obscureConfirm,
                            decoration: InputDecoration(
                              labelText: 'Confirm New Password *',
                              prefixIcon: const Icon(Icons.lock_clock_outlined),
                              suffixIcon: IconButton(
                                icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility),
                                onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                              ),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            validator: (val) {
                              if (val == null || val.isEmpty) return 'Confirm password is required.';
                              if (val != _newPasswordController.text) return 'Passwords do not match.';
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: _isLoading ? null : _updatePassword,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: cs.primary,
                              foregroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                              minimumSize: const Size.fromHeight(52),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: _isLoading
                                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : Text('UPDATE PASSWORD', style: GoogleFonts.inter(fontWeight: FontWeight.w800, letterSpacing: 0.8)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Appearance Card (Dark / Light Mode toggle)
                Consumer<ThemeProvider>(
                  builder: (ctx, tp, _) => Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: cardBorder)),
                    elevation: 0,
                    color: cardColor,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Appearance & Scanner Settings', style: sectionTitleStyle),
                          const SizedBox(height: 4),
                          Text('Configure app look and barcode scanner options.', style: sectionSubStyle),
                          const Divider(height: 28),
                          Row(
                            children: [
                              Container(
                                width: 44, height: 44,
                                decoration: BoxDecoration(
                                  color: (tp.isDarkMode ? const Color(0xFF60A5FA) : const Color(0xFFD97706)).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  tp.isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                                  color: tp.isDarkMode ? const Color(0xFF60A5FA) : const Color(0xFFD97706),
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(tp.isDarkMode ? 'Dark Mode' : 'Light Mode',
                                        style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15, color: cs.onSurface)),
                                    Text(tp.isDarkMode ? 'Dark background, light text' : 'White background, dark text',
                                        style: GoogleFonts.inter(fontSize: 13, color: cs.onSurface.withOpacity(0.55))),
                                  ],
                                ),
                              ),
                              Switch(
                                value: tp.isDarkMode,
                                onChanged: (val) => tp.setDarkMode(val),
                              ),
                            ],
                          ),
                          const Divider(height: 20),
                          Row(
                            children: [
                              Container(
                                width: 44, height: 44,
                                decoration: BoxDecoration(
                                  color: cs.primary.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.qr_code_scanner_rounded,
                                  color: cs.primary,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Camera Barcode Scanner',
                                        style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15, color: cs.onSurface)),
                                    Text('Enable camera barcode scanning on POS screen.',
                                        style: GoogleFonts.inter(fontSize: 13, color: cs.onSurface.withOpacity(0.55))),
                                  ],
                                ),
                              ),
                              Switch(
                                value: _cameraBarcodeEnabled,
                                onChanged: (val) async {
                                  setState(() => _cameraBarcodeEnabled = val);
                                  await DatabaseHelper.instance.setSetting('camera_barcode_enabled', val.toString());
                                  _showSnackBar(val ? 'Camera barcode scanner enabled. 🎉' : 'Camera barcode scanner disabled.');
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),



                // User Accounts Management Card (Admins Only)
                if (widget.userRole.toLowerCase() == 'admin') ...[
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: cardBorder)),
                    elevation: 0,
                    color: cardColor,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Manage User Accounts', style: sectionTitleStyle),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: cs.primary,
                                  foregroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                ),
                                onPressed: _showAddUserDialog,
                                icon: const Icon(Icons.add, size: 18),
                                label: Text('Add User', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14)),
                              ),
                            ],
                          ),
                          const Divider(height: 28),
                          if (_loadingUsers)
                            const Center(child: CircularProgressIndicator())
                          else if (_users.isEmpty)
                            Text('No additional users found.', style: GoogleFonts.inter(color: cs.onSurface.withOpacity(0.5), fontSize: 15))
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _users.length,
                              separatorBuilder: (ctx, i) => const Divider(),
                              itemBuilder: (ctx, index) {
                                final u = _users[index];
                                final uname = u['username'] as String;
                                final urole = u['role'] as String;
                                final uid = u['id'] as int;
                                final isCurrent = uname == widget.username;
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: CircleAvatar(
                                    backgroundColor: urole == 'admin' ? const Color(0xFF7C3AED).withOpacity(0.15) : const Color(0xFFD97706).withOpacity(0.15),
                                    child: Icon(
                                      urole == 'admin' ? Icons.admin_panel_settings : Icons.person,
                                      color: urole == 'admin' ? const Color(0xFF7C3AED) : const Color(0xFFD97706),
                                    ),
                                  ),
                                  title: Text(uname.toUpperCase(),
                                      style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15, color: cs.onSurface)),
                                  subtitle: Text(urole == 'admin' ? 'Administrator' : 'Staff Cashier',
                                      style: GoogleFonts.inter(fontSize: 13, color: cs.onSurface.withOpacity(0.55))),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: Icon(Icons.lock_open, color: cs.primary, size: 22),
                                        onPressed: () => _showChangeUserPasswordDialog(uname),
                                        tooltip: 'Change Password',
                                      ),
                                      if (!isCurrent)
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, color: Color(0xFFDC2626), size: 22),
                                          onPressed: () => _deleteUser(uid, uname),
                                          tooltip: 'Delete User',
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // R2 Cloud Sync Card
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: cardBorder)),
                  elevation: 0,
                  color: cardColor,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.cloud_sync, color: cs.primary, size: 28),
                            const SizedBox(width: 10),
                            Text('Cloudflare R2 Synchronization', style: sectionTitleStyle),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Synchronize your product catalog directly from Cloudflare R2 object storage.',
                          style: sectionSubStyle,
                        ),
                        const Divider(height: 28),
                        
                        if (widget.userRole.toLowerCase() == 'admin') ...[
                          Text(
                            'Configuration (Admin Only)',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14, color: cs.primary),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _r2AccountIdController,
                            decoration: InputDecoration(
                              labelText: 'R2 Account ID *',
                              prefixIcon: const Icon(Icons.business),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _r2AccessKeyController,
                            decoration: InputDecoration(
                              labelText: 'R2 Access Key ID *',
                              prefixIcon: const Icon(Icons.vpn_key),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _r2SecretKeyController,
                            obscureText: _obscureR2Secret,
                            decoration: InputDecoration(
                              labelText: 'R2 Secret Access Key *',
                              prefixIcon: const Icon(Icons.security),
                              suffixIcon: IconButton(
                                icon: Icon(_obscureR2Secret ? Icons.visibility_off : Icons.visibility),
                                onPressed: () => setState(() => _obscureR2Secret = !_obscureR2Secret),
                              ),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _r2BucketController,
                                  decoration: InputDecoration(
                                    labelText: 'Bucket Name',
                                    hintText: 'archerpos',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _r2FileNameController,
                                  decoration: InputDecoration(
                                    labelText: 'File Name',
                                    hintText: 'archer_pos_latest.db',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text('Daily First Sign-in Auto-Sync',
                                style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14)),
                            subtitle: Text('Automatically pull data on the first sign-in of the day.',
                                style: GoogleFonts.inter(fontSize: 12, color: cs.onSurface.withOpacity(0.55))),
                            value: _r2AutoSync,
                            onChanged: (val) => setState(() => _r2AutoSync = val),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: _isSavingR2 ? null : _saveR2Settings,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: cs.primary.withOpacity(0.12),
                              foregroundColor: cs.primary,
                              elevation: 0,
                              minimumSize: const Size.fromHeight(48),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: _isSavingR2
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.save, size: 18),
                            label: Text('SAVE CONFIGURATION', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13)),
                          ),
                          const Divider(height: 32),
                        ],
                        
                        // Sync Actions
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Sync Status', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14)),
                                const SizedBox(height: 4),
                                Text(
                                  'Last synced: $_r2LastSync',
                                  style: GoogleFonts.inter(fontSize: 13, color: cs.onSurface.withOpacity(0.55)),
                                ),
                              ],
                            ),
                            ElevatedButton.icon(
                              onPressed: _isR2Syncing ? null : _runR2Sync,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: kSuccessColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                              ),
                              icon: _isR2Syncing
                                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : const Icon(Icons.sync, size: 18),
                              label: Text(
                                _isR2Syncing ? 'SYNCING...' : 'SYNC NOW',
                                style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Database Management Card
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: cardBorder)),
                  elevation: 0,
                  color: cardColor,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Database Backup & Restore', style: sectionTitleStyle),
                        const SizedBox(height: 4),
                        Text('Export your database to back up your data, or import a database file to pre-populate products.', style: sectionSubStyle),
                        const Divider(height: 28),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: cs.primary,
                                  foregroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                onPressed: _importDatabase,
                                icon: const Icon(Icons.file_upload, size: 20),
                                label: Text('IMPORT', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 14)),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: cs.primary,
                                  side: BorderSide(color: cs.primary, width: 2),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                onPressed: _exportDatabase,
                                icon: const Icon(Icons.file_download, size: 20),
                                label: Text('EXPORT', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 14)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Sign Out Button
                ElevatedButton.icon(
                  onPressed: _handleSignOut,
                  icon: const Icon(Icons.exit_to_app, size: 20),
                  label: Text('SIGN OUT OF ARCHER POS', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        ),
          );
        },
      ),
    );
  }
}
