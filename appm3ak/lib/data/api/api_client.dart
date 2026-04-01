import 'package:dio/dio.dart';
import '../../core/config/app_config.dart';
import 'auth_interceptor.dart';

/// Client HTTP Dio configuré pour l'API Ma3ak.
class ApiClient {
  ApiClient({
    required this.getAccessToken,
  }) {
    _dio = Dio(BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Accept': 'application/json',
        // Ne pas définir Content-Type par défaut - sera défini automatiquement selon le type de données
      },
    ));

    _dio.interceptors.addAll([
      AuthInterceptor(getAccessToken: getAccessToken),
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        error: true,
      ),
    ]);
  }

  late final Dio _dio;
  final Future<String?> Function() getAccessToken;

  Dio get dio => _dio;
}
