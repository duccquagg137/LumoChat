import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/chat_models.dart';
import '../services/friend_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import 'chat_screen.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final FriendService _friendService = FriendService();
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _busyUserIds = {};
  String _searchQuery = '';

  String get _currentUserId => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Set<String> _readIdSet(dynamic raw) {
    if (raw is! Iterable) return <String>{};
    return raw.map((e) => e.toString()).where((e) => e.isNotEmpty).toSet();
  }

  bool _matchSearch(ChatUser user) {
    if (_searchQuery.isEmpty) return true;
    return user.name.toLowerCase().contains(_searchQuery);
  }

  Future<void> _runAction(String userId, Future<void> Function() action, String successText) async {
    if (_busyUserIds.contains(userId)) return;
    setState(() => _busyUserIds.add(userId));
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(successText)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Thao tác thất bại: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _busyUserIds.remove(userId));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(_currentUserId).snapshots(),
        builder: (context, mySnapshot) {
          if (mySnapshot.hasError) {
            return const Center(child: Text('Lỗi tải hồ sơ', style: TextStyle(color: AppColors.textMuted)));
          }
          if (mySnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }

          final myData = mySnapshot.data?.data() as Map<String, dynamic>? ?? const {};
          final friendIds = _readIdSet(myData['friends']);
          final receivedRequestIds = _readIdSet(myData['friendRequestsReceived']);
          final sentRequestIds = _readIdSet(myData['friendRequestsSent']);

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('users').snapshots(),
            builder: (context, usersSnapshot) {
              if (usersSnapshot.hasError) {
                return const Center(child: Text('Lỗi tải danh bạ', style: TextStyle(color: AppColors.textMuted)));
              }
              if (usersSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: AppColors.primary));
              }
              if (!usersSnapshot.hasData) {
                return const SizedBox.shrink();
              }

              final allUsers = usersSnapshot.data!.docs
                  .map((doc) => ChatUser.fromDocument(doc))
                  .where((user) => user.id != _currentUserId)
                  .toList()
                ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

              final friends = allUsers.where((u) => friendIds.contains(u.id)).where(_matchSearch).toList();
              final receivedRequests = allUsers.where((u) => receivedRequestIds.contains(u.id)).where(_matchSearch).toList();
              final sentRequests = allUsers.where((u) => sentRequestIds.contains(u.id)).where(_matchSearch).toList();
              final suggestions = allUsers
                  .where((u) => !friendIds.contains(u.id))
                  .where((u) => !receivedRequestIds.contains(u.id))
                  .where((u) => !sentRequestIds.contains(u.id))
                  .where(_matchSearch)
                  .toList();

              final onlineFriends = friends.where((u) => u.isOnline).toList();
              final groupedFriends = <String, List<ChatUser>>{};
              for (final user in friends) {
                final letter = user.name.isNotEmpty ? user.name[0].toUpperCase() : '#';
                groupedFriends.putIfAbsent(letter, () => []).add(user);
              }
              final sortedLetters = groupedFriends.keys.toList()..sort();

              return Stack(
                children: [
                  Positioned(
                    top: -80,
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
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                          child: Row(
                            children: [
                              const Text(
                                'Danh bạ',
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
                                child: const Icon(Icons.people_alt_outlined, color: AppColors.textPrimary, size: 20),
                              ),
                            ],
                          ),
                        ),
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
                              onChanged: (value) => setState(() => _searchQuery = value.trim().toLowerCase()),
                              style: const TextStyle(color: AppColors.textPrimary, fontFamily: 'Inter'),
                              decoration: const InputDecoration(
                                prefixIcon: Icon(Icons.search_rounded, color: AppColors.textMuted, size: 20),
                                hintText: 'Tìm bạn bè...',
                                hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 14, fontFamily: 'Inter'),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          child: Row(
                            children: [
                              _buildQuickAction(Icons.mail_outline_rounded, 'Lời mời', badge: receivedRequests.length),
                              const SizedBox(width: 12),
                              _buildQuickAction(Icons.schedule_send_rounded, 'Đã gửi', badge: sentRequests.length),
                              const SizedBox(width: 12),
                              _buildQuickAction(Icons.people_outline_rounded, 'Bạn bè', badge: friends.length),
                            ],
                          ),
                        ),
                        if (onlineFriends.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Row(
                              children: [
                                Text(
                                  'Bạn bè đang trực tuyến (${onlineFriends.length})',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'Inter',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 82,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: onlineFriends.length,
                              itemBuilder: (_, index) {
                                final user = onlineFriends[index];
                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      AvatarWidget(name: user.name, imageUrl: user.avatar, size: 48, isOnline: true),
                                      const SizedBox(height: 6),
                                      SizedBox(
                                        width: 56,
                                        child: Text(
                                          user.name.split(' ').last,
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
                              },
                            ),
                          ),
                        ],
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            children: [
                              if (receivedRequests.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                _buildSectionTitle('Lời mời kết bạn'),
                                ...receivedRequests.map((user) {
                                  final isBusy = _busyUserIds.contains(user.id);
                                  return _buildUserItem(
                                    user: user,
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _buildMiniAction(
                                          icon: Icons.close_rounded,
                                          color: AppColors.textMuted,
                                          onTap: isBusy
                                              ? null
                                              : () => _runAction(
                                                    user.id,
                                                    () => _friendService.rejectFriendRequest(user.id),
                                                    'Đã từ chối lời mời',
                                                  ),
                                        ),
                                        const SizedBox(width: 8),
                                        _buildMiniAction(
                                          icon: Icons.check_rounded,
                                          color: AppColors.accentGreen,
                                          onTap: isBusy
                                              ? null
                                              : () => _runAction(
                                                    user.id,
                                                    () => _friendService.acceptFriendRequest(user.id),
                                                    'Đã chấp nhận kết bạn',
                                                  ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                              if (sentRequests.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                _buildSectionTitle('Đã gửi lời mời'),
                                ...sentRequests.map((user) {
                                  final isBusy = _busyUserIds.contains(user.id);
                                  return _buildUserItem(
                                    user: user,
                                    subtitle: 'Đang chờ phản hồi',
                                    trailing: _buildActionText(
                                      label: isBusy ? '...' : 'Hủy',
                                      onTap: isBusy
                                          ? null
                                          : () => _runAction(
                                                user.id,
                                                () => _friendService.cancelFriendRequest(user.id),
                                                'Đã hủy lời mời',
                                              ),
                                    ),
                                  );
                                }),
                              ],
                              if (friends.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                _buildSectionTitle('Bạn bè'),
                                ...sortedLetters.map((letter) {
                                  final usersInLetter = groupedFriends[letter] ?? [];
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(12, 14, 0, 8),
                                        child: Text(
                                          letter,
                                          style: const TextStyle(
                                            color: AppColors.primaryLight,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            fontFamily: 'Inter',
                                          ),
                                        ),
                                      ),
                                      ...usersInLetter.map((user) {
                                        final isBusy = _busyUserIds.contains(user.id);
                                        return _buildUserItem(
                                          user: user,
                                          trailing: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              GestureDetector(
                                                onTap: () {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (_) => ChatScreen(
                                                        userName: user.name,
                                                        receiverId: user.id,
                                                        userAvatar: user.avatar,
                                                        isOnline: user.isOnline,
                                                      ),
                                                    ),
                                                  );
                                                },
                                                child: _buildCircleAction(Icons.chat_bubble_outline_rounded),
                                              ),
                                              const SizedBox(width: 8),
                                              GestureDetector(
                                                onTap: isBusy
                                                    ? null
                                                    : () => _runAction(
                                                          user.id,
                                                          () => _friendService.unfriend(user.id),
                                                          'Đã xóa bạn bè',
                                                        ),
                                                child: _buildCircleAction(
                                                  Icons.person_remove_outlined,
                                                  color: AppColors.error,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }),
                                    ],
                                  );
                                }),
                              ],
                              if (suggestions.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                _buildSectionTitle('Khám phá'),
                                ...suggestions.map((user) {
                                  final isBusy = _busyUserIds.contains(user.id);
                                  return _buildUserItem(
                                    user: user,
                                    trailing: _buildActionText(
                                      label: isBusy ? '...' : 'Kết bạn',
                                      onTap: isBusy
                                          ? null
                                          : () => _runAction(
                                                user.id,
                                                () => _friendService.sendFriendRequest(user.id),
                                                'Đã gửi lời mời kết bạn',
                                              ),
                                    ),
                                  );
                                }),
                              ],
                              if (friends.isEmpty &&
                                  receivedRequests.isEmpty &&
                                  sentRequests.isEmpty &&
                                  suggestions.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.only(top: 60),
                                  child: Center(
                                    child: Text(
                                      'Không có dữ liệu phù hợp',
                                      style: TextStyle(color: AppColors.textMuted, fontFamily: 'Inter'),
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 36),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          fontFamily: 'Inter',
        ),
      ),
    );
  }

  Widget _buildUserItem({
    required ChatUser user,
    Widget? trailing,
    String? subtitle,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          AvatarWidget(name: user.name, imageUrl: user.avatar, size: 44, isOnline: user.isOnline),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle ?? (user.bio?.isNotEmpty == true ? user.bio! : (user.isOnline ? 'Đang hoạt động' : 'Ngoại tuyến')),
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontFamily: 'Inter',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
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
                Text(
                  label,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontFamily: 'Inter'),
                ),
              ],
            ),
            if (badge > 0)
              Positioned(
                top: 0,
                right: 16,
                child: UnreadBadge(count: badge, size: 18),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniAction({
    required IconData icon,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: AppColors.glassBg,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.glassBorder, width: 0.5),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }

  Widget _buildCircleAction(IconData icon, {Color? color}) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: AppColors.glassBg,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.glassBorder, width: 0.5),
      ),
      child: Icon(icon, color: color ?? AppColors.textSecondary, size: 18),
    );
  }

  Widget _buildActionText({
    required String label,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.primary.withOpacity(0.35)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: AppColors.primaryLight,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            fontFamily: 'Inter',
          ),
        ),
      ),
    );
  }
}
