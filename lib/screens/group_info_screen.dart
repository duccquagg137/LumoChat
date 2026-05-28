import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chat_models.dart';
import '../services/app_providers.dart';
import '../theme/app_theme.dart';
import '../utils/l10n.dart';
import '../widgets/glass_card.dart';
import 'user_profile_screen.dart';

enum GroupInfoAction { openSearch }

class _GroupInfoUiState {
  const _GroupInfoUiState({
    this.isPinned = false,
    this.isLoadingPin = true,
    this.isActionRunning = false,
    this.memberIds = const <String>[],
  });

  final bool isPinned;
  final bool isLoadingPin;
  final bool isActionRunning;
  final List<String> memberIds;

  _GroupInfoUiState copyWith({
    bool? isPinned,
    bool? isLoadingPin,
    bool? isActionRunning,
    List<String>? memberIds,
  }) {
    return _GroupInfoUiState(
      isPinned: isPinned ?? this.isPinned,
      isLoadingPin: isLoadingPin ?? this.isLoadingPin,
      isActionRunning: isActionRunning ?? this.isActionRunning,
      memberIds: memberIds ?? this.memberIds,
    );
  }
}

class _GroupInfoUiController extends StateNotifier<_GroupInfoUiState> {
  _GroupInfoUiController() : super(const _GroupInfoUiState());

  void initializeMembers(List<String> memberIds) {
    if (state.memberIds.isNotEmpty || memberIds.isEmpty) return;
    state = state.copyWith(memberIds: memberIds);
  }

  void setPinned(bool value) {
    state = state.copyWith(isPinned: value);
  }

  void setLoadingPin(bool value) {
    state = state.copyWith(isLoadingPin: value);
  }

  void setActionRunning(bool value) {
    state = state.copyWith(isActionRunning: value);
  }

  void setMembers(List<String> ids) {
    state = state.copyWith(memberIds: ids);
  }
}

final _groupInfoUiControllerProvider = StateNotifierProvider.autoDispose<
    _GroupInfoUiController,
    _GroupInfoUiState>((ref) => _GroupInfoUiController());

final _groupInfoMembersProvider =
    FutureProvider.autoDispose.family<List<ChatUser>, String>((ref, key) async {
  final memberIds = _memberIdsFromKey(key);
  if (memberIds.isEmpty) return const <ChatUser>[];

  const chunkSize = 10;
  final futures = <Future<QuerySnapshot<Map<String, dynamic>>>>[];
  for (int i = 0; i < memberIds.length; i += chunkSize) {
    final end =
        (i + chunkSize < memberIds.length) ? i + chunkSize : memberIds.length;
    final chunk = memberIds.sublist(i, end);
    futures.add(
      FirebaseFirestore.instance
          .collection('users')
          .where(FieldPath.documentId, whereIn: chunk)
          .get(),
    );
  }

  final snapshots = await Future.wait(futures);
  final users = <ChatUser>[];
  for (final snap in snapshots) {
    users.addAll(snap.docs.map(ChatUser.fromDocument));
  }
  users.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return users;
});

String _memberIdsKey(List<String> memberIds) {
  final sorted = memberIds.toSet().toList()..sort();
  return sorted.join('|');
}

List<String> _memberIdsFromKey(String key) {
  if (key.isEmpty) return const <String>[];
  return key.split('|').where((id) => id.isNotEmpty).toList(growable: false);
}

class GroupInfoScreen extends ConsumerStatefulWidget {
  final String groupId;
  final String groupName;
  final int memberCount;
  final List<String> memberIds;

  const GroupInfoScreen({
    super.key,
    required this.groupId,
    required this.groupName,
    required this.memberCount,
    this.memberIds = const [],
  });

  @override
  ConsumerState<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends ConsumerState<GroupInfoScreen> {
  String get _currentUserId => ref.read(currentUserIdProvider);

  bool _isEnglish(BuildContext context) =>
      Localizations.localeOf(context).languageCode == 'en';

  String _txt(
    BuildContext context, {
    required String vi,
    required String en,
  }) {
    return _isEnglish(context) ? en : vi;
  }

  @override
  void initState() {
    super.initState();
    ref
        .read(_groupInfoUiControllerProvider.notifier)
        .initializeMembers(widget.memberIds);
    _loadPinState();
    _loadMembersIfMissing();
  }

  Future<void> _loadPinState() async {
    if (_currentUserId.isEmpty) return;
    try {
      final myDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId)
          .get();
      final data = myDoc.data() ?? const <String, dynamic>{};
      final groupMeta = data['groupMeta'];
      bool pinned = false;
      if (groupMeta is Map && groupMeta[widget.groupId] is Map) {
        pinned = (groupMeta[widget.groupId] as Map)['pinned'] == true;
      }
      if (!mounted) return;
      ref.read(_groupInfoUiControllerProvider.notifier).setPinned(pinned);
    } catch (_) {
    } finally {
      if (mounted) {
        ref.read(_groupInfoUiControllerProvider.notifier).setLoadingPin(false);
      }
    }
  }

  Future<void> _loadMembersIfMissing() async {
    if (ref.read(_groupInfoUiControllerProvider).memberIds.isNotEmpty) return;
    try {
      final groupDoc = await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .get();
      final data = groupDoc.data() ?? const <String, dynamic>{};
      final raw = data['members'];
      if (raw is! Iterable) return;
      final ids = raw
          .map((e) => e.toString())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList();
      if (!mounted) return;
      ref.read(_groupInfoUiControllerProvider.notifier).setMembers(ids);
    } catch (_) {}
  }

  Future<void> _togglePin() async {
    final uiController = ref.read(_groupInfoUiControllerProvider.notifier);
    final uiState = ref.read(_groupInfoUiControllerProvider);
    if (uiState.isActionRunning) return;
    final nextPinned = !uiState.isPinned;
    uiController.setActionRunning(true);
    try {
      await ref.read(groupServiceProvider).setGroupPinned(
            widget.groupId,
            nextPinned,
          );
      if (!mounted) return;
      uiController.setPinned(nextPinned);
      final l10n = context.l10n;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              nextPinned ? l10n.groupsPinSuccess : l10n.groupsUnpinSuccess),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.commonUnexpectedError)),
      );
    } finally {
      if (mounted) {
        uiController.setActionRunning(false);
      }
    }
  }

  Future<void> _leaveGroup() async {
    final uiController = ref.read(_groupInfoUiControllerProvider.notifier);
    if (ref.read(_groupInfoUiControllerProvider).isActionRunning) return;
    final l10n = context.l10n;
    final accepted = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: AppColors.bgSurface,
            title: Text(
              _txt(context, vi: 'Xác nhận rời nhóm', en: 'Leave group?'),
              style: TextStyle(color: AppColors.textPrimary),
            ),
            content: Text(
              _txt(
                context,
                vi: 'Bạn có chắc muốn rời nhóm "${widget.groupName}"?',
                en: 'Do you want to leave "${widget.groupName}"?',
              ),
              style: TextStyle(color: AppColors.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(l10n.commonCancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(l10n.commonLeave),
              ),
            ],
          ),
        ) ??
        false;

    if (!accepted) return;
    uiController.setActionRunning(true);
    try {
      await ref.read(groupServiceProvider).leaveGroup(widget.groupId);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.groupsLeaveSuccess)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.commonUnexpectedError)),
      );
    } finally {
      if (mounted) {
        uiController.setActionRunning(false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final uiState = ref.watch(_groupInfoUiControllerProvider);
    final members = uiState.memberIds;
    final headerLetter = widget.groupName.trim().isEmpty
        ? 'G'
        : widget.groupName.trim().substring(0, 1).toUpperCase();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.bgSurface,
        title: Text(
          _txt(context, vi: 'Thông tin nhóm', en: 'Group info'),
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontFamily: 'Inter',
          ),
        ),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GlassCard(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      gradient: AppGradients.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        headerLetter,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.groupName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Inter',
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.groupsMemberCount(members.isEmpty
                              ? widget.memberCount
                              : members.length),
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 13,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            GlassCard(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(
                      uiState.isPinned
                          ? Icons.push_pin_rounded
                          : Icons.push_pin_outlined,
                      color: AppColors.primaryLight,
                    ),
                    title: Text(
                      uiState.isPinned ? l10n.commonUnpin : l10n.commonPin,
                      style: TextStyle(
                          color: AppColors.textPrimary, fontFamily: 'Inter'),
                    ),
                    onTap: uiState.isLoadingPin || uiState.isActionRunning
                        ? null
                        : _togglePin,
                  ),
                  ListTile(
                    leading: Icon(Icons.search_rounded,
                        color: AppColors.primaryLight),
                    title: Text(
                      _txt(context,
                          vi: 'Tìm kiếm trong nhóm', en: 'Search in group'),
                      style: TextStyle(
                          color: AppColors.textPrimary, fontFamily: 'Inter'),
                    ),
                    onTap: () =>
                        Navigator.pop(context, GroupInfoAction.openSearch),
                  ),
                  ListTile(
                    leading: const Icon(Icons.logout_rounded,
                        color: AppColors.error),
                    title: Text(
                      l10n.commonLeave,
                      style: const TextStyle(
                          color: AppColors.error, fontFamily: 'Inter'),
                    ),
                    onTap: uiState.isActionRunning ? null : _leaveGroup,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              _txt(context, vi: 'Thành viên', en: 'Members'),
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                fontFamily: 'Inter',
              ),
            ),
            const SizedBox(height: 8),
            ref.watch(_groupInfoMembersProvider(_memberIdsKey(members))).when(
              loading: () {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                );
              },
              error: (_, __) {
                return GlassCard(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    _txt(context,
                        vi: 'ChÆ°a cÃ³ dá»¯ liá»‡u thÃ nh viÃªn.',
                        en: 'No member data available.'),
                    style: TextStyle(
                        color: AppColors.textMuted, fontFamily: 'Inter'),
                  ),
                );
              },
              data: (users) {
                if (users.isEmpty) {
                  return GlassCard(
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      _txt(context,
                          vi: 'Chưa có dữ liệu thành viên.',
                          en: 'No member data available.'),
                      style: TextStyle(
                          color: AppColors.textMuted, fontFamily: 'Inter'),
                    ),
                  );
                }

                return GlassCard(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    children: users.map((user) {
                      final isMe = user.id == _currentUserId;
                      return ListTile(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => UserProfileScreen(
                                userId: user.id,
                              ),
                            ),
                          );
                        },
                        leading: AvatarWidget(
                          name: user.name,
                          imageUrl: user.avatar,
                          size: 40,
                          isOnline: user.isOnline,
                          showStatus: true,
                        ),
                        title: Text(
                          user.name,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Inter',
                          ),
                        ),
                        subtitle: Text(
                          isMe
                              ? _txt(context, vi: 'Bạn', en: 'You')
                              : (user.isOnline
                                  ? l10n.commonOnline
                                  : l10n.commonOffline),
                          style: TextStyle(
                            color: user.isOnline
                                ? AppColors.accentGreen
                                : AppColors.textMuted,
                            fontSize: 12,
                            fontFamily: 'Inter',
                          ),
                        ),
                        trailing: Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.textMuted,
                          size: 20,
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
