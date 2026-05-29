# LumoChat

LumoChat is a real-time chat mobile application built with Flutter and Firebase. The app supports direct messages, group conversations, contact management, user profiles, WebRTC voice/video calls, push notifications, localization, and persisted user preferences.

## Features

- Email/password, Google Sign-In, and phone OTP authentication with Firebase Authentication.
- Required profile completion flow for newly registered users.
- Real-time 1-1 messaging with text, image messages, replies, reactions, message search, pinned messages, recall/delete actions, typing indicators, unread counts, and delivery/read status.
- Group chat with group creation, avatar upload, member management, group info, pin/unpin, leave group, and delete group flows.
- Contact system with friend requests, accept/reject/cancel actions, unfriend support, and user profile viewing.
- 1-1 voice and video calls using WebRTC, including incoming call handling, call status tracking, and call records saved into chat history.
- Firebase Cloud Messaging and Flutter Local Notifications for message and call notifications.
- In-app notification center with read state management.
- Profile privacy controls for personal information visibility.
- English and Vietnamese localization using Flutter gen-l10n.
- Persisted light/dark theme and language settings.
- First-run onboarding flow.

## Tech Stack

- **Framework**: Flutter, Dart `^3.5.1`
- **State management**: Riverpod
- **Backend**: Firebase Core, Firebase Authentication, Cloud Firestore
- **Notifications**: Firebase Cloud Messaging, Flutter Local Notifications
- **Serverless**: Firebase Cloud Functions v2, Node.js 20, Firebase Admin SDK
- **Calls**: WebRTC via local `third_party/flutter_webrtc`
- **Media**: Image Picker, Cloudinary
- **Persistence**: SharedPreferences
- **Localization**: Flutter gen-l10n, `intl`
- **Permissions**: `permission_handler`
- **Testing and linting**: `flutter_test`, `flutter_lints`

## Architecture

The app uses Riverpod as the main state management layer:

- `Provider` for service and Firebase dependencies.
- `StateProvider` for lightweight app state such as theme, locale, and selected tab.
- `StateNotifierProvider` for screen-level UI state and user actions.
- `StreamProvider` for real-time Firestore data.
- `FutureProvider` for one-time asynchronous reads.

Long-lived Flutter lifecycle objects such as `TextEditingController`, `ScrollController`, `FocusNode`, `AnimationController`, WebRTC renderers, and stream subscriptions are kept inside widgets and disposed with the widget lifecycle.

## Project Structure

```text
lib/
  main.dart                 App bootstrap and ProviderScope
  firebase_options.dart     Firebase configuration
  models/                   Chat, call, and notification models
  screens/                  App screens and user flows
  services/                 Auth, chat, group, call, notification, locale, theme
  theme/                    App theme, colors, and system UI styles
  utils/                    Error mapping, retry policy, localization, privacy
  widgets/                  Shared UI widgets

functions/                  Firebase Cloud Functions for push notifications
test/                       Unit and widget tests
firestore.rules             Firestore security rules
storage.rules               Firebase Storage security rules
l10n.yaml                   Localization generation config
```

## Requirements

- Flutter stable compatible with Flutter `3.24.1`
- Dart SDK compatible with `^3.5.1`
- Java 17 for Android builds
- Firebase CLI for deploying rules and functions
- Node.js 20 for Cloud Functions
- Android device or emulator for the configured Firebase app

## Getting Started

Clone the project and install dependencies:

```bash
git clone https://github.com/duccquagg137/LumoChat.git
cd LumoChat
flutter pub get
flutter gen-l10n
```

Run the app:

```bash
flutter run
```

## Firebase Setup

Firebase configuration files are included in the project:

```text
firebase.json
lib/firebase_options.dart
android/app/google-services.json
firestore.rules
storage.rules
functions/index.js
```

Deploy Firestore and Storage rules:

```bash
firebase deploy --only firestore:rules,storage
```

Install and deploy Cloud Functions:

```bash
npm --prefix functions install
firebase deploy --only functions
```

The Cloud Function `sendPushOnNotificationCreated` runs in `asia-southeast1`. It listens to `notifications/{notificationId}` documents, reads FCM tokens from `users/{uid}.fcmTokens`, sends multicast push notifications, stores push results, and removes invalid tokens.

## Localization

Localization source files are stored in `lib/utils`:

```text
app_en.arb
app_vi.arb
gen_l10n/
```

Regenerate localization files after editing ARB files:

```bash
flutter gen-l10n
```

## Quality Checks

Run these commands before committing changes:

```bash
flutter analyze
flutter test
flutter build apk --debug
```

Cloud Functions linting:

```bash
npm --prefix functions run lint
```

## CI

GitHub Actions workflow: `.github/workflows/flutter-ci.yml`

The CI pipeline runs:

- `flutter pub get`
- `flutter gen-l10n`
- `flutter analyze`
- `flutter test`
- `flutter build apk --debug`
- Debug APK artifact upload

## Main Dependencies

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

See `pubspec.yaml` for the full dependency list.

## Notes

- Keep Firestore rules and Cloud Functions in sync with chat, group, call, and notification schema changes.
- Do not commit private production credentials beyond the intended Firebase client configuration files.
- Regenerate localization files after changing `app_en.arb` or `app_vi.arb`.

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.
