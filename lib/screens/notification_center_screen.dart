import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/app_notification_model.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';

class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  State<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  final NotificationService _notificationService = NotificationService();
  bool _isMarkingAllRead = false;

  bool _isEnglish(BuildContext context) =>
      Localizations.localeOf(context).languageCode == 'en';

  String _txt(
    BuildContext context, {
    required String vi,
    required String en,
  }) {
    return _isEnglish(context) ? en : vi;
  }

  Future<void> _markAllAsRead() async {
    if (_isMarkingAllRead) return;
    setState(() => _isMarkingAllRead = true);
    try {
      await _notificationService.markAllAsRead();
    } finally {
      if (mounted) {
        setState(() => _isMarkingAllRead = false);
      }
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.bgSurface,
        title: Text(
          _txt(
            context,
            vi: 'Trung tÃ¢m thÃ´ng bÃ¡o',
            en: 'Notification Center',
          ),
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
          ),
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          TextButton(
            onPressed: _isMarkingAllRead ? null : _markAllAsRead,
            child: Text(
              _txt(context, vi: 'Äá»c táº¥t cáº£', en: 'Read all'),
              style: TextStyle(
                color: _isMarkingAllRead
                    ? AppColors.textMuted
                    : AppColors.primaryLight,
                fontWeight: FontWeight.w600,
                fontFamily: 'Inter',
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _notificationService.watchMyNotifications(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                _txt(
                  context,
                  vi: 'KhÃ´ng táº£i Ä‘Æ°á»£c thÃ´ng bÃ¡o',
                  en: 'Unable to load notifications',
                ),
                style: const TextStyle(color: AppColors.textMuted),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          final items = snapshot.data!.docs
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
                style: const TextStyle(
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
                  onTap: () => _notificationService.markAsRead(item.id),
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
                      style: const TextStyle(
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
                          decoration: const BoxDecoration(
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
