import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../models/chat_models.dart';
import '../services/chat_service.dart';
import '../services/group_service.dart';
import '../services/auth_service.dart';
import '../utils/app_logger.dart';
import '../utils/error_mapper.dart';
import '../utils/l10n.dart';
import 'group_info_screen.dart';
import 'user_profile_screen.dart';

class ChatScreen extends StatefulWidget {
  final String userName;
  final String receiverId;
  final bool isOnline;
  final bool isGroup;
  final int memberCount;
  final String userAvatar;

  const ChatScreen({
    super.key,
    required this.userName,
    required this.receiverId,
    this.isOnline = false,
    this.isGroup = false,
    this.memberCount = 0,
    this.userAvatar = '',
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _messageSearchController =
      TextEditingController();
  final FocusNode _messageSearchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final ChatService _chatService = ChatService();
  final GroupService _groupService = GroupService();
  final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  String _currentUserName =
      FirebaseAuth.instance.currentUser?.displayName ?? '';

  File? _pickedImage;
  bool _isOtherTyping = false;
  bool _isMeTyping = false;
  bool _isSearchingMessages = false;
  String _messageSearchQuery = '';
  Timer? _typingTimer;
  Timer? _messageSearchDebounce;
  Timer? _readReceiptTimer;
  Timer? _groupReadTimer;
  StreamSubscription? _chatRoomSubscription;
  int _lastMessageCount = -1;
  bool _isSyncingReceipts = false;
  bool _isSyncingGroupReads = false;
  bool _isUploadingImage = false;
  File? _failedImageUpload;
  String? _failedImageReplyId;
  final Map<String, int> _imageReloadAttempts = {};

  // Reply state
  ChatMessage? _replyingTo;

  String _resolvedMessageImageUrl(ChatMessage message) {
    final attempt = _imageReloadAttempts[message.id] ?? 0;
    if (attempt <= 0) return message.text;
    final separator = message.text.contains('#') ? '&' : '#';
    return '${message.text}${separator}retry=$attempt';
  }

  void _retryLoadMessageImage(String messageId) {
    setState(() {
      _imageReloadAttempts[messageId] =
          (_imageReloadAttempts[messageId] ?? 0) + 1;
    });
  }

  @override
  void initState() {
    super.initState();
    _loadCurrentUserProfile();
    _setupTypingListener();
    _setupOtherTypingListener();
    _recordLastScreen();
    if (!widget.isGroup) {
      _chatService.markConversationVisible(widget.receiverId);
    } else {
      _groupService
          .markGroupMessagesRead(widget.receiverId)
          .catchError((_) => 0);
    }
  }

  Future<void> _loadCurrentUserProfile() async {
    if (currentUserId.isEmpty) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .get();
      if (!doc.exists || !mounted) return;
      final data = doc.data();
      final name = data?['name']?.toString().trim();
      if (name != null && name.isNotEmpty) {
        setState(() {
          _currentUserName = name;
        });
      }
    } catch (_) {}
  }

  void _recordLastScreen() {
    AuthService().updateLastScreen({
      'name': 'chat',
      'receiverId': widget.receiverId,
      'userName': widget.userName,
      'userAvatar': widget.userAvatar,
      'isOnline': widget.isOnline,
      'isGroup': widget.isGroup,
      'memberCount': widget.memberCount,
    });
  }

  void _setupTypingListener() {
    _messageController.addListener(() {
      if (_messageController.text.isNotEmpty && !_isMeTyping) {
        _setMeTyping(true);
      } else if (_messageController.text.isEmpty && _isMeTyping) {
        _setMeTyping(false);
      }

      // Reset timer whenever user types
      _typingTimer?.cancel();
      _typingTimer = Timer(const Duration(seconds: 3), () {
        if (_isMeTyping) _setMeTyping(false);
      });
    });
  }

  void _setMeTyping(bool typing) {
    if (mounted) {
      setState(() => _isMeTyping = typing);
      if (widget.isGroup) {
        _groupService.updateTypingStatus(widget.receiverId, typing);
      } else {
        _chatService.updateTypingStatus(widget.receiverId, typing);
      }
    }
  }

  void _setupOtherTypingListener() {
    final stream = widget.isGroup
        ? _groupService.getGroupStream(widget.receiverId)
        : _chatService.getChatRoomStream(widget.receiverId);

    _chatRoomSubscription = stream.listen((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        final data = snapshot.data() as Map<String, dynamic>;
        if (data.containsKey('typing')) {
          final typingData = data['typing'] as Map<String, dynamic>;
          bool isOtherTyping = false;
          if (widget.isGroup) {
            isOtherTyping = typingData.entries.any(
              (entry) => entry.key != currentUserId && entry.value == true,
            );
          } else {
            isOtherTyping = typingData[widget.receiverId] == true;
          }
          if (mounted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _isOtherTyping = isOtherTyping;
                });
              }
            });
          }
        }
      }
    });
  }

  void _syncScrollToLatest(int messageCount) {
    if (messageCount == _lastMessageCount) return;
    final shouldAnimate = _lastMessageCount >= 0;
    _lastMessageCount = messageCount;
    _scrollToBottom(animated: shouldAnimate);
  }

  void _scrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if (animated) {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(target);
      }
    });
  }

  DateTime _messageTimestamp(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    final rawTimestamp = data?['timestamp'];
    if (rawTimestamp is Timestamp) {
      return rawTimestamp.toDate();
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  bool _hasUnreadIncomingDirectMessages(List<DocumentSnapshot> docs) {
    if (widget.isGroup || currentUserId.isEmpty) return false;
    return docs.any((doc) {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) return false;
      final senderId = data['senderId']?.toString();
      final receiverId = data['receiverId']?.toString();
      final isRead = data['isRead'] == true;
      return senderId != currentUserId &&
          receiverId == currentUserId &&
          !isRead;
    });
  }

  void _syncDirectReceiptsIfNeeded(List<DocumentSnapshot> docs) {
    if (!_hasUnreadIncomingDirectMessages(docs) || _isSyncingReceipts) {
      return;
    }

    _isSyncingReceipts = true;
    _chatService.markMessagesDelivered(widget.receiverId).catchError((_) => 0);

    _readReceiptTimer?.cancel();
    _readReceiptTimer = Timer(const Duration(milliseconds: 700), () async {
      try {
        await _chatService.markMessagesRead(widget.receiverId);
      } catch (_) {
      } finally {
        _isSyncingReceipts = false;
      }
    });
  }

  bool _hasUnreadIncomingGroupMessages(List<DocumentSnapshot> docs) {
    if (!widget.isGroup || currentUserId.isEmpty) return false;
    return docs.any((doc) {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) return false;
      final senderId = data['senderId']?.toString();
      if (senderId == null ||
          senderId.isEmpty ||
          senderId == currentUserId ||
          senderId == 'system') {
        return false;
      }

      final readBy = List<dynamic>.from(data['readBy'] ?? const []);
      return !readBy.map((e) => e.toString()).contains(currentUserId);
    });
  }

  void _syncGroupReadsIfNeeded(List<DocumentSnapshot> docs) {
    if (!_hasUnreadIncomingGroupMessages(docs) || _isSyncingGroupReads) {
      return;
    }

    _isSyncingGroupReads = true;
    _groupReadTimer?.cancel();
    _groupReadTimer = Timer(const Duration(milliseconds: 700), () async {
      try {
        await _groupService.markGroupMessagesRead(widget.receiverId);
      } catch (_) {
      } finally {
        _isSyncingGroupReads = false;
      }
    });
  }

  void _toggleMessageSearch() {
    if (_isSearchingMessages) {
      _closeMessageSearch();
      return;
    }

    setState(() => _isSearchingMessages = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _messageSearchFocusNode.requestFocus();
      }
    });
  }

  void _closeMessageSearch() {
    _messageSearchDebounce?.cancel();
    _messageSearchController.clear();
    _messageSearchFocusNode.unfocus();
    setState(() {
      _isSearchingMessages = false;
      _messageSearchQuery = '';
    });
  }

  void _onMessageSearchChanged(String value) {
    _messageSearchDebounce?.cancel();
    _messageSearchDebounce = Timer(const Duration(milliseconds: 220), () {
      if (!mounted) return;
      setState(() {
        _messageSearchQuery = value.trim().toLowerCase();
      });
    });
  }

  List<DocumentSnapshot> _filterMessagesBySearch(List<DocumentSnapshot> docs) {
    if (_messageSearchQuery.isEmpty) return docs;
    final query = _messageSearchQuery;
    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) return false;

      final rawType = data['type']?.toString() ?? 'text';
      if (rawType == 'deleted') return false;

      final text = data['text']?.toString().toLowerCase() ?? '';
      final senderName = data['senderName']?.toString().toLowerCase() ?? '';
      return text.contains(query) || senderName.contains(query);
    }).toList();
  }

  void _openUserProfile(String userId) {
    if (userId.isEmpty || userId == currentUserId) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => UserProfileScreen(userId: userId)),
    );
  }

  Future<void> _openGroupInfo() async {
    if (!widget.isGroup) return;
    try {
      final groupDoc = await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.receiverId)
          .get();
      final data = groupDoc.data() ?? const <String, dynamic>{};
      final memberIds = (data['members'] is Iterable)
          ? (data['members'] as Iterable)
              .map((e) => e.toString())
              .where((e) => e.isNotEmpty)
              .toList()
          : <String>[];
      if (!mounted) return;

      final result = await Navigator.push<GroupInfoAction>(
        context,
        MaterialPageRoute(
          builder: (_) => GroupInfoScreen(
            groupId: widget.receiverId,
            groupName: widget.userName,
            memberCount: widget.memberCount,
            memberIds: memberIds,
          ),
        ),
      );

      if (!mounted) return;
      if (result == GroupInfoAction.openSearch && !_isSearchingMessages) {
        _toggleMessageSearch();
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.commonUnexpectedError)),
      );
    }
  }

  void _setReplyingWithKeepPosition(ChatMessage message) {
    final offset =
        _scrollController.hasClients ? _scrollController.offset : null;
    setState(() => _replyingTo = message);
    if (offset == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final max = _scrollController.position.maxScrollExtent;
      _scrollController.jumpTo(offset.clamp(0, max));
    });
  }

  void _clearReplyingWithKeepPosition() {
    if (_replyingTo == null) return;
    final offset =
        _scrollController.hasClients ? _scrollController.offset : null;
    setState(() => _replyingTo = null);
    if (offset == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final max = _scrollController.position.maxScrollExtent;
      _scrollController.jumpTo(offset.clamp(0, max));
    });
  }

  Widget _buildUserAvatarById({
    required String? userId,
    required String fallbackName,
    required double size,
    bool isOnline = false,
    bool showStatus = false,
    String fallbackImage = '',
  }) {
    if (userId == null || userId.isEmpty) {
      return AvatarWidget(
        name: fallbackName,
        imageUrl: fallbackImage,
        size: size,
        isOnline: isOnline,
        showStatus: showStatus,
      );
    }
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>?;
        final name = data?['name']?.toString() ?? fallbackName;
        final avatar = data?['avatar']?.toString() ?? fallbackImage;
        final online = data?['isOnline'] == true;
        return AvatarWidget(
          name: name,
          imageUrl: avatar,
          size: size,
          isOnline: isOnline || online,
          showStatus: showStatus,
        );
      },
    );
  }

  @override
  void dispose() {
    _setMeTyping(false);
    _typingTimer?.cancel();
    _messageSearchDebounce?.cancel();
    _readReceiptTimer?.cancel();
    _groupReadTimer?.cancel();
    _chatRoomSubscription?.cancel();
    _messageSearchController.dispose();
    _messageSearchFocusNode.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background glow
          Positioned(
            top: -80,
            left: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withOpacity(0.1),
                    Colors.transparent
                  ],
                ),
              ),
            ),
          ),
          Column(
            children: [
              // App bar
              _buildAppBar(context),
              // Messages
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: widget.isGroup
                      ? _groupService.getGroupMessagesStream(widget.receiverId)
                      : _chatService.getMessagesStream(widget.receiverId),
                  builder: (context, snapshot) {
                    final l10n = context.l10n;
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          l10n.commonUnexpectedError,
                          style: const TextStyle(color: AppColors.textMuted),
                        ),
                      );
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                          child: CircularProgressIndicator(
                              color: AppColors.primary));
                    }

                    if (!snapshot.hasData) {
                      return const SizedBox.shrink();
                    }

                    final messageDocs = snapshot.data!.docs.toList()
                      ..sort((a, b) =>
                          _messageTimestamp(a).compareTo(_messageTimestamp(b)));

                    if (messageDocs.isEmpty) {
                      return Center(
                        child: Text(
                          l10n.chatListNoConversations,
                          style: const TextStyle(color: AppColors.textMuted),
                        ),
                      );
                    }

                    if (widget.isGroup) {
                      _syncGroupReadsIfNeeded(messageDocs);
                    } else {
                      _syncDirectReceiptsIfNeeded(messageDocs);
                    }
                    if (_messageSearchQuery.isEmpty) {
                      _syncScrollToLatest(messageDocs.length);
                    }

                    final visibleDocs = _filterMessagesBySearch(messageDocs);
                    if (visibleDocs.isEmpty) {
                      return Center(
                        child: Text(
                          l10n.chatSearchNoMatches,
                          style: const TextStyle(color: AppColors.textMuted),
                        ),
                      );
                    }

                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount: visibleDocs.length,
                      itemBuilder: (context, i) {
                        final msgData =
                            ChatMessage.fromDocument(visibleDocs[i]);
                        if (msgData.deletedFor.contains(currentUserId)) {
                          return const SizedBox.shrink();
                        }
                        // Overwrite isSent based on actual sender
                        final bool isSent = msgData.senderId == currentUserId;
                        final ChatMessage msg = ChatMessage(
                          id: msgData.id,
                          text: msgData.text,
                          isSent: isSent,
                          time: msgData.time,
                          type: msgData.type,
                          senderId: msgData.senderId,
                          senderName: msgData.senderName,
                          isRead: msgData.isRead,
                          deliveryStatus: msgData.deliveryStatus,
                          replyTo: msgData.replyTo,
                          reactions: msgData.reactions,
                          deletedFor: msgData.deletedFor,
                          isRecalledForEveryone: msgData.isRecalledForEveryone,
                        );
                        return _buildMessage(msg);
                      },
                    );
                  },
                ),
              ),
              // Typing indicator
              if (_isOtherTyping && !widget.isGroup)
                Padding(
                  padding: const EdgeInsets.only(left: 20, bottom: 8),
                  child: Row(
                    children: [
                      _buildUserAvatarById(
                        userId: widget.receiverId,
                        fallbackName: widget.userName,
                        fallbackImage: widget.userAvatar,
                        size: 24,
                        showStatus: false,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${widget.userName.split(' ').last} ${context.l10n.chatListTyping}',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          fontFamily: 'Inter',
                        ),
                      ),
                      const SizedBox(width: 4),
                      _buildTypingDots(),
                    ],
                  ),
                ),
              // Input bar
              _buildInputBar(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      decoration: const BoxDecoration(
        color: AppColors.bgSurface,
        border: Border(
          bottom: BorderSide(color: AppColors.glassBorder, width: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_rounded,
                  color: AppColors.textPrimary, size: 20),
              onPressed: () {
                if (_isSearchingMessages) {
                  _closeMessageSearch();
                  return;
                }
                Navigator.pop(context);
              },
            ),
            GestureDetector(
              onTap: widget.isGroup
                  ? null
                  : () => _openUserProfile(widget.receiverId),
              child: _buildUserAvatarById(
                userId: widget.isGroup ? null : widget.receiverId,
                fallbackName: widget.userName,
                fallbackImage: widget.userAvatar,
                size: 40,
                isOnline: widget.isOnline,
                showStatus: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _isSearchingMessages
                  ? Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.glassBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: AppColors.glassBorder, width: 0.5),
                      ),
                      child: TextField(
                        controller: _messageSearchController,
                        focusNode: _messageSearchFocusNode,
                        onChanged: _onMessageSearchChanged,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontFamily: 'Inter',
                        ),
                        decoration: InputDecoration(
                          hintText: l10n.chatSearchHint,
                          hintStyle: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 13,
                            fontFamily: 'Inter',
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          prefixIcon: const Icon(Icons.search_rounded,
                              color: AppColors.textMuted, size: 18),
                        ),
                      ),
                    )
                  : GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: widget.isGroup
                          ? null
                          : () => _openUserProfile(widget.receiverId),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.userName,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Inter',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.isGroup
                                ? l10n.groupsMemberCount(widget.memberCount)
                                : widget.isOnline
                                    ? l10n.commonOnline
                                    : l10n.commonOffline,
                            style: TextStyle(
                              color: widget.isOnline
                                  ? AppColors.accentGreen
                                  : AppColors.textMuted,
                              fontSize: 12,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            if (_isSearchingMessages)
              _buildActionIcon(
                Icons.close_rounded,
                onTap: _closeMessageSearch,
              )
            else ...[
              if (widget.isGroup) ...[
                _buildActionIcon(
                  Icons.search_rounded,
                  onTap: _toggleMessageSearch,
                ),
                _buildActionIcon(
                  Icons.info_outline_rounded,
                  onTap: _openGroupInfo,
                ),
              ] else ...[
                _buildActionIcon(Icons.call_outlined),
                _buildActionIcon(Icons.videocam_outlined),
                _buildActionIcon(
                  Icons.search_rounded,
                  onTap: _toggleMessageSearch,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionIcon(IconData icon, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        width: 36,
        height: 36,
        child: Icon(icon, color: AppColors.textSecondary, size: 22),
      ),
    );
  }

  Widget _buildMessage(ChatMessage message) {
    if (message.deletedFor.contains(currentUserId)) {
      return const SizedBox.shrink();
    }

    if (message.type == MessageType.system) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            message.text,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
              fontStyle: FontStyle.italic,
              fontFamily: 'Inter',
            ),
          ),
        ),
      );
    }

    final isSent = message.isSent;
    final senderLabel = message.senderName ??
        message.senderId ??
        context.l10n.profileFallbackUser;
    final isDeletedMessage =
        message.type == MessageType.deleted || message.isRecalledForEveryone;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment:
            isSent ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isSent && widget.isGroup) ...[
            GestureDetector(
              onTap: () => _openUserProfile(message.senderId ?? ''),
              child: _buildUserAvatarById(
                userId: message.senderId,
                fallbackName: senderLabel,
                size: 28,
                showStatus: false,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isSent ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isSent && widget.isGroup)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 4),
                    child: Text(
                      senderLabel,
                      style: TextStyle(
                        color: _getSenderColor(senderLabel),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.72,
                  ),
                  child: GestureDetector(
                    onLongPress: isDeletedMessage
                        ? null
                        : () => _showContextMenu(message),
                    child: Column(
                      crossAxisAlignment: isSent
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        if (message.replyTo != null)
                          _buildReplyPreview(message.replyTo!, isSent),
                        isDeletedMessage
                            ? _buildDeletedBubble(isSent)
                            : message.type == MessageType.image
                                ? _buildImageMessage(isSent, message)
                                : _buildTextBubble(isSent, message),
                        if (!isDeletedMessage &&
                            message.reactions != null &&
                            message.reactions!.isNotEmpty)
                          _buildReactionsDisplay(message.reactions!),
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

  Widget _buildReplyPreview(String replyId, bool isMe) {
    final l10n = context.l10n;
    final Future<DocumentSnapshot> replyFuture = widget.isGroup
        ? FirebaseFirestore.instance
            .collection('groups')
            .doc(widget.receiverId)
            .collection('messages')
            .doc(replyId)
            .get()
        : FirebaseFirestore.instance
            .collection('chat_rooms')
            .doc(_getChatRoomId())
            .collection('messages')
            .doc(replyId)
            .get();

    return FutureBuilder<DocumentSnapshot>(
      future: replyFuture,
      builder: (context, snapshot) {
        String replyText = l10n.chatMessageDeleted;
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          final deletedFor = List<dynamic>.from(data['deletedFor'] ?? const []);
          final isDeletedForMe =
              deletedFor.map((e) => e.toString()).contains(currentUserId);
          final isRecalled =
              data['recalledForEveryone'] == true || data['type'] == 'deleted';
          if (isDeletedForMe || isRecalled) {
            replyText = l10n.chatMessageRecalled;
          } else {
            replyText = data['type'] == 'image'
                ? l10n.chatImagePlaceholder
                : (data['text']?.toString() ?? '');
          }
        }
        return Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(8),
            border: Border(
                left: BorderSide(
                    color: isMe ? Colors.white70 : AppColors.primary,
                    width: 3)),
          ),
          child: Text(
            replyText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: Colors.white60,
                fontSize: 12,
                fontStyle: FontStyle.italic),
          ),
        );
      },
    );
  }

  Widget _buildReactionsDisplay(Map<String, dynamic> reactions) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.bgSurface.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.glassBorder, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: reactions.entries.map((e) {
          return Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Text('${e.key} ${e.value.length}',
                style: const TextStyle(fontSize: 10)),
          );
        }).toList(),
      ),
    );
  }

  String _getChatRoomId() {
    List<String> ids = [currentUserId, widget.receiverId];
    ids.sort();
    return ids.join("_");
  }

  Widget _buildDeletedBubble(bool isSent) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isSent ? Colors.white10 : AppColors.glassBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.glassBorder, width: 0.5),
      ),
      child: Text(
        l10n.chatMessageRecalled,
        style: TextStyle(
          color: isSent ? Colors.white70 : AppColors.textMuted,
          fontSize: 13,
          fontStyle: FontStyle.italic,
          fontFamily: 'Inter',
        ),
      ),
    );
  }

  String _deliveryStatusLabel(MessageDeliveryStatus status) {
    final l10n = context.l10n;
    switch (status) {
      case MessageDeliveryStatus.read:
        return l10n.chatStatusRead;
      case MessageDeliveryStatus.delivered:
        return l10n.chatStatusDelivered;
      case MessageDeliveryStatus.sent:
        return l10n.chatStatusSent;
    }
  }

  IconData _deliveryStatusIcon(MessageDeliveryStatus status) {
    switch (status) {
      case MessageDeliveryStatus.read:
        return Icons.done_all_rounded;
      case MessageDeliveryStatus.delivered:
        return Icons.done_all_rounded;
      case MessageDeliveryStatus.sent:
        return Icons.done_rounded;
    }
  }

  Color _deliveryStatusColor(
      MessageDeliveryStatus status, bool onDarkBackground) {
    if (status == MessageDeliveryStatus.read) {
      return const Color(0xFF60A5FA);
    }
    return onDarkBackground
        ? Colors.white.withOpacity(0.72)
        : AppColors.textMuted;
  }

  Widget _buildDeliveryStatusBadge(
    ChatMessage message, {
    required bool onDarkBackground,
    bool showLabel = true,
  }) {
    final color =
        _deliveryStatusColor(message.deliveryStatus, onDarkBackground);
    final label = _deliveryStatusLabel(message.deliveryStatus);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          _deliveryStatusIcon(message.deliveryStatus),
          color: color,
          size: 14,
        ),
        if (showLabel) ...[
          const SizedBox(width: 2),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTextBubble(bool isSent, ChatMessage message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: isSent ? AppGradients.sentBubble : null,
        color: isSent ? null : AppColors.glassBg,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(20),
          topRight: const Radius.circular(20),
          bottomLeft: Radius.circular(isSent ? 20 : 4),
          bottomRight: Radius.circular(isSent ? 4 : 20),
        ),
        border: isSent
            ? null
            : Border.all(color: AppColors.glassBorder, width: 0.5),
        boxShadow: isSent
            ? [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            message.text,
            style: TextStyle(
              color: isSent ? Colors.white : AppColors.textPrimary,
              fontSize: 15,
              fontFamily: 'Inter',
              height: 1.3,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message.time,
                style: TextStyle(
                  color: isSent
                      ? Colors.white.withOpacity(0.7)
                      : AppColors.textMuted,
                  fontSize: 11,
                  fontFamily: 'Inter',
                ),
              ),
              if (isSent) ...[
                const SizedBox(width: 4),
                _buildDeliveryStatusBadge(
                  message,
                  onDarkBackground: true,
                  showLabel: !widget.isGroup,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImageMessage(bool isSent, ChatMessage message) {
    final l10n = context.l10n;
    final pixelRatio = MediaQuery.of(context).devicePixelRatio;
    final cacheWidth = (220 * pixelRatio).round();
    final cacheHeight = (160 * pixelRatio).round();
    final imageUrl = _resolvedMessageImageUrl(message);
    final retryVersion = _imageReloadAttempts[message.id] ?? 0;

    return Column(
      crossAxisAlignment:
          isSent ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Container(
          width: 220,
          height: 160,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              colors: [Color(0xFF4A2B7A), Color(0xFF2D1B69)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: AppColors.glassBorder, width: 0.5),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Render image from Firebase Storage
                Image.network(
                  imageUrl,
                  key: ValueKey('message-image-${message.id}-$retryVersion'),
                  fit: BoxFit.cover,
                  cacheWidth: cacheWidth,
                  cacheHeight: cacheHeight,
                  filterQuality: FilterQuality.medium,
                  frameBuilder:
                      (context, child, frame, wasSynchronouslyLoaded) {
                    if (wasSynchronouslyLoaded) return child;
                    return AnimatedOpacity(
                      opacity: frame == null ? 0 : 1,
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      child: child,
                    );
                  },
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primaryLight,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) => Center(
                    child: GestureDetector(
                      onTap: () => _retryLoadMessageImage(message.id),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.broken_image_rounded,
                              color: AppColors.textMuted, size: 38),
                          const SizedBox(height: 6),
                          Text(
                            l10n.commonRetry,
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Time overlay
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          message.time,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 11),
                        ),
                        if (isSent) ...[
                          const SizedBox(width: 4),
                          _buildDeliveryStatusBadge(
                            message,
                            onDarkBackground: true,
                            showLabel: false,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTypingDots() {
    return Row(
      children: List.generate(3, (i) {
        return AnimatedContainer(
          duration: Duration(milliseconds: 300 + i * 200),
          margin: const EdgeInsets.symmetric(horizontal: 1),
          width: 5,
          height: 5,
          decoration: const BoxDecoration(
            color: AppColors.textMuted,
            shape: BoxShape.circle,
          ),
        );
      }),
    );
  }

  Widget _buildInputBar() {
    final l10n = context.l10n;
    final canSend = !_isUploadingImage &&
        (_messageController.text.isNotEmpty || _pickedImage != null);
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: const BoxDecoration(
        color: AppColors.bgSurface,
        border: Border(
          top: BorderSide(color: AppColors.glassBorder, width: 0.5),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_replyingTo != null) _buildReplyInputBar(),
          if (_pickedImage != null)
            Padding(
              padding: const EdgeInsets.only(left: 52, bottom: 12),
              child: _buildImagePreview(),
            ),
          Row(
            children: [
              _buildAddButton(),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.glassBg,
                    borderRadius: BorderRadius.circular(24),
                    border:
                        Border.all(color: AppColors.glassBorder, width: 0.5),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontFamily: 'Inter',
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText: l10n.chatInputHint,
                            hintStyle:
                                const TextStyle(color: AppColors.textMuted),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: _isUploadingImage
                            ? null
                            : () => _sendImage(ImageSource.gallery),
                        child: const Icon(Icons.add_photo_alternate_outlined,
                            color: AppColors.textMuted, size: 22),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _isUploadingImage
                            ? null
                            : () => _sendImage(ImageSource.camera),
                        child: const Icon(Icons.camera_alt_outlined,
                            color: AppColors.textMuted, size: 22),
                      ),
                      const SizedBox(width: 12),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: canSend ? _sendMessage : null,
                child: Opacity(
                  opacity: canSend ? 1 : 0.45,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: AppGradients.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: _isUploadingImage
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.send_rounded,
                            color: Colors.white, size: 20),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReplyInputBar() {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.glassBg,
        borderRadius: BorderRadius.circular(12),
        border:
            const Border(left: BorderSide(color: AppColors.primary, width: 4)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.chatReplyingTo,
                  style: const TextStyle(
                      color: AppColors.primaryLight,
                      fontSize: 12,
                      fontWeight: FontWeight.bold),
                ),
                Text(
                  (_replyingTo!.type == MessageType.image)
                      ? l10n.chatImagePlaceholder
                      : (_replyingTo!.type == MessageType.deleted ||
                              _replyingTo!.isRecalledForEveryone)
                          ? l10n.chatMessageRecalled
                          : _replyingTo!.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: AppColors.textMuted),
            onPressed: _clearReplyingWithKeepPosition,
          ),
        ],
      ),
    );
  }

  Widget _buildAddButton() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.glassBg,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.glassBorder, width: 0.5),
      ),
      child: const Icon(Icons.add_rounded,
          color: AppColors.textSecondary, size: 22),
    );
  }

  Widget _buildImagePreview() {
    final l10n = context.l10n;
    final hasPendingRetry = _failedImageUpload?.path == _pickedImage?.path;

    return Stack(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.glassBorder, width: 1),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Image.file(_pickedImage!,
                height: 100, width: 100, fit: BoxFit.cover),
          ),
        ),
        if (_isUploadingImage)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        if (hasPendingRetry && !_isUploadingImage)
          Positioned(
            left: 4,
            bottom: 4,
            child: GestureDetector(
              onTap: _retryFailedImageUpload,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  l10n.chatRetry,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 11, fontFamily: 'Inter'),
                ),
              ),
            ),
          ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: () => setState(() {
              _pickedImage = null;
              _failedImageUpload = null;
              _failedImageReplyId = null;
            }),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 16),
            ),
          ),
        ),
      ],
    );
  }

  Color _getSenderColor(String name) {
    final colors = [
      AppColors.primaryLight,
      AppColors.accent,
      AppColors.accentPink,
      AppColors.accentGreen,
      const Color(0xFFF59E0B),
      const Color(0xFF06B6D4),
    ];
    return colors[name.hashCode.abs() % colors.length];
  }

  Future<bool> _uploadImageWithRetry(File imageFile,
      {String? replyTo, bool isRetry = false}) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final senderName = _currentUserName.trim().isNotEmpty
        ? _currentUserName.trim()
        : l10n.profileFallbackUser;

    if (!isRetry) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.chatUploadingImage)));
    }

    if (mounted) {
      setState(() {
        _isUploadingImage = true;
      });
    }

    try {
      if (widget.isGroup) {
        await _groupService.sendImageMessage(
          widget.receiverId,
          senderName,
          imageFile,
          replyTo: replyTo,
        );
      } else {
        await _chatService.sendImageMessage(
          widget.receiverId,
          imageFile,
          replyTo: replyTo,
        );
      }

      if (mounted) {
        setState(() {
          _pickedImage = null;
          _failedImageUpload = null;
          _failedImageReplyId = null;
        });
      }
      return true;
    } catch (e, stackTrace) {
      final reason = AppErrorMapper.mapChat(e);
      AppLogger.error(
        'Failed to upload image message',
        tag: 'chat',
        error: e,
        stackTrace: stackTrace,
        context: {
          'operation': 'chat.upload_image',
          'isGroup': widget.isGroup,
          'receiverId': widget.receiverId,
          'reason': reason.name,
        },
      );
      if (mounted) {
        setState(() {
          _pickedImage = imageFile;
          _failedImageUpload = imageFile;
          _failedImageReplyId = replyTo;
        });
        messenger.showSnackBar(
          SnackBar(
            content: Text(l10n.chatImageUploadFailedWithReason(
                AppErrorText.forChat(context, e))),
            backgroundColor: Colors.redAccent,
            action: SnackBarAction(
              label: l10n.chatRetry,
              onPressed: _retryFailedImageUpload,
            ),
          ),
        );
      }
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingImage = false;
        });
      }
    }
  }

  void _retryFailedImageUpload() {
    final imageFile = _failedImageUpload;
    if (imageFile == null || _isUploadingImage) return;
    _uploadImageWithRetry(imageFile,
        replyTo: _failedImageReplyId, isRetry: true);
  }

  Future<bool> _sendTextMessage({
    required String text,
    required String senderName,
    String? replyId,
  }) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (widget.isGroup) {
        await _groupService.sendGroupMessage(
          widget.receiverId,
          senderName,
          text,
          replyTo: replyId,
        );
      } else {
        await _chatService.sendMessage(
          widget.receiverId,
          text,
          replyTo: replyId,
        );
      }
      return true;
    } catch (e, stackTrace) {
      final reason = AppErrorMapper.mapChat(e);
      AppLogger.error(
        'Failed to send text message',
        tag: 'chat',
        error: e,
        stackTrace: stackTrace,
        context: {
          'operation': 'chat.send_text',
          'isGroup': widget.isGroup,
          'receiverId': widget.receiverId,
          'reason': reason.name,
        },
      );
      if (!mounted) return false;

      final shouldOfferRetry = AppErrorMapper.isRetryableForChat(e);
      if (_messageController.text.trim().isEmpty) {
        _messageController.text = text;
        _messageController.selection = TextSelection.fromPosition(
          TextPosition(offset: _messageController.text.length),
        );
      }

      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.chatSendFailed(AppErrorText.forChat(context, e))),
          backgroundColor: Colors.redAccent,
          action: shouldOfferRetry
              ? SnackBarAction(
                  label: l10n.commonRetry,
                  onPressed: () {
                    _sendTextMessage(
                      text: text,
                      senderName: senderName,
                      replyId: replyId,
                    );
                  },
                )
              : null,
        ),
      );
      return false;
    }
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    final imageToUpload = _pickedImage;
    final replyId = _replyingTo?.id;

    if (text.isEmpty && imageToUpload == null) return;

    if (text.isNotEmpty) {
      _messageController.clear();
    }

    var sentAnything = false;
    final l10n = context.l10n;
    final senderName = _currentUserName.trim().isNotEmpty
        ? _currentUserName.trim()
        : l10n.profileFallbackUser;

    if (imageToUpload != null) {
      final imageSent =
          await _uploadImageWithRetry(imageToUpload, replyTo: replyId);
      sentAnything = sentAnything || imageSent;
    }

    if (text.isNotEmpty) {
      final textSent = await _sendTextMessage(
        text: text,
        senderName: senderName,
        replyId: replyId,
      );
      sentAnything = sentAnything || textSent;
    }

    if (sentAnything) {
      if (mounted) {
        setState(() {
          _replyingTo = null;
        });
      }
      _setMeTyping(false);
      _scrollToBottom(animated: true);
    }
  }

  void _sendImage(ImageSource source) async {
    final l10n = context.l10n;
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image =
          await picker.pickImage(source: source, imageQuality: 70);
      if (image != null) {
        setState(() {
          _pickedImage = File(image.path);
          _failedImageUpload = null;
          _failedImageReplyId = null;
        });
      }
    } catch (e, stackTrace) {
      final reason = AppErrorMapper.mapChat(e);
      AppLogger.error(
        'Failed to pick image',
        tag: 'chat',
        error: e,
        stackTrace: stackTrace,
        context: {
          'operation': 'chat.pick_image',
          'source': source.name,
          'reason': reason.name,
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                l10n.chatImagePickFailed(AppErrorText.forChat(context, e))),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _showContextMenu(ChatMessage message) {
    final l10n = context.l10n;
    final bool isMyMessage = message.senderId == currentUserId;
    final bool isDeletedMessage =
        message.type == MessageType.deleted || message.isRecalledForEveryone;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppColors.bgSurface.withOpacity(0.95),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: AppColors.glassBorder),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Reactions Row
            if (!isDeletedMessage) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: ['❤️', '😂', '😮', '😢', '👍', '👎'].map((emoji) {
                  return GestureDetector(
                    onTap: () {
                      if (widget.isGroup) {
                        _groupService.toggleReaction(
                            widget.receiverId, message.id, emoji);
                      } else {
                        _chatService.toggleReaction(
                            widget.receiverId, message.id, emoji);
                      }
                      Navigator.pop(context);
                    },
                    child: Text(emoji, style: const TextStyle(fontSize: 28)),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              _buildContextMenuItem(Icons.reply_rounded, l10n.chatContextReply,
                  () {
                Navigator.pop(context);
                _setReplyingWithKeepPosition(message);
              }),
              _buildContextMenuItem(Icons.copy_rounded, l10n.chatContextCopy,
                  () {
                Clipboard.setData(ClipboardData(text: message.text));
                Navigator.pop(context);
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(l10n.chatCopied)));
              }),
            ],
            if (isMyMessage && !isDeletedMessage) ...[
              _buildContextMenuItem(
                  Icons.visibility_off_outlined, l10n.chatRecallForMe,
                  () async {
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(context);
                if (widget.isGroup) {
                  await _groupService.recallMessageForMe(
                      widget.receiverId, message.id);
                } else {
                  await _chatService.recallMessageForMe(
                      widget.receiverId, message.id);
                }
                messenger.showSnackBar(
                    SnackBar(content: Text(l10n.chatRecalledForMeSuccess)));
              }, color: AppColors.error),
              _buildContextMenuItem(
                  Icons.delete_outline_rounded, l10n.chatRecallForEveryone,
                  () async {
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(context);
                if (widget.isGroup) {
                  await _groupService.recallMessageForEveryone(
                      widget.receiverId, message.id);
                } else {
                  await _chatService.recallMessageForEveryone(
                      widget.receiverId, message.id);
                }
                messenger.showSnackBar(SnackBar(
                    content: Text(l10n.chatRecalledForEveryoneSuccess)));
              }, color: AppColors.error),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildContextMenuItem(IconData icon, String label, VoidCallback onTap,
      {Color? color}) {
    return ListTile(
      leading: Icon(icon, color: color ?? AppColors.textPrimary),
      title:
          Text(label, style: TextStyle(color: color ?? AppColors.textPrimary)),
      onTap: onTap,
    );
  }
}
