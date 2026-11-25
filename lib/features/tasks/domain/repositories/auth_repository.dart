import 'package:task_flow_v2/features/tasks/data/models/user_model.dart';

abstract interface class AuthRepository {
  Future<UserModel> login({required String email, required String password});

  Future<UserModel> getCurrentUser();

  Future<void> register({
    required String name,
    required String email,
    required String password,
  });

  Future<void> requestPasswordReset({required String email});

  Future<String> verifyPasswordResetOtp({
    required String email,
    required String otp,
  });

  Future<void> resetPassword({
    required String email,
    required String resetToken,
    required String newPassword,
  });

  Future<UserModel> updateCurrentUser({required String name});

  Future<void> logout();

  Future<bool> hasToken();

  Future<UserModel?> readRememberedAccount();

  Future<void> saveRememberedAccount(UserModel user);

  Future<void> clearRememberedAccount();

  Future<bool> isBiometricLoginEnabledFor(String userId);

  Future<String?> readFaceIdPromptSeenUserId();

  Future<void> markFaceIdPromptSeen({required String userId});

  Future<void> saveBiometricToken(String token);

  Future<String?> readBiometricToken();

  Future<void> deleteBiometricToken();

  Future<void> enableBiometricLogin({required String userId});

  Future<UserModel> loginWithBiometric();
}
