import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/core/widgets/dear_days_header.dart';
import 'package:deardays/core/utils/password_validator.dart';
import 'package:deardays/features/journal/data/repositories/profile_repository.dart';
import 'package:deardays/features/journal/data/models/user_profile.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  late final ProfileRepository _profileRepo = ProfileRepository(
    client: Supabase.instance.client,
  );

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isChangingPassword = false;
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  UserProfile? _profile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _profileRepo.getProfile();
      final user = Supabase.instance.client.auth.currentUser;
      if (mounted && profile != null) {
        setState(() {
          _profile = profile;
          _nameController.text = profile.displayName ?? '';
          _emailController.text = user?.email ?? '';
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[EditProfile] loadProfile: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (_profile == null) return;

    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showError('Name cannot be empty.');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final updated = _profile!.copyWith(displayName: name);
      await _profileRepo.updateProfile(updated);

      if (mounted) {
        _showSuccess('Profile updated.');
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) _showError('Failed to update profile.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _updateEmail() async {
    final newEmail = _emailController.text.trim();
    if (newEmail.isEmpty) {
      _showError('Email cannot be empty.');
      return;
    }

    setState(() => _isSaving = true);

    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(email: newEmail),
      );

      if (mounted) {
        _showSuccess('Confirmation email sent to $newEmail.');
      }
    } on AuthException catch (e) {
      if (mounted) _showError(e.message);
    } catch (e) {
      debugPrint('[EditProfile] updateEmail: $e');
      if (mounted) _showError('Failed to update email.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _changePassword() async {
    final currentPassword = _currentPasswordController.text;
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (currentPassword.isEmpty) {
      _showError('Please enter your current password.');
      return;
    }

    final pwError = PasswordValidator.validate(newPassword);
    if (pwError != null) {
      _showError(pwError);
      return;
    }

    if (newPassword != confirmPassword) {
      _showError('Passwords do not match.');
      return;
    }

    setState(() => _isChangingPassword = true);

    try {
      // Verify current password before allowing change.
      final email = Supabase.instance.client.auth.currentUser?.email;
      if (email == null) {
        _showError('Could not determine your email address.');
        return;
      }
      await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: currentPassword,
      );

      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      if (mounted) {
        _newPasswordController.clear();
        _confirmPasswordController.clear();
        _currentPasswordController.clear();
        _showSuccess('Password updated.');
      }
    } on AuthException catch (e) {
      if (mounted) _showError(e.message);
    } catch (e) {
      debugPrint('[EditProfile] changePassword: $e');
      if (mounted) _showError('Failed to change password.');
    } finally {
      if (mounted) setState(() => _isChangingPassword = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.of(context).textPrimary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: DearDaysHeader.appBar(
        context: context,
        title: 'Edit Profile',
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar
                  Center(
                    child: Stack(
                      children: [
                        Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.of(context).accent.withAlpha(38),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            _initials(),
                            style: GoogleFonts.manrope(
                              fontSize: 32,
                              fontWeight: FontWeight.w600,
                              color: AppColors.of(context).textPrimary,
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.of(context).accent,
                              shape: BoxShape.circle,
                              border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2),
                            ),
                            child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Name
                  _buildSectionLabel('DISPLAY NAME'),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _nameController,
                    hint: 'Your name',
                    icon: Icons.person_outline,
                  ),
                  const SizedBox(height: 24),

                  // Email
                  _buildSectionLabel('EMAIL ADDRESS'),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _emailController,
                    hint: 'you@example.com',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _isSaving ? null : _updateEmail,
                      child: Text(
                        'Update Email',
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.of(context).textPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Divider
                  Divider(color: AppColors.of(context).border),
                  const SizedBox(height: 16),

                  // Change Password
                  _buildSectionLabel('CHANGE PASSWORD'),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _currentPasswordController,
                    hint: 'Current password',
                    icon: Icons.lock_outline,
                    obscure: _obscureCurrentPassword,
                    toggleObscure: () {
                      setState(() => _obscureCurrentPassword = !_obscureCurrentPassword);
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _newPasswordController,
                    hint: 'New password (${PasswordValidator.hint})',
                    icon: Icons.lock_reset,
                    obscure: _obscureNewPassword,
                    toggleObscure: () {
                      setState(() => _obscureNewPassword = !_obscureNewPassword);
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _confirmPasswordController,
                    hint: 'Confirm new password',
                    icon: Icons.lock_outline,
                    obscure: _obscureNewPassword,
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _isChangingPassword ? null : _changePassword,
                      child: _isChangingPassword
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              'Change Password',
                              style: GoogleFonts.manrope(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.of(context).textPrimary,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Divider
                  Divider(color: AppColors.of(context).border),
                  const SizedBox(height: 24),

                  // Save button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.of(context).textPrimary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppColors.of(context).accent.withAlpha(128),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'Save Profile',
                              style: GoogleFonts.manrope(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  String _initials() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return '?';
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.manrope(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppColors.of(context).textMuted,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscure = false,
    VoidCallback? toggleObscure,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      style: GoogleFonts.manrope(fontSize: 15, color: AppColors.of(context).textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.manrope(fontSize: 15, color: AppColors.of(context).textMuted),
        prefixIcon: Icon(icon, size: 20, color: AppColors.of(context).textMuted),
        suffixIcon: toggleObscure != null
            ? IconButton(
                icon: Icon(
                  obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  size: 20,
                  color: AppColors.of(context).textMuted,
                ),
                onPressed: toggleObscure,
              )
            : null,
        filled: true,
        fillColor: AppColors.of(context).card,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.of(context).border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.of(context).border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.of(context).accent, width: 2),
        ),
      ),
    );
  }
}
