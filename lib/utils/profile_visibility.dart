class ProfileVisibility {
  ProfileVisibility._();

  static const email = 'email';
  static const bio = 'bio';
  static const phoneNumber = 'phoneNumber';
  static const address = 'address';
  static const city = 'city';
  static const gender = 'gender';
  static const dateOfBirth = 'dateOfBirth';
  static const occupation = 'occupation';
  static const website = 'website';

  static const fields = [
    email,
    bio,
    phoneNumber,
    address,
    city,
    gender,
    dateOfBirth,
    occupation,
    website,
  ];

  static const defaultValues = {
    email: true,
    bio: true,
    phoneNumber: true,
    address: true,
    city: true,
    gender: true,
    dateOfBirth: true,
    occupation: true,
    website: true,
  };

  static Map<String, bool> fromUserData(Map<String, dynamic> userData) {
    final settings = userData['settings'];
    final rawVisibility =
        settings is Map ? settings['profileVisibility'] : null;
    final visibility = Map<String, bool>.from(defaultValues);

    if (rawVisibility is Map) {
      for (final entry in rawVisibility.entries) {
        final key = entry.key.toString();
        if (fields.contains(key) && entry.value is bool) {
          visibility[key] = entry.value as bool;
        }
      }
    }

    return visibility;
  }

  static bool isVisible(
    Map<String, dynamic> userData,
    String field, {
    required bool isOwner,
  }) {
    if (isOwner) return true;
    return fromUserData(userData)[field] != false;
  }
}
