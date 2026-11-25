import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import 'app_svg_icon.dart';

abstract final class AboutTaskFlowDialog {
  static Future<void> show(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420, maxHeight: 620),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.lg,
              AppSpace.xl,
              AppSpace.lg,
              AppSpace.md,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppSvgIcon(
                  name: 'task-01',
                  color: colors.primary,
                  size: 52,
                ),
                const SizedBox(height: AppSpace.md),
                Text(
                  'TaskFlow',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpace.xxs),
                Text(
                  'Phiên bản 1.0.0',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpace.md),
                Text(
                  'Nơi tập trung cho những việc tiếp theo.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpace.sm),
                Text(
                  'TaskFlow giúp bạn quản lý công việc, lịch trình và nhắc nhở hằng ngày trong một không gian đơn giản.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: AppSpace.lg),
                _FeatureRow(
                  icon: 'task-01',
                  title: 'Quản lý công việc',
                  subtitle: 'Tạo, sắp xếp và theo dõi tiến độ.',
                ),
                _FeatureRow(
                  icon: 'calendar-check-in-01',
                  title: 'Theo dõi lịch trình',
                  subtitle: 'Không bỏ lỡ lịch nhắc quan trọng.',
                ),
                _FeatureRow(
                  icon: 'notification-01',
                  title: 'Nhắc nhở đúng lúc',
                  subtitle: 'Chủ động hoàn thành công việc mỗi ngày.',
                ),
                _FeatureRow(
                  icon: 'face-id',
                  title: 'Đăng nhập bảo mật',
                  subtitle: 'Hỗ trợ đăng nhập nhanh bằng Face ID.',
                ),
                const SizedBox(height: AppSpace.md),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                    child: const Text('Đóng'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final String icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSvgIcon(name: icon, color: colors.primary, size: 22),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
