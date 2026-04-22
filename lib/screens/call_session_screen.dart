import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

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
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  Timer? _ringingTimeout;
  Timer? _elapsedTimer;
  Duration _elapsed = Duration.zero;
  DateTime? _acceptedAt;
  bool _closeScheduled = false;
  bool _isMicMuted = false;
  bool _isSpeakerOn = true;
  bool _isCameraOn = true;

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  bool _rtcReady = false;
  bool _hasRemoteStream = false;
  bool _sentOffer = false;
  bool _sentAnswer = false;
  bool _appliedAnswer = false;
  bool _remoteDescriptionSet = false;
  bool _isSignalingProcessing = false;
  bool _rtcDisposed = false;

  final Set<String> _appliedRemoteCandidateKeys = <String>{};
  final List<Map<String, dynamic>> _pendingRemoteCandidates =
      <Map<String, dynamic>>[];
  Map<String, dynamic>? _queuedSignalData;
  AppCall? _queuedCallState;
  Map<String, dynamic>? _latestSignalData;
  AppCall? _latestCallState;

  bool get _isCallerSide => !widget.isIncoming;

  void _attachRemoteStream(MediaStream? stream, {String source = ''}) {
    if (stream == null) return;
    final hasVideoTrack = stream.getVideoTracks().isNotEmpty;
    final canRender = widget.callType == CallType.video ? hasVideoTrack : true;
    _remoteStream = stream;
    _remoteRenderer.srcObject = stream;
    if (mounted) {
      setState(() => _hasRemoteStream = canRender);
    } else {
      _hasRemoteStream = canRender;
    }
    debugPrint(
      'Call[$source] remote stream attached: id=${stream.id}, '
      'audio=${stream.getAudioTracks().length}, '
      'video=${stream.getVideoTracks().length}, '
      'render=$canRender',
    );
  }

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
    if (!_isCallerSide) {
      // Incoming side does not auto-mark missed.
    } else {
      _ringingTimeout = Timer(const Duration(seconds: 35), () {
        _callService.markMissed(widget.callId);
      });
    }
    unawaited(_initializeRtc());
  }

  @override
  void dispose() {
    _ringingTimeout?.cancel();
    _elapsedTimer?.cancel();
    unawaited(_tearDownRtc());
    super.dispose();
  }

  Future<void> _initializeRtc() async {
    if (_rtcReady || _rtcDisposed) return;
    _remoteDescriptionSet = false;
    _pendingRemoteCandidates.clear();
    _appliedRemoteCandidateKeys.clear();
    try {
      await _localRenderer.initialize();
      await _remoteRenderer.initialize();

      final localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': widget.callType == CallType.video
            ? <String, dynamic>{'facingMode': 'user'}
            : false,
      });
      _localStream = localStream;
      if (widget.callType == CallType.video) {
        _localRenderer.srcObject = localStream;
        final hasLocalVideo = localStream.getVideoTracks().isNotEmpty;
        if (!hasLocalVideo) {
          _isCameraOn = false;
          debugPrint('Call[local] no video track from getUserMedia');
        }
        debugPrint(
          'Call[local] tracks audio=${localStream.getAudioTracks().length}, '
          'video=${localStream.getVideoTracks().length}',
        );
      }

      final peer = await createPeerConnection({
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'},
          {'urls': 'stun:stun1.l.google.com:19302'},
        ],
      });
      _peerConnection = peer;

      for (final track in localStream.getTracks()) {
        await peer.addTrack(track, localStream);
      }

      peer.onIceCandidate = (candidate) {
        final value = candidate.candidate;
        if (value == null || value.isEmpty) return;
        unawaited(
          _callService.addIceCandidate(
            callId: widget.callId,
            isCallerSide: _isCallerSide,
            candidate: {
              'candidate': value,
              'sdpMid': candidate.sdpMid ?? '',
              'sdpMLineIndex': candidate.sdpMLineIndex ?? 0,
            },
          ),
        );
      };

      peer.onAddStream = (stream) {
        _attachRemoteStream(stream, source: 'onAddStream');
      };

      peer.onAddTrack = (stream, track) {
        if (widget.callType == CallType.video && track.kind != 'video') return;
        _attachRemoteStream(stream, source: 'onAddTrack:${track.kind}');
      };

      peer.onTrack = (event) {
        if (widget.callType == CallType.video && event.track.kind != 'video') {
          return;
        }
        if (event.streams.isNotEmpty) {
          _attachRemoteStream(event.streams.first, source: 'onTrack');
          return;
        }

        final fromPeer = peer.getRemoteStreams();
        final existing = fromPeer.isNotEmpty ? fromPeer.first : _remoteStream;
        if (existing != null) {
          unawaited(
            existing
                .addTrack(event.track, addToNative: false)
                .catchError((_) {}),
          );
          _attachRemoteStream(existing, source: 'onTrack-fallback');
          return;
        }

        debugPrint(
            'Call[onTrack] no stream payload for track=${event.track.kind}');
      };

      peer.onIceConnectionState = (state) {
        debugPrint('Call[ice] state=$state');
        if (state == RTCIceConnectionState.RTCIceConnectionStateConnected ||
            state == RTCIceConnectionState.RTCIceConnectionStateCompleted) {
          final streams = peer.getRemoteStreams();
          if (streams.isNotEmpty) {
            _attachRemoteStream(streams.first, source: 'ice-state');
          }
        }
      };

      await Helper.setSpeakerphoneOn(_isSpeakerOn);
      _applyTrackStates();

      if (_isCallerSide) {
        await _createAndSendOfferIfNeeded();
      }

      if (!mounted) return;
      setState(() => _rtcReady = true);
      _tryProcessLatestSignaling();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _txt(
              context,
              vi: 'Khong khoi tao duoc media cuoc goi',
              en: 'Cannot initialize call media',
            ),
          ),
        ),
      );
    }
  }

  Future<void> _tearDownRtc() async {
    if (_rtcDisposed) return;
    _rtcDisposed = true;
    try {
      await Helper.setSpeakerphoneOn(false);
    } catch (_) {}

    final peer = _peerConnection;
    _peerConnection = null;
    try {
      await peer?.close();
    } catch (_) {}

    final stream = _localStream;
    _localStream = null;
    if (stream != null) {
      for (final track in stream.getTracks()) {
        try {
          track.stop();
        } catch (_) {}
      }
      try {
        await stream.dispose();
      } catch (_) {}
    }

    _localRenderer.srcObject = null;
    _remoteRenderer.srcObject = null;
    _remoteStream = null;
    _pendingRemoteCandidates.clear();
    try {
      await _localRenderer.dispose();
    } catch (_) {}
    try {
      await _remoteRenderer.dispose();
    } catch (_) {}
  }

  Future<void> _acceptCall() async {
    HapticFeedback.lightImpact();
    await _callService.acceptCall(widget.callId);
  }

  Future<void> _declineCall() async {
    HapticFeedback.mediumImpact();
    await _callService.declineCall(widget.callId);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _cancelCall() async {
    HapticFeedback.mediumImpact();
    await _callService.cancelCall(widget.callId);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _endCall() async {
    HapticFeedback.mediumImpact();
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

  void _queueSignaling(AppCall call, Map<String, dynamic> data) {
    if (_rtcDisposed) return;
    if (!_rtcReady || _peerConnection == null) {
      _latestCallState = call;
      _latestSignalData = data;
      return;
    }
    _handleSignaling(call, data);
  }

  void _tryProcessLatestSignaling() {
    final call = _latestCallState;
    final data = _latestSignalData;
    if (call == null || data == null) return;
    _latestCallState = null;
    _latestSignalData = null;
    _handleSignaling(call, data);
  }

  void _handleSignaling(AppCall call, Map<String, dynamic> data) {
    if (_isSignalingProcessing) {
      _queuedCallState = call;
      _queuedSignalData = data;
      return;
    }
    _isSignalingProcessing = true;
    unawaited(_runSignaling(call, data));
  }

  Future<void> _runSignaling(AppCall call, Map<String, dynamic> data) async {
    try {
      if (_isCallerSide) {
        await _createAndSendOfferIfNeeded();

        final answerRaw = data['answer'];
        if (answerRaw is Map && !_appliedAnswer) {
          final answer = answerRaw.map(
            (key, value) => MapEntry(key.toString(), value),
          );
          await _applyRemoteAnswer(answer);
        }

        final calleeCandidates = data['calleeCandidates'];
        if (calleeCandidates is Iterable) {
          await _applyRemoteCandidates(calleeCandidates);
        }
      } else {
        final offerRaw = data['offer'];
        if (offerRaw is Map &&
            call.status == CallStatus.accepted &&
            !_sentAnswer) {
          final offer = offerRaw.map(
            (key, value) => MapEntry(key.toString(), value),
          );
          await _applyOfferAndSendAnswer(offer);
        }

        final callerCandidates = data['callerCandidates'];
        if (callerCandidates is Iterable) {
          await _applyRemoteCandidates(callerCandidates);
        }
      }
    } finally {
      _isSignalingProcessing = false;
      final nextCall = _queuedCallState;
      final nextData = _queuedSignalData;
      if (nextCall != null && nextData != null) {
        _queuedCallState = null;
        _queuedSignalData = null;
        _handleSignaling(nextCall, nextData);
      }
    }
  }

  Future<void> _createAndSendOfferIfNeeded() async {
    final peer = _peerConnection;
    if (peer == null || _sentOffer) return;
    final offer = await peer.createOffer({
      'offerToReceiveAudio': 1,
      'offerToReceiveVideo': widget.callType == CallType.video ? 1 : 0,
    });
    await peer.setLocalDescription(offer);
    await _callService.setOffer(
      callId: widget.callId,
      offer: {
        'type': offer.type,
        'sdp': offer.sdp ?? '',
      },
    );
    _sentOffer = true;
  }

  Future<void> _applyOfferAndSendAnswer(Map<String, dynamic> offer) async {
    final peer = _peerConnection;
    if (peer == null || _sentAnswer) return;
    final type = offer['type']?.toString() ?? '';
    final sdp = offer['sdp']?.toString() ?? '';
    if (type.isEmpty || sdp.isEmpty) return;

    await peer.setRemoteDescription(RTCSessionDescription(sdp, type));
    _remoteDescriptionSet = true;
    await _flushPendingRemoteCandidates();
    final answer = await peer.createAnswer({
      'offerToReceiveAudio': 1,
      'offerToReceiveVideo': widget.callType == CallType.video ? 1 : 0,
    });
    await peer.setLocalDescription(answer);
    await _callService.setAnswer(
      callId: widget.callId,
      answer: {
        'type': answer.type,
        'sdp': answer.sdp ?? '',
      },
    );
    _sentAnswer = true;
  }

  Future<void> _applyRemoteAnswer(Map<String, dynamic> answer) async {
    final peer = _peerConnection;
    if (peer == null || _appliedAnswer) return;
    final type = answer['type']?.toString() ?? '';
    final sdp = answer['sdp']?.toString() ?? '';
    if (type.isEmpty || sdp.isEmpty) return;

    await peer.setRemoteDescription(RTCSessionDescription(sdp, type));
    _appliedAnswer = true;
    _remoteDescriptionSet = true;
    await _flushPendingRemoteCandidates();
  }

  Future<void> _applyRemoteCandidates(Iterable rawCandidates) async {
    final peer = _peerConnection;
    if (peer == null) return;
    for (final raw in rawCandidates) {
      if (raw is! Map) continue;
      final candidateText = raw['candidate']?.toString() ?? '';
      if (candidateText.isEmpty) continue;
      final sdpMid = raw['sdpMid']?.toString();
      final rawLine = raw['sdpMLineIndex'];
      final lineIndex = rawLine is int
          ? rawLine
          : (rawLine is num
              ? rawLine.toInt()
              : int.tryParse(rawLine?.toString() ?? ''));
      final key = _candidateKey(candidateText, sdpMid, lineIndex);
      if (_appliedRemoteCandidateKeys.contains(key)) continue;
      final normalized = <String, dynamic>{
        'candidate': candidateText,
        'sdpMid': sdpMid,
        'sdpMLineIndex': lineIndex,
      };

      if (!_remoteDescriptionSet) {
        _queuePendingCandidate(normalized);
        continue;
      }

      try {
        await peer.addCandidate(
          RTCIceCandidate(candidateText, sdpMid, lineIndex),
        );
        _appliedRemoteCandidateKeys.add(key);
      } catch (e) {
        debugPrint('Call[candidate] delayed add: $e');
        _queuePendingCandidate(normalized);
      }
    }
  }

  String _candidateKey(String candidate, String? sdpMid, int? lineIndex) {
    return '$candidate|${sdpMid ?? ''}|${lineIndex ?? -1}';
  }

  void _queuePendingCandidate(Map<String, dynamic> candidate) {
    final key = _candidateKey(
      candidate['candidate']?.toString() ?? '',
      candidate['sdpMid']?.toString(),
      candidate['sdpMLineIndex'] as int?,
    );
    if (_appliedRemoteCandidateKeys.contains(key)) return;
    final exists = _pendingRemoteCandidates.any((item) {
      return _candidateKey(
            item['candidate']?.toString() ?? '',
            item['sdpMid']?.toString(),
            item['sdpMLineIndex'] as int?,
          ) ==
          key;
    });
    if (exists) return;
    _pendingRemoteCandidates.add(candidate);
  }

  Future<void> _flushPendingRemoteCandidates() async {
    final peer = _peerConnection;
    if (peer == null || !_remoteDescriptionSet) return;
    if (_pendingRemoteCandidates.isEmpty) return;

    final pending = List<Map<String, dynamic>>.from(_pendingRemoteCandidates);
    _pendingRemoteCandidates.clear();
    for (final candidate in pending) {
      final candidateText = candidate['candidate']?.toString() ?? '';
      if (candidateText.isEmpty) continue;
      final sdpMid = candidate['sdpMid']?.toString();
      final lineIndex = candidate['sdpMLineIndex'] as int?;
      final key = _candidateKey(candidateText, sdpMid, lineIndex);
      if (_appliedRemoteCandidateKeys.contains(key)) continue;
      try {
        await peer.addCandidate(
          RTCIceCandidate(candidateText, sdpMid, lineIndex),
        );
        _appliedRemoteCandidateKeys.add(key);
      } catch (e) {
        debugPrint('Call[candidate] flush failed: $e');
      }
    }
  }

  String _statusText(AppCall call) {
    switch (call.status) {
      case CallStatus.ringing:
        return widget.isIncoming
            ? _txt(context, vi: 'Cuoc goi den', en: 'Incoming call')
            : _txt(context, vi: 'Dang do chuong...', en: 'Ringing...');
      case CallStatus.accepted:
        return _txt(context, vi: 'Dang ket noi', en: 'Connected');
      case CallStatus.declined:
        return _txt(context, vi: 'Cuoc goi bi tu choi', en: 'Call declined');
      case CallStatus.cancelled:
        return _txt(context, vi: 'Cuoc goi da huy', en: 'Call canceled');
      case CallStatus.missed:
        return _txt(context, vi: 'Cuoc goi nho', en: 'Missed call');
      case CallStatus.ended:
        return _txt(context, vi: 'Cuoc goi ket thuc', en: 'Call ended');
      case CallStatus.unknown:
        return _txt(context,
            vi: 'Trang thai khong xac dinh', en: 'Unknown status');
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

  String _callTypeLabel() {
    if (widget.callType == CallType.video) {
      return _txt(context, vi: 'Video call', en: 'Video call');
    }
    return _txt(context, vi: 'Voice call', en: 'Voice call');
  }

  void _applyTrackStates() {
    final local = _localStream;
    if (local == null) return;
    for (final audio in local.getAudioTracks()) {
      audio.enabled = !_isMicMuted;
    }
    for (final video in local.getVideoTracks()) {
      video.enabled = _isCameraOn;
    }
  }

  void _toggleMic() {
    HapticFeedback.selectionClick();
    final nextMuted = !_isMicMuted;
    for (final track
        in _localStream?.getAudioTracks() ?? <MediaStreamTrack>[]) {
      track.enabled = !nextMuted;
    }
    setState(() => _isMicMuted = nextMuted);
  }

  void _toggleSpeaker() {
    HapticFeedback.selectionClick();
    final nextSpeaker = !_isSpeakerOn;
    unawaited(Helper.setSpeakerphoneOn(nextSpeaker));
    setState(() => _isSpeakerOn = nextSpeaker);
  }

  void _toggleCamera() {
    HapticFeedback.selectionClick();
    final nextCamera = !_isCameraOn;
    for (final track
        in _localStream?.getVideoTracks() ?? <MediaStreamTrack>[]) {
      track.enabled = nextCamera;
    }
    setState(() => _isCameraOn = nextCamera);
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
                vi: 'Cuoc goi khong con ton tai',
                en: 'Call no longer exists',
              ),
            );
          }

          final rawData = snapshot.data!.data() ?? const <String, dynamic>{};
          final call = AppCall.fromDocument(snapshot.data!);
          _latestCallState = call;
          _latestSignalData = rawData;
          _queueSignaling(call, rawData);
          _syncAcceptedTimer(call);
          _scheduleAutoClose(call.status);

          return SafeArea(
            child: Stack(
              children: [
                Positioned(
                  top: -80,
                  left: -30,
                  child: Container(
                    width: 210,
                    height: 210,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.primary.withAlphaFraction(0.25),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: -40,
                  bottom: 140,
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.accent.withAlphaFraction(0.18),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.glassBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.glassBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            widget.callType == CallType.video
                                ? Icons.videocam_rounded
                                : Icons.call_rounded,
                            size: 16,
                            color: AppColors.primaryLight,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _callTypeLabel(),
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildMediaStage(),
                    const SizedBox(height: 14),
                    Text(
                      widget.peerName,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 28,
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
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                    const Spacer(),
                    _buildControls(call),
                    const SizedBox(height: 28),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMediaStage() {
    if (widget.callType != CallType.video) {
      return CircleAvatar(
        radius: 56,
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
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                ),
              )
            : null,
      );
    }

    return Container(
      height: 280,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.glassBorder),
        color: AppColors.bgSurface,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            Positioned.fill(
              child: _hasRemoteStream
                  ? RTCVideoView(
                      _remoteRenderer,
                      objectFit:
                          RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    )
                  : Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary.withAlphaFraction(0.25),
                            AppColors.bgCard,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          _txt(
                            context,
                            vi: 'Dang cho video tu doi phuong...',
                            en: 'Waiting for remote video...',
                          ),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ),
                    ),
            ),
            if (_localStream != null)
              Positioned(
                right: 10,
                bottom: 10,
                child: Container(
                  width: 102,
                  height: 146,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.glassBorder),
                    color: AppColors.bgDark,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: RTCVideoView(
                      _localRenderer,
                      mirror: true,
                      objectFit:
                          RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    ),
                  ),
                ),
              ),
            if (!_rtcReady)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withAlphaFraction(0.35),
                  child: const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primaryLight),
                  ),
                ),
              ),
          ],
        ),
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
                child: Text(_txt(context, vi: 'Dong', en: 'Close')),
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
        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildControlWithLabel(
                  icon: Icons.call_end_rounded,
                  label: _txt(context, vi: 'Tu choi', en: 'Decline'),
                  color: AppColors.error,
                  onTap: _declineCall,
                  size: 78,
                ),
                const SizedBox(width: 24),
                _buildControlWithLabel(
                  icon: Icons.call_rounded,
                  label: _txt(context, vi: 'Tra loi', en: 'Answer'),
                  color: AppColors.accentGreen,
                  onTap: _acceptCall,
                  size: 78,
                ),
              ],
            ),
          ],
        );
      }
      return Column(
        children: [
          _buildControlWithLabel(
            icon: Icons.call_end_rounded,
            label: _txt(context, vi: 'Huy cuoc goi', en: 'Cancel call'),
            color: AppColors.error,
            onTap: _cancelCall,
            size: 86,
          ),
        ],
      );
    }

    if (call.status == CallStatus.accepted) {
      return Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildControlWithLabel(
                icon: _isMicMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                label: _txt(context, vi: 'Mic', en: 'Mic'),
                color: _isMicMuted ? AppColors.error : AppColors.glassBg,
                onTap: _toggleMic,
                iconColor: _isMicMuted ? Colors.white : AppColors.textPrimary,
                size: 72,
              ),
              const SizedBox(width: 18),
              _buildControlWithLabel(
                icon: _isSpeakerOn
                    ? Icons.volume_up_rounded
                    : Icons.volume_off_rounded,
                label: _txt(context, vi: 'Loa', en: 'Speaker'),
                color: _isSpeakerOn ? AppColors.glassBg : AppColors.error,
                onTap: _toggleSpeaker,
                iconColor: _isSpeakerOn ? AppColors.textPrimary : Colors.white,
                size: 72,
              ),
              if (widget.callType == CallType.video) ...[
                const SizedBox(width: 18),
                _buildControlWithLabel(
                  icon: _isCameraOn
                      ? Icons.videocam_rounded
                      : Icons.videocam_off_rounded,
                  label: _txt(context, vi: 'Camera', en: 'Camera'),
                  color: _isCameraOn ? AppColors.glassBg : AppColors.error,
                  onTap: _toggleCamera,
                  iconColor: _isCameraOn ? AppColors.textPrimary : Colors.white,
                  size: 72,
                ),
              ],
            ],
          ),
          const SizedBox(height: 22),
          _buildControlWithLabel(
            icon: Icons.call_end_rounded,
            label: _txt(context, vi: 'Ket thuc', en: 'End call'),
            color: AppColors.error,
            onTap: _endCall,
            size: 92,
          ),
        ],
      );
    }

    return _buildControlWithLabel(
      icon: Icons.close_rounded,
      label: _txt(context, vi: 'Dong', en: 'Close'),
      color: AppColors.glassBg,
      iconColor: AppColors.textPrimary,
      onTap: () => Navigator.pop(context),
      size: 72,
    );
  }

  Widget _buildControlWithLabel({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    Color iconColor = Colors.white,
    double size = 62,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withAlphaFraction(0.45),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Icon(icon, color: iconColor, size: size * 0.42),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 86,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              fontFamily: 'Inter',
            ),
          ),
        ),
      ],
    );
  }
}
