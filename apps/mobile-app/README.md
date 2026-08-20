# Budgcoach mobile app

Flutter client for Budgcoach. Android and iOS accept bank/wallet statements
from the system share sheet as well as the in-app file picker.

Use JDK 17 for Android builds. Newer Android Studio previews may bundle a JDK
that is newer than the Gradle/Flutter toolchain supports.

## Development

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
```

The Android emulator uses `10.0.2.2` for a backend running on the host. iOS
simulator and desktop development default to `127.0.0.1` when no define is
provided. Release builds intentionally fail at startup unless an absolute HTTPS
endpoint is supplied.

## Release builds

```bash
flutter build appbundle \
  --dart-define=API_BASE_URL=https://api.example.com/api/v1

flutter build ipa \
  --dart-define=API_BASE_URL=https://api.example.com/api/v1
```

For Android, copy `android/key.properties.example` to
`android/key.properties` and point it to the Play upload keystore. The real
properties file and keystores are ignored by Git. For iOS, select the Apple
team for both `Runner` and `ShareExtension`, then enable their existing shared
App Group: `group.com.budgcoach.budgcoach`.
