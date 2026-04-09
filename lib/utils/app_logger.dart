import 'dart:developer' as developer;

enum AppLogLevel { info, warning, error }

class AppLogger {
  const AppLogger._();

  static void info(
    String message, {
    String tag = 'app',
    Map<String, Object?> context = const {},
  }) {
    _log(
      level: AppLogLevel.info,
      message: message,
      tag: tag,
      context: context,
    );
  }

  static void warning(
    String message, {
    String tag = 'app',
    Map<String, Object?> context = const {},
  }) {
    _log(
      level: AppLogLevel.warning,
      message: message,
      tag: tag,
      context: context,
    );
  }

  static void error(
    String message, {
    String tag = 'app',
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> context = const {},
  }) {
    _log(
      level: AppLogLevel.error,
      message: message,
      tag: tag,
      error: error,
      stackTrace: stackTrace,
      context: context,
    );
  }

  static void _log({
    required AppLogLevel level,
    required String message,
    required String tag,
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> context = const {},
  }) {
    final contextText = context.entries
        .where((entry) => entry.value != null)
        .map((entry) => '${entry.key}=${entry.value}')
        .join(', ');
    final output = contextText.isEmpty ? message : '$message | $contextText';

    developer.log(
      output,
      name: 'LumoChat/$tag',
      level: _developerLevel(level),
      error: error,
      stackTrace: stackTrace,
    );
  }

  static int _developerLevel(AppLogLevel level) {
    switch (level) {
      case AppLogLevel.info:
        return 800;
      case AppLogLevel.warning:
        return 900;
      case AppLogLevel.error:
        return 1000;
    }
  }
}
