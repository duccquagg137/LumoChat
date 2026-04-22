import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../services/auth_service.dart';
import '../utils/error_mapper.dart';
import '../utils/l10n.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

enum AuthMode { email, phone }

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  bool _isLogin = true;
  bool _showPassword = false;
  bool _isLoading = false;
  AuthMode _authMode = AuthMode.email;
  
  // Phone auth state
  bool _isCodeSent = false;
  String _verificationId = '';
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  // Email auth state
  late TabController _tabController;
  final _authService = AuthService();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();

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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ));
    }
  }

  void _navigateToHome() {
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        PageRouteBuilder(
          pageBuilder: (_, a, __) => const HomeScreen(),
          transitionDuration: const Duration(milliseconds: 600),
          transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
        ),
        (_) => false,
      );
    }
  }

  // --- Email Auth ---
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
      _navigateToHome();
    } catch (e) {
      _showError(AppErrorText.forAuthL10n(l10n, e));
    } finally {
      _setLoading(false);
    }
  }

  // --- Phone Auth ---
  void _sendPhoneCode() async {
    final l10n = context.l10n;
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      _showError(l10n.authValidationPhoneRequired);
      return;
    }

    _setLoading(true);
    
    // Clean input: remove spaces, hyphens, parentheses
    String cleanPhone = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    
    // Format phone to standard format (add country code +84 if missing)
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
          // Auto-resolution on Android
          try {
            await FirebaseAuth.instance.signInWithCredential(credential);
            _navigateToHome();
          } catch (e) {
            _showError(l10n.authErrorAutoVerificationFailed(AppErrorText.forAuthL10n(l10n, e)));
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
      _showError(l10n.authErrorSendOtpFailed(AppErrorText.forAuthL10n(l10n, e)));
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
      await _authService.signInWithOTP(_verificationId, code);
      _navigateToHome();
    } catch (e) {
      _showError(AppErrorText.forAuthL10n(l10n, e));
      _setLoading(false);
    }
  }

  // --- Social Auth ---
  void _signInWithGoogle() async {
    final l10n = context.l10n;
    _setLoading(true);
    try {
      final userOpt = await _authService.signInWithGoogle();
      if (userOpt != null) {
        _navigateToHome();
      } else {
        _setLoading(false); // Cancelled
      }
    } catch (e) {
      _showError(l10n.authErrorGoogleFailed(AppErrorText.forAuthL10n(l10n, e)));
      _setLoading(false);
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(decoration: const BoxDecoration(gradient: AppGradients.hero)),
          // Glow orbs
          Positioned(
            top: -80, right: -60,
            child: Container(
              width: 250, height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [AppColors.primary.withAlphaFraction(0.25), Colors.transparent],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 150, left: -80,
            child: Container(
              width: 200, height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [AppColors.primaryLight.withAlphaFraction(0.15), Colors.transparent],
                ),
              ),
            ),
          ),
          // Content
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  // Logo
                  Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      gradient: AppGradients.primary,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withAlphaFraction(0.4),
                          blurRadius: 30, offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 40),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'LumoChat',
                    style: TextStyle(
                      fontSize: 28, fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary, fontFamily: 'Inter',
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Mode Switcher
                  GlassCard(
                    padding: const EdgeInsets.all(4),
                    borderRadius: 16,
                    child: Row(
                      children: [
                        _buildModeTab('Email', AuthMode.email),
                        _buildModeTab('Sá»‘ Ä‘iá»‡n thoáº¡i', AuthMode.phone),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  
                  // Form Area
                  _authMode == AuthMode.email ? _buildEmailForm() : _buildPhoneForm(),
                  
                  const SizedBox(height: 24),
                  // Divider
                  Row(
                    children: [
                      Expanded(child: Divider(color: AppColors.textMuted.withAlphaFraction(0.3))),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text('hoáº·c', style: TextStyle(color: AppColors.textMuted, fontSize: 13, fontFamily: 'Inter')),
                      ),
                      Expanded(child: Divider(color: AppColors.textMuted.withAlphaFraction(0.3))),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Social login
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildSocialButton(Icons.g_mobiledata_rounded, 'Google', _signInWithGoogle),
                      const SizedBox(width: 16),
                      // Mock apple button
                      _buildSocialButton(Icons.apple_rounded, 'Apple', () => _showError(context.l10n.authAppleComingSoon)),
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
              fontWeight: FontWeight.w600, fontFamily: 'Inter',
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
            indicator: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.primaryLight, width: 2)),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelColor: AppColors.primaryLight,
            unselectedLabelColor: AppColors.textSecondary,
            labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Inter'),
            tabs: const [Tab(text: 'ÄÄƒng nháº­p'), Tab(text: 'ÄÄƒng kÃ½')],
          ),
          const SizedBox(height: 20),
          if (!_isLogin) ...[
            _buildInput(Icons.person_outline_rounded, 'Há» vÃ  tÃªn', controller: _nameController),
            const SizedBox(height: 16),
          ],
          _buildInput(Icons.email_outlined, 'Email', controller: _emailController, keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 16),
          _buildInput(
            Icons.lock_outline_rounded, 'Máº­t kháº©u',
            isPassword: true, controller: _passwordController,
          ),
          if (!_isLogin) ...[
            const SizedBox(height: 16),
            _buildInput(
              Icons.lock_outline_rounded, 'XÃ¡c nháº­n máº­t kháº©u',
              isPassword: true, controller: _confirmPasswordController,
            ),
          ],
          if (_isLogin) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {},
                child: const Text('QuÃªn máº­t kháº©u?', style: TextStyle(color: AppColors.primaryLight, fontSize: 13, fontFamily: 'Inter')),
              ),
            ),
          ],
          const SizedBox(height: 20),
          _isLoading 
              ? const CircularProgressIndicator(color: AppColors.primary)
              : GradientButton(
                  text: _isLogin ? 'ÄÄƒng nháº­p' : 'ÄÄƒng kÃ½',
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
            _isCodeSent ? 'Nháº­p mÃ£ xÃ¡c nháº­n' : 'ÄÄƒng nháº­p báº±ng sá»‘ Ä‘iá»‡n thoáº¡i',
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700, fontFamily: 'Inter'),
          ),
          const SizedBox(height: 8),
          Text(
            _isCodeSent 
              ? 'MÃ£ OTP Ä‘Ã£ Ä‘Æ°á»£c gá»­i Ä‘áº¿n sá»‘ Ä‘iá»‡n thoáº¡i cá»§a báº¡n'
              : 'ChÃºng tÃ´i sáº½ gá»­i mÃ£ OTP Ä‘á»ƒ xÃ¡c minh',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13, fontFamily: 'Inter'),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          
          if (!_isCodeSent)
            _buildInput(
              Icons.phone_outlined, 'Sá»‘ Ä‘iá»‡n thoáº¡i', 
              controller: _phoneController, 
              keyboardType: TextInputType.phone,
            )
          else
            _buildInput(
              Icons.password_rounded, 'MÃ£ OTP 6 chá»¯ sá»‘', 
              controller: _otpController, 
              keyboardType: TextInputType.number,
            ),
            
          const SizedBox(height: 24),
          
          _isLoading 
              ? const CircularProgressIndicator(color: AppColors.primary)
              : GradientButton(
                  text: _isCodeSent ? 'XÃ¡c nháº­n' : 'Gá»­i mÃ£ OTP',
                  width: double.infinity,
                  onPressed: _isCodeSent ? _verifyOTP : _sendPhoneCode,
                ),
                
          if (_isCodeSent) ...[
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => setState(() => _isCodeSent = false),
              child: const Text('Thay Ä‘á»•i sá»‘ Ä‘iá»‡n thoáº¡i', style: TextStyle(color: AppColors.textSecondary)),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildInput(IconData icon, String hint, {
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
        style: const TextStyle(color: AppColors.textPrimary, fontFamily: 'Inter'),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: AppColors.textMuted, size: 22),
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.textMuted),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    _showPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                    color: AppColors.textMuted, size: 22,
                  ),
                  onPressed: () => setState(() => _showPassword = !_showPassword),
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildSocialButton(IconData icon, String label, VoidCallback onTap) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      borderRadius: 16,
      onTap: onTap,
      child: Icon(icon, color: AppColors.textPrimary, size: 28),
    );
  }
}
