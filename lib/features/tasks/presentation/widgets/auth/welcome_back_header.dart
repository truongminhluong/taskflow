import 'package:flutter/material.dart';
import 'package:task_flow_v2/core/theme/app_theme.dart';
import 'package:task_flow_v2/features/tasks/presentation/widgets/common/app_svg_icon.dart';

class WelcomeBackHeader extends StatelessWidget {
  const WelcomeBackHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: AppSvgIcon(
            name: 'user-circle',
            size: 56,
            color: colors.onPrimaryContainer,
          ),
        ),
        const SizedBox(height: AppSpace.lg),
        Text(
          'Chào mừng trở lại!',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            color: colors.onSurface,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
      ],
    );
  }
}
