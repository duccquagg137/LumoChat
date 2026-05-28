import 'package:flutter_test/flutter_test.dart';
import 'package:lumochat/utils/profile_visibility.dart';

void main() {
  group('ProfileVisibility', () {
    test('defaults every field to visible', () {
      final visibility = ProfileVisibility.fromUserData(const {});

      expect(visibility[ProfileVisibility.email], isTrue);
      expect(visibility[ProfileVisibility.phoneNumber], isTrue);
      expect(visibility[ProfileVisibility.dateOfBirth], isTrue);
    });

    test('hides disabled fields from other users', () {
      final userData = {
        'settings': {
          'profileVisibility': {
            ProfileVisibility.email: false,
            ProfileVisibility.phoneNumber: true,
          },
        },
      };

      expect(
        ProfileVisibility.isVisible(
          userData,
          ProfileVisibility.email,
          isOwner: false,
        ),
        isFalse,
      );
      expect(
        ProfileVisibility.isVisible(
          userData,
          ProfileVisibility.phoneNumber,
          isOwner: false,
        ),
        isTrue,
      );
    });

    test('always shows fields to the owner', () {
      final userData = {
        'settings': {
          'profileVisibility': {
            ProfileVisibility.email: false,
          },
        },
      };

      expect(
        ProfileVisibility.isVisible(
          userData,
          ProfileVisibility.email,
          isOwner: true,
        ),
        isTrue,
      );
    });
  });
}
