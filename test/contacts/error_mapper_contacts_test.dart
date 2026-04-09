import 'package:flutter_test/flutter_test.dart';
import 'package:lumochat/utils/error_mapper.dart';

void main() {
  group('AppErrorMapper.mapContacts', () {
    test('maps permission denied', () {
      expect(
        AppErrorMapper.mapContacts(Exception('permission-denied')),
        AppErrorReason.permissionDenied,
      );
    });

    test('maps network errors', () {
      expect(
        AppErrorMapper.mapContacts(Exception('network-request-failed')),
        AppErrorReason.network,
      );

      expect(
        AppErrorMapper.mapContacts(Exception('deadline-exceeded')),
        AppErrorReason.timeout,
      );
    });

    test('falls back to unknown for unexpected errors', () {
      expect(
        AppErrorMapper.mapContacts(Exception('internal-error')),
        AppErrorReason.unknown,
      );
    });

    test('marks retryable reasons correctly', () {
      expect(
        AppErrorMapper.isRetryableForContacts(Exception('network-request-failed')),
        isTrue,
      );
      expect(
        AppErrorMapper.isRetryableForContacts(Exception('timeout')),
        isTrue,
      );
      expect(
        AppErrorMapper.isRetryableForContacts(Exception('permission-denied')),
        isFalse,
      );
    });
  });
}
