import 'package:flutter/material.dart';
import 'package:task_flow_v2/core/theme/app_theme.dart';

/// Compact overview of today's task completion on the Home screen.
class HomeProgressOverview extends StatelessWidget {
  const HomeProgressOverview({
    required this.completed,
    required this.total,
    required this.progress,
    required this.onOpenTasks,
    this.statusMessage,
    super.key,
  });

  final int completed;
  final int total;
  final double progress;
  final VoidCallback onOpenTasks;
  final String? statusMessage;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final normalizedProgress = progress.clamp(0.0, 1.0).toDouble();
    final remaining = (total - completed).clamp(0, total);

    return Container(
      constraints: const BoxConstraints(minHeight: 156),
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.surface.withValues(alpha: .96),
            colors.primaryContainer.withValues(alpha: .42),
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: .72)),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: .08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: statusMessage == null
          ? _buildProgressContent(context, normalizedProgress, remaining)
          : _buildStatusContent(context, statusMessage!),
    );
  }

  Widget _buildProgressContent(
    BuildContext context,
    double normalizedProgress,
    int remaining,
  ) {
    final colors = Theme.of(context).colorScheme;

    return Row(
      children: [
        SizedBox(
          width: 94,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox.square(
                dimension: 78,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: normalizedProgress,
                        strokeWidth: 8,
                        strokeCap: StrokeCap.round,
                        backgroundColor: colors.primary.withValues(alpha: .16),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          colors.primary,
                        ),
                      ),
                    ),
                    Text(
                      '$completed/$total',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: colors.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpace.xs),
              Text(
                'công việc',
                style: Theme.of(context).textTheme.labelMedium
                    ?.copyWith(color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpace.sm),
        Container(
          width: 1,
          height: 104,
          color: colors.outlineVariant.withValues(alpha: .8),
        ),
        const SizedBox(width: AppSpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Icon(Icons.track_changes_rounded, color: colors.primary),
                  const SizedBox(width: AppSpace.xs),
                  Expanded(
                    child: Text(
                      'Tiến độ hôm nay',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Mở tất cả công việc',
                    visualDensity: VisualDensity.compact,
                    onPressed: onOpenTasks,
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.xxs),
              Text(
                _encouragement(normalizedProgress),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpace.sm),
              Semantics(
                label: 'Tiến độ công việc hôm nay',
                value: '$completed trên $total',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: LinearProgressIndicator(
                    value: normalizedProgress,
                    minHeight: 9,
                    backgroundColor: colors.primary.withValues(alpha: .14),
                    valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.xs),
              Text(
                remaining == 0 && total > 0
                    ? 'Đã hoàn thành tất cả công việc hôm nay'
                    : 'Còn $remaining công việc hôm nay',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium
                    ?.copyWith(color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusContent(BuildContext context, String message) {
    final colors = Theme.of(context).colorScheme;

    return Row(
      children: [
        Icon(Icons.info_outline_rounded, color: colors.primary, size: 30),
        const SizedBox(width: AppSpace.md),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tiến độ hôm nay',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpace.xs),
              Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Mở tất cả công việc',
          onPressed: onOpenTasks,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }

  String _encouragement(double normalizedProgress) {
    if (total == 0) return 'Hôm nay chưa có công việc nào.';
    if (normalizedProgress >= 1) return 'Tuyệt vời! Bạn đã hoàn thành hết!';
    if (normalizedProgress == 0) return 'Bắt đầu thôi, bạn làm được mà!';
    return 'Cố lên! Bạn làm được mà!';
  }
}
