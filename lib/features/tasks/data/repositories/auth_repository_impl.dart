import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_data_source.dart';
import '../models/user_model.dart';

final class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({AuthRemoteDataSource? dataSource})
    : _dataSource = dataSource ?? AuthRemoteDataSource();

  final AuthRemoteDataSource _dataSource;

  @override
  Future<UserModel> login({required String email, required String password}) {
    return _dataSource.login(email: email, password: password);
  }

  @override
  Future<UserModel> getCurrentUser() {
    return _dataSource.getCurrentUser();
  }

  @override
  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) {
    return _dataSource.register(name: name, email: email, password: password);
  }

  @override
  Future<UserModel> updateCurrentUser({required String name}) {
    return _dataSource.updateCurrentUser(name: name);
  }

  @override
  Future<void> requestPasswordReset({required String email}) {
    return _dataSource.requestPasswordReset(email: email);
  }

  @override
  Future<String> verifyPasswordResetOtp({
    required String email,
    required String otp,
  }) {
    return _dataSource.verifyPasswordResetOtp(email: email, otp: otp);
  }

  @override
  Future<void> resetPassword({
    required String email,
    required String resetToken,
    required String newPassword,
  }) {
    return _dataSource.resetPassword(
      email: email,
      resetToken: resetToken,
      newPassword: newPassword,
    );
  }

  @override
  Future<void> logout() {
    return _dataSource.logout();
  }

  @override
  Future<bool> hasToken() {
    return _dataSource.getToken().then(
      (token) => token != null && token.isNotEmpty,
    );
  }

  @override
  Future<UserModel?> readRememberedAccount() {
    return _dataSource.readRememberedAccount();
  }

  @override
  Future<void> saveRememberedAccount(UserModel user) {
    return _dataSource.saveRememberedAccount(user);
  }

  @override
  Future<void> clearRememberedAccount() {
    return _dataSource.clearRememberedAccount();
  }

  @override
  Future<bool> isBiometricLoginEnabledFor(String userId) {
    return _dataSource.isBiometricLoginEnabledFor(userId);
  }

  @override
  Future<String?> readFaceIdPromptSeenUserId() {
    return _dataSource.readFaceIdPromptSeenUserId();
  }

  @override
  Future<void> markFaceIdPromptSeen({required String userId}) {
    return _dataSource.markFaceIdPromptSeen(userId: userId);
  }

  @override
  Future<void> saveBiometricToken(String token) {
    return _dataSource.saveBiometricToken(token);
  }

  @override
  Future<String?> readBiometricToken() {
    return _dataSource.readBiometricToken();
  }

  @override
  Future<void> deleteBiometricToken() {
    return _dataSource.deleteBiometricToken();
  }

  @override
  Future<void> enableBiometricLogin({required String userId}) {
    return _dataSource.enableBiometricLogin(userId: userId);
  }

  @override
  Future<UserModel> loginWithBiometric() {
    return _dataSource.loginWithBiometric();
  }
}
