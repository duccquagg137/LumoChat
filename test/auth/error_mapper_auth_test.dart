import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumochat/utils/error_mapper.dart';

void main() {
  group('AppErrorMapper.mapAuth', () {
    test('maps invalid credentials errors', () {
      expect(
        AppErrorMapper.mapAuth(
          FirebaseAuthException(code: 'wrong-password'),
        ),
        AppErrorReason.invalidCredentials,
      );

      expect(
        AppErrorMapper.mapAuth(
          Exception('INVALID_LOGIN_CREDENTIALS'),
        ),
        AppErrorReason.invalidCredentials,
      );
    });

    test('maps otp and phone related errors', () {
      expect(
        AppErrorMapper.mapAuth(
          FirebaseAuthException(code: 'invalid-verification-code'),
        ),
        AppErrorReason.invalidOtp,
      );

      expect(
        AppErrorMapper.mapAuth(
          FirebaseAuthException(code: 'invalid-phone-number'),
        ),
        AppErrorReason.invalidPhoneNumber,
      );
    });

    test('maps sms quota and billing errors', () {
      expect(
        AppErrorMapper.mapAuth(Exception('quota exceeded')),
        AppErrorReason.smsQuotaExceeded,
      );

      expect(
        AppErrorMapper.mapAuth(Exception('BILLING_NOT_ENABLED')),
        AppErrorReason.billingNotEnabled,
      );
    });
  });
}
