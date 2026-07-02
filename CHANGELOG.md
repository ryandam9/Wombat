# Changelog

All notable changes to Wombat are documented here. This project adheres to
[Semantic Versioning](https://semver.org).

## [Unreleased]

### Added
- **macOS desktop support**: the `macos/` runner is now part of the repo, with
  the sandbox entitlements the app needs (OpenRouter network access, microphone
  for voice notes, open/save panels, Keychain for the API key), the launcher
  icon, and a CI job that builds the target on every push/PR.
- **GitHub Actions CI** (`.github/workflows/flutter.yml`): runs `flutter analyze`
  and `flutter test` on every push to `main` and on pull requests, pinned to the
  same Flutter version as the Claude Code web hook.
- **Attachment size limits** (10 MB images, 25 MB audio, 20 MB PDFs) with a
  clear message when a file is too large.
- **Privacy & debug documentation** in the README, plus an in-app notice on the
  debug panel explaining that capture is local, opt-in, and cleared on restart.
- `pubspec.lock` and the Android Gradle wrapper (`gradlew`, `gradlew.bat`,
  `gradle-wrapper.jar`) are now committed for reproducible builds and reliable
  fresh-clone Android builds.

### Changed
- **Debug capture is now off by default.** Request/response bodies are redacted
  (base64 attachment payloads removed) and long strings truncated before being
  retained in the in-memory debug log.
- README brought in sync with the code: Riverpod (not `provider`), Drift/SQLite
  persistence (not JSON), corrected dependency table, and the tested Flutter
  version.

### Fixed
- The OpenRouter `HTTP-Referer` attribution header now points at the correct
  repository (`ryandam9/Wombat`).
- Saving output no longer silently overwrites an existing file — a numeric
  suffix is added (e.g. `wombat-reply-001.md`).
- `OpenRouterService`'s HTTP client is now closed when its provider is disposed.
- The model picker no longer mutates state during `build`.
