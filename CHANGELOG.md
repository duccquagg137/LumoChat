# Changelog

All notable changes to this project are documented in this file.

## [1.0.1] - 2026-04-09

### Added
- Retry/backoff and domain-aware error mapping for chat, contacts, and groups.
- Logging hooks for critical network/permission/timeout failures.
- In-chat message search and group info navigation from group conversations.
- Unread badge synchronization for direct chat and groups.
- Group pin/unpin support in list and group info.
- Firestore and Storage security rules with least-privilege defaults.
- CI workflow for `flutter gen-l10n`, `flutter analyze`, `flutter test`, and debug APK artifact upload.
- Security checklist for cross-user authorization tests.

### Changed
- Optimized chat, groups, and contacts list rendering to reduce redundant rebuilds.
- Improved image loading with caching, placeholders, and retry UX.
- Added onboarding first-run routing using persisted completion flag.
- Bumped app version to `1.0.1+2`.

### Notes
- Remaining release tasks: finalize release checklist results and tag after manual regression verification.
