abstract final class AppConfig {
  static const appName = 'SecurePlan';

  /// Base URL of the API. Override at compile time with
  /// `--dart-define=API_BASE_URL=https://host`.
  ///
  /// Android emulators cannot reach the host through `localhost`. That
  /// exception is documented in `docs/Development.md` and is not encoded here.
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000',
  );
}
