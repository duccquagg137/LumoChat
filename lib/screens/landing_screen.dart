import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import 'login_screen.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _counterController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..forward();
    _counterController = AnimationController(vsync: this, duration: const Duration(seconds: 2));
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _counterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(decoration: const BoxDecoration(gradient: AppGradients.hero)),
          SingleChildScrollView(
            child: Column(
              children: [
                _buildHeader(context),
                _buildHero(context),
                _buildFeatures(context),
                _buildAppPreview(context),
                _buildGroupExperience(context),
                _buildStats(context),
                _buildFooter(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _isEnglish(BuildContext context) => Localizations.localeOf(context).languageCode == 'en';

  String _txt(BuildContext context, {required String vi, required String en}) {
    return _isEnglish(context) ? en : vi;
  }

  // ---- HEADER ----
  Widget _buildHeader(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            // Logo
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                gradient: AppGradients.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            const Text('LumoChat', style: TextStyle(
              color: AppColors.textPrimary, fontSize: 18,
              fontWeight: FontWeight.w800, fontFamily: 'Inter',
            )),
            const Spacer(),
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: AppGradients.primary,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: AppColors.primary.withAlphaFraction(0.3), blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: Text(
                  _txt(context, vi: 'Má»Ÿ á»©ng dá»¥ng', en: 'Open App'),
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'Inter'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- HERO ----
  Widget _buildHero(BuildContext context) {
    return Stack(
      children: [
        // Orbs
        Positioned(
          top: 20, right: -40,
          child: Container(
            width: 200, height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [AppColors.primary.withAlphaFraction(0.3), Colors.transparent]),
            ),
          ),
        ),
        Positioned(
          bottom: 20, left: -60,
          child: Container(
            width: 180, height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [AppColors.primaryLight.withAlphaFraction(0.2), Colors.transparent]),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 40),
          child: Column(
            children: [
              Text(
                _txt(
                  context,
                  vi: 'TrÃ² chuyá»‡n rÃµ rÃ ng hÆ¡n,\nkáº¿t ná»‘i gáº§n hÆ¡n.',
                  en: 'Chat with more clarity,\nconnect with more ease.',
                ),
                style: const TextStyle(
                  fontSize: 38, fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary, fontFamily: 'Inter',
                  height: 1.15, letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                _txt(
                  context,
                  vi: 'Nháº¯n tin 1-1, trÃ² chuyá»‡n nhÃ³m mÆ°á»£t mÃ , giao diá»‡n hiá»‡n Ä‘áº¡i\nvÃ  táº­p trung vÃ o tráº£i nghiá»‡m trÃ² chuyá»‡n.',
                  en: 'Smooth 1-1 messaging, effortless group chats,\nand a modern interface focused on conversations.',
                ),
                style: const TextStyle(
                  fontSize: 15, color: AppColors.textSecondary,
                  fontFamily: 'Inter', height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              // CTAs
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GradientButton(
                    text: _txt(context, vi: 'Báº¯t Ä‘áº§u trÃ² chuyá»‡n', en: 'Start chatting'),
                    icon: Icons.chat_rounded,
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
                  ),
                  const SizedBox(width: 12),
                  OutlinedPillButton(
                    text: _txt(context, vi: 'Xem demo', en: 'See demo'),
                    icon: Icons.play_arrow_rounded,
                    onPressed: () {},
                  ),
                ],
              ),
              const SizedBox(height: 40),
              // Phone mockup
              _buildPhoneMockup(context),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneMockup(BuildContext context) {
    return Container(
      width: 260,
      height: 420,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: AppColors.glassBorder, width: 2),
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1128), Color(0xFF16102A)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        boxShadow: [
          BoxShadow(color: AppColors.primary.withAlphaFraction(0.2), blurRadius: 40, spreadRadius: 5),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Column(
          children: [
            // Status bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(width: 80, height: 4, decoration: BoxDecoration(color: AppColors.textMuted, borderRadius: BorderRadius.circular(2))),
                ],
              ),
            ),
            // Chat header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 32, height: 32,
                    decoration: const BoxDecoration(
                      gradient: AppGradients.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(child: Text('M', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700))),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Minh Anh', style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                      Text(
                        _txt(context, vi: 'Trá»±c tuyáº¿n', en: 'Online'),
                        style: const TextStyle(color: AppColors.accentGreen, fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(color: AppColors.glassBorder, height: 1),
            // Chat messages
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    _buildMockBubble(_txt(context, vi: 'ChÃ o báº¡n! ðŸ‘‹', en: 'Hey there! ðŸ‘‹'), false),
                    _buildMockBubble(_txt(context, vi: 'HÃ´m nay Ä‘i cafe khÃ´ng?', en: 'Coffee later today?'), false),
                    _buildMockBubble(_txt(context, vi: 'Ok, 3h chiá»u nhÃ©! â˜•', en: 'Sure, 3 PM! â˜•'), true),
                    _buildMockBubble(_txt(context, vi: 'Tuyá»‡t vá»i! ðŸ˜', en: 'Awesome! ðŸ˜'), false),
                    _buildMockBubble(_txt(context, vi: 'Gáº·p lÃºc Ä‘Ã³ nhÃ©!', en: 'See you then!'), true),
                    const Spacer(),
                    // Input bar
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.glassBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.glassBorder, width: 0.5),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.add_rounded, color: AppColors.textMuted, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _txt(context, vi: 'Nháº­p tin nháº¯n...', en: 'Type a message...'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                            ),
                          ),
                          Container(
                            width: 24, height: 24,
                            decoration: const BoxDecoration(gradient: AppGradients.primary, shape: BoxShape.circle),
                            child: const Icon(Icons.send_rounded, color: Colors.white, size: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMockBubble(String text, bool isSent) {
    return Align(
      alignment: isSent ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          gradient: isSent ? AppGradients.sentBubble : null,
          color: isSent ? null : AppColors.glassBg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(isSent ? 14 : 4),
            bottomRight: Radius.circular(isSent ? 4 : 14),
          ),
          border: isSent ? null : Border.all(color: AppColors.glassBorder, width: 0.5),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSent ? Colors.white : AppColors.textPrimary,
            fontSize: 12, fontFamily: 'Inter',
          ),
        ),
      ),
    );
  }

  // ---- FEATURES ----
  Widget _buildFeatures(BuildContext context) {
    final features = [
      _FeatureItem(
        Icons.bolt_rounded,
        _txt(context, vi: 'TrÃ² chuyá»‡n 1-1 nhanh', en: 'Fast 1-1 chat'),
        _txt(context, vi: 'Gá»­i tin nháº¯n tá»©c thÃ¬ vá»›i tá»‘c Ä‘á»™ Ã¡nh sÃ¡ng', en: 'Instant messaging with lightning speed'),
        const [Color(0xFF7C3AED), Color(0xFF9333EA)],
      ),
      _FeatureItem(
        Icons.group_add_rounded,
        _txt(context, vi: 'Táº¡o nhÃ³m dá»… dÃ ng', en: 'Easy group creation'),
        _txt(context, vi: 'Káº¿t ná»‘i nhÃ³m báº¡n bÃ¨ chá»‰ vÃ i thao tÃ¡c', en: 'Bring your friends together in seconds'),
        const [Color(0xFF3B82F6), Color(0xFF6366F1)],
      ),
      _FeatureItem(
        Icons.photo_library_rounded,
        _txt(context, vi: 'Gá»­i áº£nh / emoji / file', en: 'Share photos / emoji / files'),
        _txt(context, vi: 'Chia sáº» khoáº£nh kháº¯c vÃ  tÃ i liá»‡u nhanh', en: 'Share moments and documents instantly'),
        const [Color(0xFFEC4899), Color(0xFFF43F5E)],
      ),
      _FeatureItem(
        Icons.notifications_active_rounded,
        _txt(context, vi: 'ThÃ´ng bÃ¡o thá»i gian thá»±c', en: 'Real-time notifications'),
        _txt(context, vi: 'KhÃ´ng bá» lá»¡ báº¥t ká»³ tin nháº¯n nÃ o', en: 'Never miss an important message'),
        const [Color(0xFF10B981), Color(0xFF059669)],
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      child: Column(
        children: [
          Text(
            _txt(context, vi: 'TÃ­nh nÄƒng ná»•i báº­t', en: 'Highlighted features'),
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _txt(context, vi: 'Má»i thá»© báº¡n cáº§n cho tráº£i nghiá»‡m trÃ² chuyá»‡n tuyá»‡t vá»i', en: 'Everything you need for a great chat experience'),
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 24),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.85,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: features.length,
            itemBuilder: (_, i) {
              final f = features[i];
              return GlassCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: f.colors),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [BoxShadow(color: f.colors[0].withAlphaFraction(0.3), blurRadius: 12, offset: const Offset(0, 6))],
                      ),
                      child: Icon(f.icon, color: Colors.white, size: 24),
                    ),
                    const SizedBox(height: 16),
                    Text(f.title, style: const TextStyle(
                      color: AppColors.textPrimary, fontSize: 14,
                      fontWeight: FontWeight.w700, fontFamily: 'Inter',
                    )),
                    const SizedBox(height: 6),
                    Text(f.desc, style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 12,
                      fontFamily: 'Inter', height: 1.4,
                    )),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ---- APP PREVIEW ----
  Widget _buildAppPreview(BuildContext context) {
    final previewItems = _isEnglish(context)
        ? [
            ('Minh Anh', 'See you there! â˜•', true),
            ('Hung Do', 'Done coding yet?', false),
            ('Besties ðŸ’•', 'Can I join too?', true),
            ('Mai Dinh', 'ðŸ“· Photo', false),
          ]
        : [
            ('Minh Anh', 'Háº¹n gáº·p nhÃ©! â˜•', true),
            ('HÃ¹ng Äá»—', 'Code xong chÆ°a?', false),
            ('Báº¡n thÃ¢n ðŸ’•', 'Cho mÃ¬nh tham gia vá»›i!', true),
            ('Mai Äinh', 'ðŸ“· áº¢nh', false),
          ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
      child: Column(
        children: [
          Text(
            _txt(context, vi: 'Tráº£i nghiá»‡m mÆ°á»£t mÃ ', en: 'Smooth experience'),
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _txt(context, vi: 'Giao diá»‡n hiá»‡n Ä‘áº¡i, tá»‘i Æ°u cho má»i tÆ°Æ¡ng tÃ¡c', en: 'Modern UI built for every interaction'),
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 24),
          // Split preview
          Row(
            children: [
              // Left - chat list
              Expanded(
                child: GlassCard(
                  padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _txt(context, vi: 'Cuá»™c trÃ² chuyá»‡n', en: 'Conversations'),
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                      const SizedBox(height: 12),
                      ...previewItems.map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Container(
                              width: 32, height: 32,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(colors: [AppColors.primary, AppColors.primaryLight]),
                              ),
                              child: Center(child: Text(item.$1[0], style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600))),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.$1, style: TextStyle(color: AppColors.textPrimary, fontSize: 11, fontWeight: item.$3 ? FontWeight.w700 : FontWeight.w500)),
                                  Text(item.$2, style: const TextStyle(color: AppColors.textMuted, fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
                                ],
                              ),
                            ),
                            if (item.$3)
                              Container(
                                width: 8, height: 8,
                                decoration: const BoxDecoration(shape: BoxShape.circle, gradient: AppGradients.primary),
                              ),
                          ],
                        ),
                      )),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Right - active chat
              Expanded(
                child: GlassCard(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 28, height: 28,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: AppGradients.primary,
                            ),
                            child: const Center(child: Text('M', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))),
                          ),
                          const SizedBox(width: 8),
                          const Text('Minh Anh', style: TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildMockBubble(_txt(context, vi: 'ChÃ o! ðŸ‘‹', en: 'Hi! ðŸ‘‹'), false),
                      _buildMockBubble(_txt(context, vi: 'Äi cafe nhÃ©?', en: 'Coffee later?'), false),
                      _buildMockBubble(_txt(context, vi: 'Ok! â˜•', en: 'Sure! â˜•'), true),
                      _buildMockBubble(_txt(context, vi: 'Tuyá»‡t! ðŸ˜', en: 'Great! ðŸ˜'), false),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---- GROUP EXPERIENCE ----
  Widget _buildGroupExperience(BuildContext context) {
    final items = _isEnglish(context)
        ? [
            ('Create friend groups', Icons.people_alt_rounded, 'Invite friends into a group in seconds'),
            ('Name your group', Icons.edit_rounded, 'Set custom group name and avatar'),
            ('Manage members', Icons.admin_panel_settings_rounded, 'Flexible admin controls'),
            ('Share instantly', Icons.share_rounded, 'Send files, images, and links quickly'),
          ]
        : [
            ('Táº¡o nhÃ³m báº¡n bÃ¨', Icons.people_alt_rounded, 'Má»i báº¡n bÃ¨ vÃ o nhÃ³m chá»‰ vÃ i giÃ¢y'),
            ('Äáº·t tÃªn nhÃ³m', Icons.edit_rounded, 'Äáº·t tÃªn vÃ  avatar riÃªng cho nhÃ³m'),
            ('Quáº£n lÃ½ thÃ nh viÃªn', Icons.admin_panel_settings_rounded, 'PhÃ¢n quyá»n admin linh hoáº¡t'),
            ('Chia sáº» nhanh', Icons.share_rounded, 'Gá»­i file, áº£nh, link siÃªu nhanh'),
          ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
      child: Column(
        children: [
          Text(
            _txt(context, vi: 'Tráº£i nghiá»‡m nhÃ³m', en: 'Group experience'),
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _txt(context, vi: 'TrÃ² chuyá»‡n nhÃ³m chÆ°a bao giá» dá»… dÃ ng Ä‘áº¿n tháº¿', en: 'Group chat has never been this easy'),
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 24),
          ...items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GlassCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlphaFraction(0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(item.$2, color: AppColors.primaryLight, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.$1, style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w700, fontFamily: 'Inter')),
                        const SizedBox(height: 4),
                        Text(item.$3, style: const TextStyle(color: AppColors.textMuted, fontSize: 13, fontFamily: 'Inter')),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                ],
              ),
            ),
          )),
        ],
      ),
    );
  }

  // ---- STATS ----
  Widget _buildStats(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              '500+',
              _txt(context, vi: 'NhÃ³m\nhoáº¡t Ä‘á»™ng', en: 'Active\ngroups'),
              const Color(0xFF7C3AED),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildStatCard(
              '10K+',
              _txt(context, vi: 'Tin nháº¯n\nmá»—i ngÃ y', en: 'Messages\nper day'),
              const Color(0xFF3B82F6),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildStatCard(
              '< 1s',
              _txt(context, vi: 'Pháº£n há»“i\ntá»©c thÃ¬', en: 'Instant\nresponse'),
              const Color(0xFF10B981),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String value, String label, Color color) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
      child: Column(
        children: [
          Text(value, style: TextStyle(
            fontSize: 28, fontWeight: FontWeight.w900,
            color: color, fontFamily: 'Inter',
          )),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(
            color: AppColors.textSecondary, fontSize: 12,
            fontFamily: 'Inter', height: 1.3,
          ), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  // ---- FOOTER ----
  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
      decoration: const BoxDecoration(
        color: AppColors.bgSurface,
        border: Border(top: BorderSide(color: AppColors.glassBorder, width: 0.5)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  gradient: AppGradients.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 8),
              const Text('LumoChat', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700, fontFamily: 'Inter')),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              _buildFooterLink(_txt(context, vi: 'Táº£i app', en: 'Download')),
              _buildFooterLink(_txt(context, vi: 'ChÃ­nh sÃ¡ch', en: 'Policy')),
              _buildFooterLink(_txt(context, vi: 'Há»— trá»£', en: 'Support')),
              _buildFooterLink(_txt(context, vi: 'Blog', en: 'Blog')),
            ],
          ),
          const SizedBox(height: 20),
          // Social icons
          Row(
            children: [
              _buildSocialIcon(Icons.language_rounded),
              _buildSocialIcon(Icons.camera_alt_rounded),
              _buildSocialIcon(Icons.alternate_email_rounded),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: AppColors.glassBorder),
          const SizedBox(height: 16),
          Text(
            _txt(context, vi: 'Â© 2026 LumoChat. Má»i quyá»n Ä‘Æ°á»£c báº£o lÆ°u.', en: 'Â© 2026 LumoChat. All rights reserved.'),
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12, fontFamily: 'Inter'),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterLink(String text) {
    return Padding(
      padding: const EdgeInsets.only(right: 20),
      child: Text(text, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontFamily: 'Inter')),
    );
  }

  Widget _buildSocialIcon(IconData icon) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      width: 36, height: 36,
      decoration: BoxDecoration(
        color: AppColors.glassBg, shape: BoxShape.circle,
        border: Border.all(color: AppColors.glassBorder, width: 0.5),
      ),
      child: Icon(icon, color: AppColors.textSecondary, size: 18),
    );
  }
}

class _FeatureItem {
  final IconData icon;
  final String title;
  final String desc;
  final List<Color> colors;
  const _FeatureItem(this.icon, this.title, this.desc, this.colors);
}
