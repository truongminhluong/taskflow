import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:task_flow_v2/features/tasks/data/models/user_model.dart';
import 'package:task_flow_v2/features/tasks/domain/repositories/auth_repository.dart';
import 'package:task_flow_v2/features/tasks/presentation/providers/auth_provider.dart';
import 'package:task_flow_v2/features/tasks/presentation/screens/login_screen.dart';

void main() {
  const remembered = UserModel(
    id: 'user-1',
    name: 'Nguyễn Minh Anh',
    email: 'minhanh@example.com',
  );

  testWidgets('shows ordinary login when there is no remembered account', (
    tester,
  ) async {
    final repository = _LoginRepository();
    final container = _container(repository);
    addTearDown(container.dispose);
    await container.read(authProvider.notifier).restoreSession();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: LoginScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Nhập địa chỉ email'), findsOneWidget);
    expect(find.text('Chưa có tài khoản?'), findsOneWidget);
    expect(find.text('minhanh@example.com'), findsNothing);
  });

  testWidgets('shows remembered identity and retains Welcome Back on failure', (
    tester,
  ) async {
    final repository = _LoginRepository(
      remembered: remembered,
      loginError: Exception('invalid credentials'),
    );
    final container = _container(repository);
    addTearDown(container.dispose);
    await container.read(authProvider.notifier).restoreSession();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: LoginScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(remembered.name), findsOneWidget);
    expect(find.text(remembered.email), findsOneWidget);
    expect(find.text('Đăng nhập bằng tài khoản khác'), findsOneWidget);
    expect(find.text('Email'), findsNothing);

    await tester.enterText(find.byType(TextFormField), 'wrong-password');
    await tester.tap(find.text('Đăng nhập').first);
    await tester.pumpAndSettle();

    expect(find.text(remembered.name), findsOneWidget);
    expect(find.text(remembered.email), findsOneWidget);
    expect(container.read(authProvider).isAuthenticated, isFalse);
  });

  testWidgets(
    'account switch shows email login without deleting remembered data',
    (tester) async {
      final repository = _LoginRepository(remembered: remembered);
      final container = _container(repository);
      addTearDown(container.dispose);
      await container.read(authProvider.notifier).restoreSession();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: LoginScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Đăng nhập bằng tài khoản khác'));
      await tester.pumpAndSettle();

      expect(find.text('Nhập địa chỉ email'), findsOneWidget);
      expect(find.text(remembered.email), findsNothing);
      expect(repository.remembered?.id, remembered.id);
    },
  );

  testWidgets('remembered password login authenticates the remembered email', (
    tester,
  ) async {
    final repository = _LoginRepository(
      remembered: remembered,
      loginUser: remembered,
    );
    final container = _container(repository);
    addTearDown(container.dispose);
    await container.read(authProvider.notifier).restoreSession();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: LoginScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'valid-password');
    await tester.tap(find.text('Đăng nhập').first);
    await tester.pumpAndSettle();

    expect(repository.lastLoginEmail, remembered.email);
    expect(container.read(authProvider).isAuthenticated, isTrue);
    expect(container.read(authProvider).user?.id, remembered.id);
  });

  testWidgets(
    'iOS Face ID tap uses one protected-token challenge and resists double tap',
    (tester) async {
      final loginCompleter = Completer<UserModel>();
      final repository = _LoginRepository(
        remembered: remembered,
        biometricEnabled: true,
        biometricLoginCompleter: loginCompleter,
      );
      final localAuthentication = _FakeLocalAuthentication();
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(repository),
          localAuthenticationProvider.overrideWithValue(localAuthentication),
        ],
      );
      addTearDown(container.dispose);
      await container.read(authProvider.notifier).restoreSession();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: LoginScreen(),
            theme: ThemeData(platform: TargetPlatform.iOS),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final faceIdButton = find.byTooltip('Đăng nhập bằng Face ID');

      expect(faceIdButton, findsOneWidget);
      await tester.tap(faceIdButton);
      await tester.pump();
      await tester.tap(faceIdButton);
      await tester.pump();

      expect(localAuthentication.authenticateCalls, 0);
      expect(repository.biometricLoginCalls, 1);

      loginCompleter.complete(remembered);
      await tester.pumpAndSettle();
      expect(container.read(authProvider).isAuthenticated, isTrue);
    },
  );
}

ProviderContainer _container(_LoginRepository repository) => ProviderContainer(
  overrides: [authRepositoryProvider.overrideWithValue(repository)],
);

class _LoginRepository implements AuthRepository {
  _LoginRepository({
    this.remembered,
    this.loginError,
    this.loginUser,
    this.biometricEnabled = false,
    this.biometricLoginCompleter,
  });

  UserModel? remembered;
  Object? loginError;
  final UserModel? loginUser;
  final bool biometricEnabled;
  final Completer<UserModel>? biometricLoginCompleter;
  String? lastLoginEmail;
  int biometricLoginCalls = 0;
  bool hasSession = false;
  String? faceIdPromptSeenUserId;

  @override
  Future<bool> hasToken() async => hasSession;

  @override
  Future<UserModel?> readRememberedAccount() async => remembered;

  @override
  Future<void> saveRememberedAccount(UserModel user) async {
    remembered = user;
  }

  @override
  Future<void> clearRememberedAccount() async {
    remembered = null;
  }

  @override
  Future<String?> readFaceIdPromptSeenUserId() async => faceIdPromptSeenUserId;

  @override
  Future<void> markFaceIdPromptSeen({required String userId}) async {
    faceIdPromptSeenUserId = userId;
  }

  @override
  Future<bool> isBiometricLoginEnabledFor(String userId) async =>
      biometricEnabled && remembered?.id == userId;

  @override
  Future<UserModel> getCurrentUser() => throw UnimplementedError();

  @override
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    lastLoginEmail = email;
    if (loginError != null) throw loginError!;
    hasSession = true;
    return loginUser ?? remembered!;
  }

  @override
  Future<void> logout() async {
    hasSession = false;
  }

  @override
  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<void> requestPasswordReset({required String email}) =>
      throw UnimplementedError();

  @override
  Future<String> verifyPasswordResetOtp({
    required String email,
    required String otp,
  }) => throw UnimplementedError();

  @override
  Future<void> resetPassword({
    required String email,
    required String resetToken,
    required String newPassword,
  }) => throw UnimplementedError();

  @override
  Future<UserModel> updateCurrentUser({required String name}) =>
      throw UnimplementedError();

  @override
  Future<void> saveBiometricToken(String token) => throw UnimplementedError();

  @override
  Future<String?> readBiometricToken() => throw UnimplementedError();

  @override
  Future<void> deleteBiometricToken() async {}

  @override
  Future<void> enableBiometricLogin({required String userId}) =>
      throw UnimplementedError();

  @override
  Future<UserModel> loginWithBiometric() {
    biometricLoginCalls++;
    return biometricLoginCompleter?.future ?? Future.value(remembered!);
  }
}

class _FakeLocalAuthentication extends LocalAuthentication {
  int authenticateCalls = 0;

  @override
  Future<bool> get canCheckBiometrics async => true;

  @override
  Future<List<BiometricType>> getAvailableBiometrics() async => [
    BiometricType.face,
  ];

  @override
  Future<bool> authenticate({
    required String localizedReason,
    Object? authMessages,
    bool biometricOnly = false,
    bool sensitiveTransaction = true,
    bool persistAcrossBackgrounding = false,
  }) async {
    authenticateCalls++;
    return true;
  }
}
