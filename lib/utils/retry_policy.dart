import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:firebase_core/firebase_core.dart';

import 'app_logger.dart';

typedef RetryTask<T> = Future<T> Function();

class RetryPolicy {
  const RetryPolicy._();

  static final Random _random = Random();

  static const Set<String> _transientFirebaseCodes = {
    'aborted',
    'deadline-exceeded',
    'internal',
    'network-request-failed',
    'resource-exhausted',
    'timed-out',
    'timeout',
    'unavailable',
  };

  static Future<T> run<T>({
    required String operation,
    required RetryTask<T> task,
    int maxAttempts = 3,
    Duration initialDelay = const Duration(milliseconds: 350),
    Duration maxDelay = const Duration(seconds: 3),
    bool Function(Object error)? isRetryable,
  }) async {
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await task();
      } catch (error, stackTrace) {
        final retryCheck = isRetryable ?? isTransient;
        final canRetry = attempt < maxAttempts && retryCheck(error);

        if (!canRetry) {
          AppLogger.error(
            'Operation failed',
            tag: 'retry',
            error: error,
            stackTrace: stackTrace,
            context: {
              'operation': operation,
              'attempt': attempt,
              'maxAttempts': maxAttempts,
              'code': errorCode(error),
            },
          );
          rethrow;
        }

        final delay = _delayForAttempt(
          attempt: attempt,
          initialDelay: initialDelay,
          maxDelay: maxDelay,
        );
        AppLogger.warning(
          'Operation failed, scheduling retry',
          tag: 'retry',
          context: {
            'operation': operation,
            'attempt': attempt,
            'maxAttempts': maxAttempts,
            'retryInMs': delay.inMilliseconds,
            'code': errorCode(error),
          },
        );
        await Future<void>.delayed(delay);
      }
    }

    throw StateError('retry-policy-unreachable');
  }

  static bool isTransient(Object error) {
    if (error is TimeoutException || error is SocketException) {
      return true;
    }

    if (error is FirebaseException) {
      final code = error.code.toLowerCase().replaceAll('_', '-');
      return _transientFirebaseCodes.contains(code);
    }

    final raw = error.toString().toLowerCase().replaceAll('_', '-');
    return raw.contains('timeout') ||
        raw.contains('timed out') ||
        raw.contains('socketexception') ||
        raw.contains('network') ||
        raw.contains('deadline-exceeded') ||
        raw.contains('unavailable');
  }

  static String errorCode(Object error) {
    if (error is FirebaseException) {
      return error.code.toLowerCase().replaceAll('_', '-');
    }

    if (error is TimeoutException) {
      return 'timeout';
    }

    if (error is SocketException) {
      return 'network';
    }

    final raw = error.toString().trim();
    if (raw.isEmpty) return 'unknown';
    return raw.length <= 120 ? raw : '${raw.substring(0, 117)}...';
  }

  static Duration _delayForAttempt({
    required int attempt,
    required Duration initialDelay,
    required Duration maxDelay,
  }) {
    final factor = 1 << (attempt - 1);
    final backoffMs = initialDelay.inMilliseconds * factor;
    final jitterMs = _random.nextInt(200);
    final totalMs = backoffMs + jitterMs;
    final clampedMs = min(totalMs, maxDelay.inMilliseconds);
    return Duration(milliseconds: clampedMs);
  }
}
