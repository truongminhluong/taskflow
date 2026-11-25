import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:task_flow_v2/core/theme/app_theme.dart';
import 'package:task_flow_v2/features/tasks/presentation/screens/register_screen.dart';
import 'package:task_flow_v2/features/tasks/presentation/widgets/auth/remembered_account_info.dart';
import 'package:task_flow_v2/features/tasks/presentation/widgets/auth/welcome_back_action_buttons.dart';
import 'package:task_flow_v2/features/tasks/presentation/widgets/auth/welcome_back_header.dart';
import 'package:task_flow_v2/features/tasks/presentation/widgets/auth/welcome_back_password_form.dart';

import '../providers/auth_provider.dart';
import '../state/auth_state.dart';
import '../widgets/common/app_svg_icon.dart';
import '../widgets/auth/auth_primary_button.dart';
import '../widgets/auth/auth_text_field.dart';
import '../widgets/common/dismiss_keyboard_on_tap.dart';
import '../widgets/common/task_flow_background.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _hidePassword = true;
  bool _showStandardLogin = false;
  bool _isFaceIdAuthenticating = false;

  bool get _isIos => Theme.of(context).platform == TargetPlatform.iOS;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      ref.read(authProvider.notifier).refreshFaceIdSettings();
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    final loggedIn = await ref
        .read(authProvider.notifier)
        .login(
          email: _emailController.text,
          password: _passwordController.text,
        );

    if (!loggedIn || !mounted) return;
  }

  Future<void> _loginWithFaceId() async {
    if (_isFaceIdAuthenticating) return;
    setState(() => _isFaceIdAuthenticating = true);

    try {
      // On iOS, reading the biometryCurrentSet Keychain item is the challenge.
      if (!_isIos) {
        final authenticated = await ref
            .read(localAuthenticationProvider)
            .authenticate(
              localizedReason: 'Xác thực để đăng nhập TaskFlow',
              biometricOnly: true,
              persistAcrossBackgrounding: true,
            );
        if (!authenticated || !mounted) return;
      }

      await ref.read(authProvider.notifier).loginWithBiometric();
    } catch (_) {
      if (mounted) {
        _showMessage('Không thể đăng nhập bằng Face ID. Hãy thử lại.');
      }
    } finally {
      if (mounted) setState(() => _isFaceIdAuthenticating = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _forgotPassword() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ForgotPasswordScreen()),
    );
  }

  void _useAnotherAccount() {
    setState(() {
      _showStandardLogin = true;
      _emailController.clear();
      _passwordController.clear();
    });
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Vui lòng nhập mật khẩu.';
    return null;
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Vui lòng nhập email.';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'Email không đúng định dạng.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      body: DismissKeyboardOnTap(
        child: TaskFlowBackground(
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.lg,
                  vertical: AppSpace.xl,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: AutofillGroup(
                    child: Form(
                      key: _formKey,
                      child:
                          !_showStandardLogin &&
                              authState.rememberedAccount != null
                          ? _buildWelcomeBack(authState)
                          : _buildStandardLogin(authState, theme, colors),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeBack(AuthState authState) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildLogo(theme, colors),
        const SizedBox(height: AppSpace.xxl),
        const WelcomeBackHeader(),
        const SizedBox(height: AppSpace.md),
        RememberedAccountInfo(
          name: authState.rememberedAccount!.name,
          email: authState.rememberedAccount!.email,
        ),
        const SizedBox(height: AppSpace.xl),
        WelcomeBackPasswordForm(
          controller: _passwordController,
          hidePassword: _hidePassword,
          enabled: !authState.isLoading,
          onTogglePassword: () {
            setState(() => _hidePassword = !_hidePassword);
          },
          onForgotPassword: _forgotPassword,
          validator: _validatePassword,
          onFieldSubmitted: (_) {
            if (!authState.isLoading) _submitWelcomeBack(authState);
          },
        ),
        WelcomeBackActionButtons(
          onLogin: () => _submitWelcomeBack(authState),
          onFaceId: authState.isBiometricLoginEnabled &&
              authState.isFaceIdAvailable
              ? _loginWithFaceId
              : null,
          isLoading: authState.isLoading,
          isFaceIdLoading: _isFaceIdAuthenticating,
        ),
        if (authState.errorMessage != null) ...[
          const SizedBox(height: AppSpace.md),
          Semantics(
            liveRegion: true,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpace.md),
              decoration: BoxDecoration(
                color: colors.errorContainer,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(
                authState.errorMessage!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onErrorContainer,
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: AppSpace.sm),
        TextButton(
          onPressed: authState.isLoading ? null : _useAnotherAccount,
          child: const Text('Đăng nhập bằng tài khoản khác'),
        ),
      ],
    );
  }

  void _submitWelcomeBack(AuthState authState) {
    final rememberedAccount = authState.rememberedAccount;
    if (rememberedAccount == null) return;
    _emailController.text = rememberedAccount.email;
    _login();
  }

  Widget _buildStandardLogin(
    AuthState authState,
    ThemeData theme,
    ColorScheme colors,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildLogo(theme, colors),
        const SizedBox(height: AppSpace.xl),
        Text(
          'Chào mừng trở lại',
          style: theme.textTheme.headlineMedium?.copyWith(
            color: colors.onSurface,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.7,
          ),
        ),
        const SizedBox(height: AppSpace.xs),
        Text(
          'Đăng nhập để tiếp tục quản lý công việc của bạn.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: colors.onSurfaceVariant,
            height: 1.45,
          ),
        ),
        const SizedBox(height: AppSpace.xl),
        AuthTextField(
          controller: _emailController,
          label: 'Email',
          hint: 'Nhập địa chỉ email',
          icon: Icons.mail_outline_rounded,
          prefixIconWidget: AppSvgIcon(
            name: 'mail-01',
            size: 22,
            color: colors.onSurfaceVariant,
          ),
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          enabled: !authState.isLoading,
          autofillHints: const [AutofillHints.username, AutofillHints.email],
          validator: _validateEmail,
        ),
        const SizedBox(height: AppSpace.md),
        WelcomeBackPasswordForm(
          controller: _passwordController,
          hidePassword: _hidePassword,
          enabled: !authState.isLoading,
          onTogglePassword: () {
            setState(() => _hidePassword = !_hidePassword);
          },
          onForgotPassword: _forgotPassword,
          validator: _validatePassword,
          onFieldSubmitted: (_) {
            if (!authState.isLoading) _login();
          },
        ),
        if (authState.errorMessage != null) ...[
          const SizedBox(height: AppSpace.md),
          Semantics(
            liveRegion: true,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpace.md),
              decoration: BoxDecoration(
                color: colors.errorContainer,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 20,
                    color: colors.onErrorContainer,
                  ),
                  const SizedBox(width: AppSpace.xs),
                  Expanded(
                    child: Text(
                      authState.errorMessage!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: AppSpace.md),
        AuthPrimaryButton(
          label: 'Đăng nhập',
          isLoading: authState.isLoading,
          onPressed: _login,
        ),
        const SizedBox(height: AppSpace.sm),
        Center(
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Chưa có tài khoản?',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              TextButton(
                onPressed: authState.isLoading
                    ? null
                    : () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const RegisterScreen(),
                          ),
                        );
                      },
                child: const Text(
                  'Đăng ký ngay',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLogo(ThemeData theme, ColorScheme colors) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: colors.primary,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: AppSvgIcon(
            name: 'checkmark-square-01',
            color: colors.onPrimary,
            size: 26,
          ),
        ),
        const SizedBox(width: AppSpace.sm),
        Text(
          'TaskFlow',
          style: theme.textTheme.titleLarge?.copyWith(
            color: colors.onSurface,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }
}
