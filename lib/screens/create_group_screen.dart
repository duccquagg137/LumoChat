import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../models/chat_models.dart';
import '../services/app_providers.dart';
import '../utils/app_logger.dart';
import '../utils/error_mapper.dart';
import '../utils/l10n.dart';
import 'chat_screen.dart';

class _CreateGroupUiState {
  const _CreateGroupUiState({
    this.selectedIds = const <String>{},
    this.friendNameById = const <String, String>{},
    this.groupAvatar,
    this.searchQuery = '',
    this.isCreatingGroup = false,
    this.isPickingAvatar = false,
  });

  final Set<String> selectedIds;
  final Map<String, String> friendNameById;
  final File? groupAvatar;
  final String searchQuery;
  final bool isCreatingGroup;
  final bool isPickingAvatar;

  _CreateGroupUiState copyWith({
    Set<String>? selectedIds,
    Map<String, String>? friendNameById,
    File? groupAvatar,
    bool clearGroupAvatar = false,
    String? searchQuery,
    bool? isCreatingGroup,
    bool? isPickingAvatar,
  }) {
    return _CreateGroupUiState(
      selectedIds: selectedIds ?? this.selectedIds,
      friendNameById: friendNameById ?? this.friendNameById,
      groupAvatar: clearGroupAvatar ? null : groupAvatar ?? this.groupAvatar,
      searchQuery: searchQuery ?? this.searchQuery,
      isCreatingGroup: isCreatingGroup ?? this.isCreatingGroup,
      isPickingAvatar: isPickingAvatar ?? this.isPickingAvatar,
    );
  }
}

class _CreateGroupUiController extends StateNotifier<_CreateGroupUiState> {
  _CreateGroupUiController() : super(const _CreateGroupUiState());

  void toggleSelected(String userId) {
    final next = <String>{...state.selectedIds};
    if (!next.remove(userId)) {
      next.add(userId);
    }
    state = state.copyWith(selectedIds: next);
  }

  void removeSelected(String userId) {
    if (!state.selectedIds.contains(userId)) return;
    state = state.copyWith(
        selectedIds: <String>{...state.selectedIds}..remove(userId));
  }

  void setFriendNames(Map<String, String> value) {
    state = state.copyWith(friendNameById: value);
  }

  void setSearchQuery(String value) {
    state = state.copyWith(searchQuery: value.trim().toLowerCase());
  }

  void setGroupAvatar(File value) {
    state = state.copyWith(groupAvatar: value);
  }

  void setCreating(bool value) {
    state = state.copyWith(isCreatingGroup: value);
  }

  void setPickingAvatar(bool value) {
    state = state.copyWith(isPickingAvatar: value);
  }
}

final _createGroupUiControllerProvider = StateNotifierProvider.autoDispose<
    _CreateGroupUiController,
    _CreateGroupUiState>((ref) => _CreateGroupUiController());

final _createGroupCurrentUserDocumentProvider = StreamProvider.autoDispose
    .family<DocumentSnapshot<Map<String, dynamic>>, String>((ref, userId) {
  return FirebaseFirestore.instance.collection('users').doc(userId).snapshots();
});

final _createGroupUsersProvider = StreamProvider.autoDispose
    .family<QuerySnapshot<Map<String, dynamic>>, String>((ref, _) {
  return FirebaseFirestore.instance.collection('users').snapshots();
});

class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _descFocusNode = FocusNode();

  Set<String> _readIdSet(dynamic raw) {
    if (raw is! Iterable) return <String>{};
    return raw.map((e) => e.toString()).where((e) => e.isNotEmpty).toSet();
  }

  String _buildAutoGroupName(
    Set<String> selectedIds,
    Map<String, String> friendNameById,
  ) {
    final l10n = context.l10n;
    final names = selectedIds
        .map((id) => (friendNameById[id] ?? '').trim())
        .where((name) => name.isNotEmpty)
        .toList();

    if (names.isEmpty) {
      return l10n.groupsCreateDefaultName;
    }
    if (names.length <= 3) {
      return names.join(', ');
    }
    final preview = names.take(3).join(', ');
    final remain = names.length - 3;
    return '$preview +$remain';
  }

  String _normalize(String value) => value.trim().toLowerCase();

  bool _matchUser(ChatUser user, String searchQuery) {
    if (searchQuery.isEmpty) return true;
    final q = searchQuery;
    final name = _normalize(user.name);
    final bio = _normalize(user.bio ?? '');
    final username = _normalize(user.username ?? '');
    return name.contains(q) || bio.contains(q) || username.contains(q);
  }

  Future<void> _createGroup({
    required String groupName,
    required String description,
    required List<String> memberIds,
    required String creatorName,
  }) async {
    final uiController = ref.read(_createGroupUiControllerProvider.notifier);
    final uiState = ref.read(_createGroupUiControllerProvider);
    if (uiState.isCreatingGroup) return;

    uiController.setCreating(true);
    try {
      final l10n = context.l10n;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.groupsCreateInProgress)),
      );

      final groupService = ref.read(groupServiceProvider);
      final groupId = await groupService.createGroup(
        groupName,
        description,
        memberIds,
        creatorName,
        avatarFile: uiState.groupAvatar,
      );

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            userName: groupName,
            receiverId: groupId,
            isGroup: true,
            memberCount: memberIds.length + 1,
          ),
        ),
      );
    } catch (e, stackTrace) {
      final reason = AppErrorMapper.mapGroups(e);
      AppLogger.error(
        'Create group failed',
        tag: 'groups',
        error: e,
        stackTrace: stackTrace,
        context: {
          'operation': 'groups.create_group',
          'memberCount': memberIds.length + 1,
          'reason': reason.name,
        },
      );
      if (!mounted) return;
      final l10n = context.l10n;
      final canRetry = AppErrorMapper.isRetryableForGroups(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              l10n.groupsCreateFailed(AppErrorText.forGroupsL10n(l10n, e))),
          backgroundColor: AppColors.error,
          action: canRetry
              ? SnackBarAction(
                  label: l10n.commonRetry,
                  onPressed: () => _createGroup(
                    groupName: groupName,
                    description: description,
                    memberIds: memberIds,
                    creatorName: creatorName,
                  ),
                )
              : null,
        ),
      );
    } finally {
      if (mounted) uiController.setCreating(false);
    }
  }

  Future<void> _pickGroupAvatar() async {
    final uiController = ref.read(_createGroupUiControllerProvider.notifier);
    final uiState = ref.read(_createGroupUiControllerProvider);
    if (uiState.isPickingAvatar || uiState.isCreatingGroup) return;
    uiController.setPickingAvatar(true);
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 78,
      );
      if (file == null || !mounted) return;
      uiController.setGroupAvatar(File(file.path));
    } catch (e, stackTrace) {
      final reason = AppErrorMapper.mapGroups(e);
      AppLogger.error(
        'Pick group avatar failed',
        tag: 'groups',
        error: e,
        stackTrace: stackTrace,
        context: {
          'operation': 'groups.pick_avatar',
          'reason': reason.name,
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.commonUnexpectedError)),
      );
    } finally {
      if (mounted) uiController.setPickingAvatar(false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _searchController.dispose();
    _nameFocusNode.dispose();
    _descFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final uiState = ref.watch(_createGroupUiControllerProvider);
    final currentUserId = ref.watch(currentUserIdProvider);

    return Scaffold(
      body: Stack(
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
                    AppColors.primary.withAlphaFraction(0.15),
                    Colors.transparent
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // App bar
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back_ios_rounded,
                            color: AppColors.textPrimary, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Text(
                          l10n.groupsCreateTitle,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: uiState.selectedIds.isNotEmpty
                              ? AppGradients.primary
                              : null,
                          color: uiState.selectedIds.isEmpty
                              ? AppColors.textMuted.withAlphaFraction(0.3)
                              : null,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          l10n.groupsCreateAction,
                          style: TextStyle(
                            color: uiState.selectedIds.isNotEmpty
                                ? Colors.white
                                : AppColors.textMuted,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: currentUserId.isEmpty
                      ? Center(
                          child: Text(
                            l10n.commonErrorUnauthenticated,
                            style: TextStyle(color: AppColors.textMuted),
                          ),
                        )
                      : ref
                          .watch(_createGroupCurrentUserDocumentProvider(
                              currentUserId))
                          .when(
                          error: (_, __) {
                            return Center(
                              child: Text(
                                l10n.groupsCreateLoadProfileError,
                                style: TextStyle(color: AppColors.textMuted),
                              ),
                            );
                          },
                          loading: () {
                            return const Center(
                                child: CircularProgressIndicator(
                                    color: AppColors.primary));
                          },
                          data: (mySnapshot) {
                            final myData =
                                mySnapshot.data() ?? const <String, dynamic>{};
                            final friendIds = _readIdSet(myData['friends']);

                            return ref
                                .watch(_createGroupUsersProvider(currentUserId))
                                .when(
                              error: (_, __) {
                                return Center(
                                  child: Text(
                                    l10n.groupsCreateLoadFriendsError,
                                    style:
                                        TextStyle(color: AppColors.textMuted),
                                  ),
                                );
                              },
                              loading: () {
                                return const Center(
                                    child: CircularProgressIndicator(
                                        color: AppColors.primary));
                              },
                              data: (usersSnapshot) {
                                final allUsers = usersSnapshot.docs
                                    .map((doc) => ChatUser.fromDocument(doc))
                                    .where((u) => u.id != currentUserId)
                                    .where((u) => friendIds.contains(u.id))
                                    .toList()
                                  ..sort((a, b) {
                                    if (a.isOnline != b.isOnline) {
                                      return a.isOnline ? -1 : 1;
                                    }
                                    return _normalize(a.name)
                                        .compareTo(_normalize(b.name));
                                  });
                                final visibleUsers = allUsers
                                    .where((user) =>
                                        _matchUser(user, uiState.searchQuery))
                                    .toList();
                                final friendNameById = {
                                  for (final u in allUsers) u.id: u.name
                                };
                                if (friendNameById.length !=
                                        uiState.friendNameById.length ||
                                    friendNameById.entries.any((entry) =>
                                        uiState.friendNameById[entry.key] !=
                                        entry.value)) {
                                  WidgetsBinding.instance
                                      .addPostFrameCallback((_) {
                                    if (!mounted) return;
                                    ref
                                        .read(_createGroupUiControllerProvider
                                            .notifier)
                                        .setFriendNames(friendNameById);
                                  });
                                }

                                return SingleChildScrollView(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 8),
                                      // Group info card
                                      GlassCard(
                                        padding: const EdgeInsets.all(20),
                                        child: Column(
                                          children: [
                                            // Avatar picker
                                            GestureDetector(
                                              onTap: _pickGroupAvatar,
                                              child: Container(
                                                width: 80,
                                                height: 80,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: AppColors.primary
                                                      .withAlphaFraction(0.15),
                                                  border: Border.all(
                                                      color:
                                                          AppColors.glassBorder,
                                                      width: 1.5),
                                                ),
                                                child: Stack(
                                                  alignment: Alignment.center,
                                                  children: [
                                                    if (uiState.groupAvatar !=
                                                        null)
                                                      ClipOval(
                                                        child: Image.file(
                                                          uiState.groupAvatar!,
                                                          width: 80,
                                                          height: 80,
                                                          fit: BoxFit.cover,
                                                        ),
                                                      )
                                                    else
                                                      Icon(Icons.group_rounded,
                                                          color: AppColors
                                                              .primaryLight,
                                                          size: 36),
                                                    if (uiState.isPickingAvatar)
                                                      Container(
                                                        width: 80,
                                                        height: 80,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors.black
                                                              .withAlphaFraction(
                                                                  0.35),
                                                          shape:
                                                              BoxShape.circle,
                                                        ),
                                                        child: const Center(
                                                          child: SizedBox(
                                                            width: 18,
                                                            height: 18,
                                                            child:
                                                                CircularProgressIndicator(
                                                              strokeWidth: 2,
                                                              color:
                                                                  Colors.white,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    Positioned(
                                                      right: 0,
                                                      bottom: 0,
                                                      child: Container(
                                                        width: 28,
                                                        height: 28,
                                                        decoration:
                                                            BoxDecoration(
                                                          gradient: AppGradients
                                                              .primary,
                                                          shape:
                                                              BoxShape.circle,
                                                          border: Border.all(
                                                              color: AppColors
                                                                  .bgDark,
                                                              width: 2),
                                                        ),
                                                        child: const Icon(
                                                            Icons
                                                                .camera_alt_rounded,
                                                            color: Colors.white,
                                                            size: 14),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 20),
                                            // Group name
                                            _buildInput(
                                              controller: _nameController,
                                              hint: l10n.groupsCreateNameHint,
                                              icon: Icons.edit_rounded,
                                              focusNode: _nameFocusNode,
                                            ),
                                            const SizedBox(height: 12),
                                            // Description
                                            _buildInput(
                                              controller: _descController,
                                              hint: l10n
                                                  .groupsCreateDescriptionHint,
                                              icon: Icons.description_outlined,
                                              focusNode: _descFocusNode,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      // Selected members chips
                                      if (uiState.selectedIds.isNotEmpty) ...[
                                        Text(
                                          l10n.groupsCreateSelectedCount(
                                              uiState.selectedIds.length),
                                          style: TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            fontFamily: 'Inter',
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children:
                                              uiState.selectedIds.map((id) {
                                            final user = allUsers.firstWhere(
                                              (u) => u.id == id,
                                              orElse: () => ChatUser(
                                                  id: '',
                                                  name:
                                                      l10n.profileFallbackUser),
                                            );
                                            return Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 8),
                                              decoration: BoxDecoration(
                                                color: AppColors.primary
                                                    .withAlphaFraction(0.15),
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                                border: Border.all(
                                                    color: AppColors.primary
                                                        .withAlphaFraction(
                                                            0.3)),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  AvatarWidget(
                                                      name: user.name,
                                                      imageUrl: user.avatar,
                                                      size: 24,
                                                      showStatus: false),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    user.name.split(' ').last,
                                                    style: TextStyle(
                                                      color:
                                                          AppColors.textPrimary,
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      fontFamily: 'Inter',
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  GestureDetector(
                                                    onTap: () => ref
                                                        .read(
                                                            _createGroupUiControllerProvider
                                                                .notifier)
                                                        .removeSelected(id),
                                                    child: Icon(
                                                        Icons.close_rounded,
                                                        color:
                                                            AppColors.textMuted,
                                                        size: 16),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                        const SizedBox(height: 20),
                                      ],
                                      Container(
                                        decoration: BoxDecoration(
                                          color: AppColors.bgCard
                                              .withAlphaFraction(0.5),
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          border: Border.all(
                                              color: AppColors.glassBorder),
                                        ),
                                        child: TextField(
                                          controller: _searchController,
                                          onChanged: (value) => ref
                                              .read(
                                                  _createGroupUiControllerProvider
                                                      .notifier)
                                              .setSearchQuery(value),
                                          style: TextStyle(
                                              color: AppColors.textPrimary,
                                              fontFamily: 'Inter'),
                                          decoration: InputDecoration(
                                            prefixIcon: Icon(
                                                Icons.search_rounded,
                                                color: AppColors.textMuted,
                                                size: 20),
                                            hintText:
                                                l10n.groupsCreateSearchHint,
                                            hintStyle: TextStyle(
                                                color: AppColors.textMuted,
                                                fontSize: 14,
                                                fontFamily: 'Inter'),
                                            border: InputBorder.none,
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 14),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      if (allUsers.isEmpty)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 16),
                                          child: Text(
                                            l10n.groupsCreateNoFriends,
                                            style: TextStyle(
                                                color: AppColors.textMuted,
                                                fontFamily: 'Inter'),
                                          ),
                                        )
                                      else if (visibleUsers.isEmpty)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 16),
                                          child: Text(
                                            l10n.commonNoSearchResults,
                                            style: TextStyle(
                                                color: AppColors.textMuted,
                                                fontFamily: 'Inter'),
                                          ),
                                        ),
                                      // Contact list from Firestore
                                      ...visibleUsers.map((user) {
                                        final isSelected = uiState.selectedIds
                                            .contains(user.id);
                                        return GestureDetector(
                                          onTap: () => ref
                                              .read(
                                                  _createGroupUiControllerProvider
                                                      .notifier)
                                              .toggleSelected(user.id),
                                          child: Container(
                                            margin: const EdgeInsets.only(
                                                bottom: 4),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 12),
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              color: isSelected
                                                  ? AppColors.primary
                                                      .withAlphaFraction(0.08)
                                                  : Colors.transparent,
                                            ),
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
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        user.name,
                                                        style: TextStyle(
                                                          color: AppColors
                                                              .textPrimary,
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          fontFamily: 'Inter',
                                                        ),
                                                      ),
                                                      if (user.bio != null)
                                                        Text(
                                                          user.bio!,
                                                          style: TextStyle(
                                                            color: AppColors
                                                                .textMuted,
                                                            fontSize: 12,
                                                            fontFamily: 'Inter',
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                                Container(
                                                  width: 24,
                                                  height: 24,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    gradient: isSelected
                                                        ? AppGradients.primary
                                                        : null,
                                                    border: isSelected
                                                        ? null
                                                        : Border.all(
                                                            color: AppColors
                                                                .textMuted,
                                                            width: 1.5),
                                                  ),
                                                  child: isSelected
                                                      ? const Icon(
                                                          Icons.check_rounded,
                                                          color: Colors.white,
                                                          size: 16)
                                                      : null,
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      }),
                                      const SizedBox(height: 100),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          // Bottom button
          if (uiState.selectedIds.isNotEmpty)
            Positioned(
              left: 20,
              right: 20,
              bottom: MediaQuery.of(context).padding.bottom + 20,
              child: GradientButton(
                text: l10n.groupsCreateButton(uiState.selectedIds.length),
                icon: Icons.group_add_rounded,
                width: double.infinity,
                onPressed: uiState.isCreatingGroup
                    ? null
                    : () async {
                        final localL10n = context.l10n;
                        final typedName = _nameController.text.trim();
                        final desc = _descController.text.trim();
                        final groupName = typedName.isNotEmpty
                            ? typedName
                            : _buildAutoGroupName(
                                uiState.selectedIds,
                                uiState.friendNameById,
                              );
                        final memberIds =
                            uiState.selectedIds.toList(growable: false);

                        final currentUser = FirebaseAuth.instance.currentUser;
                        final creatorName = currentUser?.displayName ??
                            currentUser?.phoneNumber ??
                            localL10n.profileFallbackUser;

                        await _createGroup(
                          groupName: groupName,
                          description: desc,
                          memberIds: memberIds,
                          creatorName: creatorName,
                        );
                      },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInput({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    FocusNode? focusNode,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard.withAlphaFraction(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        style: TextStyle(color: AppColors.textPrimary, fontFamily: 'Inter'),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: AppColors.textMuted, size: 22),
          hintText: hint,
          hintStyle: TextStyle(color: AppColors.textMuted),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}
