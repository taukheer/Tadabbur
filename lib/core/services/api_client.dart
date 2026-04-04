import 'dart:io';

import 'package:dio/dio.dart';

/// Custom exception for API errors with structured context.
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic data;

  const ApiException({
    required this.message,
    this.statusCode,
    this.data,
  });

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;
  bool get isServerError => statusCode != null && statusCode! >= 500;
  bool get isNetworkError => statusCode == null;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Dio-based HTTP client for the Quran Foundation API.
///
/// Provides centralized configuration for base URL, auth token injection,
/// request/response logging, error handling, and retry logic for transient
/// failures.
class ApiClient {
  late final Dio _dio;
  String? _authToken;

  static const String _baseUrl = 'https://api.qurancdn.com/api/qdc';

  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 1);

  /// Creates an [ApiClient] with default configuration.
  ///
  /// An optional [dio] instance can be injected for testing.
  ApiClient({Dio? dio}) {
    _dio = dio ?? Dio();
    _dio.options
      ..baseUrl = _baseUrl
      ..connectTimeout = const Duration(seconds: 15)
      ..receiveTimeout = const Duration(seconds: 15)
      ..sendTimeout = const Duration(seconds: 15)
      ..headers = {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };

    _dio.interceptors.addAll([
      _AuthInterceptor(this),
      _LoggingInterceptor(),
    ]);
  }

  /// Sets the Bearer token used for authenticated requests.
  void setAuthToken(String? token) {
    _authToken = token;
  }

  /// The current auth token, if set.
  String? get authToken => _authToken;

  /// Sends a GET request to [path] with optional [queryParameters].
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _executeWithRetry(
      () => _dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: options,
      ),
    );
  }

  /// Sends a POST request to [path] with an optional [data] body.
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _executeWithRetry(
      () => _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      ),
    );
  }

  /// Sends a PUT request to [path] with an optional [data] body.
  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _executeWithRetry(
      () => _dio.put<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      ),
    );
  }

  /// Sends a DELETE request to [path].
  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _executeWithRetry(
      () => _dio.delete<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      ),
    );
  }

  /// Sends a PATCH request to [path] with an optional [data] body.
  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _executeWithRetry(
      () => _dio.patch<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      ),
    );
  }

  /// Executes [request] with automatic retry for transient failures.
  ///
  /// Retries up to [_maxRetries] times on network errors and 5xx server errors
  /// using exponential backoff.
  Future<Response<T>> _executeWithRetry<T>(
    Future<Response<T>> Function() request,
  ) async {
    int attempt = 0;
    while (true) {
      try {
        return await request();
      } on DioException catch (e) {
        attempt++;
        if (!_isRetryable(e) || attempt >= _maxRetries) {
          throw _mapException(e);
        }
        await Future.delayed(_retryDelay * attempt);
      }
    }
  }

  /// Returns true if the error is transient and worth retrying.
  bool _isRetryable(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError) {
      return true;
    }
    final statusCode = e.response?.statusCode;
    if (statusCode != null && statusCode >= 500) {
      return true;
    }
    if (e.error is SocketException) {
      return true;
    }
    return false;
  }

  /// Converts a [DioException] into a structured [ApiException].
  ApiException _mapException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException(
          message: 'Request timed out. Please check your connection.',
          statusCode: e.response?.statusCode,
        );
      case DioExceptionType.connectionError:
        return const ApiException(
          message:
              'Unable to connect. Please check your internet connection.',
        );
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        final data = e.response?.data;
        String message;
        if (data is Map<String, dynamic> && data.containsKey('message')) {
          message = data['message'] as String;
        } else if (data is Map<String, dynamic> &&
            data.containsKey('error')) {
          message = data['error'] as String;
        } else {
          message = _defaultMessageForStatus(statusCode);
        }
        return ApiException(
          message: message,
          statusCode: statusCode,
          data: data,
        );
      case DioExceptionType.cancel:
        return const ApiException(message: 'Request was cancelled.');
      default:
        return ApiException(
          message: e.message ?? 'An unexpected error occurred.',
        );
    }
  }

  String _defaultMessageForStatus(int? statusCode) {
    switch (statusCode) {
      case 400:
        return 'Bad request.';
      case 401:
        return 'Authentication required.';
      case 403:
        return 'Access denied.';
      case 404:
        return 'Resource not found.';
      case 422:
        return 'Validation error.';
      case 429:
        return 'Too many requests. Please try again later.';
      case 500:
        return 'Internal server error.';
      case 502:
        return 'Bad gateway.';
      case 503:
        return 'Service temporarily unavailable.';
      default:
        return 'Request failed with status $statusCode.';
    }
  }
}

/// Interceptor that injects the Bearer auth token into request headers.
class _AuthInterceptor extends Interceptor {
  final ApiClient _client;

  _AuthInterceptor(this._client);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = _client.authToken;
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}

/// Interceptor that logs request and response details for debugging.
class _LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final timestamp = DateTime.now().toIso8601String();
    // ignore: avoid_print
    print('[$timestamp] --> ${options.method} ${options.uri}');
    if (options.queryParameters.isNotEmpty) {
      // ignore: avoid_print
      print('[$timestamp]     Query: ${options.queryParameters}');
    }
    handler.next(options);
  }

  @override
  void onResponse(
    Response response,
    ResponseInterceptorHandler handler,
  ) {
    final timestamp = DateTime.now().toIso8601String();
    // ignore: avoid_print
    print(
      '[$timestamp] <-- ${response.statusCode} '
      '${response.requestOptions.method} '
      '${response.requestOptions.uri}',
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final timestamp = DateTime.now().toIso8601String();
    // ignore: avoid_print
    print(
      '[$timestamp] <-- ERROR ${err.response?.statusCode ?? 'NETWORK'} '
      '${err.requestOptions.method} '
      '${err.requestOptions.uri} '
      '${err.message}',
    );
    handler.next(err);
  }
}
