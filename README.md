# LumoChat

Flutter chat application with direct messages, groups, contacts, and profile flows.

## Current Release
- App version: `1.0.1+2`
- Changelog: [CHANGELOG.md](./CHANGELOG.md)

## Quality Gate
Every pull request to `main`/`master` runs the CI workflow at
`.github/workflows/flutter-ci.yml` with the following required steps:
- `flutter pub get`
- `flutter gen-l10n`
- `flutter analyze`
- `flutter test`
- `flutter build apk --debug` (artifact upload)

## Local Checks
Run before opening PR:

```bash
flutter pub get
flutter gen-l10n
flutter analyze
flutter test
```

## Security Rules
- Firestore rules: `firestore.rules`
- Storage rules: `storage.rules`
- Security regression checklist: `docs/security-checklist-giai-doan-9.md`

## Notes
- On first run (not signed in), app opens onboarding once and stores completion state locally.
- Group chat now links directly to Group Info from the conversation header.
