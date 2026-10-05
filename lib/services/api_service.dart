import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/app_config.dart';
import '../models/user_model.dart';

final secureStorageProvider = Provider<FlutterSecureStorage>(
  (ref) => const FlutterSecureStorage(),
);

final dioProvider = Provider<Dio>((ref) {
  final apiUrl = AppConfig.apiBaseUrl.replaceFirst(RegExp(r'/+$'), '');
  return Dio(BaseOptions(
    baseUrl: apiUrl,
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 45),
    sendTimeout: const Duration(minutes: 2),
    headers: const {'Accept': 'application/json'},
  ));
});

final apiServiceProvider = Provider<ApiService>(
  (ref) => ApiService(ref.watch(dioProvider)),
);

class ApiService {
  ApiService(this._dio) {
    _dio.interceptors.add(InterceptorsWrapper(
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) await _unauthorizedHandler?.call();
        handler.next(error);
      },
    ));
  }

  final Dio _dio;
  Future<void> Function()? _unauthorizedHandler;

  String get apiBaseUrl => _dio.options.baseUrl;

  void setUnauthorizedHandler(Future<void> Function()? handler) {
    _unauthorizedHandler = handler;
  }

  void setAuthToken(String? token) {
    if (token == null || token.isEmpty) {
      _dio.options.headers.remove('Authorization');
    } else {
      _dio.options.headers['Authorization'] = 'Bearer $token';
    }
  }

  Future<String> login({required String email, required String password}) async {
    final response = await _dio.post(
      '/api/auth/signin',
      data: {'email': email, 'password': password},
    );
    final payload = _asMap(response.data);
    final token = '${payload['accessToken'] ?? ''}';
    if (token.isEmpty) throw Exception('Máy chủ không trả về mã đăng nhập.');
    return token;
  }

  Future<UserModel> getCurrentUser() async {
    final response = await _dio.get('/api/auth/me');
    return UserModel.fromJson(_asMap(response.data));
  }

  Future<UserModel> updateProfile({
    required String fullName,
    required String email,
    String? currentPassword,
    String? newPassword,
  }) async {
    final response = await _dio.put('/api/auth/me', data: {
      'full_name': fullName,
      'email': email,
      if ((currentPassword ?? '').isNotEmpty) 'current_password': currentPassword,
      if ((newPassword ?? '').isNotEmpty) 'new_password': newPassword,
    });
    return UserModel.fromJson(_asMap(response.data));
  }

  Future<List<Map<String, dynamic>>> getCalls({int offset = 0, int limit = 20}) async {
    final response = await _dio.get('/api/mediafile/', queryParameters: {
      'offset': offset,
      'limit': limit,
    });
    final records = _asMap(response.data)['mediaFile'];
    if (records is! List) return const [];
    return records.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
  }

  Future<Map<String, dynamic>> getAnalytics() async {
    final response = await _dio.get('/api/analytics/me');
    return _asMap(response.data);
  }

  Future<List<Map<String, dynamic>>> getJobs({int offset = 0, int limit = 100}) async {
    final response = await _dio.get('/api/transcribe/', queryParameters: {
      'offset': offset,
      'limit': limit,
    });
    if (response.data is! List) return const [];
    return (response.data as List)
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<Map<String, dynamic>> getCallResult(int callId) async {
    final response = await _dio.get('/api/mediafile/$callId/result');
    return _asMap(response.data);
  }

  Future<List<Map<String, dynamic>>> getNotifications() async {
    final response = await _dio.get('/api/notifications/');
    if (response.data is! List) return const [];
    return (response.data as List)
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<void> markNotificationRead(int notificationId) async {
    await _dio.patch('/api/notifications/$notificationId/read');
  }

  Future<Map<String, dynamic>> uploadCall({
    required PlatformFile file,
    String? clientNumber,
    required void Function(int sent, int total) onProgress,
  }) async {
    final bytes = file.bytes;
    if (bytes == null) throw Exception('Không đọc được nội dung tệp đã chọn.');
    final response = await _dio.post(
      '/api/transcribe/upload',
      data: FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: file.name),
        if ((clientNumber ?? '').trim().isNotEmpty) 'clientNumber': clientNumber!.trim(),
      }),
      onSendProgress: onProgress,
    );
    return _asMap(response.data);
  }

  String getError(Object error) {
    if (error is DioException) {
      if (error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout) {
        return 'Không kết nối được máy chủ. Hãy kiểm tra địa chỉ API và mạng.';
      }
      final response = error.response?.data;
      if (response is Map && response['detail'] is String) {
        return response['detail'] as String;
      }
      if (error.response?.statusCode == 401) return 'Phiên đăng nhập hết hạn. Vui lòng đăng nhập lại.';
      if (error.response?.statusCode == 403) return 'Tài khoản không có quyền thực hiện thao tác này.';
    }
    return error.toString().replaceFirst('Exception: ', '');
  }
}

Map<String, dynamic> _asMap(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
