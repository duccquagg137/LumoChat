import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import 'chat_screen.dart';

class UserProfileScreen extends StatelessWidget {
  final String userId;

  const UserProfileScreen({
    super.key,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
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
                  colors: [AppColors.primary.withAlphaFraction(0.15), Colors.transparent],
                ),
              ),
            ),
          ),
          SafeArea(
            child: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('users').doc(userId).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('KhÃ´ng táº£i Ä‘Æ°á»£c há»“ sÆ¡', style: TextStyle(color: AppColors.textMuted)));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                }
                final data = snapshot.data?.data() as Map<String, dynamic>?;
                if (data == null) {
                  return const Center(child: Text('KhÃ´ng tÃ¬m tháº¥y ngÆ°á»i dÃ¹ng', style: TextStyle(color: AppColors.textMuted)));
                }

                final name = (data['name'] ?? 'NgÆ°á»i dÃ¹ng').toString();
                final email = (data['email'] ?? '').toString();
                final bio = (data['bio'] ?? '').toString();
                final avatar = (data['avatar'] ?? '').toString();
                final isOnline = data['isOnline'] == true;
                final phone = (data['phoneNumber'] ?? '').toString().trim();
                final address = (data['address'] ?? '').toString().trim();
                final city = (data['city'] ?? '').toString().trim();
                final gender = (data['gender'] ?? '').toString().trim();
                final website = (data['website'] ?? '').toString().trim();
                final occupation = (data['occupation'] ?? '').toString().trim();
                final dobRaw = (data['dateOfBirth'] ?? '').toString().trim();
                final dob = DateTime.tryParse(dobRaw);
                final birthday = dob == null
                    ? (dobRaw.isEmpty ? 'ChÆ°a cáº­p nháº­t' : dobRaw)
                    : '${dob.day.toString().padLeft(2, '0')}/${dob.month.toString().padLeft(2, '0')}/${dob.year}';

                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.arrow_back_ios_rounded, color: AppColors.textPrimary, size: 20),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'Há»“ sÆ¡',
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
                              style: const TextStyle(
                                color: AppColors.primaryLight,
                                fontSize: 14,
                                fontFamily: 'Inter',
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              bio.isNotEmpty ? bio : 'Äang sá»­ dá»¥ng LumoChat',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 14,
                                fontFamily: 'Inter',
                              ),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Expanded(
                                  child: GradientButton(
                                    text: 'Nháº¯n tin',
                                    icon: Icons.chat_bubble_rounded,
                                    height: 44,
                                    onPressed: currentUserId == userId
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
                        child: Column(
                          children: [
                            _buildInfoRow(Icons.phone_outlined, 'Sá»‘ Ä‘iá»‡n thoáº¡i', phone.isEmpty ? 'ChÆ°a cáº­p nháº­t' : phone),
                            _buildInfoRow(Icons.location_on_outlined, 'Äá»‹a chá»‰', address.isEmpty ? 'ChÆ°a cáº­p nháº­t' : address),
                            _buildInfoRow(Icons.location_city_outlined, 'ThÃ nh phá»‘', city.isEmpty ? 'ChÆ°a cáº­p nháº­t' : city),
                            _buildInfoRow(Icons.wc_outlined, 'Giá»›i tÃ­nh', gender.isEmpty ? 'ChÆ°a cáº­p nháº­t' : gender),
                            _buildInfoRow(Icons.cake_outlined, 'NgÃ y sinh', birthday),
                            _buildInfoRow(Icons.work_outline_rounded, 'Nghá» nghiá»‡p', occupation.isEmpty ? 'ChÆ°a cáº­p nháº­t' : occupation),
                            _buildInfoRow(Icons.language_rounded, 'Website', website.isEmpty ? 'ChÆ°a cáº­p nháº­t' : website),
                          ],
                        ),
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
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          fontFamily: 'Inter',
        ),
      ),
      subtitle: Text(
        value,
        style: const TextStyle(
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
