import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/app_providers.dart';
import '../theme/app_theme.dart';
import '../utils/l10n.dart';
import '../utils/profile_visibility.dart';
import '../widgets/glass_card.dart';
import 'chat_screen.dart';

final _userProfileDocumentProvider = StreamProvider.autoDispose
    .family<DocumentSnapshot<Map<String, dynamic>>, String>((ref, userId) {
  return FirebaseFirestore.instance.collection('users').doc(userId).snapshots();
});

class UserProfileScreen extends ConsumerWidget {
  final String userId;

  const UserProfileScreen({
    super.key,
    required this.userId,
  });

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

  bool _isVisible(
    Map<String, dynamic> data,
    String field, {
    required bool isOwner,
  }) {
    return ProfileVisibility.isVisible(data, field, isOwner: isOwner);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserId = ref.watch(currentUserIdProvider);
    final l10n = context.l10n;
    final profile = ref.watch(_userProfileDocumentProvider(userId));

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
                  colors: [
                    AppColors.primary.withAlphaFraction(0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: profile.when(
              error: (_, __) {
                return Center(
                  child: Text(
                    l10n.profileLoadError,
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                );
              },
              loading: () {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                );
              },
              data: (snapshot) {
                final data = snapshot.data();
                if (data == null) {
                  return Center(
                    child: Text(
                      l10n.profileLoadError,
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  );
                }

                final isOwner = currentUserId == userId;
                final name = _displayOrFallback(
                  data['name'],
                  fallback: l10n.profileFallbackUser,
                );
                final avatar = (data['avatar'] ?? '').toString();
                final isOnline = data['isOnline'] == true;
                final email = _displayOrFallback(
                  data['email'],
                  fallback: l10n.profileNotUpdated,
                );
                final bio = _displayOrFallback(
                  data['bio'],
                  fallback: l10n.profileFallbackBio,
                );
                final phone = _displayOrFallback(
                  data['phoneNumber'],
                  fallback: l10n.profileNotUpdated,
                );
                final address = _displayOrFallback(
                  data['address'],
                  fallback: l10n.profileNotUpdated,
                );
                final city = _displayOrFallback(
                  data['city'],
                  fallback: l10n.profileNotUpdated,
                );
                final gender = _displayOrFallback(
                  data['gender'],
                  fallback: l10n.profileNotUpdated,
                );
                final birthday = _formatDateField(
                  data['dateOfBirth'],
                  fallback: l10n.profileNotUpdated,
                );
                final occupation = _displayOrFallback(
                  data['occupation'],
                  fallback: l10n.profileNotUpdated,
                );
                final website = _displayOrFallback(
                  data['website'],
                  fallback: l10n.profileNotUpdated,
                );

                final canShowEmail = _isVisible(
                  data,
                  ProfileVisibility.email,
                  isOwner: isOwner,
                );
                final canShowBio = _isVisible(
                  data,
                  ProfileVisibility.bio,
                  isOwner: isOwner,
                );
                final infoRows = <Widget>[
                  if (_isVisible(
                    data,
                    ProfileVisibility.phoneNumber,
                    isOwner: isOwner,
                  ))
                    _buildInfoRow(
                      Icons.phone_outlined,
                      l10n.profileFieldPhone,
                      phone,
                    ),
                  if (_isVisible(
                    data,
                    ProfileVisibility.address,
                    isOwner: isOwner,
                  ))
                    _buildInfoRow(
                      Icons.location_on_outlined,
                      l10n.profileFieldAddress,
                      address,
                    ),
                  if (_isVisible(
                    data,
                    ProfileVisibility.city,
                    isOwner: isOwner,
                  ))
                    _buildInfoRow(
                      Icons.location_city_outlined,
                      l10n.profileFieldCity,
                      city,
                    ),
                  if (_isVisible(
                    data,
                    ProfileVisibility.gender,
                    isOwner: isOwner,
                  ))
                    _buildInfoRow(
                      Icons.wc_outlined,
                      l10n.profileFieldGender,
                      gender,
                    ),
                  if (_isVisible(
                    data,
                    ProfileVisibility.dateOfBirth,
                    isOwner: isOwner,
                  ))
                    _buildInfoRow(
                      Icons.cake_outlined,
                      l10n.profileFieldBirthDate,
                      birthday,
                    ),
                  if (_isVisible(
                    data,
                    ProfileVisibility.occupation,
                    isOwner: isOwner,
                  ))
                    _buildInfoRow(
                      Icons.work_outline_rounded,
                      l10n.profileFieldOccupation,
                      occupation,
                    ),
                  if (_isVisible(
                    data,
                    ProfileVisibility.website,
                    isOwner: isOwner,
                  ))
                    _buildInfoRow(
                      Icons.language_rounded,
                      l10n.profileFieldWebsite,
                      website,
                    ),
                ];

                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: Icon(
                              Icons.arrow_back_ios_rounded,
                              color: AppColors.textPrimary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            l10n.navProfile,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      GlassCard(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            AvatarWidget(
                              name: name,
                              imageUrl: avatar,
                              size: 92,
                              isOnline: isOnline,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              name,
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'Inter',
                              ),
                            ),
                            if (canShowEmail) ...[
                              const SizedBox(height: 4),
                              Text(
                                email,
                                style: TextStyle(
                                  color: AppColors.primaryLight,
                                  fontSize: 14,
                                  fontFamily: 'Inter',
                                ),
                              ),
                            ],
                            if (canShowBio) ...[
                              const SizedBox(height: 10),
                              Text(
                                bio,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 14,
                                  fontFamily: 'Inter',
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Expanded(
                                  child: GradientButton(
                                    text: _txt(
                                      context,
                                      vi: 'Nhan tin',
                                      en: 'Message',
                                    ),
                                    icon: Icons.chat_bubble_rounded,
                                    height: 44,
                                    onPressed: isOwner
                                        ? null
                                        : () {
                                            Navigator.pushReplacement(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => ChatScreen(
                                                  userName: name,
                                                  receiverId: userId,
                                                  isOnline: isOnline,
                                                  userAvatar: avatar,
                                                ),
                                              ),
                                            );
                                          },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      GlassCard(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: infoRows.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                child: Text(
                                  _txt(
                                    context,
                                    vi: 'Nguoi dung da an thong tin ca nhan.',
                                    en: 'This user has hidden their profile details.',
                                  ),
                                  style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontFamily: 'Inter',
                                    fontSize: 13,
                                  ),
                                ),
                              )
                            : Column(children: infoRows),
                      ),
                      const SizedBox(height: 24),
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

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return ListTile(
      leading: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: AppColors.primary.withAlphaFraction(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.primaryLight, size: 18),
      ),
      title: Text(
        label,
        style: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          fontFamily: 'Inter',
        ),
      ),
      subtitle: Text(
        value,
        style: TextStyle(
          color: AppColors.textMuted,
          fontSize: 12,
          fontFamily: 'Inter',
        ),
      ),
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    );
  }
}
