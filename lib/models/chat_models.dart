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
  final String? senderName;
  final bool isRead;
  final String? replyTo; // ID tin nhắn đang trả lời
  final Map<String, dynamic>? reactions; // Map của emoji: [userIds]

  const ChatMessage({
    required this.id,
    required this.text,
    required this.isSent,
    required this.time,
    this.type = MessageType.text,
    this.senderName,
    this.isRead = false,
    this.replyTo,
    this.reactions,
  });

  factory ChatMessage.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      return ChatMessage(id: doc.id, text: '', isSent: false, time: '');
    }

    final String textData = data['text'] ?? '';
    final String timeStr = _formatTimestamp(data['timestamp']);
    
    // We check if current user is the sender (will be determined in UI layer or here if we pass currentUserId)
    // Actually, `isSent` is relative. It's better to store `senderId` and compare in UI.
    // For now, let's store senderId in `senderName` temporarily to keep the model signature unchanged, 
    // or we can adjust usages in UI. Let's add `senderId` field.
    return ChatMessage(
      id: doc.id,
      text: textData,
      isSent: false, // This will be calculated in UI based on senderId
      time: timeStr,
      senderName: data['senderId'], // Using this temporary for holding senderId
      isRead: data['isRead'] ?? false,
      type: data['type'] == 'image' ? MessageType.image : MessageType.text,
      replyTo: data['replyTo'],
      reactions: data['reactions'] as Map<String, dynamic>?,
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

enum MessageType { text, image, system, emoji }


