import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../models/chat_models.dart';
import '../services/group_service.dart';
import 'chat_screen.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final Set<String> _selectedIds = {};

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned(
            top: -80, right: -50,
            child: Container(
              width: 200, height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [AppColors.primary.withOpacity(0.15), Colors.transparent],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // App bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_rounded, color: AppColors.textPrimary, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Expanded(
                        child: Text(
                          'Tạo nhóm mới',
                          style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary, fontFamily: 'Inter',
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: _selectedIds.isNotEmpty ? AppGradients.primary : null,
                          color: _selectedIds.isEmpty ? AppColors.textMuted.withOpacity(0.3) : null,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Tạo',
                          style: TextStyle(
                            color: _selectedIds.isNotEmpty ? Colors.white : AppColors.textMuted,
                            fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'Inter',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('users').snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const Center(child: Text('Đã xảy ra lỗi', style: TextStyle(color: AppColors.textMuted)));
                      }
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                      }

                      final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
                      final allUsers = snapshot.data!.docs
                          .map((doc) => ChatUser.fromDocument(doc))
                          .where((u) => u.id != currentUserId)
                          .toList();

                      return SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 8),
                            // Group info card
                            GlassCard(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                children: [
                                  // Avatar picker
                                  Container(
                                    width: 80, height: 80,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppColors.primary.withOpacity(0.15),
                                      border: Border.all(color: AppColors.glassBorder, width: 1.5),
                                    ),
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        const Icon(Icons.group_rounded, color: AppColors.primaryLight, size: 36),
                                        Positioned(
                                          right: 0, bottom: 0,
                                          child: Container(
                                            width: 28, height: 28,
                                            decoration: BoxDecoration(
                                              gradient: AppGradients.primary,
                                              shape: BoxShape.circle,
                                              border: Border.all(color: AppColors.bgDark, width: 2),
                                            ),
                                            child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 14),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  // Group name
                                  _buildInput(
                                    controller: _nameController,
                                    hint: 'Tên nhóm',
                                    icon: Icons.edit_rounded,
                                  ),
                                  const SizedBox(height: 12),
                                  // Description
                                  _buildInput(
                                    controller: _descController,
                                    hint: 'Mô tả nhóm (tùy chọn)',
                                    icon: Icons.description_outlined,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            // Selected members chips
                            if (_selectedIds.isNotEmpty) ...[
                              Text(
                                'Đã chọn (${_selectedIds.length})',
                                style: const TextStyle(
                                  color: AppColors.textSecondary, fontSize: 14,
                                  fontWeight: FontWeight.w600, fontFamily: 'Inter',
                                ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _selectedIds.map((id) {
                                  final user = allUsers.firstWhere(
                                    (u) => u.id == id,
                                    orElse: () => const ChatUser(id: '', name: 'Không tìm thấy'),
                                  );
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        AvatarWidget(name: user.name, size: 24, showStatus: false),
                                        const SizedBox(width: 8),
                                        Text(
                                          user.name.split(' ').last,
                                          style: const TextStyle(
                                            color: AppColors.textPrimary, fontSize: 13,
                                            fontWeight: FontWeight.w500, fontFamily: 'Inter',
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        GestureDetector(
                                          onTap: () => setState(() => _selectedIds.remove(id)),
                                          child: const Icon(Icons.close_rounded, color: AppColors.textMuted, size: 16),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 20),
                            ],
                            // Search
                            const GlassCard(
                              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              borderRadius: 16,
                              child: Row(
                                children: [
                                  Icon(Icons.search_rounded, color: AppColors.textMuted, size: 20),
                                  SizedBox(width: 12),
                                  Text(
                                    'Tìm bạn bè để thêm...',
                                    style: TextStyle(color: AppColors.textMuted, fontSize: 14, fontFamily: 'Inter'),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Contact list from Firestore
                            ...allUsers.map((user) {
                              final isSelected = _selectedIds.contains(user.id);
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    if (isSelected) {
                                      _selectedIds.remove(user.id);
                                    } else {
                                      _selectedIds.add(user.id);
                                    }
                                  });
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 4),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    color: isSelected ? AppColors.primary.withOpacity(0.08) : Colors.transparent,
                                  ),
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
                                            if (user.bio != null)
                                              Text(
                                                user.bio!,
                                                style: const TextStyle(
                                                  color: AppColors.textMuted, fontSize: 12, fontFamily: 'Inter',
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        width: 24, height: 24,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: isSelected ? AppGradients.primary : null,
                                          border: isSelected ? null : Border.all(color: AppColors.textMuted, width: 1.5),
                                        ),
                                        child: isSelected
                                            ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                                            : null,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                            const SizedBox(height: 100),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          // Bottom button
          if (_selectedIds.isNotEmpty)
            Positioned(
              left: 20, right: 20,
              bottom: MediaQuery.of(context).padding.bottom + 20,
              child: GradientButton(
                text: 'Tạo nhóm với ${_selectedIds.length} thành viên',
                icon: Icons.group_add_rounded,
                width: double.infinity,
                onPressed: () async {
                  final name = _nameController.text.trim();
                  if (name.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng nhập tên nhóm')));
                    return;
                  }
                  final desc = _descController.text.trim();
                  
                  final currentUser = FirebaseAuth.instance.currentUser;
                  final creatorName = currentUser?.displayName ?? currentUser?.phoneNumber ?? 'Người dùng';
                  
                  try {
                    // Show loading optionally, for now just await
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đang tạo nhóm...')));
                    
                    final groupService = GroupService();
                    final groupId = await groupService.createGroup(name, desc, _selectedIds.toList(), creatorName);
                    
                    if (context.mounted) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            userName: name,
                            receiverId: groupId,
                            isGroup: true,
                            memberCount: _selectedIds.length + 1,
                          ),
                        ),
                      );
                    }
                  } catch (e) {
                     if (context.mounted) {
                       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
                     }
                  }
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInput({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: AppColors.textPrimary, fontFamily: 'Inter'),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: AppColors.textMuted, size: 22),
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.textMuted),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}
