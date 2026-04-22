import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/call_models.dart';
import '../services/app_providers.dart';
import '../services/incoming_call_coordinator.dart';
import '../services/push_notification_service.dart';
import '../theme/app_theme.dart';
import '../utils/l10n.dart';
import 'chat_list_screen.dart';
import 'call_session_screen.dart';
import 'contacts_screen.dart';
import 'groups_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _incomingCallSubscription;

  @override
  void initState() {
    super.initState();
    _recordLastScreen();
    _listenIncomingCalls();
    unawaited(PushNotificationService().initForCurrentUser());
  }

  void _listenIncomingCalls() {
    final callService = ref.read(callServiceProvider);
    _incomingCallSubscription?.cancel();
    _incomingCallSubscription = callService
        .watchIncomingRingingCalls()
        .listen((snapshot) {
      if (!mounted) return;
      for (final doc in snapshot.docs) {
        final call = AppCall.fromDocument(doc);
        _presentIncomingCall(call);
        break;
      }
    });
  }

  void _presentIncomingCall(AppCall call) {
    if (!IncomingCallCoordinator.tryAcquire(call.id)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        IncomingCallCoordinator.release(call.id);
        return;
      }
      Navigator.of(context, rootNavigator: true)
          .push(
            MaterialPageRoute(
              fullscreenDialog: true,
              builder: (_) => CallSessionScreen.incoming(
                callId: call.id,
                peerId: call.callerId,
                peerName: call.callerName,
                peerAvatar: call.callerAvatar,
                callType: call.type,
              ),
            ),
          )
          .whenComplete(() => IncomingCallCoordinator.release(call.id));
    });
  }

  void _recordLastScreen([int? tabIndex]) {
    final currentIndex = tabIndex ?? ref.read(homeTabIndexProvider);
    ref.read(authServiceProvider).updateLastScreen({
      'name': 'home',
      'tabIndex': currentIndex,
    });
  }

  final _screens = const [
    ChatListScreen(),
    GroupsScreen(),
    ContactsScreen(),
    ProfileScreen(),
  ];

  @override
  void dispose() {
    _incomingCallSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final currentIndex = ref.watch(homeTabIndexProvider);

    return Scaffold(
      body: IndexedStack(
        index: currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.bgSurface,
          border: Border(
            top: BorderSide(color: AppColors.glassBorder, width: 0.5),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  0,
                  Icons.chat_bubble_rounded,
                  Icons.chat_bubble_outlined,
                  l10n.navChats,
                  0,
                ),
                _buildNavItem(
                  1,
                  Icons.group_rounded,
                  Icons.group_outlined,
                  l10n.navGroups,
                  0,
                ),
                _buildNavItem(
                  2,
                  Icons.contacts_rounded,
                  Icons.contacts_outlined,
                  l10n.navContacts,
                  0,
                ),
                _buildNavItem(
                  3,
                  Icons.person_rounded,
                  Icons.person_outline_rounded,
                  l10n.navProfile,
                  0,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData activeIcon,
    IconData icon,
    String label,
    int badge,
  ) {
    final currentIndex = ref.watch(homeTabIndexProvider);
    final isActive = currentIndex == index;
    return GestureDetector(
      onTap: () {
        ref.read(homeTabIndexProvider.notifier).state = index;
        _recordLastScreen(index);
      },
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: isActive
                        ? AppColors.primary.withAlphaFraction(0.15)
                        : Colors.transparent,
                  ),
                  child: Icon(
                    isActive ? activeIcon : icon,
                    color: isActive ? AppColors.primary : AppColors.textMuted,
                    size: 24,
                  ),
                ),
                if (badge > 0)
                  Positioned(
                    right: 4,
                    top: -4,
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        gradient: AppGradients.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          badge > 99 ? '99+' : '$badge',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: isActive ? AppColors.primary : AppColors.textMuted,
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                fontFamily: 'Inter',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
