import 'package:flutter/material.dart';

import 'app_svg_icon.dart';

enum AppMessageDialogType { info, success, warning, error }

abstract final class AppMessageDialog {
  static Future<void> show({
    required BuildContext context,
    required String title,
    required String message,
    AppMessageDialogType type = AppMessageDialogType.info,
    String buttonLabel = 'Đã hiểu',
    String? iconName,
    bool barrierDismissible = true,
  }) {
    final colors = Theme.of(context).colorScheme;
    final (defaultIconName, foreground) = switch (type) {
      AppMessageDialogType.info => (
        'information-circle',
        colors.primary,
      ),
      AppMessageDialogType.success => (
        'checkmark-circle-01',
        Colors.green.shade700,
      ),
      AppMessageDialogType.warning => (
        'alert-02',
        Colors.orange.shade800,
      ),
      AppMessageDialogType.error => (
        'alert-02',
        colors.error,
      ),
    };

    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierLabel: 'Đóng thông báo',
      barrierColor: Colors.black.withValues(alpha: 0.48),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (dialogContext, animation, secondaryAnimation) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Material(
            color: colors.surface,
            elevation: 16,
            shadowColor: Colors.black.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppSvgIcon(
                      name: iconName ?? defaultIconName,
                      color: foreground,
                      size: 44,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: Theme.of(dialogContext).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: Theme.of(dialogContext).textTheme.bodyMedium
                          ?.copyWith(
                            color: colors.onSurfaceVariant,
                            height: 1.5,
                          ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(buttonLabel),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
        );
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.9, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }
}
