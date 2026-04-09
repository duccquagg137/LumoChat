import 'package:flutter_test/flutter_test.dart';
import 'package:lumochat/services/onboarding_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OnboardingService', () {
    test('defaults to not completed', () async {
      SharedPreferences.setMockInitialValues({});
      final service = OnboardingService();

      final completed = await service.isCompleted();

      expect(completed, isFalse);
    });

    test('markCompleted persists completion flag', () async {
      SharedPreferences.setMockInitialValues({});
      final service = OnboardingService();

      await service.markCompleted();
      final completed = await service.isCompleted();

      expect(completed, isTrue);
    });
  });
}
