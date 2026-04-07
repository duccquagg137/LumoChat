import 'package:cloud_firestore/cloud_firestore.dart';

class ChatUser {
  final String id;
  final String name;
  final String avatar;
  final bool isOnline;
  final String? bio;
  final String? username;

  const ChatUser({
    required this.id,
    required this.name,
    this.avatar = '',
    this.isOnline = false,
    this.bio,
    this.username,
  });

  factory ChatUser.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      return ChatUser(id: doc.id, name: 'Unknown');
    }
    return ChatUser(
      id: data['uid'] ?? doc.id,
      name: data['name'] ?? 'No Name',
      avatar: data['avatar'] ?? '',
      isOnline: data['isOnline'] ?? false,
      bio: data['bio'],
      username: data['email'], // Using email as username fallback
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': id,
      'name': name,
      'avatar': avatar,
      'isOnline': isOnline,
      'bio': bio,
      'email': username,
    };
  }
}

class Conversation {
  final String id;
  final ChatUser user;
  final String lastMessage;
  final String time;
  final int unreadCount;
  final bool isTyping;
  final bool isGroup;
  final int memberCount;
  final bool isPinned;

  const Conversation({
    required this.id,
    required this.user,
    required this.lastMessage,
    required this.time,
    this.unreadCount = 0,
    this.isTyping = false,
    this.isGroup = false,
    this.memberCount = 0,
    this.isPinned = false,
  });
}

class ChatMessage {
  final String id;
  final String text;
  final bool isSent;
  final String time;
  final MessageType type;
  final String? senderId;
  final String? senderName;
  final bool isRead;
  final String? replyTo; // ID tin nhắn đang trả lời
  final Map<String, dynamic>? reactions; // Map của emoji: [userIds]
  final List<String> deletedFor;
  final bool isRecalledForEveryone;

  const ChatMessage({
    required this.id,
    required this.text,
    required this.isSent,
    required this.time,
    this.type = MessageType.text,
    this.senderId,
    this.senderName,
    this.isRead = false,
    this.replyTo,
    this.reactions,
    this.deletedFor = const [],
    this.isRecalledForEveryone = false,
  });

  factory ChatMessage.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      return ChatMessage(id: doc.id, text: '', isSent: false, time: '');
    }

    final String textData = data['text'] ?? '';
    final String timeStr = _formatTimestamp(data['timestamp']);
    final String? senderId = data['senderId']?.toString();
    final String? senderName = data['senderName']?.toString();
    final String rawType = data['type']?.toString() ?? 'text';

    MessageType type;
    switch (rawType) {
      case 'image':
        type = MessageType.image;
        break;
      case 'system':
        type = MessageType.system;
        break;
      case 'emoji':
        type = MessageType.emoji;
        break;
      case 'deleted':
        type = MessageType.deleted;
        break;
      default:
        type = MessageType.text;
    }

    final rawReactions = data['reactions'];
    Map<String, dynamic>? parsedReactions;
    if (rawReactions is Map) {
      parsedReactions = rawReactions.map(
        (key, value) => MapEntry(key.toString(), value),
      );
    }
    final deletedFor = List<dynamic>.from(data['deletedFor'] ?? const [])
        .map((e) => e.toString())
        .toList();
    final isRecalledForEveryone = data['recalledForEveryone'] == true || rawType == 'deleted';

    return ChatMessage(
      id: doc.id,
      text: textData,
      isSent: false, // This will be calculated in UI based on senderId
      time: timeStr,
      senderId: senderId,
      senderName: senderName,
      isRead: data['isRead'] ?? false,
      type: type,
      replyTo: data['replyTo'],
      reactions: parsedReactions,
      deletedFor: deletedFor,
      isRecalledForEveryone: isRecalledForEveryone,
    );
  }

  static String _formatTimestamp(dynamic timestamp) {
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
    return '';
  }
}

enum MessageType { text, image, system, emoji, deleted }
