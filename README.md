# LumoChat

LumoChat is a Flutter realtime chat application backed by Firebase. It supports direct messages, group chats, contacts, profiles, voice/video calls, push notifications, profile privacy, localization, and light/dark mode.

## Tech Stack

- **Client**: Flutter, Dart `^3.5.1`
- **State management**: Riverpod (`flutter_riverpod`)
- **Backend**: Firebase Core, Firebase Auth, Cloud Firestore
- **Push notifications**: Firebase Cloud Messaging, Flutter Local Notifications
- **Cloud Functions**: Firebase Functions v2, Node.js 20, Firebase Admin SDK
- **Voice/video calls**: WebRTC via local `third_party/flutter_webrtc`
- **Media**: `image_picker` for local selection, Cloudinary for uploads
- **Local persistence**: `shared_preferences`
- **Localization**: Flutter gen-l10n, `intl`, English and Vietnamese ARB files
- **Permissions**: `permission_handler`
- **Testing/linting**: `flutter_test`, `flutter_lints`

## Features

- Email/password, Google Sign-In, and phone OTP authentication
- Required profile completion for new users
- Realtime 1-1 chat with text, images, replies, reactions, search, pinned messages, recall, delete-for-me, and delivery/read status
- Group creation, group chat, member management, group info, pin/unpin groups, leave/delete group flows
- Contact and friend request management
- 1-1 voice and video calls using WebRTC
- Call records stored as system messages in chat
- FCM push notifications for messages and calls
- In-app notification center with read state
- Profile privacy controls
- Persisted light/dark theme and locale
- First-run onboarding flow

## State Management

The app uses **Riverpod** as the primary state management layer.

- `Provider` is used for Firebase/service dependencies.
- `StateProvider` is used for simple app state such as locale, theme, and selected tab.
- `StateNotifierProvider` is used for screen UI state such as loading flags, filters, search state, busy item IDs, selected members, and call/chat controls.
- `StreamProvider` is used for realtime Firestore data.
- `FutureProvider` is used for one-shot async reads.

Flutter lifecycle objects such as `TextEditingController`, `ScrollController`, `AnimationController`, `FocusNode`, WebRTC renderers, and subscriptions remain inside widgets so they can be disposed correctly.

## Project Structure

```text
lib/
  main.dart                 App bootstrap and ProviderScope
  firebase_options.dart     Firebase app configuration
  models/                   Chat, call, and notification models
  screens/                  App screens and flows
  services/                 Auth, chat, group, call, notification, locale, theme
  theme/                    Theme, colors, gradients, system overlay styles
  utils/                    Error mapping, retry policy, l10n helpers, privacy
  widgets/                  Shared UI widgets

functions/                  Firebase Cloud Functions for push notifications
test/                       Unit and widget tests
firestore.rules             Firestore security rules
storage.rules               Firebase Storage security rules
l10n.yaml                   Localization generation config
```

## Requirements

- Flutter stable, compatible with Flutter `3.24.1` as used by CI
- Dart SDK compatible with `^3.5.1`
- Java 17 for Android builds
- Firebase CLI for rules/functions deployment
- Node.js 20 for Cloud Functions
- Android device/emulator for the current configured Firebase app

## Installation

```bash
git clone <repository-url>
cd LumoChat
flutter pub get
flutter gen-l10n
flutter run
```

## Firebase Setup

Firebase-related files are already present in the repository:

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

Localization sources live in `lib/utils`:

```text
app_en.arb
app_vi.arb
gen_l10n/
```

Generate localization files with:

```bash
flutter gen-l10n
```

## Quality Checks

Run these before committing or opening a pull request:

```bash
flutter analyze
flutter test
flutter build apk --debug
```

Cloud Functions:

```bash
npm --prefix functions run lint
```

Current local verification:

- `flutter analyze`: passing
- `flutter test`: passing

## CI

GitHub Actions workflow: `.github/workflows/flutter-ci.yml`

The workflow runs:

- `flutter pub get`
- `flutter gen-l10n`
- `flutter analyze`
- `flutter test`
- `flutter build apk --debug`
- Uploads the debug APK artifact

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

- Do not commit private production credentials beyond the intended Firebase client config files.
- Keep Firestore rules and Cloud Functions in sync with notification, chat, and group schema changes.
- Update generated localization files after editing ARB content.

## License

No license file is currently included. Add a `LICENSE` file before distributing or publishing this project.
