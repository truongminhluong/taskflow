import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task_flow_v2/features/tasks/presentation/providers/notification_settings_provider.dart';
import 'package:task_flow_v2/features/tasks/presentation/providers/theme_mode_provider.dart';
import 'package:task_flow_v2/features/tasks/presentation/screens/profile_screen.dart';
import 'package:task_flow_v2/features/tasks/presentation/state/notification_settings_state.dart';

void main() {
  testWidgets('profile renders the notification preference', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationSettingsProvider.overrideWith(
            _FakeNotificationSettingsNotifier.new,
          ),
          themeModeProvider.overrideWith(_FakeThemeModeNotifier.new),
        ],
        child: MaterialApp(home: Scaffold(body: ProfileScreen(isActive: true))),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Thông báo nhắc việc'), findsOneWidget);
    expect(
      find.text('Nhận thông báo khi đến giờ nhắc công việc'),
      findsOneWidget,
    );
  });

  testWidgets('profile keeps switch off when iOS permission is revoked', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationSettingsProvider.overrideWith(
            _RevokedNotificationSettingsNotifier.new,
          ),
          themeModeProvider.overrideWith(_FakeThemeModeNotifier.new),
        ],
        child: MaterialApp(home: Scaffold(body: ProfileScreen(isActive: true))),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const PageStorageKey('profile-scroll')),
      const Offset(0, -700),
    );
    await tester.pumpAndSettle();

    final notificationSwitch = tester.widget<Switch>(find.byType(Switch).last);
    expect(notificationSwitch.value, isFalse);
    expect(find.text('Mở cài đặt thông báo'), findsOneWidget);
    expect(find.text('Tắt trong TaskFlow'), findsOneWidget);
  });
}

class _FakeNotificationSettingsNotifier extends NotificationSettingsNotifier {
  @override
  NotificationSettingsState build() => const NotificationSettingsState();
}

class _RevokedNotificationSettingsNotifier
    extends NotificationSettingsNotifier {
  @override
  NotificationSettingsState build() => const NotificationSettingsState(
    enabled: true,
    permissionGranted: false,
    requiresSettingsHelp: true,
    errorMessage: 'Quyền thông báo đã bị tắt trong Cài đặt thiết bị.',
  );
}

class _FakeThemeModeNotifier extends ThemeModeNotifier {
  @override
  ThemeMode build() => ThemeMode.system;
}
