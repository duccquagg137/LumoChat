import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../utils/error_mapper.dart';
import '../utils/l10n.dart';
import '../widgets/glass_card.dart';
import 'home_screen.dart';
import 'profile_completion_screen.dart';


class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

enum AuthMode { email, phone }

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  bool _isLogin = true;
  bool _showPassword = false;
  bool _isLoading = false;
  AuthMode _authMode = AuthMode.email;

  bool _isCodeSent = false;
  String _verificationId = '';
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  late TabController _tabController;
  final _authService = AuthService();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();

  bool get _isEnglish => Localizations.localeOf(context).languageCode == 'en';

  String _txt({required String vi, required String en}) {
    return _isEnglish ? en : vi;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() => _isLogin = _tabController.index == 0);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _setLoading(bool value) {
    if (mounted) setState(() => _isLoading = value);
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<bool> _needsProfileCompletion() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get()
          .timeout(const Duration(seconds: 2));
      return snapshot.data()?['profileCompleted'] == false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _navigateAfterAuth({bool forceProfileCompletion = false}) async {
    final shouldCompleteProfile =
        forceProfileCompletion || await _needsProfileCompletion();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        PageRouteBuilder(
          pageBuilder: (_, a, __) => shouldCompleteProfile
              ? const ProfileCompletionScreen()
              : const HomeScreen(),
          transitionDuration: const Duration(milliseconds: 600),
          transitionsBuilder: (_, a, __, child) =>
              FadeTransition(opacity: a, child: child),
        ),
        (_) => false,
      );
    }
  }

  void _submitEmailAuth() async {
    final l10n = context.l10n;
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showError(l10n.authValidationRequiredFields);
      return;
    }

    _setLoading(true);
    try {
      if (_isLogin) {
        await _authService.signInWithEmailPassword(email, password);
      } else {
        final name = _nameController.text.trim();
        final confirmPassword = _confirmPasswordController.text.trim();

        if (name.isEmpty) {
          _showError(l10n.authValidationNameRequired);
          _setLoading(false);
          return;
        }
        if (password != confirmPassword) {
          _showError(l10n.authValidationPasswordMismatch);
          _setLoading(false);
          return;
        }
        await _authService.signUpWithEmailPassword(email, password, name);
      }
      await _navigateAfterAuth(forceProfileCompletion: !_isLogin);
    } catch (e) {
      _showError(AppErrorText.forAuthL10n(l10n, e));
    } finally {
      _setLoading(false);
    }
  }

  void _sendPhoneCode() async {
    final l10n = context.l10n;
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      _showError(l10n.authValidationPhoneRequired);
      return;
    }

    _setLoading(true);

    final cleanPhone = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');

    String formattedPhone = cleanPhone;
    if (cleanPhone.startsWith('0')) {
      formattedPhone = '+84${cleanPhone.substring(1)}';
    } else if (!cleanPhone.startsWith('+')) {
      formattedPhone = '+84$cleanPhone';
    }

    try {
      await _authService.verifyPhoneNumber(
        phoneNumber: formattedPhone,
        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            final userCredential =
                await _authService.signInWithPhoneCredential(credential);
            await _navigateAfterAuth(
              forceProfileCompletion:
                  userCredential?.additionalUserInfo?.isNewUser == true,
            );
          } catch (e) {
            _showError(
              l10n.authErrorAutoVerificationFailed(
                AppErrorText.forAuthL10n(l10n, e),
              ),
            );
            _setLoading(false);
          }
        },
        verificationFailed: (String error) {
          final reason = AppErrorText.forAuthL10n(l10n, error);
          _showError(l10n.authErrorVerificationFailed(reason));
          _setLoading(false);
        },
        codeSent: (String verificationId) {
          if (mounted) {
            setState(() {
              _verificationId = verificationId;
              _isCodeSent = true;
              _isLoading = false;
            });
          }
        },
      );
    } catch (e) {
      _showError(
        l10n.authErrorSendOtpFailed(AppErrorText.forAuthL10n(l10n, e)),
      );
      _setLoading(false);
    }
  }

  void _verifyOTP() async {
    final l10n = context.l10n;
    final code = _otpController.text.trim();
    if (code.isEmpty || code.length < 6) {
      _showError(l10n.authValidationOtpRequired);
      return;
    }

    _setLoading(true);
    try {
      final userCredential =
          await _authService.signInWithOTP(_verificationId, code);
      await _navigateAfterAuth(
        forceProfileCompletion:
            userCredential?.additionalUserInfo?.isNewUser == true,
      );
    } catch (e) {
      _showError(AppErrorText.forAuthL10n(l10n, e));
      _setLoading(false);
    }
  }

  void _signInWithGoogle() async {
    final l10n = context.l10n;
    _setLoading(true);
    try {
      final userOpt = await _authService.signInWithGoogle();
      if (userOpt != null) {
        await _navigateAfterAuth(
          forceProfileCompletion: userOpt.additionalUserInfo?.isNewUser == true,
        );
      } else {
        _setLoading(false);
      }
    } catch (e) {
      _showError(
        l10n.authErrorGoogleFailed(AppErrorText.forAuthL10n(l10n, e)),
      );
      _setLoading(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(decoration: BoxDecoration(gradient: AppGradients.hero)),
          Positioned(
            top: -80,
            right: -60,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withAlphaFraction(0.25),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 150,
            left: -80,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primaryLight.withAlphaFraction(0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: AppGradients.primary,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withAlphaFraction(0.4),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.chat_bubble_rounded,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'LumoChat',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      fontFamily: 'Inter',
                    ),
                  ),
                  const SizedBox(height: 32),
                  GlassCard(
                    padding: const EdgeInsets.all(4),
                    borderRadius: 16,
                    child: Row(
                      children: [
                        _buildModeTab('Email', AuthMode.email),
                        _buildModeTab(
                          _txt(vi: 'Số điện thoại', en: 'Phone'),
                          AuthMode.phone,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  _authMode == AuthMode.email
                      ? _buildEmailForm()
                      : _buildPhoneForm(),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Divider(
                          color: AppColors.textMuted.withAlphaFraction(0.3),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          _txt(vi: 'hoặc', en: 'or'),
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 13,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ),
                      Expanded(
                        child: Divider(
                          color: AppColors.textMuted.withAlphaFraction(0.3),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildSocialButton(
                        Icons.g_mobiledata_rounded,
                        _signInWithGoogle,
                      ),
                      const SizedBox(width: 16),
                      _buildSocialButton(
                        Icons.apple_rounded,
                        () => _showError(context.l10n.authAppleComingSoon),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeTab(String label, AuthMode mode) {
    final isActive = _authMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _authMode = mode;
          _isCodeSent = false;
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            gradient: isActive ? AppGradients.primary : null,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isActive ? Colors.white : AppColors.textSecondary,
              fontWeight: FontWeight.w600,
              fontFamily: 'Inter',
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmailForm() {
    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.primaryLight, width: 2),
              ),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelColor: AppColors.primaryLight,
            unselectedLabelColor: AppColors.textSecondary,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontFamily: 'Inter',
            ),
            tabs: [
              Tab(text: _txt(vi: 'Đăng nhập', en: 'Sign in')),
              Tab(text: _txt(vi: 'Đăng ký', en: 'Sign up')),
            ],
          ),
          const SizedBox(height: 20),
          if (!_isLogin) ...[
            _buildInput(
              Icons.person_outline_rounded,
              _txt(vi: 'Họ và tên', en: 'Full name'),
              controller: _nameController,
            ),
            const SizedBox(height: 16),
          ],
          _buildInput(
            Icons.email_outlined,
            'Email',
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),
          _buildInput(
            Icons.lock_outline_rounded,
            _txt(vi: 'Mật khẩu', en: 'Password'),
            isPassword: true,
            controller: _passwordController,
          ),
          if (!_isLogin) ...[
            const SizedBox(height: 16),
            _buildInput(
              Icons.lock_outline_rounded,
              _txt(vi: 'Xác nhận mật khẩu', en: 'Confirm password'),
              isPassword: true,
              controller: _confirmPasswordController,
            ),
          ],
          if (_isLogin) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {},
                child: Text(
                  _txt(vi: 'Quên mật khẩu?', en: 'Forgot password?'),
                  style: TextStyle(
                    color: AppColors.primaryLight,
                    fontSize: 13,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          _isLoading
              ? const CircularProgressIndicator(color: AppColors.primary)
              : GradientButton(
                  text: _isLogin
                      ? _txt(vi: 'Đăng nhập', en: 'Sign in')
                      : _txt(vi: 'Đăng ký', en: 'Sign up'),
                  width: double.infinity,
                  onPressed: _submitEmailAuth,
                ),
        ],
      ),
    );
  }

  Widget _buildPhoneForm() {
    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text(
            _isCodeSent
                ? _txt(vi: 'Nhập mã xác nhận', en: 'Enter verification code')
                : _txt(
                    vi: 'Đăng nhập bằng số điện thoại',
                    en: 'Sign in with phone',
                  ),
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isCodeSent
                ? _txt(
                    vi: 'Mã OTP đã được gửi đến số điện thoại của bạn',
                    en: 'An OTP code was sent to your phone',
                  )
                : _txt(
                    vi: 'Chúng tôi sẽ gửi mã OTP để xác minh',
                    en: 'We will send an OTP code to verify your phone',
                  ),
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 13,
              fontFamily: 'Inter',
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (!_isCodeSent)
            _buildInput(
              Icons.phone_outlined,
              _txt(vi: 'Số điện thoại', en: 'Phone number'),
              controller: _phoneController,
              keyboardType: TextInputType.phone,
            )
          else
            _buildInput(
              Icons.password_rounded,
              _txt(vi: 'Mã OTP 6 chữ số', en: '6-digit OTP code'),
              controller: _otpController,
              keyboardType: TextInputType.number,
            ),
          const SizedBox(height: 24),
          _isLoading
              ? const CircularProgressIndicator(color: AppColors.primary)
              : GradientButton(
                  text: _isCodeSent
                      ? _txt(vi: 'Xác nhận', en: 'Verify')
                      : _txt(vi: 'Gửi mã OTP', en: 'Send OTP'),
                  width: double.infinity,
                  onPressed: _isCodeSent ? _verifyOTP : _sendPhoneCode,
                ),
          if (_isCodeSent) ...[
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => setState(() => _isCodeSent = false),
              child: Text(
                _txt(vi: 'Thay đổi số điện thoại', en: 'Change phone number'),
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInput(
    IconData icon,
    String hint, {
    bool isPassword = false,
    TextEditingController? controller,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard.withAlphaFraction(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword && !_showPassword,
        keyboardType: keyboardType,
        style: TextStyle(
          color: AppColors.textPrimary,
          fontFamily: 'Inter',
        ),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: AppColors.textMuted, size: 22),
          hintText: hint,
          hintStyle: TextStyle(color: AppColors.textMuted),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    _showPassword
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    color: AppColors.textMuted,
                    size: 22,
                  ),
                  onPressed: () =>
                      setState(() => _showPassword = !_showPassword),
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildSocialButton(IconData icon, VoidCallback onTap) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      borderRadius: 16,
      onTap: onTap,
      child: Icon(icon, color: AppColors.textPrimary, size: 28),
    );
  }
}
