import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chat_models.dart';
import '../services/app_providers.dart';
import '../theme/app_theme.dart';
import '../utils/app_logger.dart';
import '../utils/error_mapper.dart';
import '../utils/l10n.dart';
import '../widgets/glass_card.dart';
import 'chat_screen.dart';

enum _ContactsFilter { all, requests, friends, discover }

class _ContactsUiState {
  const _ContactsUiState({
    this.activeFilter = _ContactsFilter.all,
    this.searchQuery = '',
    this.busyUserIds = const <String>{},
  });

  final _ContactsFilter activeFilter;
  final String searchQuery;
  final Set<String> busyUserIds;

  _ContactsUiState copyWith({
    _ContactsFilter? activeFilter,
    String? searchQuery,
    Set<String>? busyUserIds,
  }) {
    return _ContactsUiState(
      activeFilter: activeFilter ?? this.activeFilter,
      searchQuery: searchQuery ?? this.searchQuery,
      busyUserIds: busyUserIds ?? this.busyUserIds,
    );
  }
}

class _ContactsUiController extends StateNotifier<_ContactsUiState> {
  _ContactsUiController() : super(const _ContactsUiState());

  void setFilter(_ContactsFilter filter) {
    if (state.activeFilter == filter) return;
    state = state.copyWith(activeFilter: filter);
  }

  void setSearchQuery(String value) {
    state = state.copyWith(searchQuery: value.trim().toLowerCase());
  }

  bool beginAction(String userId) {
    if (state.busyUserIds.contains(userId)) return false;
    state = state.copyWith(
      busyUserIds: <String>{...state.busyUserIds, userId},
    );
    return true;
  }

  void endAction(String userId) {
    if (!state.busyUserIds.contains(userId)) return;
    state = state.copyWith(
      busyUserIds: <String>{...state.busyUserIds}..remove(userId),
    );
  }
}

final _contactsUiControllerProvider =
    StateNotifierProvider.autoDispose<_ContactsUiController, _ContactsUiState>(
  (ref) => _ContactsUiController(),
);

final _contactsCurrentUserDocumentProvider = StreamProvider.autoDispose
    .family<DocumentSnapshot<Map<String, dynamic>>, String>((ref, userId) {
  return FirebaseFirestore.instance.collection('users').doc(userId).snapshots();
});

final _contactsUsersProvider = StreamProvider.autoDispose
    .family<QuerySnapshot<Map<String, dynamic>>, String>((ref, _) {
  return FirebaseFirestore.instance.collection('users').snapshots();
});

class ContactsScreen extends ConsumerStatefulWidget {
  const ContactsScreen({super.key});

  @override
  ConsumerState<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends ConsumerState<ContactsScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Set<String> _readIdSet(dynamic raw) {
    if (raw is! Iterable) return <String>{};
    return raw.map((e) => e.toString()).where((e) => e.isNotEmpty).toSet();
  }

  String _normalize(String value) => value.trim().toLowerCase();

  int _compareByName(ChatUser a, ChatUser b) {
    return _normalize(a.name).compareTo(_normalize(b.name));
  }

  int _compareByOnlineThenName(ChatUser a, ChatUser b) {
    if (a.isOnline != b.isOnline) {
      return a.isOnline ? -1 : 1;
    }
    return _compareByName(a, b);
  }

  bool _matchSearch(ChatUser user, String searchQuery) {
    if (searchQuery.isEmpty) return true;
    final name = _normalize(user.name);
    final bio = _normalize(user.bio ?? '');
    final username = _normalize(user.username ?? '');
    return name.contains(searchQuery) ||
        bio.contains(searchQuery) ||
        username.contains(searchQuery);
  }

  bool _showSection(_ContactsFilter activeFilter, _ContactsFilter filter) {
    return activeFilter == _ContactsFilter.all || activeFilter == filter;
  }

  void _setFilter(_ContactsFilter filter) {
    ref.read(_contactsUiControllerProvider.notifier).setFilter(filter);
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 220), () {
      if (!mounted) return;
      ref.read(_contactsUiControllerProvider.notifier).setSearchQuery(value);
    });
  }

  Future<void> _runAction(
      String userId, Future<void> Function() action, String successText) async {
    final controller = ref.read(_contactsUiControllerProvider.notifier);
    if (!controller.beginAction(userId)) return;
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(successText)));
    } catch (e, stackTrace) {
      final reason = AppErrorMapper.mapContacts(e);
      AppLogger.error(
        'Contacts action failed',
        tag: 'contacts',
        error: e,
        stackTrace: stackTrace,
        context: {
          'operation': 'contacts.user_action',
          'userId': userId,
          'reason': reason.name,
        },
      );
      if (!mounted) return;
      final shouldOfferRetry = AppErrorMapper.isRetryableForContacts(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n
              .contactsActionFailed(AppErrorText.forContacts(context, e))),
          backgroundColor: AppColors.error,
          action: shouldOfferRetry
              ? SnackBarAction(
                  label: context.l10n.commonRetry,
                  onPressed: () => _runAction(userId, action, successText),
                )
              : null,
        ),
      );
    } finally {
      controller.endAction(userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final uiState = ref.watch(_contactsUiControllerProvider);
    final currentUserId = ref.watch(currentUserIdProvider);

    return Scaffold(
      body: currentUserId.isEmpty
          ? Center(
              child: Text(l10n.commonErrorUnauthenticated,
                  style: TextStyle(color: AppColors.textMuted)),
            )
          : ref.watch(_contactsCurrentUserDocumentProvider(currentUserId)).when(
              error: (_, __) {
                return Center(
                    child: Text(l10n.contactsLoadProfileError,
                        style: TextStyle(color: AppColors.textMuted)));
              },
              loading: () {
                return const Center(
                    child: CircularProgressIndicator(color: AppColors.primary));
              },
              data: (mySnapshot) {
                final myData = mySnapshot.data() ?? const <String, dynamic>{};
                final friendIds = _readIdSet(myData['friends']);
                final receivedRequestIds =
                    _readIdSet(myData['friendRequestsReceived']);
                final sentRequestIds = _readIdSet(myData['friendRequestsSent']);

                return ref.watch(_contactsUsersProvider(currentUserId)).when(
                  error: (_, __) {
                    return Center(
                        child: Text(l10n.contactsLoadContactsError,
                            style: TextStyle(color: AppColors.textMuted)));
                  },
                  loading: () {
                    return const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.primary));
                  },
                  data: (usersSnapshot) {
                    final allUsers = usersSnapshot.docs
                        .map((doc) => ChatUser.fromDocument(doc))
                        .where((user) => user.id != currentUserId)
                        .toList()
                      ..sort(_compareByName);

                    final friends = <ChatUser>[];
                    final receivedRequests = <ChatUser>[];
                    final sentRequests = <ChatUser>[];
                    final suggestions = <ChatUser>[];

                    for (final user in allUsers) {
                      if (!_matchSearch(user, uiState.searchQuery)) continue;
                      if (friendIds.contains(user.id)) {
                        friends.add(user);
                      } else if (receivedRequestIds.contains(user.id)) {
                        receivedRequests.add(user);
                      } else if (sentRequestIds.contains(user.id)) {
                        sentRequests.add(user);
                      } else {
                        suggestions.add(user);
                      }
                    }

                    friends.sort(_compareByOnlineThenName);
                    receivedRequests.sort(_compareByOnlineThenName);
                    sentRequests.sort(_compareByName);
                    suggestions.sort(_compareByOnlineThenName);

                    final onlineFriends =
                        friends.where((u) => u.isOnline).toList();
                    final groupedFriends = <String, List<ChatUser>>{};
                    for (final user in friends) {
                      final letter = user.name.isNotEmpty
                          ? user.name[0].toUpperCase()
                          : '#';
                      groupedFriends.putIfAbsent(letter, () => []).add(user);
                    }
                    final sortedLetters = groupedFriends.keys.toList()..sort();
                    final showRequestsSection = _showSection(
                        uiState.activeFilter, _ContactsFilter.requests);
                    final showFriendsSection = _showSection(
                        uiState.activeFilter, _ContactsFilter.friends);
                    final showDiscoverSection = _showSection(
                        uiState.activeFilter, _ContactsFilter.discover);

                    final hasVisibleData = (showRequestsSection &&
                            (receivedRequests.isNotEmpty ||
                                sentRequests.isNotEmpty)) ||
                        (showFriendsSection && friends.isNotEmpty) ||
                        (showDiscoverSection && suggestions.isNotEmpty);

                    final showOnlineStrip =
                        showFriendsSection && onlineFriends.isNotEmpty;

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
                                colors: [
                                  AppColors.primary.withAlphaFraction(0.12),
                                  Colors.transparent
                                ],
                              ),
                            ),
                          ),
                        ),
                        SafeArea(
                          child: Column(
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(20, 16, 20, 8),
                                child: Row(
                                  children: [
                                    Text(
                                      l10n.navContacts,
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
                                        border: Border.all(
                                            color: AppColors.glassBorder,
                                            width: 0.5),
                                      ),
                                      child: Icon(Icons.people_alt_outlined,
                                          color: AppColors.textPrimary,
                                          size: 20),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 8),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color:
                                        AppColors.bgCard.withAlphaFraction(0.5),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                        color: AppColors.glassBorder),
                                  ),
                                  child: TextField(
                                    controller: _searchController,
                                    onChanged: _onSearchChanged,
                                    style: TextStyle(
                                        color: AppColors.textPrimary,
                                        fontFamily: 'Inter'),
                                    decoration: InputDecoration(
                                      prefixIcon: Icon(Icons.search_rounded,
                                          color: AppColors.textMuted, size: 20),
                                      hintText: l10n.contactsSearchHint,
                                      hintStyle: TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 14,
                                          fontFamily: 'Inter'),
                                      border: InputBorder.none,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 14),
                                    ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 8),
                                child: Row(
                                  children: [
                                    _buildQuickAction(
                                      Icons.mail_outline_rounded,
                                      l10n.contactsQuickInvites,
                                      badge: receivedRequests.length,
                                      isActive: uiState.activeFilter ==
                                          _ContactsFilter.requests,
                                      onTap: () =>
                                          _setFilter(_ContactsFilter.requests),
                                    ),
                                    const SizedBox(width: 12),
                                    _buildQuickAction(
                                      Icons.schedule_send_rounded,
                                      l10n.contactsQuickSent,
                                      badge: sentRequests.length,
                                      isActive: uiState.activeFilter ==
                                          _ContactsFilter.discover,
                                      onTap: () =>
                                          _setFilter(_ContactsFilter.discover),
                                    ),
                                    const SizedBox(width: 12),
                                    _buildQuickAction(
                                      Icons.people_outline_rounded,
                                      l10n.contactsQuickFriends,
                                      badge: friends.length,
                                      isActive: uiState.activeFilter ==
                                          _ContactsFilter.friends,
                                      onTap: () =>
                                          _setFilter(_ContactsFilter.friends),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 2),
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      _buildFilterChip(
                                        label: l10n.contactsFilterAll,
                                        selected: uiState.activeFilter ==
                                            _ContactsFilter.all,
                                        onTap: () =>
                                            _setFilter(_ContactsFilter.all),
                                      ),
                                      _buildFilterChip(
                                        label: l10n.contactsFilterRequests,
                                        selected: uiState.activeFilter ==
                                            _ContactsFilter.requests,
                                        onTap: () => _setFilter(
                                            _ContactsFilter.requests),
                                      ),
                                      _buildFilterChip(
                                        label: l10n.contactsFilterFriends,
                                        selected: uiState.activeFilter ==
                                            _ContactsFilter.friends,
                                        onTap: () =>
                                            _setFilter(_ContactsFilter.friends),
                                      ),
                                      _buildFilterChip(
                                        label: l10n.contactsFilterDiscover,
                                        selected: uiState.activeFilter ==
                                            _ContactsFilter.discover,
                                        onTap: () => _setFilter(
                                            _ContactsFilter.discover),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (showOnlineStrip) ...[
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20),
                                  child: Row(
                                    children: [
                                      Text(
                                        l10n.contactsOnlineFriends(
                                            onlineFriends.length),
                                        style: TextStyle(
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
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16),
                                    itemCount: onlineFriends.length,
                                    itemBuilder: (_, index) {
                                      final user = onlineFriends[index];
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            AvatarWidget(
                                                name: user.name,
                                                imageUrl: user.avatar,
                                                size: 48,
                                                isOnline: true),
                                            const SizedBox(height: 6),
                                            SizedBox(
                                              width: 56,
                                              child: Text(
                                                user.name.split(' ').last,
                                                style: TextStyle(
                                                  color:
                                                      AppColors.textSecondary,
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
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  children: [
                                    if (showRequestsSection &&
                                        receivedRequests.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      _buildSectionTitle(
                                          l10n.contactsSectionFriendRequests),
                                      ...receivedRequests.map((user) {
                                        final isBusy = uiState.busyUserIds
                                            .contains(user.id);
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
                                                          () => ref
                                                              .read(
                                                                  friendServiceProvider)
                                                              .rejectFriendRequest(
                                                                  user.id),
                                                          l10n.contactsRejectedInvite,
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
                                                          () => ref
                                                              .read(
                                                                  friendServiceProvider)
                                                              .acceptFriendRequest(
                                                                  user.id),
                                                          l10n.contactsAcceptedFriend,
                                                        ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }),
                                    ],
                                    if (showRequestsSection &&
                                        sentRequests.isNotEmpty) ...[
                                      const SizedBox(height: 10),
                                      _buildSectionTitle(
                                          l10n.contactsSectionSent),
                                      ...sentRequests.map((user) {
                                        final isBusy = uiState.busyUserIds
                                            .contains(user.id);
                                        return _buildUserItem(
                                          user: user,
                                          subtitle:
                                              l10n.contactsPendingResponse,
                                          trailing: _buildActionText(
                                            label: isBusy
                                                ? l10n.commonLoading
                                                : l10n.commonCancel,
                                            onTap: isBusy
                                                ? null
                                                : () => _runAction(
                                                      user.id,
                                                      () => ref
                                                          .read(
                                                              friendServiceProvider)
                                                          .cancelFriendRequest(
                                                              user.id),
                                                      l10n.contactsCanceledInvite,
                                                    ),
                                          ),
                                        );
                                      }),
                                    ],
                                    if (showFriendsSection &&
                                        friends.isNotEmpty) ...[
                                      const SizedBox(height: 10),
                                      _buildSectionTitle(
                                          l10n.contactsSectionFriends),
                                      ...sortedLetters.map((letter) {
                                        final usersInLetter =
                                            groupedFriends[letter] ?? [];
                                        return Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Padding(
                                              padding:
                                                  const EdgeInsets.fromLTRB(
                                                      12, 14, 0, 8),
                                              child: Text(
                                                letter,
                                                style: TextStyle(
                                                  color: AppColors.primaryLight,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w700,
                                                  fontFamily: 'Inter',
                                                ),
                                              ),
                                            ),
                                            ...usersInLetter.map((user) {
                                              final isBusy = uiState.busyUserIds
                                                  .contains(user.id);
                                              return _buildUserItem(
                                                user: user,
                                                trailing: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    GestureDetector(
                                                      onTap: () {
                                                        Navigator.push(
                                                          context,
                                                          MaterialPageRoute(
                                                            builder: (_) =>
                                                                ChatScreen(
                                                              userName:
                                                                  user.name,
                                                              receiverId:
                                                                  user.id,
                                                              userAvatar:
                                                                  user.avatar,
                                                              isOnline:
                                                                  user.isOnline,
                                                            ),
                                                          ),
                                                        );
                                                      },
                                                      child: _buildCircleAction(
                                                          Icons
                                                              .chat_bubble_outline_rounded),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    GestureDetector(
                                                      onTap: isBusy
                                                          ? null
                                                          : () => _runAction(
                                                                user.id,
                                                                () => ref
                                                                    .read(
                                                                        friendServiceProvider)
                                                                    .unfriend(
                                                                        user.id),
                                                                l10n.contactsUnfriended,
                                                              ),
                                                      child: _buildCircleAction(
                                                        Icons
                                                            .person_remove_outlined,
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
                                    if (showDiscoverSection &&
                                        suggestions.isNotEmpty) ...[
                                      const SizedBox(height: 10),
                                      _buildSectionTitle(
                                          l10n.contactsSectionDiscover),
                                      ...suggestions.map((user) {
                                        final isBusy = uiState.busyUserIds
                                            .contains(user.id);
                                        return _buildUserItem(
                                          user: user,
                                          trailing: _buildActionText(
                                            label: isBusy
                                                ? l10n.commonLoading
                                                : l10n.commonAddFriend,
                                            onTap: isBusy
                                                ? null
                                                : () => _runAction(
                                                      user.id,
                                                      () => ref
                                                          .read(
                                                              friendServiceProvider)
                                                          .sendFriendRequest(
                                                              user.id),
                                                      l10n.contactsSentInvite,
                                                    ),
                                          ),
                                        );
                                      }),
                                    ],
                                    if (!hasVisibleData)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 60),
                                        child: Center(
                                          child: Text(
                                            uiState.searchQuery.isNotEmpty
                                                ? l10n.commonNoSearchResults
                                                : switch (
                                                    uiState.activeFilter) {
                                                    _ContactsFilter.all =>
                                                      l10n.contactsEmptyNoUsers,
                                                    _ContactsFilter.requests =>
                                                      l10n.contactsEmptyRequests,
                                                    _ContactsFilter.friends =>
                                                      l10n.contactsEmptyFriends,
                                                    _ContactsFilter.discover =>
                                                      l10n.contactsEmptyDiscover,
                                                  },
                                            style: TextStyle(
                                                color: AppColors.textMuted,
                                                fontFamily: 'Inter'),
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
        style: TextStyle(
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
    final l10n = context.l10n;

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          AvatarWidget(
              name: user.name,
              imageUrl: user.avatar,
              size: 44,
              isOnline: user.isOnline),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle ??
                      (user.bio?.isNotEmpty == true
                          ? user.bio!
                          : (user.isOnline
                              ? l10n.contactsStatusActive
                              : l10n.contactsStatusOffline)),
                  style: TextStyle(
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

  Widget _buildQuickAction(
    IconData icon,
    String label, {
    int badge = 0,
    bool isActive = false,
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: GlassCard(
          padding: const EdgeInsets.symmetric(vertical: 14),
          borderRadius: 16,
          backgroundColor:
              isActive ? AppColors.primary.withAlphaFraction(0.2) : null,
          border: isActive
              ? Border.all(
                  color: AppColors.primary.withAlphaFraction(0.45), width: 0.8)
              : null,
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
                    style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontFamily: 'Inter'),
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
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withAlphaFraction(0.2)
                : AppColors.glassBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? AppColors.primary.withAlphaFraction(0.4)
                  : AppColors.glassBorder,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color:
                  selected ? AppColors.primaryLight : AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              fontFamily: 'Inter',
            ),
          ),
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
          color: AppColors.primary.withAlphaFraction(0.15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.primary.withAlphaFraction(0.35)),
        ),
        child: Text(
          label,
          style: TextStyle(
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
