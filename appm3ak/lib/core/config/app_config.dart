import 'app_config_stub.dart'
    if (dart.library.io) 'app_config_io.dart' as _impl;

/// Configuration de l'application Ma3ak.
/// Les valeurs peuvent être surchargées via --dart-define ou environnement.
class AppConfig {
  AppConfig._();

  static const String _envApiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  /// URL de base de l'API. Sur l'émulateur Android, "localhost" du PC
  /// est accessible via 10.0.2.2 (utilisé par défaut si API_BASE_URL non défini).
  static String get apiBaseUrl {
    if (_envApiBaseUrl.isNotEmpty) return _envApiBaseUrl;
    return _impl.getDefaultApiBaseUrl();
  }

  static String get uploadsBaseUrl => apiBaseUrl;
}
