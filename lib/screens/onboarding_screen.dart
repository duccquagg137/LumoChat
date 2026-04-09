import 'package:flutter/material.dart';

import '../services/onboarding_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import 'login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  final OnboardingService _onboardingService = OnboardingService();
  int _currentPage = 0;
  bool _isNavigating = false;

  bool _isEnglish(BuildContext context) =>
      Localizations.localeOf(context).languageCode == 'en';

  String _txt(
    BuildContext context, {
    required String vi,
    required String en,
  }) {
    return _isEnglish(context) ? en : vi;
  }

  List<_OnboardingPage> _buildPages(BuildContext context) {
    return [
      _OnboardingPage(
        icon: Icons.chat_bubble_rounded,
        title: _txt(
          context,
          vi: 'Nhắn tin siêu nhanh',
          en: 'Lightning-fast messaging',
        ),
        subtitle: _txt(
          context,
          vi: 'Gửi và nhận tin nhắn tức thì\nvới trải nghiệm mượt mà.',
          en: 'Send and receive messages instantly\nwith a smooth experience.',
        ),
        gradient: const [Color(0xFF7C3AED), Color(0xFF9333EA)],
      ),
      _OnboardingPage(
        icon: Icons.group_rounded,
        title: _txt(
          context,
          vi: 'Nhóm trò chuyện linh hoạt',
          en: 'Flexible group conversations',
        ),
        subtitle: _txt(
          context,
          vi: 'Tạo nhóm, quản lý thành viên\nvà đồng bộ theo thời gian thực.',
          en: 'Create groups, manage members,\nand stay synced in real time.',
        ),
        gradient: const [Color(0xFF3B82F6), Color(0xFF6366F1)],
      ),
      _OnboardingPage(
        icon: Icons.shield_rounded,
        title: _txt(
          context,
          vi: 'Bảo mật dữ liệu',
          en: 'Data security first',
        ),
        subtitle: _txt(
          context,
          vi: 'Kiểm soát quyền truy cập rõ ràng\nvà giảm rủi ro truy cập chéo.',
          en: 'Clear access control\nwith reduced cross-user risk.',
        ),
        gradient: const [Color(0xFF10B981), Color(0xFF059669)],
      ),
    ];
  }

  Future<void> _finishOnboarding() async {
    if (_isNavigating) return;
    setState(() => _isNavigating = true);
    await _onboardingService.markCompleted();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const LoginScreen(),
        transitionDuration: const Duration(milliseconds: 400),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = _buildPages(context);
    final isLastPage = _currentPage == pages.length - 1;

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(gradient: AppGradients.hero),
          ),
          Positioned(
            top: -100,
            left: -50,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withOpacity(0.2),
                    Colors.transparent
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            right: -80,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primaryLight.withOpacity(0.15),
                    Colors.transparent
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: TextButton(
                    onPressed: _isNavigating ? null : _finishOnboarding,
                    child: Text(
                      _txt(context, vi: 'Bỏ qua', en: 'Skip'),
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: pages.length,
                    onPageChanged: (value) =>
                        setState(() => _currentPage = value),
                    itemBuilder: (context, index) {
                      final page = pages[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 132,
                              height: 132,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: page.gradient),
                                borderRadius: BorderRadius.circular(36),
                                boxShadow: [
                                  BoxShadow(
                                    color: page.gradient.first.withOpacity(0.4),
                                    blurRadius: 36,
                                    offset: const Offset(0, 14),
                                  ),
                                ],
                              ),
                              child: Icon(page.icon,
                                  color: Colors.white, size: 60),
                            ),
                            const SizedBox(height: 40),
                            Text(
                              page.title,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                                fontFamily: 'Inter',
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              page.subtitle,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 16,
                                color: AppColors.textSecondary,
                                fontFamily: 'Inter',
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 36),
                  child: GlassCard(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 18),
                    borderRadius: 22,
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(pages.length, (index) {
                            final active = _currentPage == index;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: active ? 28 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: active
                                    ? AppColors.primary
                                    : AppColors.textMuted.withOpacity(0.28),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 18),
                        GradientButton(
                          text: isLastPage
                              ? _txt(context,
                                  vi: 'Bắt đầu ngay', en: 'Get started')
                              : _txt(context, vi: 'Tiếp theo', en: 'Continue'),
                          icon: isLastPage
                              ? Icons.rocket_launch_rounded
                              : Icons.arrow_forward_rounded,
                          width: double.infinity,
                          onPressed: _isNavigating
                              ? null
                              : () {
                                  if (isLastPage) {
                                    _finishOnboarding();
                                  } else {
                                    _controller.nextPage(
                                      duration:
                                          const Duration(milliseconds: 280),
                                      curve: Curves.easeOut,
                                    );
                                  }
                                },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingPage {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> gradient;

  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
  });
}
