import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task_flow_v2/features/tasks/data/models/user_model.dart';
import 'package:task_flow_v2/features/tasks/domain/repositories/auth_repository.dart';
import 'package:task_flow_v2/features/tasks/presentation/providers/auth_provider.dart';

void main() {
  const restoredUser = UserModel(
    id: 'user_id',
    name: 'Tên người dùng',
    email: 'email@example.com',
  );

  test('no token skips current-user request and clears User', () async {
    final repository = _FakeAuthRepository(tokenAvailable: false);
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    await container.read(authProvider.notifier).restoreSession();

    final state = container.read(authProvider);
    expect(repository.getCurrentUserCalls, 0);
    expect(state.user, isNull);
    expect(state.isAuthenticated, isFalse);
    expect(state.isCheckingSession, isFalse);
  });

  test('no token restores remembered account without authenticating', () async {
    final repository = _FakeAuthRepository(
      tokenAvailable: false,
      rememberedAccount: restoredUser,
    );
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    await container.read(authProvider.notifier).restoreSession();

    final state = container.read(authProvider);
    expect(repository.getCurrentUserCalls, 0);
    expect(state.rememberedAccount?.id, restoredUser.id);
    expect(state.user, isNull);
    expect(state.isAuthenticated, isFalse);
  });

  test('no remembered account clears any orphaned biometric token', () async {
    final repository = _FakeAuthRepository(
      tokenAvailable: false,
      biometricEnabled: true,
    );
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    await container.read(authProvider.notifier).restoreSession();

    expect(repository.deleteBiometricTokenCalls, 1);
    expect(repository.biometricEnabled, isFalse);
    expect(container.read(authProvider).rememberedAccount, isNull);
    expect(container.read(authProvider).isAuthenticated, isFalse);
  });

  test(
    'successful login remembers the returned user without password',
    () async {
      const loggedInUser = UserModel(
        id: 'new-user',
        name: 'New user',
        email: 'new@example.com',
      );
      final repository = _FakeAuthRepository(
        tokenAvailable: false,
        loginUser: loggedInUser,
      );
      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final success = await container
          .read(authProvider.notifier)
          .login(email: loggedInUser.email, password: 'never-save-this');

      expect(success, isTrue);
      expect(repository.rememberedAccount?.id, loggedInUser.id);
      expect(container.read(authProvider).isAuthenticated, isTrue);
    },
  );

  test(
    'successful account switch replaces remembered account and clears Face ID',
    () async {
      const nextUser = UserModel(
        id: 'next-user',
        name: 'Next user',
        email: 'next@example.com',
      );
      final repository = _FakeAuthRepository(
        tokenAvailable: false,
        rememberedAccount: restoredUser,
        loginUser: nextUser,
        biometricEnabled: true,
      );
      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      await container
          .read(authProvider.notifier)
          .login(email: nextUser.email, password: 'password');

      expect(repository.rememberedAccount?.id, nextUser.id);
      expect(repository.biometricEnabled, isFalse);
      expect(container.read(authProvider).rememberedAccount?.id, nextUser.id);
    },
  );

  test('failed account switch keeps the previous remembered account', () async {
    final repository = _FakeAuthRepository(
      tokenAvailable: false,
      rememberedAccount: restoredUser,
      loginError: DioException(
        requestOptions: RequestOptions(path: '/auth/login'),
        response: Response(
          requestOptions: RequestOptions(path: '/auth/login'),
          statusCode: 401,
        ),
      ),
    );
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    final success = await container
        .read(authProvider.notifier)
        .login(email: 'new@example.com', password: 'incorrect');

    expect(success, isFalse);
    expect(repository.rememberedAccount?.id, restoredUser.id);
    expect(container.read(authProvider).isAuthenticated, isFalse);
  });

  test('logout clears session and retains remembered account', () async {
    final repository = _FakeAuthRepository(rememberedAccount: restoredUser);
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(authProvider.notifier);

    await notifier.restoreSession();
    await notifier.logout();
    await notifier.restoreSession();

    expect(repository.hasTokenValue, isFalse);
    expect(container.read(authProvider).isAuthenticated, isFalse);
    expect(container.read(authProvider).rememberedAccount?.id, restoredUser.id);
  });

  test(
    'restored User remains available after later provider emissions',
    () async {
      final repository = _FakeAuthRepository(user: restoredUser);
      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(authProvider.notifier);
      await notifier.restoreSession();
      final firstState = container.read(authProvider);
      await notifier.requestPasswordReset(email: restoredUser.email);
      final rebuiltState = container.read(authProvider);

      expect(firstState.user?.id, 'user_id');
      expect(firstState.user?.name, 'Tên người dùng');
      expect(firstState.user?.email, 'email@example.com');
      expect(firstState.isAuthenticated, isTrue);
      expect(firstState.rememberedAccount?.id, restoredUser.id);
      expect(rebuiltState.user, same(firstState.user));
    },
  );

  for (final statusCode in [401, 404]) {
    test('/me $statusCode clears token and user state', () async {
      final repository = _FakeAuthRepository(
        error: DioException(
          requestOptions: RequestOptions(path: '/auth/me'),
          response: Response(
            requestOptions: RequestOptions(path: '/auth/me'),
            statusCode: statusCode,
          ),
        ),
      );
      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      await container.read(authProvider.notifier).restoreSession();

      final state = container.read(authProvider);
      expect(repository.logoutCalls, 1);
      expect(repository.hasTokenValue, isFalse);
      expect(state.user, isNull);
      expect(state.isAuthenticated, isFalse);
      expect(state.isCheckingSession, isFalse);
      expect(state.isSessionRestoreError, isFalse);
    });
  }

  test('network error preserves token and exposes retry state', () async {
    final repository = _FakeAuthRepository(
      error: DioException.connectionError(
        requestOptions: RequestOptions(path: '/auth/me'),
        reason: 'offline',
      ),
    );
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    await container.read(authProvider.notifier).restoreSession();

    final state = container.read(authProvider);
    expect(repository.logoutCalls, 0);
    expect(repository.hasTokenValue, isTrue);
    expect(state.user, isNull);
    expect(state.isAuthenticated, isFalse);
    expect(state.isCheckingSession, isFalse);
    expect(state.isSessionRestoreError, isTrue);
    expect(state.errorMessage, isNotEmpty);
  });

  test(
    'retrying restore after a transient error can recover the session',
    () async {
      final repository = _FakeAuthRepository(
        error: DioException.connectionError(
          requestOptions: RequestOptions(path: '/auth/me'),
          reason: 'offline',
        ),
      );
      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      final notifier = container.read(authProvider.notifier);

      await notifier.restoreSession();
      repository.error = null;
      repository.user = restoredUser;
      await notifier.restoreSession();

      expect(container.read(authProvider).user?.name, 'Tên người dùng');
      expect(container.read(authProvider).isAuthenticated, isTrue);
      expect(container.read(authProvider).isSessionRestoreError, isFalse);
    },
  );

  test(
    'logout while restore is pending prevents stale restore from logging in',
    () async {
      final pendingUser = Completer<UserModel>();
      final repository = _FakeAuthRepository(userCompleter: pendingUser);
      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      final notifier = container.read(authProvider.notifier);

      final restoring = notifier.restoreSession();
      await Future<void>.delayed(Duration.zero);
      await notifier.logout();
      pendingUser.complete(restoredUser);
      await restoring;

      final state = container.read(authProvider);
      expect(state.user, isNull);
      expect(state.isAuthenticated, isFalse);
      expect(repository.hasTokenValue, isFalse);
    },
  );

  test(
    'login while restore is pending is not overwritten by stale restore',
    () async {
      final pendingRestore = Completer<UserModel>();
      const loginUser = UserModel(
        id: 'new_user',
        name: 'Tên mới',
        email: 'new@example.com',
      );
      final repository = _FakeAuthRepository(
        userCompleter: pendingRestore,
        loginUser: loginUser,
      );
      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      final notifier = container.read(authProvider.notifier);

      final restoring = notifier.restoreSession();
      await Future<void>.delayed(Duration.zero);
      await notifier.login(email: loginUser.email, password: 'password');
      pendingRestore.complete(restoredUser);
      await restoring;

      expect(container.read(authProvider).user?.id, 'new_user');
      expect(container.read(authProvider).isAuthenticated, isTrue);
    },
  );
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({
    this.tokenAvailable = true,
    this.user,
    this.error,
    this.userCompleter,
    this.loginUser,
    this.rememberedAccount,
    this.loginError,
    this.biometricEnabled = false,
  });

  bool hasTokenValue = true;
  final bool tokenAvailable;
  UserModel? user;
  Object? error;
  final Completer<UserModel>? userCompleter;
  final UserModel? loginUser;
  UserModel? rememberedAccount;
  Object? loginError;
  bool biometricEnabled;
  String? faceIdPromptSeenUserId;
  int deleteBiometricTokenCalls = 0;
  int getCurrentUserCalls = 0;
  int logoutCalls = 0;

  @override
  Future<bool> hasToken() async => hasTokenValue && tokenAvailable;

  @override
  Future<UserModel> getCurrentUser() async {
    getCurrentUserCalls++;
    if (userCompleter != null) return userCompleter!.future;
    if (error != null) throw error!;
    return user ??
        (throw StateError('Fake repository has no configured User.'));
  }

  @override
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    if (loginError != null) throw loginError!;
    return loginUser ?? user!;
  }

  @override
  Future<UserModel?> readRememberedAccount() async => rememberedAccount;

  @override
  Future<void> saveRememberedAccount(UserModel user) async {
    if (rememberedAccount != null && rememberedAccount!.id != user.id) {
      biometricEnabled = false;
    }
    rememberedAccount = user;
  }

  @override
  Future<void> clearRememberedAccount() async {
    rememberedAccount = null;
    biometricEnabled = false;
  }

  @override
  Future<String?> readFaceIdPromptSeenUserId() async => faceIdPromptSeenUserId;

  @override
  Future<void> markFaceIdPromptSeen({required String userId}) async {
    faceIdPromptSeenUserId = userId;
  }

  @override
  Future<bool> isBiometricLoginEnabledFor(String userId) async =>
      biometricEnabled && rememberedAccount?.id == userId;

  @override
  Future<void> saveBiometricToken(String token) async {}

  @override
  Future<String?> readBiometricToken() async => null;

  @override
  Future<void> deleteBiometricToken() async {
    deleteBiometricTokenCalls++;
    biometricEnabled = false;
  }

  @override
  Future<void> enableBiometricLogin({required String userId}) async {
    biometricEnabled = true;
  }

  @override
  Future<UserModel> loginWithBiometric() async => user!;

  @override
  Future<void> logout() async {
    logoutCalls++;
    hasTokenValue = false;
  }

  @override
  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> requestPasswordReset({required String email}) async {}

  @override
  Future<String> verifyPasswordResetOtp({
    required String email,
    required String otp,
  }) async => 'reset-token';

  @override
  Future<void> resetPassword({
    required String email,
    required String resetToken,
    required String newPassword,
  }) async {}

  @override
  Future<UserModel> updateCurrentUser({required String name}) {
    // TODO: implement updateCurrentUser
    throw UnimplementedError();
  }
}
