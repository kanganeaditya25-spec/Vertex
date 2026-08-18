# Productivity Dashboard Flutter Client Foundation

This directory contains the staged Flutter client for the cross-platform, offline-first architecture. Flutter and Dart are not installed in the current sandbox, so the client shell is committed for the next development environment with the SDK available.

## Local setup

Install the latest stable Flutter SDK, then run:

```bash
cd frontend
flutter pub get
flutter analyze
flutter test
flutter run -d chrome
```

The current shell uses Material 3, Riverpod, and Go Router. It includes light, dark, and system theme configuration and a small dashboard summary screen. Feature screens, local repositories, secure storage, local notifications, and offline synchronization will be added in later tasks.
