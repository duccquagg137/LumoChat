import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/chat_models.dart';
import '../services/group_service.dart';
import '../theme/app_theme.dart';
import '../utils/l10n.dart';
import '../widgets/glass_card.dart';

enum GroupInfoAction { openSearch }

class GroupInfoScreen extends StatefulWidget {
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
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  final GroupService _groupService = GroupService();
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  bool _isPinned = false;
  bool _isLoadingPin = true;
  bool _isActionRunning = false;
  List<String> _memberIds = const [];

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
    _memberIds = widget.memberIds;
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
      setState(() {
        _isPinned = pinned;
      });
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _isLoadingPin = false);
      }
    }
  }

  Future<void> _loadMembersIfMissing() async {
    if (_memberIds.isNotEmpty) return;
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
      setState(() => _memberIds = ids);
    } catch (_) {}
  }

  Future<List<ChatUser>> _loadMembers() async {
    if (_memberIds.isEmpty) return const [];

    const chunkSize = 10;
    final futures = <Future<QuerySnapshot<Map<String, dynamic>>>>[];
    for (int i = 0; i < _memberIds.length; i += chunkSize) {
      final end = (i + chunkSize < _memberIds.length)
          ? i + chunkSize
          : _memberIds.length;
      final chunk = _memberIds.sublist(i, end);
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
  }

  Future<void> _togglePin() async {
    if (_isActionRunning) return;
    final nextPinned = !_isPinned;
    setState(() => _isActionRunning = true);
    try {
      await _groupService.setGroupPinned(widget.groupId, nextPinned);
      if (!mounted) return;
      setState(() => _isPinned = nextPinned);
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
        setState(() => _isActionRunning = false);
      }
    }
  }

  Future<void> _leaveGroup() async {
    if (_isActionRunning) return;
    final l10n = context.l10n;
    final accepted = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: AppColors.bgSurface,
            title: Text(
              _txt(context, vi: 'Xác nhận rời nhóm', en: 'Leave group?'),
              style: const TextStyle(color: AppColors.textPrimary),
            ),
            content: Text(
              _txt(
                context,
                vi: 'Bạn có chắc muốn rời nhóm "${widget.groupName}"?',
                en: 'Do you want to leave "${widget.groupName}"?',
              ),
              style: const TextStyle(color: AppColors.textSecondary),
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
    setState(() => _isActionRunning = true);
    try {
      await _groupService.leaveGroup(widget.groupId);
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
        setState(() => _isActionRunning = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final headerLetter = widget.groupName.trim().isEmpty
        ? 'G'
        : widget.groupName.trim().substring(0, 1).toUpperCase();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.bgSurface,
        title: Text(
          _txt(context, vi: 'Thông tin nhóm', en: 'Group info'),
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontFamily: 'Inter',
          ),
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
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
                    decoration: const BoxDecoration(
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
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Inter',
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.groupsMemberCount(_memberIds.isEmpty
                              ? widget.memberCount
                              : _memberIds.length),
                          style: const TextStyle(
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
                      _isPinned
                          ? Icons.push_pin_rounded
                          : Icons.push_pin_outlined,
                      color: AppColors.primaryLight,
                    ),
                    title: Text(
                      _isPinned ? l10n.commonUnpin : l10n.commonPin,
                      style: const TextStyle(
                          color: AppColors.textPrimary, fontFamily: 'Inter'),
                    ),
                    onTap:
                        _isLoadingPin || _isActionRunning ? null : _togglePin,
                  ),
                  ListTile(
                    leading: const Icon(Icons.search_rounded,
                        color: AppColors.primaryLight),
                    title: Text(
                      _txt(context,
                          vi: 'Tìm kiếm trong nhóm', en: 'Search in group'),
                      style: const TextStyle(
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
                    onTap: _isActionRunning ? null : _leaveGroup,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              _txt(context, vi: 'Thành viên', en: 'Members'),
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                fontFamily: 'Inter',
              ),
            ),
            const SizedBox(height: 8),
            FutureBuilder<List<ChatUser>>(
              future: _loadMembers(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child:
                          CircularProgressIndicator(color: AppColors.primary),
                    ),
                  );
                }

                final users = snapshot.data ?? const <ChatUser>[];
                if (users.isEmpty) {
                  return GlassCard(
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      _txt(context,
                          vi: 'Chưa có dữ liệu thành viên.',
                          en: 'No member data available.'),
                      style: const TextStyle(
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
                        leading: AvatarWidget(
                          name: user.name,
                          imageUrl: user.avatar,
                          size: 40,
                          isOnline: user.isOnline,
                          showStatus: true,
                        ),
                        title: Text(
                          user.name,
                          style: const TextStyle(
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
