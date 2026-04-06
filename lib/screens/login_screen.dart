import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../services/auth_service.dart';
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
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    
    if (email.isEmpty || password.isEmpty) {
      _showError('Vui lòng nhập đầy đủ thông tin');
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
          _showError('Vui lòng nhập tên');
          _setLoading(false);
          return;
        }
        if (password != confirmPassword) {
          _showError('Mật khẩu không khớp');
          _setLoading(false);
          return;
        }
        await _authService.signUpWithEmailPassword(email, password, name);
      }
      _navigateToHome();
    } catch (e) {
      _showError('Lỗi: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  // --- Phone Auth ---
  void _sendPhoneCode() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      _showError('Vui lòng nhập số điện thoại');
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
            _showError('Lỗi xác thực tự động: $e');
            _setLoading(false);
          }
        },
        verificationFailed: (String error) {
          String userMsg = error;
          if (error.contains('BILLING_NOT_ENABLED')) {
            userMsg = 'Dự án Firebase chưa bật thanh toán (Billing). Vui lòng nâng cấp lên gói Blaze để nhận SMS thật.';
          } else if (error.contains('quota exceeded')) {
            userMsg = 'Đã hết hạn mức gửi SMS hôm nay. Thử lại sau 24h.';
          } else if (error.contains('invalid-phone-number')) {
            userMsg = 'Số điện thoại không hợp lệ.';
          }
          _showError('Xác minh thất bại: $userMsg');
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
      _showError('Lỗi gửi mã: $e');
      _setLoading(false);
    }
  }

  void _verifyOTP() async {
    final code = _otpController.text.trim();
    if (code.isEmpty || code.length < 6) {
      _showError('Vui lòng nhập mã OTP hợp lệ');
      return;
    }

    _setLoading(true);
    try {
      await _authService.signInWithOTP(_verificationId, code);
      _navigateToHome();
    } catch (e) {
      _showError('Mã OTP không đúng hoặc đã hết hạn');
      _setLoading(false);
    }
  }

  // --- Social Auth ---
  void _signInWithGoogle() async {
    _setLoading(true);
    try {
      final userOpt = await _authService.signInWithGoogle();
      if (userOpt != null) {
        _navigateToHome();
      } else {
        _setLoading(false); // Cancelled
      }
    } catch (e) {
      _showError('Lỗi đăng nhập Google: $e');
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
                  colors: [AppColors.primary.withOpacity(0.25), Colors.transparent],
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
                  colors: [AppColors.primaryLight.withOpacity(0.15), Colors.transparent],
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
                          color: AppColors.primary.withOpacity(0.4),
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
                        _buildModeTab('Số điện thoại', AuthMode.phone),
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
                      Expanded(child: Divider(color: AppColors.textMuted.withOpacity(0.3))),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text('hoặc', style: TextStyle(color: AppColors.textMuted, fontSize: 13, fontFamily: 'Inter')),
                      ),
                      Expanded(child: Divider(color: AppColors.textMuted.withOpacity(0.3))),
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
                      _buildSocialButton(Icons.apple_rounded, 'Apple', () => _showError('Apple login comming soon')),
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
            indicator: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.primaryLight, width: 2)),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelColor: AppColors.primaryLight,
            unselectedLabelColor: AppColors.textSecondary,
            labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Inter'),
            tabs: const [Tab(text: 'Đăng nhập'), Tab(text: 'Đăng ký')],
          ),
          const SizedBox(height: 20),
          if (!_isLogin) ...[
            _buildInput(Icons.person_outline_rounded, 'Họ và tên', controller: _nameController),
            const SizedBox(height: 16),
          ],
          _buildInput(Icons.email_outlined, 'Email', controller: _emailController, keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 16),
          _buildInput(
            Icons.lock_outline_rounded, 'Mật khẩu',
            isPassword: true, controller: _passwordController,
          ),
          if (!_isLogin) ...[
            const SizedBox(height: 16),
            _buildInput(
              Icons.lock_outline_rounded, 'Xác nhận mật khẩu',
              isPassword: true, controller: _confirmPasswordController,
            ),
          ],
          if (_isLogin) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {},
                child: const Text('Quên mật khẩu?', style: TextStyle(color: AppColors.primaryLight, fontSize: 13, fontFamily: 'Inter')),
              ),
            ),
          ],
          const SizedBox(height: 20),
          _isLoading 
              ? const CircularProgressIndicator(color: AppColors.primary)
              : GradientButton(
                  text: _isLogin ? 'Đăng nhập' : 'Đăng ký',
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
            _isCodeSent ? 'Nhập mã xác nhận' : 'Đăng nhập bằng SĐT',
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700, fontFamily: 'Inter'),
          ),
          const SizedBox(height: 8),
          Text(
            _isCodeSent 
              ? 'Mã OTP đã được gửi đến số điện thoại của bạn'
              : 'Chúng tôi sẽ gửi mã OTP để xác minh',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13, fontFamily: 'Inter'),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          
          if (!_isCodeSent)
            _buildInput(
              Icons.phone_outlined, 'Số điện thoại', 
              controller: _phoneController, 
              keyboardType: TextInputType.phone,
            )
          else
            _buildInput(
              Icons.password_rounded, 'Mã OTP 6 chữ số', 
              controller: _otpController, 
              keyboardType: TextInputType.number,
            ),
            
          const SizedBox(height: 24),
          
          _isLoading 
              ? const CircularProgressIndicator(color: AppColors.primary)
              : GradientButton(
                  text: _isCodeSent ? 'Xác nhận' : 'Gửi mã OTP',
                  width: double.infinity,
                  onPressed: _isCodeSent ? _verifyOTP : _sendPhoneCode,
                ),
                
          if (_isCodeSent) ...[
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => setState(() => _isCodeSent = false),
              child: const Text('Thay đổi số điện thoại', style: TextStyle(color: AppColors.textSecondary)),
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
        color: AppColors.bgCard.withOpacity(0.5),
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
