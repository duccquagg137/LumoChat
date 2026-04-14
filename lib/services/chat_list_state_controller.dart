import 'package:flutter_riverpod/flutter_riverpod.dart';

class ChatListUiState {
  const ChatListUiState({
    this.searchQuery = '',
    this.busyChatIds = const <String>{},
  });

  final String searchQuery;
  final Set<String> busyChatIds;

  ChatListUiState copyWith({
    String? searchQuery,
    Set<String>? busyChatIds,
  }) {
    return ChatListUiState(
      searchQuery: searchQuery ?? this.searchQuery,
      busyChatIds: busyChatIds ?? this.busyChatIds,
    );
  }
}

class ChatListUiController extends StateNotifier<ChatListUiState> {
  ChatListUiController() : super(const ChatListUiState());

  void setSearchQuery(String value) {
    state = state.copyWith(searchQuery: value.trim().toLowerCase());
  }

  bool beginAction(String roomId) {
    if (state.busyChatIds.contains(roomId)) return false;
    state = state.copyWith(
      busyChatIds: <String>{...state.busyChatIds, roomId},
    );
    return true;
  }

  void endAction(String roomId) {
    if (!state.busyChatIds.contains(roomId)) return;
    final nextBusy = <String>{...state.busyChatIds}..remove(roomId);
    state = state.copyWith(busyChatIds: nextBusy);
  }
}

final chatListUiControllerProvider =
    StateNotifierProvider.autoDispose<ChatListUiController, ChatListUiState>(
  (ref) => ChatListUiController(),
);
