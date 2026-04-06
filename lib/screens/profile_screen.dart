import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../services/auth_service.dart';
import 'landing_screen.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _darkMode = true;
  bool _notifications = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned(
            top: -100, left: -50,
            child: Container(
              width: 250, height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [AppColors.primary.withOpacity(0.15), Colors.transparent],
                ),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  // Header row
                  Row(
                    children: [
                      const Text(
                        'Cá nhân',
                        style: TextStyle(
                          fontSize: 28, fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary, fontFamily: 'Inter',
                        ),
                      ),
                      const Spacer(),
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.glassBg, shape: BoxShape.circle,
                          border: Border.all(color: AppColors.glassBorder, width: 0.5),
                        ),
                        child: const Icon(Icons.settings_outlined, color: AppColors.textPrimary, size: 20),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Profile card
                  StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(FirebaseAuth.instance.currentUser?.uid ?? '')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError || !snapshot.hasData) {
                        return const GlassCard(
                          padding: EdgeInsets.all(24),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final userData = snapshot.data!.data() as Map<String, dynamic>?;
                      if (userData == null) return const SizedBox();

                      final name = userData['name'] ?? 'Người dùng';
                      final email = userData['email'] ?? '';
                      final initial = name.isNotEmpty ? name[0].toUpperCase() : 'A';
                      final isOnline = userData['isOnline'] ?? false;

                      return GlassCard(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            // Avatar
                            Container(
                              width: 88, height: 88,
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: AppGradients.primary,
                                boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 20)],
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.bgCard,
                                  border: Border.all(color: AppColors.bgDark, width: 3),
                                ),
                                clipBehavior: Clip.hardEdge,
                                child: userData['avatar']?.isNotEmpty == true
                                    ? Image.network(userData['avatar'], fit: BoxFit.cover)
                                    : Center(
                                        child: Text(initial, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w700)),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              name,
                              style: const TextStyle(
                                color: AppColors.textPrimary, fontSize: 22,
                                fontWeight: FontWeight.w800, fontFamily: 'Inter',
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              email,
                              style: const TextStyle(color: AppColors.primaryLight, fontSize: 14, fontFamily: 'Inter'),
                            ),
                            const SizedBox(height: 8),
                            if (userData['bio'] != null && userData['bio'].toString().isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  userData['bio'],
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, fontFamily: 'Inter'),
                                ),
                              )
                            else 
                              const Text(
                                'Đang sử dụng LumoChat 💬',
                                style: TextStyle(color: AppColors.textSecondary, fontSize: 14, fontFamily: 'Inter'),
                              ),
                            const SizedBox(height: 20),
                            // Stats
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildStat('N/A', 'Bạn bè'),
                                Container(width: 1, height: 30, color: AppColors.glassBorder),
                                _buildStat('N/A', 'Nhóm'),
                                Container(width: 1, height: 30, color: AppColors.glassBorder),
                                _buildStat(isOnline ? 'Online' : 'Offline', 'Trạng thái'),
                              ],
                            ),
                            const SizedBox(height: 20),
                            // Buttons
                            Row(
                              children: [
                                Expanded(
                                  child: GradientButton(
                                    text: 'Chỉnh sửa',
                                    icon: Icons.edit_rounded,
                                    height: 44,
                                    onPressed: () {
                                      Navigator.push(context, MaterialPageRoute(
                                        builder: (_) => EditProfileScreen(userData: userData),
                                      ));
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedPillButton(
                                    text: 'Chia sẻ',
                                    icon: Icons.share_rounded,
                                    onPressed: () {},
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }
                  ),
                  const SizedBox(height: 20),
                  // Account section
                  _buildSection('Tài khoản', [
                    _buildMenuItem(Icons.person_outline_rounded, 'Thông tin cá nhân'),
                    _buildMenuItem(Icons.shield_outlined, 'Quyền riêng tư'),
                    _buildMenuItem(Icons.lock_outline_rounded, 'Bảo mật'),
                  ]),
                  const SizedBox(height: 16),
                  // Customization section
                  _buildSection('Tùy chỉnh', [
                    _buildToggleItem(Icons.dark_mode_outlined, 'Giao diện tối', _darkMode, (v) => setState(() => _darkMode = v)),
                    _buildMenuItem(Icons.language_rounded, 'Ngôn ngữ', trailing: 'Tiếng Việt'),
                    _buildToggleItem(Icons.notifications_outlined, 'Thông báo', _notifications, (v) => setState(() => _notifications = v)),
                  ]),
                  const SizedBox(height: 16),
                  // Support section
                  _buildSection('Hỗ trợ', [
                    _buildMenuItem(Icons.help_outline_rounded, 'Trung tâm hỗ trợ'),
                    _buildMenuItem(Icons.bug_report_outlined, 'Báo lỗi'),
                    _buildMenuItem(Icons.info_outline_rounded, 'Giới thiệu'),
                  ]),
                  const SizedBox(height: 24),
                  // Logout
                  GlassCard(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    borderRadius: 16,
                    onTap: () async {
                      try {
                        await AuthService().signOut();
                        if (context.mounted) {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(builder: (_) => const LandingScreen()),
                            (route) => false,
                          );
                        }
                      } catch (e) {
                         if (context.mounted) {
                           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi đăng xuất: $e')));
                         }
                      }
                    },
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.logout_rounded, color: AppColors.error, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Đăng xuất',
                          style: TextStyle(
                            color: AppColors.error, fontSize: 15,
                            fontWeight: FontWeight.w600, fontFamily: 'Inter',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'LumoChat v1.0.0',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontFamily: 'Inter'),
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

  Widget _buildStat(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary, fontSize: 18,
            fontWeight: FontWeight.w800, fontFamily: 'Inter',
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 12, fontFamily: 'Inter'),
        ),
      ],
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: const TextStyle(
              color: AppColors.textSecondary, fontSize: 14,
              fontWeight: FontWeight.w600, fontFamily: 'Inter',
            ),
          ),
        ),
        GlassCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildMenuItem(IconData icon, String title, {String? trailing}) {
    return ListTile(
      leading: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.primaryLight, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500, fontFamily: 'Inter'),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailing != null)
            Text(trailing, style: const TextStyle(color: AppColors.textMuted, fontSize: 13, fontFamily: 'Inter')),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 20),
        ],
      ),
      onTap: () {},
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      dense: true,
    );
  }

  Widget _buildToggleItem(IconData icon, String title, bool value, ValueChanged<bool> onChanged) {
    return ListTile(
      leading: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.primaryLight, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500, fontFamily: 'Inter'),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.primary,
        inactiveTrackColor: AppColors.textMuted.withOpacity(0.3),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      dense: true,
    );
  }
}
