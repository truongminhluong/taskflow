import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../../data/repositories/auth_repository_impl.dart';
import '../../data/models/user_model.dart';
import '../../domain/repositories/auth_repository.dart';
import '../state/auth_state.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl();
});

final localAuthenticationProvider = Provider<LocalAuthentication>((ref) {
  return LocalAuthentication();
});

final class AuthNotifier extends Notifier<AuthState> {
  int _sessionOperationId = 0;

  @override
  AuthState build() => const AuthState();

  Future<bool> login({required String email, required String password}) async {
    final operationId = ++_sessionOperationId;
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final user = await ref
          .read(authRepositoryProvider)
          .login(email: email.trim(), password: password);

      if (operationId != _sessionOperationId) return false;

      final repository = ref.read(authRepositoryProvider);
      try {
        await repository.saveRememberedAccount(user);
      } catch (_) {
        // Authentication succeeded; the session remains valid if storage fails.
        try {
          await repository.clearRememberedAccount();
        } catch (_) {}
      }
      var biometricEnabled = false;
      try {
        biometricEnabled = await repository.isBiometricLoginEnabledFor(user.id);
      } catch (_) {}

      state = state.copyWith(
        isLoading: false,
        isCheckingSession: false,
        isAuthenticated: true,
        isSessionRestoreError: false,
        user: user,
        rememberedAccount: user,
        isBiometricLoginEnabled: biometricEnabled,
        clearError: true,
      );

      return true;
    } catch (error) {
      if (operationId != _sessionOperationId) return false;
      state = state.copyWith(
        isLoading: false,
        errorMessage: _errorMessage(error),
      );

      return false;
    }
  }

  Future<String?> register({
    required String name,
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await ref.read(authRepositoryProvider).register(
        name: name.trim(),
        email: email.trim(),
        password: password,
      );

      state = state.copyWith(isLoading: false, clearError: true);
      return null;
    } catch (error, stackTrace) {
      final message = _errorMessage(error);

      // Xóa trạng thái loading nhưng không ghi lỗi đăng ký vào errorMessage.
      state = state.copyWith(isLoading: false);

      // ignore: avoid_print
      print('Register failed: $error\n$stackTrace');

      return message;
    }
  }

  Future<bool> updateCurrentUser({required String name}) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final user = await ref
          .read(authRepositoryProvider)
          .updateCurrentUser(name: name.trim());

      final repository = ref.read(authRepositoryProvider);
      try {
        await repository.saveRememberedAccount(user);
      } catch (_) {
        // Keep the successful profile update if local storage is unavailable.
        try {
          await repository.clearRememberedAccount();
        } catch (_) {}
      }

      state = state.copyWith(
        isLoading: false,
        user: user,
        rememberedAccount: user,
        clearError: true,
      );
      return true;
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _errorMessage(error),
      );
      return false;
    }
  }

  Future<bool> requestPasswordReset({required String email}) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await ref
          .read(authRepositoryProvider)
          .requestPasswordReset(email: email.trim());

      state = state.copyWith(isLoading: false, clearError: true);
      return true;
    } catch (error, stackTrace) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _errorMessage(error),
      );

      // ignore: avoid_print
      print('Password reset request failed: $error\n$stackTrace');
      return false;
    }
  }

  Future<String?> verifyPasswordResetOtp({
    required String email,
    required String otp,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final resetToken = await ref
          .read(authRepositoryProvider)
          .verifyPasswordResetOtp(email: email.trim(), otp: otp.trim());

      state = state.copyWith(isLoading: false, clearError: true);
      return resetToken;
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _errorMessage(error),
      );
      return null;
    }
  }

  Future<bool> resetPassword({
    required String email,
    required String resetToken,
    required String newPassword,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await ref
          .read(authRepositoryProvider)
          .resetPassword(
            email: email.trim(),
            resetToken: resetToken.trim(),
            newPassword: newPassword,
          );

      state = state.copyWith(isLoading: false, clearError: true);
      return true;
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _errorMessage(error),
      );
      return false;
    }
  }

  Future<void> logout() async {
    final operationId = ++_sessionOperationId;
    final repository = ref.read(authRepositoryProvider);
    var rememberedAccount = state.rememberedAccount;
    try {
      rememberedAccount ??= await repository.readRememberedAccount();
    } catch (_) {
      // Session cleanup must still run when local remembered data is unreadable.
    }
    try {
      await repository.logout();
    } finally {
      if (operationId == _sessionOperationId) {
        var biometricEnabled = false;
        if (rememberedAccount != null) {
          try {
            biometricEnabled = await repository.isBiometricLoginEnabledFor(
              rememberedAccount.id,
            );
          } catch (_) {}
        }
        state = AuthState(
          isCheckingSession: false,
          rememberedAccount: rememberedAccount,
          isBiometricLoginEnabled: biometricEnabled,
        );
      }
    }
  }

  Future<void> clearRememberedAccount() async {
    await ref.read(authRepositoryProvider).clearRememberedAccount();
    state = state.copyWith(
      clearRememberedAccount: true,
      isBiometricLoginEnabled: false,
    );
  }

  /// Kiểm tra Face ID trên thiết bị và trạng thái đã bật cho tài khoản hiện tại.
  Future<void> refreshFaceIdSettings() async {
    final userId = state.user?.id ?? state.rememberedAccount?.id;
    if (userId == null) {
      state = state.copyWith(
        isFaceIdAvailable: false,
        isBiometricLoginEnabled: false,
        isFaceIdUpdating: false,
      );
      return;
    }

    state = state.copyWith(isFaceIdUpdating: true);

    try {
      final localAuth = ref.read(localAuthenticationProvider);
      final canCheckBiometrics = await localAuth.canCheckBiometrics;
      final biometrics = canCheckBiometrics
          ? await localAuth.getAvailableBiometrics()
          : <BiometricType>[];

      final enabled = await ref
          .read(authRepositoryProvider)
          .isBiometricLoginEnabledFor(userId);

      // Nếu trong lúc kiểm tra tài khoản đã đổi, bỏ kết quả cũ.
      final currentUserId = state.user?.id ?? state.rememberedAccount?.id;
      if (currentUserId != userId) return;

      state = state.copyWith(
        isFaceIdAvailable: biometrics.contains(BiometricType.face),
        isBiometricLoginEnabled: enabled,
        isFaceIdUpdating: false,
      );
    } catch (_) {
      final currentUserId = state.user?.id ?? state.rememberedAccount?.id;
      if (currentUserId != userId) return;

      state = state.copyWith(
        isFaceIdAvailable: false,
        isFaceIdUpdating: false,
      );
    }
  }

  /// Kiểm tra có nên hỏi người dùng bật Face ID lần đầu hay không.
  Future<bool> shouldPromptToEnableFaceId() async {
    final userId = state.user?.id;

    if (userId == null || state.isBiometricLoginEnabled) {
      return false;
    }

    await refreshFaceIdSettings();

    // Tài khoản có thể đã đổi trong lúc kiểm tra Face ID.
    if (state.user?.id != userId ||
        state.isBiometricLoginEnabled ||
        !state.isFaceIdAvailable) {
      return false;
    }

    final promptSeenUserId = await ref
        .read(authRepositoryProvider)
        .readFaceIdPromptSeenUserId();

    return promptSeenUserId != userId;
  }

  /// Ghi nhớ lựa chọn hoãn hoặc đóng lời mời Face ID.
  Future<void> markFaceIdPromptSeen() async {
    final userId = state.user?.id;
    if (userId == null) return;

    await ref
        .read(authRepositoryProvider)
        .markFaceIdPromptSeen(userId: userId);
  }

  /// Bật hoặc tắt đăng nhập Face ID cho tài khoản hiện tại.
  ///
  /// Trả về false nếu người dùng hủy hộp thoại Face ID.
  /// Lỗi thiết bị hoặc lưu cài đặt sẽ được ném lên để UI hiển thị.
  Future<bool> setFaceIdEnabled(bool enabled) async {
    if (state.isFaceIdUpdating) return false;

    final userId = state.user?.id;
    if (userId == null) {
      throw StateError('Không tìm thấy tài khoản đang đăng nhập.');
    }

    state = state.copyWith(isFaceIdUpdating: true);

    try {
      final repository = ref.read(authRepositoryProvider);

      if (enabled) {
        if (!state.isFaceIdAvailable) {
          throw StateError('Thiết bị không có Face ID khả dụng.');
        }

        final authenticated = await ref
            .read(localAuthenticationProvider)
            .authenticate(
          localizedReason: 'Xác thực để bật đăng nhập Face ID cho TaskFlow',
          biometricOnly: true,
          persistAcrossBackgrounding: true,
        );

        if (state.user?.id != userId) return false;

        if (!authenticated) {
          // Giữ hành vi hiện tại: nếu người dùng đã được hỏi thì không hỏi lại
          // ở màn Home.
          await repository.markFaceIdPromptSeen(userId: userId);
          return false;
        }

        await repository.enableBiometricLogin(userId: userId);
      } else {
        await repository.deleteBiometricToken();
      }

      if (state.user?.id != userId) return false;

      // Người dùng đã tự chọn ở Cài đặt, không hỏi lại ở màn Home.
      await repository.markFaceIdPromptSeen(userId: userId);

      state = state.copyWith(isBiometricLoginEnabled: enabled);
      return true;
    } finally {
      if (state.user?.id == userId) {
        state = state.copyWith(isFaceIdUpdating: false);
      }
    }
  }

  String _errorMessage(Object error) {
    if (error is DioException) {
      final responseData = error.response?.data;

      if (responseData is Map && responseData['message'] is String) {
        return responseData['message'] as String;
      }

      if (error.response == null) {
        return 'Không thể kết nối máy chủ. Vui lòng kiểm tra mạng.';
      }

      if (error.response?.statusCode == 401) {
        return 'Email hoặc mật khẩu không chính xác.';
      }

      return 'Đã xảy ra lỗi. Vui lòng thử lại.';
    }

    if (error is FormatException) {
      return error.message;
    }

    return 'Không thể thực hiện yêu cầu. Vui lòng thử lại.';
  }

  Future<void> restoreSession() async {
    final operationId = ++_sessionOperationId;
    state = state.copyWith(
      isCheckingSession: true,
      isAuthenticated: false,
      isSessionRestoreError: false,
      clearUser: true,
      clearError: true,
    );

    try {
      final hasToken = await ref.read(authRepositoryProvider).hasToken();

      if (operationId != _sessionOperationId) return;

      if (!hasToken) {
        final repository = ref.read(authRepositoryProvider);
        UserModel? rememberedAccount;
        try {
          rememberedAccount = await repository.readRememberedAccount();
        } catch (_) {}
        var biometricEnabled = false;
        if (rememberedAccount != null) {
          try {
            biometricEnabled = await repository.isBiometricLoginEnabledFor(
              rememberedAccount.id,
            );
          } catch (_) {}
        }
        if (rememberedAccount == null) {
          try {
            await repository.deleteBiometricToken();
          } catch (_) {}
        }
        if (operationId != _sessionOperationId) return;

        state = state.copyWith(
          isCheckingSession: false,
          isAuthenticated: false,
          isSessionRestoreError: false,
          clearUser: true,
          rememberedAccount: rememberedAccount,
          clearRememberedAccount: rememberedAccount == null,
          isBiometricLoginEnabled: biometricEnabled,
          clearError: true,
        );
        return;
      }

      final user = await ref.read(authRepositoryProvider).getCurrentUser();

      if (operationId != _sessionOperationId) return;

      final repository = ref.read(authRepositoryProvider);
      try {
        await repository.saveRememberedAccount(user);
      } catch (_) {
        // A valid restored session does not depend on remembered-account I/O.
        try {
          await repository.clearRememberedAccount();
        } catch (_) {}
      }
      var biometricEnabled = false;
      try {
        biometricEnabled = await repository.isBiometricLoginEnabledFor(user.id);
      } catch (_) {}

      state = state.copyWith(
        isCheckingSession: false,
        isAuthenticated: true,
        isSessionRestoreError: false,
        user: user,
        rememberedAccount: user,
        isBiometricLoginEnabled: biometricEnabled,
        clearError: true,
      );
    } catch (error) {
      if (operationId != _sessionOperationId) return;

      if (error is DioException &&
          (error.response?.statusCode == 401 ||
              error.response?.statusCode == 404)) {
        try {
          await ref.read(authRepositoryProvider).logout();
        } catch (logoutError, stackTrace) {
          // ignore: avoid_print
          print('Session token cleanup failed: $logoutError\n$stackTrace');
        }
        try {
          await ref.read(authRepositoryProvider).deleteBiometricToken();
        } catch (_) {}

        if (operationId != _sessionOperationId) return;
        final repository = ref.read(authRepositoryProvider);
        UserModel? rememberedAccount;
        try {
          rememberedAccount = await repository.readRememberedAccount();
        } catch (_) {}
        var biometricEnabled = false;
        if (rememberedAccount != null) {
          try {
            biometricEnabled = await repository.isBiometricLoginEnabledFor(
              rememberedAccount.id,
            );
          } catch (_) {}
        }
        if (rememberedAccount == null) {
          try {
            await repository.deleteBiometricToken();
          } catch (_) {}
        }
        if (operationId != _sessionOperationId) return;
        state = state.copyWith(
          isCheckingSession: false,
          isAuthenticated: false,
          isSessionRestoreError: false,
          clearUser: true,
          rememberedAccount: rememberedAccount,
          clearRememberedAccount: rememberedAccount == null,
          isBiometricLoginEnabled: biometricEnabled,
          clearError: true,
        );
        return;
      }

      state = state.copyWith(
        isCheckingSession: false,
        isAuthenticated: false,
        isSessionRestoreError: true,
        errorMessage: _sessionRestoreErrorMessage(error),
        clearUser: true,
      );
    }
  }

  String _sessionRestoreErrorMessage(Object error) {
    if (error is DioException && error.response == null) {
      return 'Không thể kết nối máy chủ. Hãy kiểm tra mạng rồi thử lại.';
    }

    return 'Không thể khôi phục phiên đăng nhập. Vui lòng thử lại.';
  }

  Future<bool> loginWithBiometric() async {
    final operationId = ++_sessionOperationId;

    state = state.copyWith(
      isLoading: true,
      isCheckingSession: true,
      isAuthenticated: false,
      clearUser: true,
      clearError: true,
    );

    try {
      final user = await ref.read(authRepositoryProvider).loginWithBiometric();

      if (operationId != _sessionOperationId) return false;

      final repository = ref.read(authRepositoryProvider);
      try {
        await repository.saveRememberedAccount(user);
      } catch (_) {
        // Authentication remains valid if local remembered storage is unavailable.
        try {
          await repository.clearRememberedAccount();
        } catch (_) {}
      }

      state = state.copyWith(
        isLoading: false,
        isCheckingSession: false,
        isAuthenticated: true,
        isSessionRestoreError: false,
        user: user,
        rememberedAccount: user,
        isBiometricLoginEnabled: true,
        clearError: true,
      );

      return true;
    } catch (error) {
      if (operationId != _sessionOperationId) return false;

      var biometricEnabled = false;
      final rememberedAccount = state.rememberedAccount;
      if (rememberedAccount != null) {
        try {
          biometricEnabled = await ref
              .read(authRepositoryProvider)
              .isBiometricLoginEnabledFor(rememberedAccount.id);
        } catch (_) {}
      }

      final message =
          error is DioException &&
              (error.response?.statusCode == 401 ||
                  error.response?.statusCode == 404)
          ? 'Phiên Face ID đã hết hạn. Hãy đăng nhập bằng mật khẩu.'
          : _errorMessage(error);

      state = state.copyWith(
        isLoading: false,
        isCheckingSession: false,
        isAuthenticated: false,
        isBiometricLoginEnabled: biometricEnabled,
        clearUser: true,
        errorMessage: message,
      );

      return false;
    }
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
