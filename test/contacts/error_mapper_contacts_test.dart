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
    });

    test('falls back to unknown for unexpected errors', () {
      expect(
        AppErrorMapper.mapContacts(Exception('internal-error')),
        AppErrorReason.unknown,
      );
    });
  });
}
