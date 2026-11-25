import 'package:flutter/material.dart';
import 'package:task_flow_v2/core/theme/app_theme.dart';
import 'package:task_flow_v2/features/tasks/presentation/widgets/common/app_svg_icon.dart';
import 'package:task_flow_v2/features/tasks/presentation/widgets/auth/auth_text_field.dart';

class WelcomeBackPasswordForm extends StatelessWidget {
  const WelcomeBackPasswordForm({
    required this.controller,
    required this.hidePassword,
    required this.enabled,
    required this.onTogglePassword,
    required this.onForgotPassword,
    required this.validator,
    required this.onFieldSubmitted,
    super.key,
  });

  final TextEditingController controller;
  final bool hidePassword;
  final bool enabled;
  final VoidCallback onTogglePassword;
  final VoidCallback onForgotPassword;
  final String? Function(String?) validator;
  final ValueChanged<String> onFieldSubmitted;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuthTextField(
          controller: controller,
          label: 'Mật khẩu',
          hint: 'Nhập mật khẩu',
          icon: Icons.lock_outline_rounded,
          prefixIconWidget: AppSvgIcon(
            name: 'lock-password',
            size: 22,
            color: colors.onSurfaceVariant,
          ),
          obscureText: hidePassword,
          textInputAction: TextInputAction.done,
          enabled: enabled,
          autofillHints: const [AutofillHints.password],
          onFieldSubmitted: onFieldSubmitted,
          suffixIcon: IconButton(
            tooltip: hidePassword ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
            onPressed: enabled ? onTogglePassword : null,
            icon: AppSvgIcon(
              name: hidePassword ? 'eye' : 'view-off',
              size: 22,
              color: colors.onSurfaceVariant,
            ),
          ),
          validator: validator,
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: enabled ? onForgotPassword : null,
            child: const Text('Quên mật khẩu?'),
          ),
        ),
        const SizedBox(height: AppSpace.xs),
      ],
    );
  }
}
