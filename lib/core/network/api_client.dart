import 'package:floating_logger/floating_logger.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final class ApiClient {
  ApiClient({Dio? dio, FlutterSecureStorage? storage})
    : dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: const String.fromEnvironment(
                'API_BASE_URL',
                defaultValue: 'https://taskflow-api-z739.onrender.com/api',
              ),
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
              headers: const {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
            ),
          ),
      _storage = storage ?? const FlutterSecureStorage() {
    this.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          try {
            final token = await _storage.read(key: 'auth_token');

            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            } else {
              options.headers.remove('Authorization');
            }

            handler.next(options);
          } catch (error, stackTrace) {
            handler.reject(
              DioException(
                requestOptions: options,
                error: error,
                stackTrace: stackTrace,
              ),
            );
          }
        },
      ),
    );

    this.dio.interceptors.add(
      FloatingLoggerInterceptor(
        options: const FloatingLoggerInterceptorOptions(
          hideRequestBody: true,
          hideResponseBody: true,
          hideRequestParams: true,
          hideRequestHeaders: true,
          hideResponseHeaders: true,
        ),
      ),
    );
  }

  final Dio dio;
  final FlutterSecureStorage _storage;
}
