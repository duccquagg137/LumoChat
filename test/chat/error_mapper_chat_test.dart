import 'package:flutter_test/flutter_test.dart';
import 'package:lumochat/utils/error_mapper.dart';

void main() {
  group('AppErrorMapper.mapChat', () {
    test('maps permission denied', () {
      expect(
        AppErrorMapper.mapChat(Exception('permission-denied')),
        AppErrorReason.permissionDenied,
      );
    });

    test('maps network and unavailable states', () {
      expect(
        AppErrorMapper.mapChat(Exception('network-request-failed')),
        AppErrorReason.network,
      );

      expect(
        AppErrorMapper.mapChat(Exception('deadline-exceeded')),
        AppErrorReason.serviceUnavailable,
      );
    });

    test('falls back to unknown for unclassified errors', () {
      expect(
        AppErrorMapper.mapChat(Exception('something-random')),
        AppErrorReason.unknown,
      );
    });
  });
}
