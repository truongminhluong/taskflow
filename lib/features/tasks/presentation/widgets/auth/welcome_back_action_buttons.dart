import 'package:flutter/material.dart';
import 'package:task_flow_v2/core/theme/app_theme.dart';
import 'package:task_flow_v2/features/tasks/presentation/widgets/common/app_svg_icon.dart';
import 'package:task_flow_v2/features/tasks/presentation/widgets/auth/auth_primary_button.dart';

class WelcomeBackActionButtons extends StatelessWidget {
  const WelcomeBackActionButtons({
    required this.onLogin,
    this.onFaceId,
    required this.isLoading,
    this.isFaceIdLoading = false,
    super.key,
  });

  final VoidCallback onLogin;
  final VoidCallback? onFaceId;
  final bool isLoading;
  final bool isFaceIdLoading;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isBusy = isLoading || isFaceIdLoading;

    return Row(
      children: [
        Expanded(
          child: AuthPrimaryButton(
            label: 'Đăng nhập',
            isLoading: isLoading,
            onPressed: isBusy ? null : onLogin,
          ),
        ),
        if (onFaceId != null) ...[
          const SizedBox(width: AppSpace.sm),
          Tooltip(
            message: 'Đăng nhập bằng Face ID',
            child: Semantics(
              button: true,
              label: 'Đăng nhập bằng Face ID',
              child: SizedBox.square(
                dimension: 54,
                child: OutlinedButton(
                  onPressed: isBusy ? null : onFaceId,
                  style: OutlinedButton.styleFrom(
                    backgroundColor: colors.surface,
                    foregroundColor: colors.primary,
                    side: BorderSide(color: colors.primary),
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                  child: isFaceIdLoading
                      ? SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colors.primary,
                          ),
                        )
                      : AppSvgIcon(
                          name: 'face-id',
                          size: 24,
                          color: colors.primary,
                        ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
