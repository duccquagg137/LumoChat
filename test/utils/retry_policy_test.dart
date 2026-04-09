import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumochat/utils/retry_policy.dart';

void main() {
  group('RetryPolicy.isTransient', () {
    test('returns true for network and timeout errors', () {
      expect(RetryPolicy.isTransient(TimeoutException('timeout')), isTrue);
      expect(RetryPolicy.isTransient(const SocketException('network-down')), isTrue);
      expect(
        RetryPolicy.isTransient(
          FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
        ),
        isTrue,
      );
    });

    test('returns false for non transient firebase errors', () {
      expect(
        RetryPolicy.isTransient(
          FirebaseException(plugin: 'cloud_firestore', code: 'invalid-argument'),
        ),
        isFalse,
      );
    });
  });

  group('RetryPolicy.run', () {
    test('retries until task succeeds', () async {
      var attempts = 0;

      final result = await RetryPolicy.run<int>(
        operation: 'test.retry_success',
        maxAttempts: 3,
        initialDelay: Duration.zero,
        maxDelay: Duration.zero,
        task: () async {
          attempts++;
          if (attempts < 3) {
            throw const SocketException('temporary network issue');
          }
          return 42;
        },
      );

      expect(result, 42);
      expect(attempts, 3);
    });

    test('does not retry when error is non-retryable', () async {
      var attempts = 0;

      await expectLater(
        () => RetryPolicy.run<void>(
          operation: 'test.retry_fail_fast',
          maxAttempts: 3,
          initialDelay: Duration.zero,
          maxDelay: Duration.zero,
          task: () async {
            attempts++;
            throw FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied');
          },
          isRetryable: (_) => false,
        ),
        throwsA(isA<FirebaseException>()),
      );

      expect(attempts, 1);
    });
  });
}
