import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../models/chat_models.dart';
import 'chat_screen.dart';

class ContactsScreen extends StatelessWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text('Lỗi'));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data == null) return const Center(child: CircularProgressIndicator());

          final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
          final users = snapshot.data!.docs
              .map((doc) => ChatUser.fromDocument(doc))
              .where((u) => u.id != currentUserId)
              .toList();

          final onlineUsers = users.where((u) => u.isOnline).toList();
          
          // Group by first letter
          final Map<String, List<ChatUser>> grouped = {};
          for (var u in users) {
             if (u.name.isEmpty) continue;
            final letter = u.name[0].toUpperCase();
            grouped.putIfAbsent(letter, () => []);
            grouped[letter]!.add(u);
          }
          final sortedKeys = grouped.keys.toList()..sort();

          return Stack(
        children: [
          Positioned(
            top: -80, right: -50,
            child: Container(
              width: 200, height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [AppColors.primary.withOpacity(0.12), Colors.transparent],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Row(
                    children: [
                      const Text(
                        'Danh bạ',
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
                        child: const Icon(Icons.search_rounded, color: AppColors.textPrimary, size: 20),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.glassBg, shape: BoxShape.circle,
                          border: Border.all(color: AppColors.glassBorder, width: 0.5),
                        ),
                        child: const Icon(Icons.person_add_alt_1_rounded, color: AppColors.textPrimary, size: 20),
                      ),
                    ],
                  ),
                ),
                // Search
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: GlassCard(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    borderRadius: 16,
                    child: Row(
                      children: [
                        Icon(Icons.search_rounded, color: AppColors.textMuted, size: 20),
                        SizedBox(width: 12),
                        Text('Tìm bạn bè...', style: TextStyle(color: AppColors.textMuted, fontSize: 14, fontFamily: 'Inter')),
                      ],
                    ),
                  ),
                ),
                // Quick actions
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      _buildQuickAction(Icons.mail_outline_rounded, 'Lời mời', badge: 3),
                      const SizedBox(width: 12),
                      _buildQuickAction(Icons.qr_code_scanner_rounded, 'Quét QR'),
                      const SizedBox(width: 12),
                      _buildQuickAction(Icons.share_rounded, 'Mời bạn bè'),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Online section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Text(
                        'Đang hoạt động (${onlineUsers.length})',
                        style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 14,
                          fontWeight: FontWeight.w600, fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 80,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: onlineUsers.length,
                    itemBuilder: (_, i) {
                      final user = onlineUsers[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AvatarWidget(name: user.name, size: 48, isOnline: true),
                            const SizedBox(height: 6),
                            SizedBox(
                              width: 56,
                              child: Text(
                                user.name.split(' ').last,
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontFamily: 'Inter'),
                                textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                // Contacts list
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: sortedKeys.length,
                    itemBuilder: (_, i) {
                      final letter = sortedKeys[i];
                      final users = grouped[letter]!;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 16, 0, 8),
                            child: Text(
                              letter,
                              style: const TextStyle(
                                color: AppColors.primaryLight, fontSize: 14,
                                fontWeight: FontWeight.w700, fontFamily: 'Inter',
                              ),
                            ),
                          ),
                          ...users.map((user) => Container(
                            margin: const EdgeInsets.only(bottom: 2),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            child: Row(
                              children: [
                                AvatarWidget(name: user.name, size: 44, isOnline: user.isOnline),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        user.name,
                                        style: const TextStyle(
                                          color: AppColors.textPrimary, fontSize: 14,
                                          fontWeight: FontWeight.w600, fontFamily: 'Inter',
                                        ),
                                      ),
                                      if (user.bio != null) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          user.bio!,
                                          style: const TextStyle(color: AppColors.textMuted, fontSize: 12, fontFamily: 'Inter'),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.push(context, MaterialPageRoute(
                                        builder: (_) => ChatScreen(
                                          userName: user.name,
                                          receiverId: user.id,
                                          isOnline: user.isOnline,
                                        ),
                                      ));
                                    },
                                    child: _buildContactAction(Icons.chat_bubble_outline_rounded),
                                  ),
                                  const SizedBox(width: 8),
                                  _buildContactAction(Icons.call_outlined),
                                ],
                              ),
                            )),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    },
  ),
);
  }

  Widget _buildQuickAction(IconData icon, String label, {int badge = 0}) {
    return Expanded(
      child: GlassCard(
        padding: const EdgeInsets.symmetric(vertical: 14),
        borderRadius: 16,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: AppColors.primaryLight, size: 22),
                const SizedBox(height: 6),
                Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontFamily: 'Inter')),
              ],
            ),
            if (badge > 0)
              Positioned(
                top: 0, right: 16,
                child: UnreadBadge(count: badge, size: 18),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactAction(IconData icon) {
    return Container(
      width: 34, height: 34,
      decoration: BoxDecoration(
        color: AppColors.glassBg, shape: BoxShape.circle,
        border: Border.all(color: AppColors.glassBorder, width: 0.5),
      ),
      child: Icon(icon, color: AppColors.textSecondary, size: 18),
    );
  }
}
