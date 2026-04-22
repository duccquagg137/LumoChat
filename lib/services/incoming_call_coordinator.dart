class IncomingCallCoordinator {
  IncomingCallCoordinator._();

  static final Set<String> _activeCallIds = <String>{};

  static bool tryAcquire(String callId) {
    if (callId.isEmpty) return false;
    if (_activeCallIds.contains(callId)) return false;
    _activeCallIds.add(callId);
    return true;
  }

  static void release(String callId) {
    if (callId.isEmpty) return;
    _activeCallIds.remove(callId);
  }
}
