import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_notification_model.dart';
import '../services/app_providers.dart';
import '../theme/app_theme.dart';

final _notificationCenterBusyProvider =
    StateProvider.autoDispose<bool>((ref) => false);

final _myNotificationsProvider =
    StreamProvider.autoDispose<QuerySnapshot<Map<String, dynamic>>>((ref) {
  return ref.watch(notificationServiceProvider).watchMyNotifications();
});

class NotificationCenterScreen extends ConsumerWidget {
  const NotificationCenterScreen({super.key});

  bool _isEnglish(BuildContext context) =>
      Localizations.localeOf(context).languageCode == 'en';

  String _txt(
    BuildContext context, {
    required String vi,
    required String en,
  }) {
    return _isEnglish(context) ? en : vi;
  }

  Future<void> _markAllAsRead(BuildContext context, WidgetRef ref) async {
    final busyController = ref.read(_notificationCenterBusyProvider.notifier);
    if (ref.read(_notificationCenterBusyProvider)) return;
    busyController.state = true;
    try {
      await ref.read(notificationServiceProvider).markAllAsRead();
    } finally {
      busyController.state = false;
    }
  }

  String _formatDateTime(DateTime date) {
    final dd = date.day.toString().padLeft(2, '0');
    final mm = date.month.toString().padLeft(2, '0');
    final hh = date.hour.toString().padLeft(2, '0');
    final min = date.minute.toString().padLeft(2, '0');
    return '$dd/$mm $hh:$min';
  }

  IconData _notificationIcon(String type) {
    if (type.startsWith('incoming_')) {
      return type.contains('video')
          ? Icons.videocam_rounded
          : Icons.call_rounded;
    }
    if (type.contains('missed')) return Icons.phone_missed_rounded;
    if (type.contains('declined')) return Icons.call_end_rounded;
    return Icons.notifications_rounded;
  }

  Color _notificationColor(String type) {
    if (type.contains('missed') || type.contains('declined')) {
      return AppColors.error;
    }
    if (type.startsWith('incoming_')) {
      return AppColors.primaryLight;
    }
    return AppColors.textSecondary;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMarkingAllRead = ref.watch(_notificationCenterBusyProvider);
    final notifications = ref.watch(_myNotificationsProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.bgSurface,
        title: Text(
          _txt(
            context,
            vi: 'Trung tÃ¢m thÃ´ng bÃ¡o',
            en: 'Notification Center',
          ),
          style: TextStyle(
            color: AppColors.textPrimary,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
          ),
        ),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        actions: [
          TextButton(
            onPressed:
                isMarkingAllRead ? null : () => _markAllAsRead(context, ref),
            child: Text(
              _txt(context, vi: 'Äá»c táº¥t cáº£', en: 'Read all'),
              style: TextStyle(
                color: isMarkingAllRead
                    ? AppColors.textMuted
                    : AppColors.primaryLight,
                fontWeight: FontWeight.w600,
                fontFamily: 'Inter',
              ),
            ),
          ),
        ],
      ),
      body: notifications.when(
        error: (_, __) {
          return Center(
            child: Text(
              _txt(
                context,
                vi: 'KhÃ´ng táº£i Ä‘Æ°á»£c thÃ´ng bÃ¡o',
                en: 'Unable to load notifications',
              ),
              style: TextStyle(color: AppColors.textMuted),
            ),
          );
        },
        loading: () {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        },
        data: (snapshot) {
          final items = snapshot.docs
              .map(AppNotificationModel.fromDocument)
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

          if (items.isEmpty) {
            return Center(
              child: Text(
                _txt(
                  context,
                  vi: 'ChÆ°a cÃ³ thÃ´ng bÃ¡o nÃ o',
                  en: 'No notifications yet',
                ),
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontFamily: 'Inter',
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final icon = _notificationIcon(item.type);
              final iconColor = _notificationColor(item.type);
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: item.isRead
                      ? AppColors.bgSurface.withAlphaFraction(0.65)
                      : AppColors.primary.withAlphaFraction(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: ListTile(
                  onTap: () =>
                      ref.read(notificationServiceProvider).markAsRead(item.id),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: iconColor.withAlphaFraction(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: iconColor, size: 20),
                  ),
                  title: Text(
                    item.title,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight:
                          item.isRead ? FontWeight.w500 : FontWeight.w700,
                      fontFamily: 'Inter',
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '${item.body}\n${_formatDateTime(item.createdAt)}',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontFamily: 'Inter',
                        height: 1.4,
                      ),
                    ),
                  ),
                  trailing: item.isRead
                      ? null
                      : Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            shape: BoxShape.circle,
                          ),
                        ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
