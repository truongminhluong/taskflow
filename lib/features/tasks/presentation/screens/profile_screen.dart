import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../providers/notification_settings_provider.dart';
import '../providers/task_provider.dart';
import '../providers/theme_mode_provider.dart';
import '../widgets/common/section_heading.dart';
import '../widgets/common/task_flow_background.dart';
import '../widgets/common/app_svg_icon.dart';
import '../widgets/common/about_taskflow_dialog.dart';
import '../widgets/common/app_confirm_dialog.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  final bool isActive;

  const ProfileScreen({super.key, required this.isActive});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with WidgetsBindingObserver {
  String _initialsFor(String? name) {
    final parts = (name ?? '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2);

    return parts
        .map((part) => String.fromCharCode(part.runes.first))
        .join()
        .toUpperCase();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() {
      if (!mounted) return;
      ref.read(authProvider.notifier).refreshFaceIdSettings();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(notificationSettingsProvider.notifier).refresh();
      ref.read(authProvider.notifier).refreshFaceIdSettings();
    }
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!oldWidget.isActive && widget.isActive) {
      Future.microtask(() {
        if (!mounted) return;
        ref.read(authProvider.notifier).refreshFaceIdSettings();
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _openEditProfile() {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EditProfileScreen(name: user.name, email: user.email),
      ),
    );
  }


  Future<void> _setFaceIdEnabled(bool enabled) async {
    try {
      final updated = await ref
          .read(authProvider.notifier)
          .setFaceIdEnabled(enabled);

      // false nghĩa là xác thực Face ID bị hủy hoặc thao tác đang bận.
      if (!mounted || !updated) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            enabled
                ? 'Đã bật đăng nhập bằng Face ID.'
                : 'Đã tắt đăng nhập bằng Face ID.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể cập nhật Face ID. Vui lòng thử lại.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final authState = ref.watch(authProvider);
    final selectedThemeMode = ref.watch(themeModeProvider);
    final notificationSettings = ref.watch(notificationSettingsProvider);
    final user = authState.user;

    final name = user?.name.trim();
    final email = user?.email.trim();
    final displayName = name == null || name.isEmpty
        ? 'Tài khoản TaskFlow'
        : name;
    final hasEmail = email != null && email.isNotEmpty;
    final initials = _initialsFor(name);

    return TaskFlowBackground(
      child: ContentColumn(
        child: ListView(
          key: const PageStorageKey('profile-scroll'),
          padding: const EdgeInsets.only(
            top: AppSpace.lg,
            // Leave enough scrollable room to move the logout button above the
            // center FAB and the bottom navigation dock.
            bottom: AppSpace.xxl * 3,
          ),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Cá nhân',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Sửa trang cá nhân',
                  onPressed: _openEditProfile,
                  icon: AppSvgIcon(name: 'edit-01', color: colors.onSurface),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.xs),
            Text(
              'Thông tin và tùy chọn ứng dụng.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpace.xl),
            Row(
              children: [
                CircleAvatar(
                  radius: 34,
                  backgroundColor: colors.primaryContainer,
                  foregroundColor: colors.onPrimaryContainer,
                  child: initials.isEmpty
                      ? AppSvgIcon(
                          name: 'user-circle',
                          size: 30,
                          color: colors.onPrimaryContainer,
                        )
                      : Text(
                          initials,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSpace.xxs),
                      Text(
                        hasEmail ? email : 'Thông tin tài khoản chưa có sẵn.',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.xl),
            const SectionHeading(title: 'Bảo mật'),
            const SizedBox(height: AppSpace.xs),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: AppSvgIcon(
                name: 'face-id',
                size: 24,
                color: colors.onSurfaceVariant,
              ),
              title: const Text('Đăng nhập bằng Face ID'),
              subtitle: Text(
                !authState.isFaceIdAvailable
                    ? 'Thiết lập Face ID trong Cài đặt thiết bị để bật.'
                    : authState.isBiometricLoginEnabled
                    ? 'Đã bật trên thiết bị này'
                    : 'Bật để đăng nhập nhanh trên thiết bị này',
              ),
              trailing: authState.isFaceIdUpdating
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Switch.adaptive(
                      value: authState.isBiometricLoginEnabled,
                      onChanged: authState.isFaceIdAvailable
                          ? _setFaceIdEnabled
                          : null,
                    ),
            ),
            const Divider(height: AppSpace.xl),
            const SizedBox(height: AppSpace.md),
            Text(
              'Giao diện',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpace.xxs),
            Text(
              'Chọn cách hiển thị TaskFlow trên thiết bị này.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpace.md),
            Row(
              children: [
                Expanded(
                  child: _ThemeModeOption(
                    iconName: 'sun-01',
                    label: 'Sáng',
                    isSelected: selectedThemeMode == ThemeMode.light,
                    onTap: () => ref
                        .read(themeModeProvider.notifier)
                        .setThemeMode(ThemeMode.light),
                  ),
                ),
                const SizedBox(width: AppSpace.xs),
                Expanded(
                  child: _ThemeModeOption(
                    iconName: 'moon-01',
                    label: 'Tối',
                    isSelected: selectedThemeMode == ThemeMode.dark,
                    onTap: () => ref
                        .read(themeModeProvider.notifier)
                        .setThemeMode(ThemeMode.dark),
                  ),
                ),
                const SizedBox(width: AppSpace.xs),
                Expanded(
                  child: _ThemeModeOption(
                    iconName: 'settings-01',
                    label: 'Hệ thống',
                    isSelected: selectedThemeMode == ThemeMode.system,
                    onTap: () => ref
                        .read(themeModeProvider.notifier)
                        .setThemeMode(ThemeMode.system),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.md),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: SizedBox(
                width: 24,
                height: 24,
                child: AppSvgIcon(
                  name: 'notification-01',
                  size: 24,
                  color: colors.onSurfaceVariant,
                ),
              ),
              title: const Text('Thông báo nhắc việc'),
              subtitle: Text(
                notificationSettings.errorMessage ??
                    'Nhận thông báo khi đến giờ nhắc công việc',
                style: notificationSettings.errorMessage == null
                    ? null
                    : TextStyle(color: colors.error),
              ),
              trailing:
                  notificationSettings.isLoading ||
                      notificationSettings.isUpdating
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Switch.adaptive(
                      value:
                          notificationSettings.enabled &&
                          notificationSettings.permissionGranted,
                      onChanged: ref
                          .read(notificationSettingsProvider.notifier)
                          .setEnabled,
                    ),
            ),
            if (notificationSettings.requiresSettingsHelp)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: notificationSettings.isUpdating
                      ? null
                      : ref
                            .read(notificationSettingsProvider.notifier)
                            .openSettings,
                  icon: AppSvgIcon(name: 'settings-01', color: colors.primary),
                  label: const Text('Mở cài đặt thông báo'),
                ),
              ),
            if (notificationSettings.enabled &&
                !notificationSettings.permissionGranted)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: notificationSettings.isUpdating
                      ? null
                      : () => ref
                            .read(notificationSettingsProvider.notifier)
                            .setEnabled(false),
                  child: const Text('Tắt trong TaskFlow'),
                ),
              ),
            const Divider(height: AppSpace.xl),
            const SectionHeading(title: 'Thông tin khác'),
            const SizedBox(height: AppSpace.xs),
            ListTile(
              contentPadding: EdgeInsets.zero,
              onTap: () => AboutTaskFlowDialog.show(context),
              leading: AppSvgIcon(
                name: 'task-01',
                color: colors.onSurfaceVariant,
              ),
              title: const Text('Giới thiệu TaskFlow'),
              subtitle: const Text('Nơi tập trung cho những việc tiếp theo.'),
              trailing: const Icon(Icons.chevron_right),
            ),
            const SizedBox(height: AppSpace.lg),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _logout,
                icon: AppSvgIcon(name: 'logout-circle-01', color: colors.error),
                label: const Text('Đăng xuất'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.error,
                  side: BorderSide(color: colors.error.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _logout() async {
    final shouldLogout = await AppConfirmDialog.show(
      context: context,
      title: 'Đăng xuất',
      message: 'Bạn có chắc chắn muốn đăng xuất khỏi tài khoản này không?',
      confirmLabel: 'Đăng xuất',
      iconName: 'logout-circle-01',
      destructive: true,
    );

    if (!mounted || shouldLogout != true) return;

    final authNotifier = ref.read(authProvider.notifier);
    final container = ProviderScope.containerOf(context, listen: false);

    try {
      await authNotifier.logout();
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đăng xuất thất bại. Vui lòng thử lại.')),
      );
      return;
    }

    container.invalidate(taskProvider);
  }
}

class _ThemeModeOption extends StatelessWidget {
  const _ThemeModeOption({
    required this.iconName,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String iconName;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Semantics(
      selected: isSelected,
      label: 'Giao diện $label',
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.xxs,
            vertical: AppSpace.sm,
          ),
          decoration: BoxDecoration(
            color: isSelected ? colors.primaryContainer : colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: isSelected ? colors.primary : colors.outlineVariant,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppSvgIcon(
                name: iconName,
                size: 20,
                color: isSelected
                    ? colors.onPrimaryContainer
                    : colors.onSurfaceVariant,
              ),
              const SizedBox(height: AppSpace.xxs),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: isSelected
                      ? colors.onPrimaryContainer
                      : colors.onSurfaceVariant,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
