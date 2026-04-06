import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../models/chat_models.dart';

class GroupInfoScreen extends StatelessWidget {
  final String groupName;
  final int memberCount;
  final List<String> memberIds;

  const GroupInfoScreen({
    super.key,
    required this.groupName,
    required this.memberCount,
    this.memberIds = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned(
            top: -80, left: -50,
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
            child: CustomScrollView(
              slivers: [
                // App bar
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_rounded, color: AppColors.textPrimary, size: 20),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Text(
                          'Thông tin nhóm',
                          style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary, fontFamily: 'Inter',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        // Group header card
                        GlassCard(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              Container(
                                width: 80, height: 80,
                                decoration: BoxDecoration(
                                  gradient: AppGradients.primary,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary.withOpacity(0.3),
                                      blurRadius: 20,
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.group_rounded, color: Colors.white, size: 40),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                groupName,
                                style: const TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary, fontFamily: 'Inter',
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '$memberCount thành viên',
                                style: const TextStyle(
                                  color: AppColors.textSecondary, fontSize: 13, fontFamily: 'Inter',
                                ),
                              ),
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  Expanded(
                                    child: GradientButton(
                                      text: 'Thêm',
                                      icon: Icons.person_add_rounded,
                                      height: 42,
                                      onPressed: () {},
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: OutlinedPillButton(
                                      text: 'Tắt TB',
                                      icon: Icons.notifications_off_outlined,
                                      onPressed: () {},
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Media section
                        GlassCard(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              const Row(
                                children: [
                                  Text(
                                    'Ảnh/Video',
                                    style: TextStyle(
                                      color: AppColors.textPrimary, fontSize: 15,
                                      fontWeight: FontWeight.w700, fontFamily: 'Inter',
                                    ),
                                  ),
                                  Spacer(),
                                  Text(
                                    'Xem tất cả',
                                    style: TextStyle(
                                      color: AppColors.primaryLight, fontSize: 13, fontFamily: 'Inter',
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                height: 80,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: 6,
                                  itemBuilder: (_, i) {
                                    return Container(
                                      width: 80, height: 80,
                                      margin: const EdgeInsets.only(right: 8),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        gradient: LinearGradient(
                                          colors: [
                                            AppColors.primary.withOpacity(0.2 + i * 0.05),
                                            AppColors.primaryDark.withOpacity(0.3),
                                          ],
                                        ),
                                        border: Border.all(color: AppColors.glassBorder, width: 0.5),
                                      ),
                                      child: const Icon(Icons.photo_rounded, color: AppColors.textMuted, size: 24),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Members - loaded from Firestore
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Thành viên ($memberCount)',
                            style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 14,
                              fontWeight: FontWeight.w600, fontFamily: 'Inter',
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildMembersList(),
                        const SizedBox(height: 20),
                        // Actions
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Tùy chọn',
                            style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 14,
                              fontWeight: FontWeight.w600, fontFamily: 'Inter',
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        GlassCard(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Column(
                            children: [
                              _buildActionItem(Icons.push_pin_outlined, 'Ghim cuộc trò chuyện'),
                              _buildActionItem(Icons.search_rounded, 'Tìm kiếm trong nhóm'),
                              _buildActionItem(Icons.folder_outlined, 'File đã chia sẻ'),
                              _buildActionItem(Icons.report_outlined, 'Báo cáo nhóm'),
                              _buildActionItem(Icons.logout_rounded, 'Rời nhóm', isDestructive: true),
                            ],
                          ),
                        ),
                        const SizedBox(height: 40),
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

  Widget _buildMembersList() {
    if (memberIds.isEmpty) {
      // Fallback: load all users from Firestore
      return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').limit(memberCount).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }
          final members = snapshot.data!.docs.map((doc) => ChatUser.fromDocument(doc)).toList();
          return _buildMembersCard(members);
        },
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where(FieldPath.documentId, whereIn: memberIds.take(10).toList())
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        }
        final members = snapshot.data!.docs.map((doc) => ChatUser.fromDocument(doc)).toList();
        return _buildMembersCard(members);
      },
    );
  }

  Widget _buildMembersCard(List<ChatUser> members) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          // Add member
          ListTile(
            leading: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_add_rounded, color: AppColors.primaryLight, size: 20),
            ),
            title: const Text(
              'Thêm thành viên',
              style: TextStyle(
                color: AppColors.primaryLight, fontSize: 14,
                fontWeight: FontWeight.w600, fontFamily: 'Inter',
              ),
            ),
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          ),
          ...members.asMap().entries.map((entry) {
            final i = entry.key;
            final user = entry.value;
            return ListTile(
              leading: AvatarWidget(name: user.name, size: 40, isOnline: user.isOnline),
              title: Row(
                children: [
                  Text(
                    user.name,
                    style: const TextStyle(
                      color: AppColors.textPrimary, fontSize: 14,
                      fontWeight: FontWeight.w500, fontFamily: 'Inter',
                    ),
                  ),
                  if (i == 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Admin',
                        style: TextStyle(
                          color: AppColors.primaryLight, fontSize: 10,
                          fontWeight: FontWeight.w600, fontFamily: 'Inter',
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              subtitle: Text(
                user.isOnline ? 'Online' : 'Offline',
                style: TextStyle(
                  color: user.isOnline ? AppColors.accentGreen : AppColors.textMuted,
                  fontSize: 12, fontFamily: 'Inter',
                ),
              ),
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildActionItem(IconData icon, String title, {bool isDestructive = false}) {
    return ListTile(
      leading: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: isDestructive
              ? AppColors.error.withOpacity(0.1)
              : AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: isDestructive ? AppColors.error : AppColors.primaryLight,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isDestructive ? AppColors.error : AppColors.textPrimary,
          fontSize: 14, fontWeight: FontWeight.w500, fontFamily: 'Inter',
        ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: isDestructive ? AppColors.error.withOpacity(0.5) : AppColors.textMuted,
        size: 20,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      dense: true,
    );
  }
}
