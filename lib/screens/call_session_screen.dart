import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/call_models.dart';
import '../services/call_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';

class CallSessionScreen extends StatefulWidget {
  const CallSessionScreen.outgoing({
    super.key,
    required this.callId,
    required this.peerId,
    required this.peerName,
    required this.callType,
    this.peerAvatar = '',
  }) : isIncoming = false;

  const CallSessionScreen.incoming({
    super.key,
    required this.callId,
    required this.peerId,
    required this.peerName,
    required this.callType,
    this.peerAvatar = '',
  }) : isIncoming = true;

  final String callId;
  final String peerId;
  final String peerName;
  final String peerAvatar;
  final CallType callType;
  final bool isIncoming;

  @override
  State<CallSessionScreen> createState() => _CallSessionScreenState();
}

class _CallSessionScreenState extends State<CallSessionScreen> {
  final CallService _callService = CallService();

  Timer? _ringingTimeout;
  Timer? _elapsedTimer;
  Duration _elapsed = Duration.zero;
  DateTime? _acceptedAt;
  bool _closeScheduled = false;
  bool _isMicMuted = false;
  bool _isSpeakerOn = true;
  bool _isCameraOn = true;

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
    if (!widget.isIncoming) {
      _ringingTimeout = Timer(const Duration(seconds: 35), () {
        _callService.markMissed(widget.callId);
      });
    }
  }

  @override
  void dispose() {
    _ringingTimeout?.cancel();
    _elapsedTimer?.cancel();
    super.dispose();
  }

  Future<void> _acceptCall() async {
    await _callService.acceptCall(widget.callId);
  }

  Future<void> _declineCall() async {
    await _callService.declineCall(widget.callId);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _cancelCall() async {
    await _callService.cancelCall(widget.callId);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _endCall() async {
    await _callService.endCall(widget.callId);
    if (mounted) Navigator.pop(context);
  }

  void _syncAcceptedTimer(AppCall call) {
    if (call.status != CallStatus.accepted || call.acceptedAt == null) {
      _ringingTimeout?.cancel();
      _acceptedAt = null;
      _elapsedTimer?.cancel();
      _elapsedTimer = null;
      _elapsed = Duration.zero;
      return;
    }
    if (_acceptedAt == call.acceptedAt && _elapsedTimer != null) return;

    _acceptedAt = call.acceptedAt;
    _ringingTimeout?.cancel();
    _elapsedTimer?.cancel();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _acceptedAt == null) return;
      setState(() {
        _elapsed = DateTime.now().difference(_acceptedAt!);
      });
    });
  }

  void _scheduleAutoClose(CallStatus status) {
    if (_closeScheduled) return;
    if (status == CallStatus.ringing || status == CallStatus.accepted) return;
    _closeScheduled = true;
    Future<void>.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      Navigator.pop(context);
    });
  }

  String _statusText(AppCall call) {
    switch (call.status) {
      case CallStatus.ringing:
        return widget.isIncoming
            ? _txt(context, vi: 'Cuộc gọi đến', en: 'Incoming call')
            : _txt(context, vi: 'Đang đổ chuông...', en: 'Ringing...');
      case CallStatus.accepted:
        return _txt(context, vi: 'Đang kết nối', en: 'Connected');
      case CallStatus.declined:
        return _txt(context, vi: 'Cuộc gọi bị từ chối', en: 'Call declined');
      case CallStatus.cancelled:
        return _txt(context, vi: 'Cuộc gọi đã hủy', en: 'Call canceled');
      case CallStatus.missed:
        return _txt(context, vi: 'Cuộc gọi nhỡ', en: 'Missed call');
      case CallStatus.ended:
        return _txt(context, vi: 'Cuộc gọi kết thúc', en: 'Call ended');
      case CallStatus.unknown:
        return _txt(context, vi: 'Trạng thái không xác định', en: 'Unknown status');
    }
  }

  String _formatDuration(Duration duration) {
    final mm = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hh = duration.inHours;
    if (hh > 0) {
      return '${hh.toString().padLeft(2, '0')}:$mm:$ss';
    }
    return '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _callService.watchCall(widget.callId),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data?.exists != true) {
            return _buildFallback(
              context,
              _txt(
                context,
                vi: 'Cuộc gọi không còn tồn tại',
                en: 'Call no longer exists',
              ),
            );
          }

          final call = AppCall.fromDocument(snapshot.data!);
          _syncAcceptedTimer(call);
          _scheduleAutoClose(call.status);

          return SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 24),
                CircleAvatar(
                  radius: 52,
                  backgroundColor: AppColors.glassBg,
                  backgroundImage: widget.peerAvatar.trim().isEmpty
                      ? null
                      : NetworkImage(widget.peerAvatar),
                  child: widget.peerAvatar.trim().isEmpty
                      ? Text(
                          widget.peerName.isEmpty
                              ? '?'
                              : widget.peerName.substring(0, 1).toUpperCase(),
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 34,
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: 16),
                Text(
                  widget.peerName,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _statusText(call),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    fontFamily: 'Inter',
                  ),
                ),
                if (call.status == CallStatus.accepted) ...[
                  const SizedBox(height: 6),
                  Text(
                    _formatDuration(_elapsed),
                    style: const TextStyle(
                      color: AppColors.primaryLight,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Inter',
                    ),
                  ),
                ],
                const Spacer(),
                _buildControls(call),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFallback(BuildContext context, String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: GlassCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(_txt(context, vi: 'Đóng', en: 'Close')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControls(AppCall call) {
    if (call.status == CallStatus.ringing) {
      if (widget.isIncoming && call.calleeId == _callService.currentUserId) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildRoundButton(
              icon: Icons.call_end_rounded,
              color: AppColors.error,
              onTap: _declineCall,
            ),
            const SizedBox(width: 24),
            _buildRoundButton(
              icon: Icons.call_rounded,
              color: AppColors.accentGreen,
              onTap: _acceptCall,
            ),
          ],
        );
      }
      return _buildRoundButton(
        icon: Icons.call_end_rounded,
        color: AppColors.error,
        onTap: _cancelCall,
      );
    }

    if (call.status == CallStatus.accepted) {
      return Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildRoundButton(
                icon: _isMicMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                color: _isMicMuted ? AppColors.error : AppColors.glassBg,
                onTap: () => setState(() => _isMicMuted = !_isMicMuted),
                iconColor:
                    _isMicMuted ? Colors.white : AppColors.textPrimary,
              ),
              const SizedBox(width: 18),
              _buildRoundButton(
                icon: _isSpeakerOn
                    ? Icons.volume_up_rounded
                    : Icons.volume_off_rounded,
                color: _isSpeakerOn ? AppColors.glassBg : AppColors.error,
                onTap: () => setState(() => _isSpeakerOn = !_isSpeakerOn),
                iconColor:
                    _isSpeakerOn ? AppColors.textPrimary : Colors.white,
              ),
              if (widget.callType == CallType.video) ...[
                const SizedBox(width: 18),
                _buildRoundButton(
                  icon: _isCameraOn
                      ? Icons.videocam_rounded
                      : Icons.videocam_off_rounded,
                  color: _isCameraOn ? AppColors.glassBg : AppColors.error,
                  onTap: () => setState(() => _isCameraOn = !_isCameraOn),
                  iconColor:
                      _isCameraOn ? AppColors.textPrimary : Colors.white,
                ),
              ],
            ],
          ),
          const SizedBox(height: 22),
          _buildRoundButton(
            icon: Icons.call_end_rounded,
            color: AppColors.error,
            onTap: _endCall,
          ),
        ],
      );
    }

    return _buildRoundButton(
      icon: Icons.close_rounded,
      color: AppColors.glassBg,
      iconColor: AppColors.textPrimary,
      onTap: () => Navigator.pop(context),
    );
  }

  Widget _buildRoundButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    Color iconColor = Colors.white,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 62,
        height: 62,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Icon(icon, color: iconColor, size: 28),
      ),
    );
  }
}
