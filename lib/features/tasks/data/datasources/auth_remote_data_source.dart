import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart';
import 'package:task_flow_v2/core/network/api_client.dart';

import '../models/user_model.dart';

final class AuthRemoteDataSource {
  AuthRemoteDataSource({ApiClient? apiClient, FlutterSecureStorage? storage})
    : _apiClient = apiClient ?? ApiClient(),
      _storage = storage ?? const FlutterSecureStorage();

  final ApiClient _apiClient;
  final FlutterSecureStorage _storage;

  static const _rememberedAccountKey = 'remembered_account_v1';
  static const _biometricUserIdKey = 'biometric_user_id';
  static const _faceIdPromptSeenKey = 'face_id_setup_prompt_seen';

  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    final response = await _apiClient.dio.post(
      '/auth/login',
      data: {'email': email, 'password': password},
    );

    final body = response.data;

    if (body is! Map) {
      throw const FormatException('Dữ liệu đăng nhập không hợp lệ.');
    }

    final data = body['data'];

    if (data is! Map || data['token'] is! String) {
      throw const FormatException('API không trả về token hợp lệ.');
    }

    final userJson = data['user'];

    if (userJson is! Map) {
      throw const FormatException('API không trả về thông tin người dùng.');
    }

    final user = UserModel.fromJson(Map<String, dynamic>.from(userJson));
    _validateUserIdentity(user);

    final token = data['token'] as String;

    if (token.isEmpty) {
      throw const FormatException('Token đăng nhập đang trống.');
    }

    await _storage.write(key: 'auth_token', value: token);

    return user;
  }

  Future<UserModel> getCurrentUser() async {
    final response = await _apiClient.dio.get('/auth/me');
    final body = response.data;

    if (body is! Map) {
      throw const FormatException('Dữ liệu tài khoản không hợp lệ.');
    }

    final data = body['data'];
    if (data is! Map || data['user'] is! Map) {
      throw const FormatException('API không trả về thông tin người dùng.');
    }

    final user = UserModel.fromJson(
      Map<String, dynamic>.from(data['user'] as Map),
    );
    if (user.id.trim().isEmpty ||
        user.name.trim().isEmpty ||
        user.email.trim().isEmpty) {
      throw const FormatException('Thông tin tài khoản không đầy đủ.');
    }

    return user;
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    await _apiClient.dio.post(
      '/auth/register',
      data: {'name': name, 'email': email, 'password': password},
    );
  }

  Future<void> requestPasswordReset({required String email}) async {
    await _apiClient.dio.post('/auth/forgot-password', data: {'email': email});
  }

  Future<String> verifyPasswordResetOtp({
    required String email,
    required String otp,
  }) async {
    final response = await _apiClient.dio.post(
      '/auth/verify-reset-otp',
      data: {'email': email, 'otp': otp},
    );

    final body = response.data;
    if (body is! Map) {
      throw const FormatException('Dữ liệu xác thực OTP không hợp lệ.');
    }

    final data = body['data'];
    if (data is! Map || data['resetToken'] is! String) {
      throw const FormatException('API không trả về reset token hợp lệ.');
    }

    return data['resetToken'] as String;
  }

  Future<void> resetPassword({
    required String email,
    required String resetToken,
    required String newPassword,
  }) async {
    await _apiClient.dio.post(
      '/auth/reset-password',
      data: {
        'email': email,
        'resetToken': resetToken,
        'newPassword': newPassword,
      },
    );
  }

  Future<UserModel> updateCurrentUser({required String name}) async {
    final response = await _apiClient.dio.patch(
      '/auth/me',
      data: {'name': name.trim()},
    );

    final body = response.data;
    if (body is! Map || body['data'] is! Map) {
      throw const FormatException('Dữ liệu cập nhật hồ sơ không hợp lệ.');
    }

    final userJson = body['data']['user'];
    if (userJson is! Map) {
      throw const FormatException('API không trả về thông tin người dùng.');
    }

    final user = UserModel.fromJson(Map<String, dynamic>.from(userJson));
    _validateUserIdentity(user);
    return user;
  }

  Future<void> logout() async {
    await _storage.delete(key: 'auth_token');
  }

  Future<UserModel?> readRememberedAccount() async {
    final value = await _storage.read(key: _rememberedAccountKey);
    if (value == null) return null;

    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map) throw const FormatException();
      final user = UserModel.fromJson(Map<String, dynamic>.from(decoded));
      _validateUserIdentity(user);
      return user;
    } on FormatException {
      await _storage.delete(key: _rememberedAccountKey);
      return null;
    } on TypeError {
      await _storage.delete(key: _rememberedAccountKey);
      return null;
    }
  }

  Future<void> saveRememberedAccount(UserModel user) async {
    _validateUserIdentity(user);

    final previous = await readRememberedAccount();
    if (previous != null && previous.id != user.id) {
      await deleteBiometricToken();
      await _storage.delete(key: _rememberedAccountKey);
    }

    await _storage.write(
      key: _rememberedAccountKey,
      value: jsonEncode({
        'id': user.id,
        'name': user.name,
        'email': user.email,
      }),
    );
  }

  Future<void> clearRememberedAccount() async {
    await _storage.delete(key: _rememberedAccountKey);
    await deleteBiometricToken();
  }

  Future<bool> isBiometricLoginEnabledFor(String userId) async {
    final enabled = await _storage.read(key: 'face_id_enabled') == 'true';
    final biometricUserId = await _storage.read(key: _biometricUserIdKey);

    if (enabled && biometricUserId == userId) {
      return true;
    }

    if (enabled || biometricUserId != null) await deleteBiometricToken();
    return false;
  }

  Future<String?> readFaceIdPromptSeenUserId() {
    return _storage.read(key: _faceIdPromptSeenKey);
  }

  Future<void> markFaceIdPromptSeen({required String userId}) {
    return _storage.write(key: _faceIdPromptSeenKey, value: userId);
  }

  void _validateUserIdentity(UserModel user) {
    if (user.id.trim().isEmpty ||
        user.name.trim().isEmpty ||
        user.email.trim().isEmpty) {
      throw const FormatException(
        'Thông tin tài khoản đã ghi nhớ không hợp lệ.',
      );
    }
  }

  Future<String?> getToken() {
    return _storage.read(key: 'auth_token');
  }

  static const _biometricTokenKey = 'biometric_auth_token';

  static const _biometricOptions = IOSOptions(
    accessibility: KeychainAccessibility.unlocked_this_device,
    accessControlFlags: [AccessControlFlag.biometryCurrentSet],
  );

  Future<void> saveBiometricToken(String token) {
    return _storage.write(
      key: _biometricTokenKey,
      value: token,
      iOptions: _biometricOptions,
    );
  }

  Future<String?> readBiometricToken() {
    return _storage.read(key: _biometricTokenKey, iOptions: _biometricOptions);
  }

  Future<void> deleteBiometricToken() async {
    await _storage.delete(key: _biometricTokenKey, iOptions: _biometricOptions);
    await _storage.delete(key: 'face_id_enabled');
    await _storage.delete(key: _biometricUserIdKey);
  }

  Future<void> enableBiometricLogin({required String userId}) async {
    final token = await _storage.read(key: 'auth_token');

    if (token == null || token.isEmpty || userId.trim().isEmpty) {
      throw const FormatException('Không tìm thấy phiên đăng nhập.');
    }

    await saveBiometricToken(token);
    await _storage.write(key: _biometricUserIdKey, value: userId);
    await _storage.write(key: 'face_id_enabled', value: 'true');
  }

  Future<UserModel> loginWithBiometric() async {
    final rememberedAccount = await readRememberedAccount();
    if (rememberedAccount == null ||
        !await isBiometricLoginEnabledFor(rememberedAccount.id)) {
      throw const FormatException(
        'Đăng nhập bằng Face ID chưa được bật cho tài khoản này.',
      );
    }

    String? token;
    try {
      token = await readBiometricToken();
    } catch (error) {
      if (error is PlatformException && error.details == -128) {
        throw const FormatException('Đã hủy xác thực Face ID.');
      }
      try {
        await deleteBiometricToken();
      } catch (_) {}
      rethrow;
    }

    if (token == null || token.isEmpty) {
      await deleteBiometricToken();
      throw const FormatException(
        'Bạn chưa bật đăng nhập bằng Face ID. Vui lòng đăng nhập bằng mật khẩu trước.',
      );
    }

    // ApiClient cần khóa này để gửi Authorization cho /auth/me.
    await _storage.write(key: 'auth_token', value: token);

    try {
      final user = await getCurrentUser();
      if (user.id != rememberedAccount.id) {
        await _storage.delete(key: 'auth_token');
        await deleteBiometricToken();
        throw const FormatException(
          'Face ID không được liên kết với tài khoản đã ghi nhớ.',
        );
      }
      return user;
    } catch (error) {
      // Không giữ token thường nếu kiểm tra phiên thất bại.
      await _storage.delete(key: 'auth_token');

      if (error is DioException &&
          (error.response?.statusCode == 401 ||
              error.response?.statusCode == 404)) {
        // Phiên không còn hợp lệ: yêu cầu đăng nhập mật khẩu lại.
        await deleteBiometricToken();
        await _storage.delete(key: _faceIdPromptSeenKey);
      }

      rethrow;
    }
  }
}
