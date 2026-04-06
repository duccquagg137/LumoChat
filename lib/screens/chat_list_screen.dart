import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../models/chat_models.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Subtle glow
          Positioned(
            top: -100,
            right: -50,
            child: Container(
              width: 200,
              height: 200,
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
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Row(
                    children: [
                      const Text(
                        'Chats',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          fontFamily: 'Inter',
                        ),
                      ),
                      const Spacer(),
                      _buildHeaderIcon(Icons.search_rounded),
                      const SizedBox(width: 8),
                      _buildHeaderIcon(Icons.edit_note_rounded),
                      const SizedBox(width: 8),
                      const AvatarWidget(name: 'An', size: 36, isOnline: true),
                    ],
                  ),
                ),
                // Search bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.bgCard.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.glassBorder),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                      style: const TextStyle(color: AppColors.textPrimary, fontFamily: 'Inter'),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search_rounded, color: AppColors.textMuted, size: 20),
                        hintText: 'Tìm kiếm cuộc trò chuyện...',
                        hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 14, fontFamily: 'Inter'),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
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

                      if (!snapshot.hasData || snapshot.data == null) {
                         return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                      }

                      final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
                      
                      // Filter out current user from the list and apply search
                      final usersList = snapshot.data!.docs
                          .map((doc) => ChatUser.fromDocument(doc))
                          .where((user) => user.id != currentUserId && user.name.toLowerCase().contains(_searchQuery))
                          .toList();

                      if (usersList.isEmpty) {
                         return Center(
                           child: Text(_searchQuery.isEmpty ? 'Chưa có ai ở đây cả' : 'Không tìm thấy kết quả', style: const TextStyle(color: AppColors.textMuted)),
                         );
                      }

                      return Column(

                        children: [
                          // Stories row
                          SizedBox(
                            height: 100,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              children: [
                                _buildStoryItem('Tin của bạn', true, true),
                                ...usersList.take(7).map(
                                  (u) => _buildStoryItem(u.name.split(' ').last, false, u.isOnline),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Conversations list
                          Expanded(
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: usersList.length,
                              itemBuilder: (context, i) {
                                final user = usersList[i];
                                
                                List<String> ids = [currentUserId, user.id];
                                ids.sort();
                                String chatRoomId = ids.join("_");

                                return StreamBuilder<DocumentSnapshot>(
                                  stream: FirebaseFirestore.instance.collection('chat_rooms').doc(chatRoomId).snapshots(),
                                  builder: (context, roomSnapshot) {
                                    String lastText = 'Chạm để bắt đầu trò chuyện';
                                    String timeTxt = '';
                                    
                                    if (roomSnapshot.hasData && roomSnapshot.data!.exists) {
                                      final data = roomSnapshot.data!.data() as Map<String, dynamic>;
                                      lastText = data['lastMessage'] ?? lastText;
                                      if (data['lastTimestamp'] != null) {
                                        final ts = data['lastTimestamp'] as Timestamp;
                                        final date = ts.toDate();
                                        timeTxt = '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
                                      }
                                    }

                                    final conv = Conversation(
                                      id: user.id,
                                      user: user,
                                      lastMessage: lastText,
                                      time: timeTxt,
                                    );
                                    return _buildConversationItem(context, conv);
                                  }
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderIcon(IconData icon) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: AppColors.glassBg,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.glassBorder, width: 0.5),
      ),
      child: Icon(icon, color: AppColors.textPrimary, size: 20),
    );
  }

  Widget _buildStoryItem(String name, bool isAdd, bool isOnline) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 62,
            height: 62,
            padding: const EdgeInsets.all(2.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: isAdd
                  ? null
                  : isOnline
                      ? AppGradients.primary
                      : null,
              border: isAdd || !isOnline
                  ? Border.all(color: AppColors.textMuted.withOpacity(0.3), width: 2)
                  : null,
            ),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.bgCard,
                border: Border.all(color: AppColors.bgDark, width: 2),
              ),
              child: isAdd
                  ? const Icon(Icons.add_rounded, color: AppColors.primary, size: 24)
                  : Center(
                      child: Text(
                        name[0],
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 64,
            child: Text(
              name,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontFamily: 'Inter',
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationItem(BuildContext context, Conversation conv) {
    final hasUnread = conv.unreadCount > 0;
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              userName: conv.user.name,
              receiverId: conv.user.id,
              isOnline: conv.user.isOnline,
              isGroup: conv.isGroup,
              memberCount: conv.memberCount,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: hasUnread ? AppColors.primary.withOpacity(0.06) : Colors.transparent,
        ),
        child: Row(
          children: [
            // Avatar
            Stack(
              children: [
                AvatarWidget(
                  name: conv.user.name,
                  size: 52,
                  isOnline: conv.user.isOnline,
                ),
                if (conv.isGroup)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: AppColors.bgDark,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.group_rounded, color: AppColors.primaryLight, size: 14),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (conv.isPinned)
                        const Padding(
                          padding: EdgeInsets.only(right: 4),
                          child: Icon(Icons.push_pin_rounded, size: 14, color: AppColors.primaryLight),
                        ),
                      Expanded(
                        child: Text(
                          conv.user.name,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w500,
                            fontFamily: 'Inter',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        conv.time,
                        style: TextStyle(
                          color: hasUnread ? AppColors.primaryLight : AppColors.textMuted,
                          fontSize: 12,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: conv.isTyping
                            ? const Text(
                                'đang nhập...',
                                style: TextStyle(
                                  color: AppColors.accentGreen,
                                  fontSize: 13,
                                  fontStyle: FontStyle.italic,
                                  fontFamily: 'Inter',
                                ),
                              )
                            : Text(
                                conv.lastMessage,
                                style: TextStyle(
                                  color: hasUnread ? AppColors.textSecondary : AppColors.textMuted,
                                  fontSize: 13,
                                  fontWeight: hasUnread ? FontWeight.w500 : FontWeight.w400,
                                  fontFamily: 'Inter',
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                      ),
                      if (hasUnread) ...[
                        const SizedBox(width: 8),
                        UnreadBadge(count: conv.unreadCount),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
