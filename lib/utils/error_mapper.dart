import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

enum AppErrorReason {
  invalidCredentials,
  emailAlreadyInUse,
  weakPassword,
  tooManyRequests,
  invalidOtp,
  invalidPhoneNumber,
  smsQuotaExceeded,
  billingNotEnabled,
  operationNotAllowed,
  invalidInput,
  conflict,
  notFound,
  unauthenticated,
  permissionDenied,
  network,
  timeout,
  serviceUnavailable,
  unknown,
}

class AppErrorMapper {
  const AppErrorMapper._();

  static AppErrorReason mapAuth(Object error) {
    final raw = _normalizedError(error);

    if (_containsAny(raw, const [
      'wrong-password',
      'user-not-found',
      'invalid-email',
      'invalid-credential',
      'invalid-login-credentials',
    ])) {
      return AppErrorReason.invalidCredentials;
    }
    if (_containsAny(raw, const ['email-already-in-use'])) {
      return AppErrorReason.emailAlreadyInUse;
    }
    if (_containsAny(raw, const ['weak-password'])) {
      return AppErrorReason.weakPassword;
    }
    if (_containsAny(raw, const ['too-many-requests'])) {
      return AppErrorReason.tooManyRequests;
    }
    if (_containsAny(raw, const [
      'invalid-verification-code',
      'session-expired',
      'code-expired',
      'invalid-otp',
    ])) {
      return AppErrorReason.invalidOtp;
    }
    if (_containsAny(raw, const ['invalid-phone-number'])) {
      return AppErrorReason.invalidPhoneNumber;
    }
    if (_containsAny(raw, const ['quota-exceeded', 'quota exceeded'])) {
      return AppErrorReason.smsQuotaExceeded;
    }
    if (_containsAny(raw, const ['billing-not-enabled', 'billing_not_enabled'])) {
      return AppErrorReason.billingNotEnabled;
    }
    if (_containsAny(raw, const ['operation-not-allowed'])) {
      return AppErrorReason.operationNotAllowed;
    }

    return _mapSharedReason(raw);
  }

  static AppErrorReason mapChat(Object error) {
    final raw = _normalizedError(error);
    if (_containsAny(raw, const ['chat-room-not-found', 'message-not-found', 'not-found'])) {
      return AppErrorReason.notFound;
    }
    if (_containsAny(raw, const [
      'message-too-long',
      'invalid-argument',
      'failed-precondition',
      'out-of-range',
    ])) {
      return AppErrorReason.invalidInput;
    }
    return _mapSharedReason(raw);
  }

  static AppErrorReason mapContacts(Object error) {
    final raw = _normalizedError(error);
    if (_containsAny(raw, const [
      'already-friends',
      'request-already-sent',
      'already-exists',
      'duplicate',
    ])) {
      return AppErrorReason.conflict;
    }
    if (_containsAny(raw, const ['user-not-found', 'not-found'])) {
      return AppErrorReason.notFound;
    }
    if (_containsAny(raw, const ['invalid-argument', 'failed-precondition'])) {
      return AppErrorReason.invalidInput;
    }
    return _mapSharedReason(raw);
  }

  static AppErrorReason mapGroups(Object error) {
    final raw = _normalizedError(error);
    if (_containsAny(raw, const ['group-not-found', 'not-found'])) {
      return AppErrorReason.notFound;
    }
    if (_containsAny(raw, const ['not-allowed'])) {
      return AppErrorReason.permissionDenied;
    }
    if (_containsAny(raw, const ['invalid-argument', 'failed-precondition'])) {
      return AppErrorReason.invalidInput;
    }
    return _mapSharedReason(raw);
  }

  static bool isRetryableForChat(Object error) => _isRetryable(mapChat(error));

  static bool isRetryableForContacts(Object error) => _isRetryable(mapContacts(error));

  static bool isRetryableForGroups(Object error) => _isRetryable(mapGroups(error));

  static AppErrorReason _mapSharedReason(String raw) {
    if (_containsAny(raw, const ['unauthenticated', 'requires-recent-login'])) {
      return AppErrorReason.unauthenticated;
    }
    if (_containsAny(raw, const ['permission-denied'])) {
      return AppErrorReason.permissionDenied;
    }
    if (_containsAny(raw, const ['network-request-failed', 'network', 'socketexception'])) {
      return AppErrorReason.network;
    }
    if (_containsAny(raw, const ['deadline-exceeded', 'timeout', 'timed-out'])) {
      return AppErrorReason.timeout;
    }
    if (_containsAny(raw, const ['unavailable', 'service unavailable'])) {
      return AppErrorReason.serviceUnavailable;
    }
    return AppErrorReason.unknown;
  }

  static bool _isRetryable(AppErrorReason reason) {
    switch (reason) {
      case AppErrorReason.network:
      case AppErrorReason.timeout:
      case AppErrorReason.serviceUnavailable:
        return true;
      default:
        return false;
    }
  }

  static bool _containsAny(String raw, List<String> markers) {
    for (final marker in markers) {
      if (raw.contains(marker)) return true;
    }
    return false;
  }

  static String _normalizedError(Object error) {
    if (error is FirebaseAuthException) {
      return error.code.toLowerCase().replaceAll('_', '-');
    }
    if (error is FirebaseException) {
      return error.code.toLowerCase().replaceAll('_', '-');
    }

    return error.toString().toLowerCase().replaceAll('_', '-');
  }
}

class AppErrorText {
  const AppErrorText._();

  static String forAuth(BuildContext context, Object error) {
    return forAuthL10n(AppLocalizations.of(context)!, error);
  }

  static String forChat(BuildContext context, Object error) {
    return forChatL10n(AppLocalizations.of(context)!, error);
  }

  static String forContacts(BuildContext context, Object error) {
    return forContactsL10n(AppLocalizations.of(context)!, error);
  }

  static String forGroups(BuildContext context, Object error) {
    return forGroupsL10n(AppLocalizations.of(context)!, error);
  }

  static String forAuthL10n(AppLocalizations l10n, Object error) {
    return _fromReason(l10n, AppErrorMapper.mapAuth(error));
  }

  static String forChatL10n(AppLocalizations l10n, Object error) {
    return _fromReason(l10n, AppErrorMapper.mapChat(error));
  }

  static String forContactsL10n(AppLocalizations l10n, Object error) {
    return _fromReason(l10n, AppErrorMapper.mapContacts(error));
  }

  static String forGroupsL10n(AppLocalizations l10n, Object error) {
    return _fromReason(l10n, AppErrorMapper.mapGroups(error));
  }

  static String _fromReason(AppLocalizations l10n, AppErrorReason reason) {
    switch (reason) {
      case AppErrorReason.invalidCredentials:
        return l10n.authErrorInvalidCredentials;
      case AppErrorReason.emailAlreadyInUse:
        return l10n.authErrorEmailAlreadyInUse;
      case AppErrorReason.weakPassword:
        return l10n.authErrorWeakPassword;
      case AppErrorReason.tooManyRequests:
        return l10n.authErrorTooManyRequests;
      case AppErrorReason.invalidOtp:
        return l10n.authErrorInvalidOtp;
      case AppErrorReason.invalidPhoneNumber:
        return l10n.authErrorInvalidPhoneNumber;
      case AppErrorReason.smsQuotaExceeded:
        return l10n.authErrorSmsQuotaExceeded;
      case AppErrorReason.billingNotEnabled:
        return l10n.authErrorBillingNotEnabled;
      case AppErrorReason.operationNotAllowed:
        return l10n.authErrorOperationNotAllowed;
      case AppErrorReason.invalidInput:
        return l10n.commonErrorInvalidInput;
      case AppErrorReason.conflict:
        return l10n.commonErrorConflict;
      case AppErrorReason.notFound:
        return l10n.commonErrorNotFound;
      case AppErrorReason.unauthenticated:
        return l10n.commonErrorUnauthenticated;
      case AppErrorReason.permissionDenied:
        return l10n.commonErrorPermissionDenied;
      case AppErrorReason.network:
        return l10n.commonErrorNetwork;
      case AppErrorReason.timeout:
        return l10n.commonErrorTimeout;
      case AppErrorReason.serviceUnavailable:
        return l10n.commonErrorServiceUnavailable;
      case AppErrorReason.unknown:
        return l10n.commonUnexpectedError;
    }
  }
}
