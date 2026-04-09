import 'package:flutter_test/flutter_test.dart';
import 'package:lumochat/utils/error_mapper.dart';

void main() {
  group('AppErrorMapper.mapGroups', () {
    test('maps permission and not found errors', () {
      expect(
        AppErrorMapper.mapGroups(Exception('not-allowed')),
        AppErrorReason.permissionDenied,
      );

      expect(
        AppErrorMapper.mapGroups(Exception('group-not-found')),
        AppErrorReason.notFound,
      );
    });

    test('maps transient service errors', () {
      expect(
        AppErrorMapper.mapGroups(Exception('network-request-failed')),
        AppErrorReason.network,
      );

      expect(
        AppErrorMapper.mapGroups(Exception('deadline-exceeded')),
        AppErrorReason.timeout,
      );

      expect(
        AppErrorMapper.mapGroups(Exception('unavailable')),
        AppErrorReason.serviceUnavailable,
      );
    });

    test('marks retryable reasons correctly', () {
      expect(
        AppErrorMapper.isRetryableForGroups(Exception('network-request-failed')),
        isTrue,
      );
      expect(
        AppErrorMapper.isRetryableForGroups(Exception('deadline-exceeded')),
        isTrue,
      );
      expect(
        AppErrorMapper.isRetryableForGroups(Exception('permission-denied')),
        isFalse,
      );
    });
  });
}
