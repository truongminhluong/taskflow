import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../widgets/common/app_svg_icon.dart';
import '../widgets/auth/auth_primary_button.dart';
import '../widgets/auth/auth_text_field.dart';
import '../widgets/common/app_message_dialog.dart';
import '../widgets/common/dismiss_keyboard_on_tap.dart';
import '../widgets/common/task_flow_background.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _hidePassword = true;
  bool _hideConfirmPassword = true;
  bool _acceptedPolicies = false;
  bool _showPolicyError = false;

  Future<void> _showPolicy(String title, String content) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(content)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;
    if (!_acceptedPolicies) {
      setState(() => _showPolicyError = true);
      return;
    }

    final errorMessage = await ref
        .read(authProvider.notifier)
        .register(
          name: _nameController.text,
          email: _emailController.text,
          password: _passwordController.text,
        );

    if (!mounted) return;

    if (errorMessage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đăng ký thành công. Hãy đăng nhập tài khoản.'),
        ),
      );

      Navigator.of(context).pop();
    } else {
      await AppMessageDialog.show(
        context: context,
        title: 'Không thể đăng ký',
        message: errorMessage,
        type: AppMessageDialogType.error,
        iconName: 'mail-01',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Tạo tài khoản'),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bắt đầu với TaskFlow',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.8,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tạo tài khoản để quản lý công việc hiệu quả hơn.',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 28),

                        AuthTextField(
                          controller: _nameController,
                          label: 'Họ và tên',
                          hint: 'Nhập họ và tên',
                          icon: Icons.person_outline_rounded,
                          prefixIconWidget: AppSvgIcon(
                            name: 'user-circle',
                            size: 22,
                            color: colors.onSurfaceVariant,
                          ),
                          textInputAction: TextInputAction.next,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Vui lòng nhập họ và tên.';
                            }

                            return null;
                          },
                        ),
                        const SizedBox(height: 18),

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
                          validator: (value) {
                            final email = value?.trim() ?? '';

                            if (email.isEmpty) {
                              return 'Vui lòng nhập email.';
                            }

                            if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                .hasMatch(email)) {
                              return 'Email không đúng định dạng.';
                            }

                            return null;
                          },
                        ),
                        const SizedBox(height: 18),

                        AuthTextField(
                          controller: _passwordController,
                          label: 'Mật khẩu',
                          hint: 'Tối thiểu 8 ký tự',
                          icon: Icons.lock_outline_rounded,
                          prefixIconWidget: AppSvgIcon(
                            name: 'lock-password',
                            size: 22,
                            color: colors.onSurfaceVariant,
                          ),
                          obscureText: _hidePassword,
                          textInputAction: TextInputAction.next,
                          suffixIcon: IconButton(
                            tooltip: _hidePassword
                                ? 'Hiện mật khẩu'
                                : 'Ẩn mật khẩu',
                            onPressed: () {
                              setState(() {
                                _hidePassword = !_hidePassword;
                              });
                            },
                            icon: AppSvgIcon(
                              name: _hidePassword ? 'eye' : 'view-off',
                              size: 22,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Vui lòng nhập mật khẩu.';
                            }

                            if (value.length < 8) {
                              return 'Mật khẩu phải có ít nhất 8 ký tự.';
                            }

                            return null;
                          },
                        ),
                        const SizedBox(height: 18),

                        AuthTextField(
                          controller: _confirmPasswordController,
                          label: 'Xác nhận mật khẩu',
                          hint: 'Nhập lại mật khẩu',
                          icon: Icons.lock_outline_rounded,
                          prefixIconWidget: AppSvgIcon(
                            name: 'lock-password',
                            size: 22,
                            color: colors.onSurfaceVariant,
                          ),
                          obscureText: _hideConfirmPassword,
                          textInputAction: TextInputAction.done,
                          suffixIcon: IconButton(
                            tooltip: _hideConfirmPassword
                                ? 'Hiện mật khẩu'
                                : 'Ẩn mật khẩu',
                            onPressed: () {
                              setState(() {
                                _hideConfirmPassword = !_hideConfirmPassword;
                              });
                            },
                            icon: AppSvgIcon(
                              name: _hideConfirmPassword ? 'eye' : 'view-off',
                              size: 22,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Vui lòng xác nhận mật khẩu.';
                            }

                            if (value != _passwordController.text) {
                              return 'Mật khẩu xác nhận không khớp.';
                            }

                            return null;
                          },
                        ),

                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: colors.surface.withValues(alpha: 0.72),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _showPolicyError
                                  ? colors.error
                                  : colors.outlineVariant,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Checkbox.adaptive(
                                value: _acceptedPolicies,
                                onChanged: authState.isLoading
                                    ? null
                                    : (value) => setState(() {
                                        _acceptedPolicies = value ?? false;
                                        _showPolicyError = false;
                                      }),
                                visualDensity: VisualDensity.compact,
                              ),
                              Expanded(
                                child: Wrap(
                                  children: [
                                    const Text('Tôi đồng ý với '),
                                    _policyLink(
                                      'Điều khoản sử dụng',
                                      () => _showPolicy(
                                        'Điều khoản sử dụng',
                                        'Bằng việc tạo tài khoản TaskFlow, bạn đồng ý sử dụng ứng dụng để quản lý công việc cá nhân một cách hợp pháp và có trách nhiệm.',
                                      ),
                                    ),
                                    const Text(' và '),
                                    _policyLink(
                                      'Chính sách quyền riêng tư',
                                      () => _showPolicy(
                                        'Chính sách quyền riêng tư',
                                        'TaskFlow sử dụng tên, email và dữ liệu công việc bạn cung cấp để tạo tài khoản và đồng bộ trải nghiệm. Thông tin của bạn không được hiển thị công khai theo mặc định.',
                                      ),
                                    ),
                                    const Text('.'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_showPolicyError) ...[
                          const SizedBox(height: 6),
                          Padding(
                            padding: const EdgeInsets.only(left: 12),
                            child: Text(
                              'Vui lòng đồng ý với điều khoản và chính sách để tiếp tục.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.error,
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 26),
                        AuthPrimaryButton(
                          label: 'Tạo tài khoản',
                          isLoading: authState.isLoading,
                          onPressed: _register,
                        ),
                        const SizedBox(height: 20),
                        Center(
                          child: TextButton(
                            onPressed: authState.isLoading
                                ? null
                                : () => Navigator.of(context).pop(),
                            child: const Text('Đã có tài khoản? Đăng nhập'),
                          ),
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

  Widget _policyLink(String label, VoidCallback onPressed) {
    final color = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onPressed,
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.underline,
          decorationColor: color,
        ),
      ),
    );
  }
}
