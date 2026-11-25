import 'package:flutter/material.dart';
import 'package:task_flow_v2/features/tasks/presentation/widgets/common/app_svg_icon.dart';

class AddTaskButton extends StatelessWidget {
  const AddTaskButton({super.key, required this.onPressed, this.size = 64});

  final VoidCallback onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: size,
      height: size,
      child: Material(
        color: colorScheme.primary,
        shape: const CircleBorder(),
        elevation: 5,
        shadowColor: colorScheme.primary.withValues(alpha: 0.35),
        child: InkWell(
          key: const ValueKey('add-task'),
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: const Center(
            child: AppSvgIcon(name: 'add-02', size: 38, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
