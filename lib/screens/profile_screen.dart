import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../models/call_models.dart';
import '../services/app_providers.dart';
import '../services/auth_service.dart';
import '../services/call_service.dart';
import '../theme/app_theme.dart';
import '../utils/l10n.dart';
import '../widgets/glass_card.dart';
import 'notification_center_screen.dart';
import 'edit_profile_screen.dart';
import 'landing_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _darkMode = true;
  bool _notifications = true;
  bool _settingsLoaded = false;
  final CallService _callService = CallService();

  bool _isEnglish(BuildContext context) =>
      Localizations.localeOf(context).languageCode == 'en';

  String _txt(
    BuildContext context, {
    required String vi,
    required String en,
  }) {
    return _isEnglish(context) ? en : vi;
  }

  String _displayOrFallback(dynamic value, {required String fallback}) {
    final text = (value ?? '').toString().trim();
    return text.isEmpty ? fallback : text;
  }

  String _formatDateField(dynamic raw, {required String fallback}) {
    final text = (raw ?? '').toString().trim();
    if (text.isEmpty) return fallback;
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
        SnackBar(content: Text(context.l10n.profileSaveSettingFailed(e.toString()))),
      );
    }
  }

  Future<void> _setLanguage(String languageCode) async {
    await ref.read(appLocaleActionsProvider).setLocale(languageCode);

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() {});
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'settings': {'languageCode': languageCode}
      }, SetOptions(merge: true));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.profileLanguageSaveFailed(e.toString()))),
      );
    }

    if (mounted) {
      setState(() {});
    }
  }

  void _showSimpleDialog({required String title, required String message}) {
    final l10n = context.l10n;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.bgSurface,
        title: Text(title, style: const TextStyle(color: AppColors.textPrimary)),
        content: Text(message, style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.commonClose),
          ),
        ],
      ),
    );
  }

  void _showLanguageDialog() {
    final l10n = context.l10n;
    final currentCode = ref.read(appLanguageCodeProvider);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.bgSurface,
        title: Text(
          l10n.profileLanguageDialogTitle,
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              value: 'vi',
              groupValue: currentCode,
              onChanged: (value) {
                if (value == null) return;
                Navigator.pop(dialogContext);
                _setLanguage(value);
              },
              activeColor: AppColors.primary,
              title: Text(
                l10n.profileLanguageVietnamese,
                style: const TextStyle(color: AppColors.textPrimary, fontFamily: 'Inter'),
              ),
            ),
            RadioListTile<String>(
              value: 'en',
              groupValue: currentCode,
              onChanged: (value) {
                if (value == null) return;
                Navigator.pop(dialogContext);
                _setLanguage(value);
              },
              activeColor: AppColors.primary,
              title: Text(
                l10n.profileLanguageEnglish,
                style: const TextStyle(color: AppColors.textPrimary, fontFamily: 'Inter'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.commonClose),
          ),
        ],
      ),
    );
  }

  String _currentLanguageLabel() {
    final l10n = context.l10n;
    return ref.watch(appLanguageCodeProvider) == 'en'
        ? l10n.profileLanguageEnglish
        : l10n.profileLanguageVietnamese;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
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
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      l10n.profileLoadError,
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                }

                final userData = snapshot.data!.data() as Map<String, dynamic>?;
                if (userData == null) {
                  return Center(
                    child: Text(
                      l10n.profileLoadError,
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                  );
                }

                final settings = (userData['settings'] as Map<String, dynamic>?) ?? const {};
                if (!_settingsLoaded) {
                  _darkMode = settings['darkMode'] != false;
                  _notifications = settings['notifications'] != false;
                  final savedLanguage = (settings['languageCode'] ?? '').toString();
                  if (savedLanguage == 'vi' || savedLanguage == 'en') {
                    ref.read(appLocaleActionsProvider).setLocale(savedLanguage);
                  }
                  _settingsLoaded = true;
                }

                final name = _displayOrFallback(userData['name'], fallback: l10n.profileFallbackUser);
                final email = _displayOrFallback(userData['email'], fallback: l10n.profileNotUpdated);
                final bio = _displayOrFallback(userData['bio'], fallback: l10n.profileFallbackBio);
                final avatar = (userData['avatar'] ?? '').toString();
                final isOnline = userData['isOnline'] == true;
                final friendCount = (userData['friends'] is List) ? (userData['friends'] as List).length : 0;

                final phone = _displayOrFallback(userData['phoneNumber'], fallback: l10n.profileNotUpdated);
                final address = _displayOrFallback(userData['address'], fallback: l10n.profileNotUpdated);
                final city = _displayOrFallback(userData['city'], fallback: l10n.profileNotUpdated);
                final gender = _displayOrFallback(userData['gender'], fallback: l10n.profileNotUpdated);
                final birthday = _formatDateField(userData['dateOfBirth'], fallback: l10n.profileNotUpdated);
                final website = _displayOrFallback(userData['website'], fallback: l10n.profileNotUpdated);
                final occupation = _displayOrFallback(userData['occupation'], fallback: l10n.profileNotUpdated);

                final profileSummary = StringBuffer()
                  ..writeln(l10n.profileSummaryTitle)
                  ..writeln('${l10n.profileSummaryName}: $name')
                  ..writeln('${l10n.profileSummaryEmail}: $email')
                  ..writeln('${l10n.profileSummaryPhone}: $phone')
                  ..writeln('${l10n.profileSummaryAddress}: $address')
                  ..writeln('${l10n.profileSummaryCity}: $city')
                  ..writeln('${l10n.profileSummaryGender}: $gender')
                  ..writeln('${l10n.profileSummaryBirthDate}: $birthday')
                  ..writeln('${l10n.profileSummaryOccupation}: $occupation')
                  ..writeln('${l10n.profileSummaryWebsite}: $website');

                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Text(
                            l10n.navProfile,
                            style: const TextStyle(
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
                                    _buildStat('$friendCount', l10n.profileStatFriends),
                                    Container(width: 1, height: 30, color: AppColors.glassBorder),
                                    _buildStat('$groupCount', l10n.profileStatGroups),
                                    Container(width: 1, height: 30, color: AppColors.glassBorder),
                                    _buildStat(isOnline ? l10n.commonOnline : l10n.commonOffline, l10n.profileStatStatus),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Expanded(
                                  child: GradientButton(
                                    text: l10n.profileEdit,
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
                                    text: l10n.profileShare,
                                    icon: Icons.share_rounded,
                                    onPressed: () async {
                                      await Clipboard.setData(ClipboardData(text: profileSummary.toString()));
                                      if (!profileContext.mounted) return;
                                      ScaffoldMessenger.of(profileContext).showSnackBar(
                                        SnackBar(content: Text(l10n.profileCopySummarySuccess)),
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
                      _buildSection(l10n.profileSectionBasicInfo, [
                        _buildInfoRow(Icons.phone_outlined, l10n.profileFieldPhone, phone),
                        _buildInfoRow(Icons.location_on_outlined, l10n.profileFieldAddress, address),
                        _buildInfoRow(Icons.location_city_outlined, l10n.profileFieldCity, city),
                        _buildInfoRow(Icons.wc_outlined, l10n.profileFieldGender, gender),
                        _buildInfoRow(Icons.cake_outlined, l10n.profileFieldBirthDate, birthday),
                        _buildInfoRow(Icons.work_outline_rounded, l10n.profileFieldOccupation, occupation),
                        _buildInfoRow(Icons.language_rounded, l10n.profileFieldWebsite, website),
                      ]),
                      const SizedBox(height: 16),
                      _buildSection(l10n.profileSectionAccount, [
                        _buildMenuItem(
                          Icons.person_outline_rounded,
                          l10n.profileMenuPersonalInfo,
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
                          l10n.profileMenuCopyUserId,
                          onTap: () async {
                            await Clipboard.setData(ClipboardData(text: uid));
                            if (!profileContext.mounted) return;
                            ScaffoldMessenger.of(profileContext).showSnackBar(
                              SnackBar(content: Text(l10n.profileCopyUserIdSuccess)),
                            );
                          },
                        ),
                        _buildMenuItem(
                          Icons.lock_outline_rounded,
                          l10n.profileMenuSecurity,
                          onTap: () => _showSimpleDialog(
                            title: l10n.profileSecurityTitle,
                            message: l10n.profileSecurityMessage,
                          ),
                        ),
                      ]),
                      const SizedBox(height: 16),
                      _buildSection(l10n.profileSectionCustomization, [
                        _buildToggleItem(
                          Icons.dark_mode_outlined,
                          l10n.profileMenuDarkMode,
                          _darkMode,
                          (value) => _updateSetting('darkMode', value),
                        ),
                        _buildMenuItem(
                          Icons.language_rounded,
                          l10n.profileMenuLanguage,
                          trailing: _currentLanguageLabel(),
                          onTap: _showLanguageDialog,
                        ),
                        _buildToggleItem(
                          Icons.notifications_outlined,
                          l10n.profileMenuNotifications,
                          _notifications,
                          (value) => _updateSetting('notifications', value),
                        ),
                      ]),
                      const SizedBox(height: 16),
                      _buildSection(
                        _txt(
                          context,
                          vi: 'Lịch sử cuộc gọi',
                          en: 'Call history',
                        ),
                        [
                          _buildCallHistoryList(
                            currentUserId: uid,
                            currentUserName: name,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildSection(l10n.profileSectionSupport, [
                        _buildMenuItem(
                          Icons.notifications_active_outlined,
                          _txt(
                            context,
                            vi: 'Trung tâm thông báo',
                            en: 'Notification Center',
                          ),
                          onTap: () {
                            Navigator.push(
                              profileContext,
                              MaterialPageRoute(
                                builder: (_) => const NotificationCenterScreen(),
                              ),
                            );
                          },
                        ),
                        _buildMenuItem(
                          Icons.help_outline_rounded,
                          l10n.profileMenuHelpCenter,
                          onTap: () => _showSimpleDialog(
                            title: l10n.profileHelpTitle,
                            message: l10n.profileHelpMessage,
                          ),
                        ),
                        _buildMenuItem(
                          Icons.bug_report_outlined,
                          l10n.profileMenuReportBug,
                          onTap: () => _showSimpleDialog(
                            title: l10n.profileReportBugTitle,
                            message: l10n.profileReportBugMessage,
                          ),
                        ),
                        _buildMenuItem(
                          Icons.info_outline_rounded,
                          l10n.profileMenuAbout,
                          onTap: () => _showSimpleDialog(
                            title: l10n.profileAboutTitle,
                            message: l10n.profileAboutMessage,
                          ),
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
                            ScaffoldMessenger.of(profileContext).showSnackBar(
                              SnackBar(content: Text(l10n.profileLogoutError(e.toString()))),
                            );
                          }
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.logout_rounded, color: AppColors.error, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              l10n.profileLogout,
                              style: const TextStyle(
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
                      Text(
                        l10n.profileVersion('1.0.0'),
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 12, fontFamily: 'Inter'),
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

  Widget _buildCallHistoryList({
    required String currentUserId,
    required String currentUserName,
  }) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _callService.watchCallHistory(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Text(
              _txt(
                context,
                vi: 'Không tải được lịch sử cuộc gọi',
                en: 'Unable to load call history',
              ),
              style: const TextStyle(
                color: AppColors.textMuted,
                fontFamily: 'Inter',
                fontSize: 13,
              ),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: AppColors.primary,
                ),
              ),
            ),
          );
        }

        final calls = snapshot.data!.docs
            .map(AppCall.fromDocument)
            .where((call) => call.status != CallStatus.ringing)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        if (calls.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Text(
              _txt(
                context,
                vi: 'Chưa có cuộc gọi nào',
                en: 'No calls yet',
              ),
              style: const TextStyle(
                color: AppColors.textMuted,
                fontFamily: 'Inter',
                fontSize: 13,
              ),
            ),
          );
        }

        return Column(
          children: calls.take(8).map((call) {
            return _buildCallHistoryTile(
              call: call,
              currentUserId: currentUserId,
              currentUserName: currentUserName,
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildCallHistoryTile({
    required AppCall call,
    required String currentUserId,
    required String currentUserName,
  }) {
    final isIncoming = call.isIncomingFor(currentUserId);
    final peerName = call.peerNameFor(currentUserId).trim().isEmpty
        ? currentUserName
        : call.peerNameFor(currentUserId);
    final icon = call.type == CallType.video
        ? (isIncoming ? Icons.video_call_rounded : Icons.videocam_outlined)
        : (isIncoming ? Icons.call_received_rounded : Icons.call_made_rounded);
    final isFailed = call.status == CallStatus.missed ||
        call.status == CallStatus.declined ||
        call.status == CallStatus.cancelled;
    final iconColor = isFailed ? AppColors.error : AppColors.primaryLight;
    final subtitle = '${_callHistoryStatus(call, isIncoming)} • ${_formatCallTime(call.createdAt)}';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      dense: true,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        peerName,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          fontFamily: 'Inter',
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 12,
          fontFamily: 'Inter',
        ),
      ),
    );
  }

  String _callHistoryStatus(AppCall call, bool isIncoming) {
    switch (call.status) {
      case CallStatus.missed:
        return isIncoming
            ? _txt(context, vi: 'Cuộc gọi nhỡ', en: 'Missed call')
            : _txt(context, vi: 'Không trả lời', en: 'No answer');
      case CallStatus.declined:
        return isIncoming
            ? _txt(context, vi: 'Bạn đã từ chối', en: 'You declined')
            : _txt(context, vi: 'Đã bị từ chối', en: 'Declined');
      case CallStatus.cancelled:
        return isIncoming
            ? _txt(context, vi: 'Đã bị hủy', en: 'Canceled')
            : _txt(context, vi: 'Bạn đã hủy', en: 'You canceled');
      case CallStatus.accepted:
      case CallStatus.ended:
        return isIncoming
            ? _txt(context, vi: 'Cuộc gọi đến', en: 'Incoming')
            : _txt(context, vi: 'Cuộc gọi đi', en: 'Outgoing');
      case CallStatus.ringing:
        return _txt(context, vi: 'Đang đổ chuông', en: 'Ringing');
      case CallStatus.unknown:
        return _txt(context, vi: 'Không xác định', en: 'Unknown');
    }
  }

  String _formatCallTime(DateTime dateTime) {
    final dd = dateTime.day.toString().padLeft(2, '0');
    final mm = dateTime.month.toString().padLeft(2, '0');
    final hh = dateTime.hour.toString().padLeft(2, '0');
    final min = dateTime.minute.toString().padLeft(2, '0');
    return '$dd/$mm $hh:$min';
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

