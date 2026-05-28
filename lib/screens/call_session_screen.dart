import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../models/call_models.dart';
import '../services/app_providers.dart';
import '../services/call_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';

class _CallSessionUiState {
  const _CallSessionUiState({
    this.elapsed = Duration.zero,
    this.isMicMuted = false,
    this.isSpeakerOn = true,
    this.isCameraOn = true,
    this.rtcReady = false,
    this.hasRemoteStream = false,
  });

  final Duration elapsed;
  final bool isMicMuted;
  final bool isSpeakerOn;
  final bool isCameraOn;
  final bool rtcReady;
  final bool hasRemoteStream;

  _CallSessionUiState copyWith({
    Duration? elapsed,
    bool? isMicMuted,
    bool? isSpeakerOn,
    bool? isCameraOn,
    bool? rtcReady,
    bool? hasRemoteStream,
  }) {
    return _CallSessionUiState(
      elapsed: elapsed ?? this.elapsed,
      isMicMuted: isMicMuted ?? this.isMicMuted,
      isSpeakerOn: isSpeakerOn ?? this.isSpeakerOn,
      isCameraOn: isCameraOn ?? this.isCameraOn,
      rtcReady: rtcReady ?? this.rtcReady,
      hasRemoteStream: hasRemoteStream ?? this.hasRemoteStream,
    );
  }
}

class _CallSessionUiController extends StateNotifier<_CallSessionUiState> {
  _CallSessionUiController() : super(const _CallSessionUiState());

  void setElapsed(Duration value) {
    state = state.copyWith(elapsed: value);
  }

  void setMicMuted(bool value) {
    state = state.copyWith(isMicMuted: value);
  }

  void setSpeakerOn(bool value) {
    state = state.copyWith(isSpeakerOn: value);
  }

  void setCameraOn(bool value) {
    state = state.copyWith(isCameraOn: value);
  }

  void setRtcReady(bool value) {
    state = state.copyWith(rtcReady: value);
  }

  void setHasRemoteStream(bool value) {
    state = state.copyWith(hasRemoteStream: value);
  }
}

final _callSessionUiControllerProvider = StateNotifierProvider.autoDispose
    .family<_CallSessionUiController, _CallSessionUiState, String>(
  (ref, _) => _CallSessionUiController(),
);

final _callSessionDocumentProvider = StreamProvider.autoDispose
    .family<DocumentSnapshot<Map<String, dynamic>>, String>((ref, callId) {
  return ref.watch(callServiceProvider).watchCall(callId);
});

class CallSessionScreen extends ConsumerStatefulWidget {
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
  ConsumerState<CallSessionScreen> createState() => _CallSessionScreenState();
}

class _CallSessionScreenState extends ConsumerState<CallSessionScreen> {
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
      ref
          .read(_callSessionUiControllerProvider(widget.callId).notifier)
          .setHasRemoteStream(canRender);
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
          if (mounted) {
            ref
                .read(_callSessionUiControllerProvider(widget.callId).notifier)
                .setCameraOn(false);
          }
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
      _rtcReady = true;
      ref
          .read(_callSessionUiControllerProvider(widget.callId).notifier)
          .setRtcReady(true);
      _tryProcessLatestSignaling();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _txt(
              context,
              vi: 'Không khởi tạo được media cuộc gọi',
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
      if (mounted) {
        ref
            .read(_callSessionUiControllerProvider(widget.callId).notifier)
            .setElapsed(Duration.zero);
      }
      return;
    }
    if (_acceptedAt == call.acceptedAt && _elapsedTimer != null) return;

    _acceptedAt = call.acceptedAt;
    _ringingTimeout?.cancel();
    _elapsedTimer?.cancel();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _acceptedAt == null) return;
      _elapsed = DateTime.now().difference(_acceptedAt!);
      ref
          .read(_callSessionUiControllerProvider(widget.callId).notifier)
          .setElapsed(_elapsed);
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
        return _txt(context,
            vi: 'Trạng thái không xác định', en: 'Unknown status');
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
      return _txt(context, vi: 'Cuộc gọi video', en: 'Video call');
    }
    return _txt(context, vi: 'Cuộc gọi thoại', en: 'Voice call');
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
    _isMicMuted = nextMuted;
    ref
        .read(_callSessionUiControllerProvider(widget.callId).notifier)
        .setMicMuted(nextMuted);
  }

  void _toggleSpeaker() {
    HapticFeedback.selectionClick();
    final nextSpeaker = !_isSpeakerOn;
    unawaited(Helper.setSpeakerphoneOn(nextSpeaker));
    _isSpeakerOn = nextSpeaker;
    ref
        .read(_callSessionUiControllerProvider(widget.callId).notifier)
        .setSpeakerOn(nextSpeaker);
  }

  void _toggleCamera() {
    HapticFeedback.selectionClick();
    final nextCamera = !_isCameraOn;
    for (final track
        in _localStream?.getVideoTracks() ?? <MediaStreamTrack>[]) {
      track.enabled = nextCamera;
    }
    _isCameraOn = nextCamera;
    ref
        .read(_callSessionUiControllerProvider(widget.callId).notifier)
        .setCameraOn(nextCamera);
  }

  @override
  Widget build(BuildContext context) {
    final callSnapshot = ref.watch(_callSessionDocumentProvider(widget.callId));
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: callSnapshot.when(
        loading: () => _buildLoading(context),
        error: (_, __) {
          return _buildFallback(
            context,
            _txt(
              context,
              vi: 'Không tải được cuộc gọi',
              en: 'Unable to load call',
            ),
          );
        },
        data: (snapshot) {
          if (!snapshot.exists) {
            return _buildFallback(
              context,
              _txt(
                context,
                vi: 'Cuộc gọi không còn tồn tại',
                en: 'Call no longer exists',
              ),
            );
          }

          final rawData = snapshot.data() ?? const <String, dynamic>{};
          final call = AppCall.fromDocument(snapshot);
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
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 10),
                        _buildCallTypePill(),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildMediaStage(),
                              const SizedBox(height: 18),
                              Text(
                                widget.peerName,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'Inter',
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _statusText(call),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 14,
                                  fontFamily: 'Inter',
                                ),
                              ),
                              if (call.status == CallStatus.accepted) ...[
                                const SizedBox(height: 6),
                                Text(
                                  _formatDuration(ref
                                      .watch(_callSessionUiControllerProvider(
                                          widget.callId))
                                      .elapsed),
                                  style: TextStyle(
                                    color: AppColors.primaryLight,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'Inter',
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        _buildControls(call),
                        SizedBox(
                          height:
                              MediaQuery.sizeOf(context).height < 700 ? 18 : 28,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoading(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: AppColors.primaryLight),
          const SizedBox(height: 14),
          Text(
            _txt(context, vi: 'Đang mở cuộc gọi...', en: 'Opening call...'),
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              fontFamily: 'Inter',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCallTypePill() {
    return Container(
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
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              fontFamily: 'Inter',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaStage() {
    final uiState = ref.watch(_callSessionUiControllerProvider(widget.callId));
    final screenSize = MediaQuery.sizeOf(context);
    final isCompact = screenSize.height < 700;
    if (widget.callType != CallType.video) {
      return CircleAvatar(
        radius: isCompact ? 48 : 56,
        backgroundColor: AppColors.glassBg,
        backgroundImage: widget.peerAvatar.trim().isEmpty
            ? null
            : NetworkImage(widget.peerAvatar),
        child: widget.peerAvatar.trim().isEmpty
            ? Text(
                widget.peerName.isEmpty
                    ? '?'
                    : widget.peerName.substring(0, 1).toUpperCase(),
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                ),
              )
            : null,
      );
    }

    final stageHeight = math.min(
      isCompact ? 220.0 : 280.0,
      math.max(180.0, screenSize.height * 0.42),
    );
    final previewWidth = isCompact ? 86.0 : 102.0;
    final previewHeight = isCompact ? 124.0 : 146.0;

    return Container(
      width: double.infinity,
      height: stageHeight,
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
              child: uiState.hasRemoteStream
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
                            vi: 'Đang chờ video từ đối phương...',
                            en: 'Waiting for remote video...',
                          ),
                          textAlign: TextAlign.center,
                          style: TextStyle(
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
                  width: previewWidth,
                  height: previewHeight,
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
            if (!uiState.rtcReady)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withAlphaFraction(0.35),
                  child: Center(
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
                style: TextStyle(
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
    final uiState = ref.watch(_callSessionUiControllerProvider(widget.callId));
    final isCompact = MediaQuery.sizeOf(context).height < 700;
    if (call.status == CallStatus.ringing) {
      if (widget.isIncoming && call.calleeId == _callService.currentUserId) {
        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildControlWithLabel(
                  icon: Icons.call_end_rounded,
                  label: _txt(context, vi: 'Từ chối', en: 'Decline'),
                  color: AppColors.error,
                  onTap: _declineCall,
                  size: isCompact ? 68 : 78,
                ),
                const SizedBox(width: 24),
                _buildControlWithLabel(
                  icon: Icons.call_rounded,
                  label: _txt(context, vi: 'Trả lời', en: 'Answer'),
                  color: AppColors.accentGreen,
                  onTap: _acceptCall,
                  size: isCompact ? 68 : 78,
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
            label: _txt(context, vi: 'Hủy cuộc gọi', en: 'Cancel call'),
            color: AppColors.error,
            onTap: _cancelCall,
            size: isCompact ? 76 : 86,
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
                icon: uiState.isMicMuted
                    ? Icons.mic_off_rounded
                    : Icons.mic_rounded,
                label: _txt(context, vi: 'Mic', en: 'Mic'),
                color: uiState.isMicMuted ? AppColors.error : AppColors.glassBg,
                onTap: _toggleMic,
                iconColor:
                    uiState.isMicMuted ? Colors.white : AppColors.textPrimary,
                size: isCompact ? 62 : 72,
              ),
              SizedBox(width: isCompact ? 12 : 18),
              _buildControlWithLabel(
                icon: uiState.isSpeakerOn
                    ? Icons.volume_up_rounded
                    : Icons.volume_off_rounded,
                label: _txt(context, vi: 'Loa', en: 'Speaker'),
                color:
                    uiState.isSpeakerOn ? AppColors.glassBg : AppColors.error,
                onTap: _toggleSpeaker,
                iconColor:
                    uiState.isSpeakerOn ? AppColors.textPrimary : Colors.white,
                size: isCompact ? 62 : 72,
              ),
              if (widget.callType == CallType.video) ...[
                SizedBox(width: isCompact ? 12 : 18),
                _buildControlWithLabel(
                  icon: uiState.isCameraOn
                      ? Icons.videocam_rounded
                      : Icons.videocam_off_rounded,
                  label: _txt(context, vi: 'Camera', en: 'Camera'),
                  color:
                      uiState.isCameraOn ? AppColors.glassBg : AppColors.error,
                  onTap: _toggleCamera,
                  iconColor:
                      uiState.isCameraOn ? AppColors.textPrimary : Colors.white,
                  size: isCompact ? 62 : 72,
                ),
              ],
            ],
          ),
          SizedBox(height: isCompact ? 14 : 22),
          _buildControlWithLabel(
            icon: Icons.call_end_rounded,
            label: _txt(context, vi: 'Kết thúc', en: 'End call'),
            color: AppColors.error,
            onTap: _endCall,
            size: isCompact ? 78 : 92,
          ),
        ],
      );
    }

    return _buildControlWithLabel(
      icon: Icons.close_rounded,
      label: _txt(context, vi: 'Đóng', en: 'Close'),
      color: AppColors.glassBg,
      iconColor: AppColors.textPrimary,
      onTap: () => Navigator.pop(context),
      size: isCompact ? 62 : 72,
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
            style: TextStyle(
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
