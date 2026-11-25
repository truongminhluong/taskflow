import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task_flow_v2/core/network/api_client.dart';
import 'package:task_flow_v2/features/tasks/data/datasources/auth_remote_data_source.dart';
import 'package:task_flow_v2/features/tasks/data/models/user_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'GET /auth/me parses data.user and uses the existing Bearer token',
    () async {
      FlutterSecureStorage.setMockInitialValues({'auth_token': 'saved-token'});
      final adapter = _MeAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://taskflow.test/api'))
        ..httpClientAdapter = adapter;
      final storage = const FlutterSecureStorage();
      final dataSource = AuthRemoteDataSource(
        apiClient: ApiClient(dio: dio, storage: storage),
        storage: storage,
      );
      addTearDown(dio.close);

      final user = await dataSource.getCurrentUser();

      expect(adapter.requestPath, '/api/auth/me');
      expect(adapter.authorization, 'Bearer saved-token');
      expect(user.id, 'user_id');
      expect(user.name, 'Tên người dùng');
      expect(user.email, 'email@example.com');
    },
  );

  test('remembered account stores identity only and survives logout', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final storage = const FlutterSecureStorage();
    final dataSource = AuthRemoteDataSource(storage: storage);
    const user = UserModel(id: 'user-1', name: 'Minh Anh', email: 'a@b.com');

    await dataSource.saveRememberedAccount(user);
    await storage.write(key: 'auth_token', value: 'session-secret');
    await dataSource.saveBiometricToken('biometric-session');
    await storage.write(key: 'face_id_enabled', value: 'true');
    await storage.write(key: 'biometric_user_id', value: user.id);
    await dataSource.logout();

    final remembered = await dataSource.readRememberedAccount();
    expect(remembered?.id, user.id);
    expect(remembered?.name, user.name);
    expect(remembered?.email, user.email);
    expect(await storage.read(key: 'auth_token'), isNull);
    expect(await dataSource.readBiometricToken(), 'biometric-session');
    expect(await storage.read(key: 'face_id_enabled'), 'true');
    final serialized = await storage.read(key: 'remembered_account_v1');
    expect(serialized, contains('user-1'));
    expect(serialized, isNot(contains('password')));
    expect(serialized, isNot(contains('session-secret')));
  });

  test(
    'switching remembered account clears old biometric credentials',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        'auth_token': 'new-session',
        'biometric_auth_token': 'old-session',
        'face_id_enabled': 'true',
        'biometric_user_id': 'old-user',
        'remembered_account_v1': jsonEncode({
          'id': 'old-user',
          'name': 'Old user',
          'email': 'old@example.com',
        }),
      });
      final storage = const FlutterSecureStorage();
      final dataSource = AuthRemoteDataSource(storage: storage);

      await dataSource.saveRememberedAccount(
        const UserModel(
          id: 'new-user',
          name: 'New user',
          email: 'new@example.com',
        ),
      );

      expect((await dataSource.readRememberedAccount())?.id, 'new-user');
      expect(await dataSource.readBiometricToken(), isNull);
      expect(await storage.read(key: 'face_id_enabled'), isNull);
      expect(await storage.read(key: 'biometric_user_id'), isNull);
      expect(await storage.read(key: 'auth_token'), 'new-session');
    },
  );

  test(
    'biometric token without a matching enabled account is rejected',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        'biometric_auth_token': 'old-session',
        'face_id_enabled': 'true',
        'remembered_account_v1': jsonEncode({
          'id': 'remembered-user',
          'name': 'User',
          'email': 'user@example.com',
        }),
      });
      final storage = const FlutterSecureStorage();
      final dataSource = AuthRemoteDataSource(storage: storage);

      expect(
        await dataSource.isBiometricLoginEnabledFor('remembered-user'),
        false,
      );
      expect(await dataSource.readBiometricToken(), isNull);
      expect(await storage.read(key: 'face_id_enabled'), isNull);
    },
  );

  test(
    'biometric response for a different account clears token and setting',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        'biometric_auth_token': 'saved-token',
        'face_id_enabled': 'true',
        'biometric_user_id': 'another-user',
        'remembered_account_v1': jsonEncode({
          'id': 'another-user',
          'name': 'Another user',
          'email': 'another@example.com',
        }),
      });
      final storage = const FlutterSecureStorage();
      final dio = Dio(BaseOptions(baseUrl: 'https://taskflow.test/api'))
        ..httpClientAdapter = _MeAdapter();
      final dataSource = AuthRemoteDataSource(
        apiClient: ApiClient(dio: dio, storage: storage),
        storage: storage,
      );
      addTearDown(dio.close);

      await expectLater(dataSource.loginWithBiometric(), throwsFormatException);

      expect(await storage.read(key: 'auth_token'), isNull);
      expect(await dataSource.readBiometricToken(), isNull);
      expect(await storage.read(key: 'face_id_enabled'), isNull);
    },
  );

  test(
    'biometric login validates the token against the remembered user',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        'biometric_auth_token': 'saved-token',
        'face_id_enabled': 'true',
        'biometric_user_id': 'user_id',
        'remembered_account_v1': jsonEncode({
          'id': 'user_id',
          'name': 'Tên người dùng',
          'email': 'email@example.com',
        }),
      });
      final storage = const FlutterSecureStorage();
      final dio = Dio(BaseOptions(baseUrl: 'https://taskflow.test/api'))
        ..httpClientAdapter = _MeAdapter();
      final dataSource = AuthRemoteDataSource(
        apiClient: ApiClient(dio: dio, storage: storage),
        storage: storage,
      );
      addTearDown(dio.close);

      final user = await dataSource.loginWithBiometric();

      expect(user.id, 'user_id');
      expect(await storage.read(key: 'auth_token'), 'saved-token');
    },
  );

  test(
    'missing protected biometric token disables stale Face ID setting',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        'face_id_enabled': 'true',
        'biometric_user_id': 'user_id',
        'remembered_account_v1': jsonEncode({
          'id': 'user_id',
          'name': 'Tên người dùng',
          'email': 'email@example.com',
        }),
      });
      final dataSource = AuthRemoteDataSource(
        storage: const FlutterSecureStorage(),
      );

      await expectLater(dataSource.loginWithBiometric(), throwsFormatException);

      expect(await dataSource.isBiometricLoginEnabledFor('user_id'), false);
    },
  );

  test(
    'enrollment stores the current account binding with the protected token',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        'auth_token': 'session-token',
      });
      final storage = const FlutterSecureStorage();
      final dataSource = AuthRemoteDataSource(storage: storage);

      await dataSource.enableBiometricLogin(userId: 'user_id');

      expect(await storage.read(key: 'biometric_user_id'), 'user_id');
      expect(await storage.read(key: 'face_id_enabled'), 'true');
      expect(await dataSource.readBiometricToken(), 'session-token');
      expect(await storage.read(key: 'auth_token'), 'session-token');
    },
  );

  test(
    'Face ID setup prompt marker is scoped to the current account',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      final storage = const FlutterSecureStorage();
      final dataSource = AuthRemoteDataSource(storage: storage);

      expect(await dataSource.readFaceIdPromptSeenUserId(), isNull);
      await dataSource.markFaceIdPromptSeen(userId: 'user_a');
      expect(await dataSource.readFaceIdPromptSeenUserId(), 'user_a');

      await dataSource.markFaceIdPromptSeen(userId: 'user_b');
      expect(await dataSource.readFaceIdPromptSeenUserId(), 'user_b');
    },
  );
}

class _MeAdapter implements HttpClientAdapter {
  String? requestPath;
  String? authorization;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestPath = options.uri.path;
    authorization = options.headers['Authorization'] as String?;
    return ResponseBody.fromString(
      jsonEncode({
        'message': 'Lấy thông tin tài khoản thành công',
        'data': {
          'user': {
            'id': 'user_id',
            'name': 'Tên người dùng',
            'email': 'email@example.com',
          },
        },
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
