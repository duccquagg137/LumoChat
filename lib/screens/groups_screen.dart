import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/chat_models.dart';
import '../services/group_service.dart';
import '../theme/app_theme.dart';
import '../utils/error_mapper.dart';
import '../utils/l10n.dart';
import 'chat_screen.dart';
import 'create_group_screen.dart';

enum _GroupSortMode { recent, name, members }

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _MemberCandidateResult {
  final List<ChatUser> candidates;
  final bool hasFriends;

  const _MemberCandidateResult({
    required this.candidates,
    required this.hasFriends,
  });
}

class _GroupsScreenState extends State<GroupsScreen> {
  final GroupService _groupService = GroupService();
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _busyGroupIds = {};
  _GroupSortMode _sortMode = _GroupSortMode.recent;
  String _searchQuery = '';

  String get _currentUserId => FirebaseAuth.instance.currentUser?.uid ?? '';

  DateTime _groupTimestamp(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    final rawTimestamp = data?['lastTimestamp'];
    if (rawTimestamp is Timestamp) {
      return rawTimestamp.toDate();
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  List<String> _readIdList(dynamic raw) {
    if (raw is! Iterable) return <String>[];
    return raw.map((e) => e.toString()).where((e) => e.isNotEmpty).toSet().toList();
  }

  String _normalize(String value) => value.trim().toLowerCase();

  bool _matchGroup(Map<String, dynamic> data) {
    if (_searchQuery.isEmpty) return true;
    final name = _normalize((data['name'] ?? '').toString());
    final lastMessage = _normalize((data['lastMessage'] ?? '').toString());
    return name.contains(_searchQuery) || lastMessage.contains(_searchQuery);
  }

  int _groupMemberCount(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    return _readIdList(data?['members']).length;
  }

  int _compareByName(DocumentSnapshot a, DocumentSnapshot b) {
    final dataA = a.data() as Map<String, dynamic>? ?? const {};
    final dataB = b.data() as Map<String, dynamic>? ?? const {};
    final nameA = _normalize((dataA['name'] ?? '').toString());
    final nameB = _normalize((dataB['name'] ?? '').toString());
    return nameA.compareTo(nameB);
  }

  void _sortGroups(List<DocumentSnapshot> groups) {
    switch (_sortMode) {
      case _GroupSortMode.recent:
        groups.sort((a, b) => _groupTimestamp(b).compareTo(_groupTimestamp(a)));
        break;
      case _GroupSortMode.name:
        groups.sort(_compareByName);
        break;
      case _GroupSortMode.members:
        groups.sort((a, b) {
          final memberCompare = _groupMemberCount(b).compareTo(_groupMemberCount(a));
          if (memberCompare != 0) return memberCompare;
          return _compareByName(a, b);
        });
        break;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _runGroupAction(String groupId, Future<void> Function() action, String successText) async {
    if (_busyGroupIds.contains(groupId)) return;
    setState(() => _busyGroupIds.add(groupId));
    final l10n = context.l10n;
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(successText)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.groupsActionFailed(AppErrorText.forGroupsL10n(l10n, e)))),
      );
    } finally {
      if (mounted) {
        setState(() => _busyGroupIds.remove(groupId));
      }
    }
  }

  Future<_MemberCandidateResult> _loadAddMemberCandidates(List<String> currentMemberIds) async {
    final myDoc = await FirebaseFirestore.instance.collection('users').doc(_currentUserId).get();
    final myData = myDoc.data() ?? const <String, dynamic>{};
    final friendIds = _readIdList(myData['friends']);
    if (friendIds.isEmpty) {
      return const _MemberCandidateResult(candidates: <ChatUser>[], hasFriends: false);
    }

    final existing = currentMemberIds.toSet();
    final candidates = <ChatUser>[];

    const chunkSize = 10;
    for (int i = 0; i < friendIds.length; i += chunkSize) {
      final end = (i + chunkSize < friendIds.length) ? i + chunkSize : friendIds.length;
      final chunk = friendIds.sublist(i, end);

      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();

      for (final doc in snap.docs) {
        final user = ChatUser.fromDocument(doc);
        if (user.id.isEmpty || user.id == _currentUserId) continue;
        if (existing.contains(user.id)) continue;
        candidates.add(user);
      }
    }

    candidates.sort((a, b) {
      if (a.isOnline != b.isOnline) {
        return a.isOnline ? -1 : 1;
      }
      return _normalize(a.name).compareTo(_normalize(b.name));
    });
    return _MemberCandidateResult(candidates: candidates, hasFriends: true);
  }

  Future<void> _showAddMembersDialog({
    required String groupId,
    required List<String> memberIds,
  }) async {
    final l10n = context.l10n;
    final result = await _loadAddMemberCandidates(memberIds);

    if (!mounted) return;

    if (!result.hasFriends) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.groupsAddMembersNoFriends)));
      return;
    }

    if (result.candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.groupsAddMembersNoCandidates)));
      return;
    }

    final selected = <String>{};
    var dialogQuery = '';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filteredCandidates = result.candidates.where((user) {
              if (dialogQuery.isEmpty) return true;
              final q = _normalize(dialogQuery);
              final name = _normalize(user.name);
              final bio = _normalize(user.bio ?? '');
              return name.contains(q) || bio.contains(q);
            }).toList();

            return AlertDialog(
              backgroundColor: AppColors.bgSurface,
              title: Text(
                l10n.groupsAddMembersDialogTitle,
                style: const TextStyle(color: AppColors.textPrimary),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      onChanged: (value) => setDialogState(() => dialogQuery = value),
                      style: const TextStyle(color: AppColors.textPrimary, fontFamily: 'Inter'),
                      decoration: InputDecoration(
                        hintText: l10n.groupsAddMembersSearchHint,
                        hintStyle: const TextStyle(color: AppColors.textMuted, fontFamily: 'Inter'),
                        prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMuted, size: 20),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.glassBorder.withOpacity(0.5)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.glassBorder.withOpacity(0.5)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.primary.withOpacity(0.7)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 280,
                      child: filteredCandidates.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 24),
                                child: Text(
                                  l10n.commonNoSearchResults,
                                  style: const TextStyle(color: AppColors.textMuted, fontFamily: 'Inter'),
                                ),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: filteredCandidates.length,
                              itemBuilder: (_, index) {
                                final user = filteredCandidates[index];
                                final isSelected = selected.contains(user.id);
                                return CheckboxListTile(
                                  value: isSelected,
                                  onChanged: (value) {
                                    setDialogState(() {
                                      if (value == true) {
                                        selected.add(user.id);
                                      } else {
                                        selected.remove(user.id);
                                      }
                                    });
                                  },
                                  activeColor: AppColors.primary,
                                  title: Text(
                                    user.name,
                                    style: const TextStyle(color: AppColors.textPrimary, fontFamily: 'Inter', fontSize: 14),
                                  ),
                                  subtitle: Text(
                                    user.bio ?? '',
                                    style: const TextStyle(color: AppColors.textMuted, fontFamily: 'Inter', fontSize: 12),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  controlAffinity: ListTileControlAffinity.leading,
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(l10n.commonCancel),
                ),
                TextButton(
                  onPressed: selected.isEmpty
                      ? null
                      : () async {
                          Navigator.pop(dialogContext);
                          await _runGroupAction(
                            groupId,
                            () async {
                              final added = await _groupService.addMembers(groupId, selected.toList());
                              if (added <= 0) return;
                            },
                            l10n.groupsAddMembersSuccess(selected.length),
                          );
                        },
                  child: Text(l10n.commonSave),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmLeaveGroup({required String groupId, required String groupName}) async {
    final l10n = context.l10n;
    final accepted = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: AppColors.bgSurface,
            title: Text(l10n.groupsLeaveConfirmTitle, style: const TextStyle(color: AppColors.textPrimary)),
            content: Text(l10n.groupsLeaveConfirmMessage(groupName), style: const TextStyle(color: AppColors.textSecondary)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(l10n.commonCancel)),
              TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(l10n.commonLeave)),
            ],
          ),
        ) ??
        false;

    if (!accepted) return;

    await _runGroupAction(
      groupId,
      () => _groupService.leaveGroup(groupId),
      l10n.groupsLeaveSuccess,
    );
  }

  Future<void> _confirmDeleteGroup({
    required String groupId,
    required String groupName,
    required bool canDelete,
  }) async {
    final l10n = context.l10n;

    if (!canDelete) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.groupsDeleteNotAllowed)));
      return;
    }

    final accepted = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: AppColors.bgSurface,
            title: Text(l10n.groupsDeleteConfirmTitle, style: const TextStyle(color: AppColors.textPrimary)),
            content: Text(l10n.groupsDeleteConfirmMessage(groupName), style: const TextStyle(color: AppColors.textSecondary)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(l10n.commonCancel)),
              TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(l10n.commonDelete)),
            ],
          ),
        ) ??
        false;

    if (!accepted) return;

    await _runGroupAction(
      groupId,
      () => _groupService.deleteGroup(groupId),
      l10n.groupsDeleteSuccess,
    );
  }

  Future<void> _showGroupActionsSheet({
    required String groupId,
    required String groupName,
    required List<String> members,
    required Map<String, dynamic> groupData,
  }) async {
    final l10n = context.l10n;
    final canDelete = _groupService.canDeleteGroupFromData(groupData);

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
                groupName,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(height: 10),
              ListTile(
                leading: const Icon(Icons.person_add_alt_1_rounded, color: AppColors.primaryLight),
                title: Text(l10n.groupsActionAddMembers, style: const TextStyle(color: AppColors.textPrimary)),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await _showAddMembersDialog(groupId: groupId, memberIds: members);
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout_rounded, color: AppColors.error),
                title: Text(l10n.groupsActionLeaveGroup, style: const TextStyle(color: AppColors.error)),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await _confirmLeaveGroup(groupId: groupId, groupName: groupName);
                },
              ),
              ListTile(
                leading: Icon(Icons.delete_forever_rounded, color: canDelete ? AppColors.error : AppColors.textMuted),
                title: Text(
                  l10n.groupsActionDeleteGroup,
                  style: TextStyle(color: canDelete ? AppColors.error : AppColors.textMuted),
                ),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await _confirmDeleteGroup(
                    groupId: groupId,
                    groupName: groupName,
                    canDelete: canDelete,
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
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      body: Stack(
        children: [
          Positioned(
            top: -80,
            right: -60,
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
                        l10n.groupsTitle,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          fontFamily: 'Inter',
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateGroupScreen()));
                        },
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(
                            gradient: AppGradients.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
                        ),
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
                      onChanged: (value) => setState(() => _searchQuery = _normalize(value)),
                      style: const TextStyle(color: AppColors.textPrimary, fontFamily: 'Inter'),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMuted, size: 20),
                        hintText: l10n.groupsSearchHint,
                        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14, fontFamily: 'Inter'),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 2, 20, 10),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildSortChip(
                          label: l10n.groupsSortRecent,
                          selected: _sortMode == _GroupSortMode.recent,
                          onTap: () => setState(() => _sortMode = _GroupSortMode.recent),
                        ),
                        _buildSortChip(
                          label: l10n.groupsSortName,
                          selected: _sortMode == _GroupSortMode.name,
                          onTap: () => setState(() => _sortMode = _GroupSortMode.name),
                        ),
                        _buildSortChip(
                          label: l10n.groupsSortMembers,
                          selected: _sortMode == _GroupSortMode.members,
                          onTap: () => setState(() => _sortMode = _GroupSortMode.members),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _groupService.getUserGroups(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        final reason = AppErrorText.forGroups(
                          context,
                          snapshot.error ?? Exception('groups-load-error'),
                        );
                        return Center(
                          child: Text(
                            l10n.groupsLoadError(reason),
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.textMuted),
                          ),
                        );
                      }
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                      }

                      final sourceGroups = (snapshot.data?.docs ?? []).toList();
                      final groups = sourceGroups.where((doc) {
                        final data = doc.data() as Map<String, dynamic>? ?? const {};
                        return _matchGroup(data);
                      }).toList();
                      _sortGroups(groups);

                      if (groups.isEmpty) {
                        final emptyText = sourceGroups.isNotEmpty && _searchQuery.isNotEmpty
                            ? l10n.groupsNoSearchResults
                            : l10n.groupsEmpty;
                        return Center(
                          child: Text(
                            emptyText,
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 14, fontFamily: 'Inter'),
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: groups.length,
                        itemBuilder: (context, i) {
                          final doc = groups[i];
                          final data = doc.data() as Map<String, dynamic>;
                          final groupId = doc.id;
                          final name = (data['name'] ?? l10n.groupsUnnamed).toString();
                          final lastMessage = (data['lastMessage'] ?? '').toString();
                          final displayMessage = lastMessage.trim().isEmpty ? l10n.groupsNoMessagesYet : lastMessage;
                          final members = _readIdList(data['members']);

                          String timeTxt = '';
                          if (data['lastTimestamp'] is Timestamp) {
                            final ts = data['lastTimestamp'] as Timestamp;
                            final date = ts.toDate();
                            timeTxt = '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
                          }

                          return Dismissible(
                            key: ValueKey('group-$groupId'),
                            direction: DismissDirection.horizontal,
                            confirmDismiss: (direction) async {
                              if (direction == DismissDirection.startToEnd) {
                                await _showAddMembersDialog(groupId: groupId, memberIds: members);
                                return false;
                              }

                              await _showGroupActionsSheet(
                                groupId: groupId,
                                groupName: name,
                                members: members,
                                groupData: data,
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
                                  const Icon(Icons.person_add_alt_1_rounded, color: AppColors.primaryLight),
                                  const SizedBox(width: 8),
                                  Text(
                                    l10n.groupsActionAddMembers,
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
                            child: _buildGroupItem(context, groupId, name, displayMessage, timeTxt, members.length),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 20,
            bottom: 20,
            child: GestureDetector(
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateGroupScreen()));
              },
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: AppGradients.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 8)),
                  ],
                ),
                child: const Icon(Icons.group_add_rounded, color: Colors.white, size: 26),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortChip({
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
            color: selected ? AppColors.primary.withOpacity(0.2) : AppColors.glassBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.primary.withOpacity(0.4) : AppColors.glassBorder,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? AppColors.primaryLight : AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              fontFamily: 'Inter',
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGroupItem(BuildContext context, String groupId, String name, String lastMessage, String timeStr, int memberCount) {
    final l10n = context.l10n;
    final subtitle = '${l10n.groupsMemberCount(memberCount)} • $lastMessage';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              userName: name,
              receiverId: groupId,
              isGroup: true,
              memberCount: memberCount,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.transparent,
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: AppGradients.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.bgDark, width: 2),
                  ),
                  child: Center(
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'G',
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                Positioned(
                  right: -4,
                  bottom: -4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.bgSurface,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.bgDark, width: 1.5),
                    ),
                    child: const Icon(Icons.group_rounded, color: AppColors.primaryLight, size: 12),
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
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Inter',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        timeStr,
                        style: const TextStyle(
                          color: AppColors.textMuted,
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
                        child: Text(
                          subtitle,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 13,
                            fontFamily: 'Inter',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
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
