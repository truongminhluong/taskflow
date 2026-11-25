import '../../data/models/user_model.dart';

class AuthState {
  const AuthState({
    this.isLoading = false,
    this.isCheckingSession = true,
    this.isAuthenticated = false,
    this.isSessionRestoreError = false,
    this.isBiometricLoginEnabled = false,
    this.isFaceIdAvailable = false,
    this.isFaceIdUpdating = false,
    this.errorMessage,
    this.user,
    this.rememberedAccount,
  });

  final bool isLoading;
  final bool isCheckingSession;
  final bool isAuthenticated;
  final bool isSessionRestoreError;
  final bool isBiometricLoginEnabled;
  final bool isFaceIdAvailable;
  final bool isFaceIdUpdating;
  final String? errorMessage;
  final UserModel? user;
  final UserModel? rememberedAccount;

  AuthState copyWith({
    bool? isLoading,
    bool? isCheckingSession,
    bool? isAuthenticated,
    bool? isSessionRestoreError,
    bool? isBiometricLoginEnabled,
    bool? isFaceIdAvailable,
    bool? isFaceIdUpdating,
    String? errorMessage,
    bool clearError = false,
    UserModel? user,
    bool clearUser = false,
    UserModel? rememberedAccount,
    bool clearRememberedAccount = false,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isCheckingSession: isCheckingSession ?? this.isCheckingSession,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isSessionRestoreError:
          isSessionRestoreError ?? this.isSessionRestoreError,
      isBiometricLoginEnabled:
          isBiometricLoginEnabled ?? this.isBiometricLoginEnabled,
      isFaceIdAvailable: isFaceIdAvailable ?? this.isFaceIdAvailable,
      isFaceIdUpdating: isFaceIdUpdating ?? this.isFaceIdUpdating,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      user: clearUser ? null : user ?? this.user,
      rememberedAccount: clearRememberedAccount
          ? null
          : rememberedAccount ?? this.rememberedAccount,
    );
  }
}
