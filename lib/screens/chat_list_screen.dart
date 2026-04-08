import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/chat_models.dart';
import '../services/chat_service.dart';
import '../theme/app_theme.dart';
import '../utils/error_mapper.dart';
import '../utils/l10n.dart';
import '../widgets/glass_card.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ChatService _chatService = ChatService();
  final Set<String> _busyChatIds = {};
  String _searchQuery = '';

  String get _currentUserId => FirebaseAuth.instance.currentUser?.uid ?? '';

  Set<String> _readIdSet(dynamic raw) {
    if (raw is! Iterable) return <String>{};
    return raw.map((e) => e.toString()).where((e) => e.isNotEmpty).toSet();
  }

  Map<String, dynamic> _readChatMeta(dynamic raw) {
    if (raw is! Map) return <String, dynamic>{};
    return raw.map((key, value) {
      if (value is Map<String, dynamic>) {
        return MapEntry(key.toString(), value);
      }
      if (value is Map) {
        return MapEntry(key.toString(), value.map((k, v) => MapEntry(k.toString(), v)));
      }
      return MapEntry(key.toString(), <String, dynamic>{});
    });
  }

  bool _chatFlag(Map<String, dynamic> chatMeta, String roomId, String key) {
    final room = chatMeta[roomId];
    if (room is! Map) return false;
    return room[key] == true;
  }

  Future<void> _runChatAction(String roomId, Future<void> Function() action, String successText) async {
    if (_busyChatIds.contains(roomId)) return;
    setState(() => _busyChatIds.add(roomId));
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(successText)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.chatListActionFailed(AppErrorText.forChat(context, e)))),
      );
    } finally {
      if (mounted) {
        setState(() => _busyChatIds.remove(roomId));
      }
    }
  }

  Future<void> _showChatActionsBottomSheet({
    required String roomId,
    required String peerId,
    required String peerName,
  }) async {
    final l10n = context.l10n;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.bgSurface.withOpacity(0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: AppColors.glassBorder),
          ),
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                peerName,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.visibility_off_outlined, color: AppColors.textSecondary),
                title: Text(l10n.commonHide, style: const TextStyle(color: AppColors.textPrimary)),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await _runChatAction(
                    roomId,
                    () => _chatService.hideConversation(peerId),
                    l10n.chatListHideSuccess,
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                title: Text(l10n.commonDelete, style: const TextStyle(color: AppColors.error)),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await _runChatAction(
                    roomId,
                    () => _chatService.deleteConversationForMe(peerId),
                    l10n.chatListDeleteSuccess,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      body: Stack(
        children: [
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Row(
                    children: [
                      Text(
                        l10n.navChats,
                        style: const TextStyle(
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
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMuted, size: 20),
                        hintText: l10n.chatListSearchHint,
                        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14, fontFamily: 'Inter'),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance.collection('users').doc(_currentUserId).snapshots(),
                    builder: (context, mySnapshot) {
                      if (mySnapshot.hasError) {
                        return Center(child: Text(l10n.commonUnexpectedError, style: const TextStyle(color: AppColors.textMuted)));
                      }
                      if (mySnapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                      }

                      final myData = mySnapshot.data?.data() as Map<String, dynamic>? ?? const {};
                      final friendIds = _readIdSet(myData['friends']);
                      final chatMeta = _readChatMeta(myData['chatMeta']);

                      if (friendIds.isEmpty) {
                        return Center(
                          child: Text(
                            l10n.chatListNoFriendsPrompt,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.textMuted),
                          ),
                        );
                      }

                      return StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance.collection('users').snapshots(),
                        builder: (context, usersSnapshot) {
                          if (usersSnapshot.hasError) {
                            return Center(child: Text(l10n.commonUnexpectedError, style: const TextStyle(color: AppColors.textMuted)));
                          }
                          if (usersSnapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                          }
                          if (!usersSnapshot.hasData || usersSnapshot.data == null) {
                            return const SizedBox.shrink();
                          }

                          final usersList = usersSnapshot.data!.docs
                              .map((doc) => ChatUser.fromDocument(doc))
                              .where((user) => user.id != _currentUserId)
                              .where((user) => friendIds.contains(user.id))
                              .where((user) => user.name.toLowerCase().contains(_searchQuery))
                              .where((user) {
                                final roomId = _chatService.buildChatRoomId(user.id);
                                return !_chatFlag(chatMeta, roomId, 'hidden');
                              })
                              .toList()
                            ..sort((a, b) {
                              final roomA = _chatService.buildChatRoomId(a.id);
                              final roomB = _chatService.buildChatRoomId(b.id);
                              final pinA = _chatFlag(chatMeta, roomA, 'pinned');
                              final pinB = _chatFlag(chatMeta, roomB, 'pinned');
                              if (pinA != pinB) {
                                return pinB ? 1 : -1;
                              }
                              return a.name.toLowerCase().compareTo(b.name.toLowerCase());
                            });

                          if (usersList.isEmpty) {
                            return Center(
                              child: Text(
                                _searchQuery.isEmpty ? l10n.chatListNoConversations : l10n.commonNoSearchResults,
                                style: const TextStyle(color: AppColors.textMuted),
                              ),
                            );
                          }

                          return Column(
                            children: [
                              SizedBox(
                                height: 100,
                                child: ListView(
                                  scrollDirection: Axis.horizontal,
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  children: [
                                    _buildStoryItem(l10n.chatListYourStory, true, true),
                                    ...usersList.take(7).map(
                                      (user) => _buildStoryItem(user.name.split(' ').last, false, user.isOnline),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Expanded(
                                child: ListView.builder(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  itemCount: usersList.length,
                                  itemBuilder: (context, i) {
                                    final user = usersList[i];
                                    final chatRoomId = _chatService.buildChatRoomId(user.id);
                                    final isPinned = _chatFlag(chatMeta, chatRoomId, 'pinned');

                                    return StreamBuilder<DocumentSnapshot>(
                                      stream: FirebaseFirestore.instance.collection('chat_rooms').doc(chatRoomId).snapshots(),
                                      builder: (context, roomSnapshot) {
                                        String lastText = l10n.chatListTapToStart;
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
                                          isPinned: isPinned,
                                        );

                                        return Dismissible(
                                          key: ValueKey('chat-$chatRoomId-${user.id}'),
                                          direction: DismissDirection.horizontal,
                                          confirmDismiss: (direction) async {
                                            if (direction == DismissDirection.startToEnd) {
                                              final nextPinned = !isPinned;
                                              await _runChatAction(
                                                chatRoomId,
                                                () => _chatService.setChatPinned(user.id, nextPinned),
                                                nextPinned ? l10n.chatListPinSuccess : l10n.chatListUnpinSuccess,
                                              );
                                              return false;
                                            }

                                            await _showChatActionsBottomSheet(
                                              roomId: chatRoomId,
                                              peerId: user.id,
                                              peerName: user.name,
                                            );
                                            return false;
                                          },
                                          background: Container(
                                            margin: const EdgeInsets.only(bottom: 4),
                                            padding: const EdgeInsets.symmetric(horizontal: 20),
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(16),
                                              color: AppColors.primary.withOpacity(0.2),
                                            ),
                                            alignment: Alignment.centerLeft,
                                            child: Row(
                                              children: [
                                                Icon(isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded, color: AppColors.primaryLight),
                                                const SizedBox(width: 8),
                                                Text(
                                                  isPinned ? l10n.commonUnpin : l10n.commonPin,
                                                  style: const TextStyle(color: AppColors.primaryLight, fontWeight: FontWeight.w600),
                                                ),
                                              ],
                                            ),
                                          ),
                                          secondaryBackground: Container(
                                            margin: const EdgeInsets.only(bottom: 4),
                                            padding: const EdgeInsets.symmetric(horizontal: 20),
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(16),
                                              color: AppColors.error.withOpacity(0.18),
                                            ),
                                            alignment: Alignment.centerRight,
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.end,
                                              children: [
                                                const Icon(Icons.more_horiz_rounded, color: AppColors.error),
                                                const SizedBox(width: 8),
                                                Text(
                                                  l10n.commonMore,
                                                  style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w600),
                                                ),
                                              ],
                                            ),
                                          ),
                                          child: _buildConversationItem(context, conv),
                                        );
                                      },
                                    );
                                  },
                                ),
                              ),
                            ],
                          );
                        },
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
    final l10n = context.l10n;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              userName: conv.user.name,
              receiverId: conv.user.id,
              userAvatar: conv.user.avatar,
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
            Stack(
              children: [
                AvatarWidget(
                  name: conv.user.name,
                  imageUrl: conv.user.avatar,
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
                            ? Text(
                                l10n.chatListTyping,
                                style: const TextStyle(
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
