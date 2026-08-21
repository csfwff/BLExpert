/// Application version shown in the settings workspace.
///
/// Release builds can override this with
/// `--dart-define=APP_VERSION=<version>`. Keep the default in sync with the
/// `version:` value in pubspec.yaml.
abstract final class AppVersion {
  static const String display = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '1.0.0+1',
  );
}
