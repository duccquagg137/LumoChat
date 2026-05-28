# LumoChat - Flutter Chat App

A realtime Flutter chat application built with Firebase. LumoChat supports direct messages, group chats, contacts, user profiles, voice/video calls, push notifications, and light/dark mode.

The app uses the following main packages and services:

- `firebase_core`, `firebase_auth`, `cloud_firestore`, `firebase_messaging`: Firebase initialization, authentication, realtime database, and push notifications.
- `flutter_local_notifications`: Local foreground notifications for messages and calls.
- `flutter_webrtc`: 1-1 voice and video calls.
- `flutter_riverpod`: App-level state providers for theme, locale, services, and navigation state.
- `google_sign_in`: Google authentication.
- `image_picker`: Pick images for profile, group avatar, and chat image messages.
- `cloudinary_public`: Upload image messages and avatars to Cloudinary.
- `permission_handler`: Runtime permissions for camera, microphone, storage, and notifications.
- `shared_preferences`: Persist onboarding, locale, and theme mode.
- `intl` and Flutter localization: Vietnamese/English localization.

## Features

- **Authentication**: Sign in and sign up with Firebase Auth, Google Sign-In, and phone OTP.
- **Required Profile Setup**: New users must complete their profile before entering the main app.
- **Direct Chat**: Realtime 1-1 chat with text, image, reply, reaction, recall, delete-for-me, pinned messages, search, and delivery/read status.
- **Group Chat**: Create groups, add members, leave/delete groups, view group info, pin groups, and open member profiles.
- **Contacts**: Send, cancel, accept, reject friend requests, and remove friends.
- **Voice and Video Calls**: 1-1 call sessions using WebRTC.
- **Call Records in Chat**: Ended, missed, cancelled, or declined calls are saved as system messages in the related chat.
- **Push Notifications**: FCM push notifications for direct messages, group messages, and calls.
- **Notification Center**: In-app notification list with read state.
- **Profile Privacy**: Users can choose which profile fields are visible to others.
- **Theme Modes**: Light mode and dark mode with persisted preference.
- **Localization**: English and Vietnamese language support.
- **Onboarding**: First-run onboarding flow saved locally.

## Installation

```bash
# 1. Clone the repository
git clone <repository-url>

# 2. Navigate to the project directory
cd LumoChat

# 3. Install Flutter dependencies
flutter pub get

# 4. Generate localization files if needed
flutter gen-l10n

# 5. Run the application
flutter run
```

## Firebase Setup

The project is already structured for Firebase:

- `firebase.json`
- `lib/firebase_options.dart`
- `android/app/google-services.json`
- `firestore.rules`
- `storage.rules`
- `functions/index.js`

Deploy Firestore and Storage rules:

```bash
firebase deploy --only firestore:rules,storage
```

Deploy Cloud Functions for push notifications:

```bash
npm --prefix functions install
firebase deploy --only functions
```

The Cloud Function listens to `notifications/{notificationId}` documents and sends FCM notifications to tokens stored in `users/{uid}.fcmTokens`.

## Usage

1. Run the app on an Android device or emulator.
2. Sign up or sign in with a supported authentication method.
3. Complete your required profile information after registration.
4. Add friends from the Contacts screen.
5. Start a 1-1 chat or create a group chat.
6. Send text/image messages, reply, react, recall, pin, or search messages.
7. Start voice/video calls from a direct chat.
8. Check call records saved directly inside the conversation.
9. Configure profile privacy and switch between light/dark mode from Profile.

## Dependencies

Main dependencies:

```yaml
firebase_core: ^3.0.0
firebase_auth: ^5.0.0
cloud_firestore: ^5.0.0
firebase_messaging: ^15.0.0
flutter_local_notifications: ^19.5.0
flutter_riverpod: ^2.6.1
google_sign_in: ^6.2.2
image_picker: 1.0.7
cloudinary_public: ^0.23.1
permission_handler: ^11.3.1
shared_preferences: ^2.2.3
intl: ">=0.19.0 <0.21.0"
flutter_webrtc:
  path: third_party/flutter_webrtc
```

See [pubspec.yaml](./pubspec.yaml) for the full dependency list.

## Quality Checks

Run these checks before opening a pull request:

```bash
flutter analyze
flutter test --reporter expanded
flutter build apk --debug
```

Cloud Functions script:

```bash
npm --prefix functions run lint
```

## Project Structure

```text
lib/
  models/       Data models for chat, calls, and notifications
  screens/      App screens and user flows
  services/     Auth, chat, group, call, notification, theme, and locale services
  theme/        App theme, colors, gradients, and light/dark mode
  utils/        Localization helpers, error mapping, retry policy, profile visibility
  widgets/      Shared UI widgets

functions/      Firebase Cloud Functions for push notifications
test/           Unit and widget tests
firestore.rules Firestore security rules
storage.rules   Firebase Storage security rules
```

## CI

The GitHub Actions workflow is located at:

```text
.github/workflows/flutter-ci.yml
```

The workflow runs:

- `flutter pub get`
- `flutter gen-l10n`
- `flutter analyze`
- `flutter test`
- `flutter build apk --debug`

## Contributing

Contributions are welcome. Before submitting changes:

1. Keep changes scoped to one feature or bug fix.
2. Run the quality checks listed above.
3. Update documentation when changing setup, Firebase rules, notification behavior, or user-facing flows.
4. Avoid committing secrets, private Firebase credentials, or local build artifacts.

## License

No license file is currently included in this repository. Add a `LICENSE` file before distributing or publishing the project.

## Acknowledgments

Thanks to the Flutter, Firebase, WebRTC, Riverpod, and open-source package communities that make this project possible.

## Contact

For questions, suggestions, or bug reports, open an issue in the project repository.

