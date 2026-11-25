import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pinput/pinput.dart';

import '../providers/auth_provider.dart';
import '../widgets/auth/auth_primary_button.dart';
import '../widgets/common/task_flow_background.dart';
import '../widgets/common/dismiss_keyboard_on_tap.dart';
import 'reset_password_screen.dart';

class OtpVerificationScreen extends ConsumerStatefulWidget {
  const OtpVerificationScreen({super.key, required this.email});

  final String email;

  @override
  ConsumerState<OtpVerificationScreen> createState() =>
      _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _otpController = TextEditingController();

  Timer? _countdownTimer;
  int _remainingSeconds = 60;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _otpController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _verifyOtp() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    final resetToken = await ref
        .read(authProvider.notifier)
        .verifyPasswordResetOtp(email: widget.email, otp: _otpController.text);

    if (!mounted || resetToken == null) return;

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            ResetPasswordScreen(email: widget.email, resetToken: resetToken),
      ),
    );
  }

  void _startCountdown() {
    _countdownTimer?.cancel();

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_remainingSeconds <= 1) {
        timer.cancel();
        setState(() => _remainingSeconds = 0);
      } else {
        setState(() => _remainingSeconds--);
      }
    });
  }

  Future<void> _resendOtp() async {
    final success = await ref
        .read(authProvider.notifier)
        .requestPasswordReset(email: widget.email);

    if (!mounted || !success) return;

    setState(() => _remainingSeconds = 120);
    _startCountdown();

    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Mã OTP mới đã được gửi.')));
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final defaultPinTheme = PinTheme(
      width: 52,
      height: 58,
      textStyle: theme.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.outlineVariant),
      ),
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Xác thực OTP'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: DismissKeyboardOnTap(
        child: TaskFlowBackground(
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        Icon(
                          Icons.mark_email_read_outlined,
                          size: 64,
                          color: colors.primary,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Nhập mã xác thực',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Mã OTP đã được gửi đến ${widget.email}.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
                        Material(
                          color: Colors.transparent,
                          child: Pinput(
                            controller: _otpController,
                            length: 6,
                            enabled: !authState.isLoading,
                            keyboardType: TextInputType.number,
                            defaultPinTheme: defaultPinTheme,
                            focusedPinTheme: defaultPinTheme.copyWith(
                              decoration: defaultPinTheme.decoration!.copyWith(
                                border: Border.all(
                                  color: colors.primary,
                                  width: 1.5,
                                ),
                              ),
                            ),
                            submittedPinTheme: defaultPinTheme.copyWith(
                              decoration: defaultPinTheme.decoration!.copyWith(
                                border: Border.all(color: colors.primary),
                              ),
                            ),
                            validator: (value) {
                              if (value == null ||
                                  !RegExp(r'^\d{6}$').hasMatch(value)) {
                                return 'Vui lòng nhập đủ 6 chữ số.';
                              }
                              return null;
                            },
                          ),
                        ),
                        if (authState.errorMessage != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            authState.errorMessage!,
                            style: TextStyle(color: colors.error),
                            textAlign: TextAlign.center,
                          ),
                        ],
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Không nhận được mã?',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                            TextButton(
                              onPressed:
                                  _remainingSeconds == 0 && !authState.isLoading
                                  ? _resendOtp
                                  : null,
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.only(left: 6),
                              ),
                              child: Text(
                                _remainingSeconds == 0
                                    ? 'Gửi lại mã'
                                    : '${(_remainingSeconds ~/ 60).toString().padLeft(2, '0')}:'
                                          '${(_remainingSeconds % 60).toString().padLeft(2, '0')}',
                              ),
                            ),
                          ],
                        ),
                        AuthPrimaryButton(
                          label: 'Xác nhận mã',
                          onPressed: _verifyOtp,
                          isLoading: authState.isLoading,
                          useMaterialDefaults: true,
                        ),
                      ],
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
}
