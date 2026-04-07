import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import 'edit_profile_screen.dart';
import 'landing_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _darkMode = true;
  bool _notifications = true;
  bool _settingsLoaded = false;

  String _displayOrFallback(dynamic value, {String fallback = 'Chưa cập nhật'}) {
    final text = (value ?? '').toString().trim();
    return text.isEmpty ? fallback : text;
  }

  String _formatDateField(dynamic raw) {
    final text = (raw ?? '').toString().trim();
    if (text.isEmpty) return 'Chưa cập nhật';
    final parsed = DateTime.tryParse(text);
    if (parsed == null) return text;
    final dd = parsed.day.toString().padLeft(2, '0');
    final mm = parsed.month.toString().padLeft(2, '0');
    final yyyy = parsed.year.toString();
    return '$dd/$mm/$yyyy';
  }

  Future<void> _updateSetting(String key, bool value) async {
    setState(() {
      if (key == 'darkMode') {
        _darkMode = value;
      } else {
        _notifications = value;
      }
    });
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'settings': {key: value}
      }, SetOptions(merge: true));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lưu cài đặt thất bại: $e')),
      );
    }
  }

  void _showSimpleDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bgSurface,
        title: Text(title, style: const TextStyle(color: AppColors.textPrimary)),
        content: Text(message, style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return Scaffold(
      body: Stack(
        children: [
          Positioned(
            top: -100,
            left: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [AppColors.primary.withOpacity(0.15), Colors.transparent],
                ),
              ),
            ),
          ),
          SafeArea(
            child: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
              builder: (profileContext, snapshot) {
                if (snapshot.hasError || !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                }
                final userData = snapshot.data!.data() as Map<String, dynamic>?;
                if (userData == null) {
                  return const Center(
                    child: Text('Không tải được hồ sơ', style: TextStyle(color: AppColors.textMuted)),
                  );
                }

                final name = _displayOrFallback(userData['name'], fallback: 'Người dùng');
                final email = _displayOrFallback(userData['email']);
                final bio = _displayOrFallback(userData['bio'], fallback: 'Đang sử dụng LumoChat');
                final avatar = (userData['avatar'] ?? '').toString();
                final isOnline = userData['isOnline'] == true;
                final friendCount = (userData['friends'] is List) ? (userData['friends'] as List).length : 0;

                final settings = (userData['settings'] as Map<String, dynamic>?) ?? const {};
                if (!_settingsLoaded) {
                  _darkMode = settings['darkMode'] != false;
                  _notifications = settings['notifications'] != false;
                  _settingsLoaded = true;
                }

                final phone = _displayOrFallback(userData['phoneNumber']);
                final address = _displayOrFallback(userData['address']);
                final city = _displayOrFallback(userData['city']);
                final gender = _displayOrFallback(userData['gender']);
                final birthday = _formatDateField(userData['dateOfBirth']);
                final website = _displayOrFallback(userData['website']);
                final occupation = _displayOrFallback(userData['occupation']);

                final profileSummary = StringBuffer()
                  ..writeln('Hồ sơ LumoChat')
                  ..writeln('Tên: $name')
                  ..writeln('Email: $email')
                  ..writeln('Số điện thoại: $phone')
                  ..writeln('Địa chỉ: $address')
                  ..writeln('Thành phố: $city')
                  ..writeln('Giới tính: $gender')
                  ..writeln('Ngày sinh: $birthday')
                  ..writeln('Nghề nghiệp: $occupation')
                  ..writeln('Website: $website');

                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Text(
                            'Cá nhân',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                              fontFamily: 'Inter',
                            ),
                          ),
                          const Spacer(),
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.glassBg,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.glassBorder, width: 0.5),
                            ),
                            child: const Icon(Icons.settings_outlined, color: AppColors.textPrimary, size: 20),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      GlassCard(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            AvatarWidget(
                              name: name,
                              imageUrl: avatar,
                              size: 88,
                              isOnline: isOnline,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              name,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'Inter',
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              email,
                              style: const TextStyle(color: AppColors.primaryLight, fontSize: 14, fontFamily: 'Inter'),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              bio,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, fontFamily: 'Inter'),
                            ),
                            const SizedBox(height: 20),
                            StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('groups')
                                  .where('members', arrayContains: uid)
                                  .snapshots(),
                              builder: (context, groupSnapshot) {
                                final groupCount = groupSnapshot.data?.docs.length ?? 0;
                                return Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    _buildStat('$friendCount', 'Bạn bè'),
                                    Container(width: 1, height: 30, color: AppColors.glassBorder),
                                    _buildStat('$groupCount', 'Nhóm'),
                                    Container(width: 1, height: 30, color: AppColors.glassBorder),
                                    _buildStat(isOnline ? 'Online' : 'Offline', 'Trạng thái'),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Expanded(
                                  child: GradientButton(
                                    text: 'Chỉnh sửa',
                                    icon: Icons.edit_rounded,
                                    height: 44,
                                    onPressed: () {
                                      Navigator.push(
                                        profileContext,
                                        MaterialPageRoute(
                                          builder: (_) => EditProfileScreen(userData: userData),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedPillButton(
                                    text: 'Chia sẻ',
                                    icon: Icons.share_rounded,
                                    onPressed: () async {
                                      await Clipboard.setData(ClipboardData(text: profileSummary.toString()));
                                      if (!profileContext.mounted) return;
                                      ScaffoldMessenger.of(profileContext).showSnackBar(
                                        const SnackBar(content: Text('Đã sao chép thông tin hồ sơ')),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildSection('Thông tin cơ bản', [
                        _buildInfoRow(Icons.phone_outlined, 'Số điện thoại', phone),
                        _buildInfoRow(Icons.location_on_outlined, 'Địa chỉ', address),
                        _buildInfoRow(Icons.location_city_outlined, 'Thành phố', city),
                        _buildInfoRow(Icons.wc_outlined, 'Giới tính', gender),
                        _buildInfoRow(Icons.cake_outlined, 'Ngày sinh', birthday),
                        _buildInfoRow(Icons.work_outline_rounded, 'Nghề nghiệp', occupation),
                        _buildInfoRow(Icons.language_rounded, 'Website', website),
                      ]),
                      const SizedBox(height: 16),
                      _buildSection('Tài khoản', [
                        _buildMenuItem(
                          Icons.person_outline_rounded,
                          'Thông tin cá nhân',
                          onTap: () {
                            Navigator.push(
                              profileContext,
                              MaterialPageRoute(
                                builder: (_) => EditProfileScreen(userData: userData),
                              ),
                            );
                          },
                        ),
                        _buildMenuItem(
                          Icons.content_copy_rounded,
                          'Sao chép ID người dùng',
                          onTap: () async {
                            await Clipboard.setData(ClipboardData(text: uid));
                            if (!profileContext.mounted) return;
                            ScaffoldMessenger.of(profileContext).showSnackBar(
                              const SnackBar(content: Text('Đã sao chép ID')),
                            );
                          },
                        ),
                        _buildMenuItem(
                          Icons.lock_outline_rounded,
                          'Bảo mật',
                          onTap: () => _showSimpleDialog('Bảo mật', 'Tính năng bảo mật nâng cao sẽ được cập nhật sớm.'),
                        ),
                      ]),
                      const SizedBox(height: 16),
                      _buildSection('Tùy chỉnh', [
                        _buildToggleItem(
                          Icons.dark_mode_outlined,
                          'Giao diện tối',
                          _darkMode,
                          (value) => _updateSetting('darkMode', value),
                        ),
                        _buildMenuItem(
                          Icons.language_rounded,
                          'Ngôn ngữ',
                          trailing: 'Tiếng Việt',
                          onTap: () => _showSimpleDialog('Ngôn ngữ', 'Hiện tại ứng dụng đang dùng Tiếng Việt.'),
                        ),
                        _buildToggleItem(
                          Icons.notifications_outlined,
                          'Thông báo',
                          _notifications,
                          (value) => _updateSetting('notifications', value),
                        ),
                      ]),
                      const SizedBox(height: 16),
                      _buildSection('Hỗ trợ', [
                        _buildMenuItem(
                          Icons.help_outline_rounded,
                          'Trung tâm hỗ trợ',
                          onTap: () => _showSimpleDialog('Hỗ trợ', 'Liên hệ: support@lumochat.app'),
                        ),
                        _buildMenuItem(
                          Icons.bug_report_outlined,
                          'Báo lỗi',
                          onTap: () => _showSimpleDialog('Báo lỗi', 'Gửi lỗi qua email: bug@lumochat.app'),
                        ),
                        _buildMenuItem(
                          Icons.info_outline_rounded,
                          'Giới thiệu',
                          onTap: () => _showSimpleDialog('Giới thiệu', 'LumoChat - Kết nối và trò chuyện thời gian thực.'),
                        ),
                      ]),
                      const SizedBox(height: 24),
                      GlassCard(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        borderRadius: 16,
                        onTap: () async {
                          try {
                            await AuthService().signOut();
                            if (profileContext.mounted) {
                              Navigator.of(profileContext).pushAndRemoveUntil(
                                MaterialPageRoute(builder: (_) => const LandingScreen()),
                                (route) => false,
                              );
                            }
                          } catch (e) {
                            if (!profileContext.mounted) return;
                            ScaffoldMessenger.of(profileContext).showSnackBar(SnackBar(content: Text('Lỗi đăng xuất: $e')));
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
                                color: AppColors.error,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Inter',
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
                );
              },
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
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            fontFamily: 'Inter',
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
              color: AppColors.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              fontFamily: 'Inter',
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

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.primaryLight, size: 20),
      ),
      title: Text(
        label,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          fontFamily: 'Inter',
        ),
      ),
      subtitle: Text(
        value,
        style: const TextStyle(color: AppColors.textMuted, fontSize: 12, fontFamily: 'Inter'),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      dense: true,
    );
  }

  Widget _buildMenuItem(
    IconData icon,
    String title, {
    String? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
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
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      dense: true,
    );
  }

  Widget _buildToggleItem(IconData icon, String title, bool value, ValueChanged<bool> onChanged) {
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
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
