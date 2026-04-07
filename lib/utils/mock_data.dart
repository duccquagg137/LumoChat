import '../models/chat_models.dart';

class MockData {
  static const List<ChatUser> users = [
    ChatUser(id: '1', name: 'Nguyễn Văn A', isOnline: true, bio: 'Xin chào thế giới'),
    ChatUser(id: '2', name: 'Trần Thị B', isOnline: false, bio: 'Nhà thiết kế UI/UX'),
    ChatUser(id: '3', name: 'Lê Hoàng C', isOnline: true),
    ChatUser(id: '4', name: 'Phạm Minh D', isOnline: false),
    ChatUser(id: '5', name: 'Đoàn Hữu E', isOnline: true),
  ];
}
