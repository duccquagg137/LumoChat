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

class ChatScreen extends StatefulWidget {
  final String userName;
  final String receiverId;
  final bool isOnline;
  final bool isGroup;
  final int memberCount;

  const ChatScreen({
    super.key,
    required this.userName,
    required this.receiverId,
    this.isOnline = false,
    this.isGroup = false,
    this.memberCount = 0,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ChatService _chatService = ChatService();
  final GroupService _groupService = GroupService();
  final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  final String currentUserName = FirebaseAuth.instance.currentUser?.displayName ?? 'Người dùng';

  File? _pickedImage;
  bool _isOtherTyping = false;
  bool _isMeTyping = false;
  Timer? _typingTimer;
  StreamSubscription? _chatRoomSubscription;

  // Reply state
  ChatMessage? _replyingTo;

  @override
  void initState() {
    super.initState();
    _setupTypingListener();
    _setupOtherTypingListener();
    _recordLastScreen();
  }

  void _recordLastScreen() {
    AuthService().updateLastScreen({
      'name': 'chat',
      'receiverId': widget.receiverId,
      'userName': widget.userName,
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
          if (mounted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _isOtherTyping = typingData[widget.receiverId] ?? false;
                });
              }
            });
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _setMeTyping(false);
    _typingTimer?.cancel();
    _chatRoomSubscription?.cancel();
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
                  colors: [AppColors.primary.withOpacity(0.1), Colors.transparent],
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
                    if (snapshot.hasError) {
                      return const Center(child: Text('Lỗi tải tin nhắn', style: TextStyle(color: AppColors.textMuted)));
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                    }

                    final messageDocs = snapshot.data!.docs;
                    
                    if (messageDocs.isEmpty) {
                      return const Center(
                        child: Text('Chưa có tin nhắn', style: TextStyle(color: AppColors.textMuted)),
                      );
                    }

                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount: messageDocs.length,
                      itemBuilder: (context, i) {
                        final msgData = ChatMessage.fromDocument(messageDocs[i]);
                        // Overwrite isSent based on actual sender
                        final bool isSent = msgData.senderName == currentUserId;
                        final ChatMessage msg = ChatMessage(
                          id: msgData.id,
                          text: msgData.text,
                          isSent: isSent,
                          time: msgData.time,
                          type: msgData.type,
                          senderName: msgData.senderName,
                          isRead: msgData.isRead,
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
                      AvatarWidget(name: widget.userName, size: 24, showStatus: false),
                      const SizedBox(width: 8),
                      Text(
                        '${widget.userName.split(' ').last} đang nhập...',
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
              icon: const Icon(Icons.arrow_back_ios_rounded, color: AppColors.textPrimary, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            AvatarWidget(name: widget.userName, size: 40, isOnline: widget.isOnline),
            const SizedBox(width: 12),
            Expanded(
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
                        ? '${widget.memberCount} thành viên'
                        : widget.isOnline
                            ? 'Online'
                            : 'Offline',
                    style: TextStyle(
                      color: widget.isOnline ? AppColors.accentGreen : AppColors.textMuted,
                      fontSize: 12,
                      fontFamily: 'Inter',
                    ),
                  ),
                ],
              ),
            ),
            _buildActionIcon(Icons.call_outlined),
            _buildActionIcon(Icons.videocam_outlined),
            _buildActionIcon(Icons.more_vert_rounded),
          ],
        ),
      ),
    );
  }

  Widget _buildActionIcon(IconData icon) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      width: 36,
      height: 36,
      child: Icon(icon, color: AppColors.textSecondary, size: 22),
    );
  }

  Widget _buildMessage(ChatMessage message) {
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: isSent ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isSent && widget.isGroup) ...[
            AvatarWidget(name: message.senderName ?? '?', size: 28, showStatus: false),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isSent ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isSent && widget.isGroup && message.senderName != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 4),
                    child: Text(
                      message.senderName!,
                      style: TextStyle(
                        color: _getSenderColor(message.senderName!),
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
                    onLongPress: () => _showContextMenu(message),
                    child: Column(
                      crossAxisAlignment: isSent ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        if (message.replyTo != null) _buildReplyPreview(message.replyTo!, isSent),
                        message.type == MessageType.image
                            ? _buildImageMessage(isSent, message)
                            : _buildTextBubble(isSent, message),
                        if (message.reactions != null && message.reactions!.isNotEmpty)
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
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('chat_rooms')
          .doc(_getChatRoomId())
          .collection('messages')
          .doc(replyId)
          .get(),
      builder: (context, snapshot) {
        String replyText = 'Tin nhắn đã bị xóa';
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          replyText = data['type'] == 'image' ? '📷 Hình ảnh' : data['text'];
        }
        return Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(8),
            border: Border(left: BorderSide(color: isMe ? Colors.white70 : AppColors.primary, width: 3)),
          ),
          child: Text(
            replyText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white60, fontSize: 12, fontStyle: FontStyle.italic),
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
            child: Text('${e.key} ${e.value.length}', style: const TextStyle(fontSize: 10)),
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
        border: isSent ? null : Border.all(color: AppColors.glassBorder, width: 0.5),
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
                  color: isSent ? Colors.white.withOpacity(0.7) : AppColors.textMuted,
                  fontSize: 11,
                  fontFamily: 'Inter',
                ),
              ),
              if (isSent) ...[
                const SizedBox(width: 4),
                Icon(
                  message.isRead ? Icons.done_all_rounded : Icons.done_rounded,
                  color: message.isRead ? const Color(0xFF60A5FA) : Colors.white.withOpacity(0.7),
                  size: 14,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImageMessage(bool isSent, ChatMessage message) {
    return Column(
      crossAxisAlignment: isSent ? CrossAxisAlignment.end : CrossAxisAlignment.start,
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
                  message.text, 
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(child: CircularProgressIndicator(color: AppColors.primaryLight));
                  },
                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image_rounded, color: AppColors.textMuted, size: 48),
                ),
                // Time overlay
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          message.time,
                          style: const TextStyle(color: Colors.white, fontSize: 11),
                        ),
                        if (isSent) ...[
                          const SizedBox(width: 4),
                          Icon(
                            message.isRead ? Icons.done_all_rounded : Icons.done_rounded,
                            color: message.isRead ? const Color(0xFF60A5FA) : Colors.white70,
                            size: 14,
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
                    border: Border.all(color: AppColors.glassBorder, width: 0.5),
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
                          decoration: const InputDecoration(
                            hintText: 'Nhập tin nhắn...',
                            hintStyle: TextStyle(color: AppColors.textMuted),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _sendImage(ImageSource.gallery),
                        child: const Icon(Icons.add_photo_alternate_outlined, color: AppColors.textMuted, size: 22),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => _sendImage(ImageSource.camera),
                        child: const Icon(Icons.camera_alt_outlined, color: AppColors.textMuted, size: 22),
                      ),
                      const SizedBox(width: 12),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _messageController.text.isNotEmpty || _pickedImage != null ? _sendMessage : null,
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
                  child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReplyInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.glassBg,
        borderRadius: BorderRadius.circular(12),
        border: const Border(left: BorderSide(color: AppColors.primary, width: 4)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Trả lời', style: TextStyle(color: AppColors.primaryLight, fontSize: 12, fontWeight: FontWeight.bold)),
                Text(
                  _replyingTo!.type == MessageType.image ? '📷 Hình ảnh' : _replyingTo!.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: AppColors.textMuted),
            onPressed: () => setState(() => _replyingTo = null),
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
      child: const Icon(Icons.add_rounded, color: AppColors.textSecondary, size: 22),
    );
  }

  Widget _buildImagePreview() {
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
            child: Image.file(_pickedImage!, height: 100, width: 100, fit: BoxFit.cover),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: () => setState(() => _pickedImage = null),
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

  void _sendMessage() async {
    final text = _messageController.text.trim();
    final imageToUpload = _pickedImage;
    final replyId = _replyingTo?.id;
    
    if (text.isEmpty && imageToUpload == null) return;

    // Clear UI state
    _messageController.clear();
    if (imageToUpload != null) {
      setState(() => _pickedImage = null);
    }
    setState(() => _replyingTo = null);
    _setMeTyping(false);

    try {
      if (imageToUpload != null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đang tải ảnh lên...')));
        if (widget.isGroup) {
          await _groupService.sendImageMessage(widget.receiverId, currentUserName, imageToUpload);
        } else {
          await _chatService.sendImageMessage(widget.receiverId, imageToUpload);
        }
      }
      
      if (text.isNotEmpty) {
        if (widget.isGroup) {
          await _groupService.sendGroupMessage(widget.receiverId, currentUserName, text, replyTo: replyId);
        } else {
          await _chatService.sendMessage(widget.receiverId, text, replyTo: replyId);
        }
      }
      
      // Scroll to bottom
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 200,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi gửi: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  void _sendImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(source: source, imageQuality: 70);
      if (image != null) {
        setState(() {
          _pickedImage = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi chọn ảnh: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  void _showContextMenu(ChatMessage message) {
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: ['❤️', '😂', '😮', '😢', '👍', '👎'].map((emoji) {
                return GestureDetector(
                  onTap: () {
                    if (widget.isGroup) {
                      _groupService.toggleReaction(widget.receiverId, message.id, emoji);
                    } else {
                      _chatService.toggleReaction(widget.receiverId, message.id, emoji);
                    }
                    Navigator.pop(context);
                  },
                  child: Text(emoji, style: const TextStyle(fontSize: 28)),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            _buildContextMenuItem(Icons.reply_rounded, 'Trả lời', () {
              Navigator.pop(context);
              setState(() => _replyingTo = message);
            }),
            _buildContextMenuItem(Icons.copy_rounded, 'Sao chép', () {
              Clipboard.setData(ClipboardData(text: message.text));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã sao chép')));
            }),
            if (message.senderName == currentUserId)
              _buildContextMenuItem(Icons.delete_outline_rounded, 'Thu hồi', () async {
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(context);
                if (widget.isGroup) {
                  await _groupService.deleteMessage(widget.receiverId, message.id);
                } else {
                  await _chatService.deleteMessage(widget.receiverId, message.id);
                }
                messenger.showSnackBar(const SnackBar(content: Text('Đã thu hồi')));
              }, color: AppColors.error),
          ],
        ),
      ),
    );
  }

  Widget _buildContextMenuItem(IconData icon, String label, VoidCallback onTap, {Color? color}) {
    return ListTile(
      leading: Icon(icon, color: color ?? AppColors.textPrimary),
      title: Text(label, style: TextStyle(color: color ?? AppColors.textPrimary)),
      onTap: onTap,
    );
  }
}
