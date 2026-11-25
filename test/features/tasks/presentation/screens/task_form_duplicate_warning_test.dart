import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart'
    show ImagePickerPlatform, ImagePickerOptions;
import 'package:task_flow_v2/core/notifications/task_reminder_coordinator.dart';
import 'package:task_flow_v2/core/theme/app_theme.dart';
import 'package:task_flow_v2/features/tasks/data/models/task_model.dart';
import 'package:task_flow_v2/features/tasks/data/models/task_overview_model.dart';
import 'package:task_flow_v2/features/tasks/data/models/task_page_model.dart';
import 'package:task_flow_v2/features/tasks/domain/repositories/task_repository.dart';
import 'package:task_flow_v2/features/tasks/presentation/providers/task_provider.dart';
import 'package:task_flow_v2/features/tasks/presentation/providers/task_reminder_coordinator_provider.dart';
import 'package:task_flow_v2/features/tasks/presentation/screens/task_form_screen.dart';
import 'package:task_flow_v2/features/tasks/presentation/widgets/common/app_svg_icon.dart';

void main() {
  testWidgets('create form header matches the compact back-navigation design', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskRepositoryProvider.overrideWithValue(_FormRepository([])),
          taskReminderCoordinatorProvider.overrideWithValue(_FakeCoordinator()),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const TaskFormScreen()),
      ),
    );

    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.toolbarHeight, 88);
    expect(appBar.titleSpacing, AppSpace.md);
    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is AppSvgIcon && widget.name == 'task-add-01',
      ),
      findsNothing,
    );
    expect(find.text('Thêm công việc'), findsOneWidget);
    expect(find.text('Ghi lại để được nhắc đúng lúc nhé!'), findsOneWidget);
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(320, 720);
    await tester.pump();
    expect(tester.widget<AppBar>(find.byType(AppBar)).toolbarHeight, 96);
    expect(tester.takeException(), isNull);
  });

  testWidgets('urgent reminder hint changes with its switch', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskRepositoryProvider.overrideWithValue(_FormRepository([])),
          taskReminderCoordinatorProvider.overrideWithValue(_FakeCoordinator()),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const TaskFormScreen()),
      ),
    );

    const normalHint = 'Đánh dấu lời nhắc này là khẩn cấp để đặt cảnh báo.';
    const urgentHint = 'Lời nhắc đã được đánh dấu là khẩn cấp.';
    expect(find.text(normalHint), findsOneWidget);

    final urgentRow = find
        .ancestor(of: find.text('Khẩn cấp'), matching: find.byType(Row))
        .first;
    final urgentSwitch = find.descendant(
      of: urgentRow,
      matching: find.byType(Switch),
    );
    await tester.tap(urgentSwitch);
    await tester.pumpAndSettle();
    expect(find.text(urgentHint), findsOneWidget);
    expect(find.text(normalHint), findsNothing);

    await tester.tap(urgentSwitch);
    await tester.pumpAndSettle();
    expect(find.text(normalHint), findsOneWidget);
    expect(find.text(urgentHint), findsNothing);
  });

  testWidgets('attachment tile displays an image icon', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskRepositoryProvider.overrideWithValue(_FormRepository([])),
          taskReminderCoordinatorProvider.overrideWithValue(_FakeCoordinator()),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const TaskFormScreen()),
      ),
    );

    expect(find.text('Thêm hình ảnh'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is AppSvgIcon && widget.name == 'image-add-01',
      ),
      findsOneWidget,
    );
    final colors = AppTheme.light.colorScheme;
    final imageIcon = tester.widget<AppSvgIcon>(
      find.byWidgetPredicate(
        (widget) => widget is AppSvgIcon && widget.name == 'image-add-01',
      ),
    );
    final title = tester.widget<Text>(find.text('Thêm hình ảnh'));
    final subtitle = tester.widget<Text>(find.text('Chụp hoặc chọn ảnh'));
    final chevron = tester.widget<Icon>(
      find.byIcon(Icons.chevron_right_rounded),
    );

    expect(imageIcon.color, colors.primary);
    expect(title.style?.color, colors.onSurface);
    expect(subtitle.style?.color, colors.onSurfaceVariant);
    expect(chevron.color, colors.onSurfaceVariant);
    expect(tester.takeException(), isNull);
  });

  testWidgets('edit form previews and removes a saved attachment', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const savedAttachment = TaskAttachment(
      name: 'saved-photo.png',
      url: 'https://cdn.example.test/saved-photo.png',
      publicId: 'taskflow/users/user/saved-photo',
      mimeType: 'image/png',
      sizeBytes: 123,
    );
    final task = _task('task-1', 'Task with image', null).copyWith(
      attachments: const [savedAttachment],
    );
    final repository = _FormRepository([task]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskRepositoryProvider.overrideWithValue(repository),
          taskReminderCoordinatorProvider.overrideWithValue(_FakeCoordinator()),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: TaskFormScreen(task: task),
        ),
      ),
    );

    expect(find.text('saved-photo.png'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);

    await tester.tap(find.byTooltip('Xóa ảnh'));
    await tester.pumpAndSettle();
    expect(find.text('saved-photo.png'), findsNothing);
    expect(find.text('Thêm hình ảnh'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey('save-task')));
    await tester.tap(find.byKey(const ValueKey('save-task')));
    await tester.pumpAndSettle();

    expect(repository.updatedTasks.single.attachments, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('create retries only uploads that did not already succeed', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final paths = [
      XFile.fromData(
        Uint8List.fromList(_pngSignature),
        path: 'first.png',
        length: _pngSignature.length,
      ),
      XFile.fromData(
        Uint8List.fromList(_pngSignature),
        path: 'second.png',
        length: _pngSignature.length,
      ),
    ];
    final previousPicker = ImagePickerPlatform.instance;
    ImagePickerPlatform.instance = _FixtureImagePickerPlatform(paths);
    addTearDown(() => ImagePickerPlatform.instance = previousPicker);

    final repository = _FormRepository([]);
    repository.failUploadName = 'second.png';
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskRepositoryProvider.overrideWithValue(repository),
          taskReminderCoordinatorProvider.overrideWithValue(_FakeCoordinator()),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const TaskFormScreen()),
      ),
    );
    await tester.enterText(
      find.byKey(const ValueKey('task-title')),
      'Task with images',
    );

    await _pickTaskImage(tester, find.text('Thêm hình ảnh'));
    expect(find.text(paths[0].name), findsOneWidget);
    expect(find.text('Thêm ảnh'), findsOneWidget);
    await _pickTaskImage(tester, find.text('Thêm ảnh'));
    final firstName = paths[0].name;
    final secondName = paths[1].name;
    expect(find.text(firstName), findsOneWidget);
    expect(find.text(secondName), findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey('save-task')));
    await tester.tap(find.byKey(const ValueKey('save-task')));
    await _pumpUntil(
      tester,
      () => find
          .text('Không thể tải ảnh lên. Kiểm tra kết nối rồi thử lại.')
          .evaluate()
          .isNotEmpty,
    );
    expect(repository.createdTasks, isEmpty);
    expect(repository.uploadAttempts, [firstName, secondName]);

    await tester.tap(find.byKey(const ValueKey('save-task')));
    await _pumpUntil(
      tester,
      () => find.text('Tạo công việc thành công.').evaluate().isNotEmpty,
    );

    expect(repository.uploadAttempts, [firstName, secondName, secondName]);
    expect(repository.createdTasks, hasLength(1));
    expect(
      repository.createdTasks.single.attachments.map((item) => item.name),
      [firstName, secondName],
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('task form uses theme colors for section and schedule icons', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskRepositoryProvider.overrideWithValue(_FormRepository([])),
          taskReminderCoordinatorProvider.overrideWithValue(_FakeCoordinator()),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const TaskFormScreen()),
      ),
    );

    final colors = AppTheme.light.colorScheme;
    const themedIconNames = {
      'calendar-01',
      'clock-01',
      'calendar-check-in-01',
      'notification-01',
      'flag-01',
    };
    final themedIcons = tester
        .widgetList<AppSvgIcon>(
          find.byWidgetPredicate(
            (widget) =>
                widget is AppSvgIcon && themedIconNames.contains(widget.name),
          ),
        )
        .toList();

    expect(themedIcons.map((icon) => icon.name).toSet(), themedIconNames);
    for (final icon in themedIcons) {
      if (icon.name == 'notification-01') {
        expect(icon.color, colors.primary);
      } else if (icon.name == 'flag-01') {
        expect({colors.primary, AppPalette.warning}, contains(icon.color));
      } else {
        expect(icon.color, colors.primary);
      }
    }
    expect(
      tester.widget<Text>(find.text('Ngày')).style?.color,
      colors.onSurface,
    );
    expect(
      tester.widget<Text>(find.text('Lặp lại')).style?.color,
      colors.onSurface,
    );

    await tester.drag(find.byType(ListView).first, const Offset(0, -1200));
    await tester.pumpAndSettle();

    final categoryIcons = tester.widgetList<AppSvgIcon>(
      find.byWidgetPredicate(
        (widget) =>
            widget is AppSvgIcon &&
            {'dashboard-square-01', 'folder-01'}.contains(widget.name),
      ),
    );
    expect(categoryIcons, hasLength(2));
    expect(categoryIcons.every((icon) => icon.color == colors.primary), isTrue);
    expect(
      tester.widget<Text>(find.text('Danh mục')).style?.color,
      colors.onSurface,
    );
  });

  testWidgets('duplicate warning can return to edit or create once', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final today = DateTime.now();
    final repository = _FormRepository([
      _task(
        'existing',
        'Existing task',
        DateTime(today.year, today.month, today.day, 9),
      ),
      _task(
        'existing-completed',
        'Completed task',
        DateTime(today.year, today.month, today.day, 9),
        isCompleted: true,
      ),
    ]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskRepositoryProvider.overrideWithValue(repository),
          taskReminderCoordinatorProvider.overrideWithValue(_FakeCoordinator()),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const TaskFormScreen()),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('task-title')),
      'New task',
    );
    await tester.tap(find.byKey(const ValueKey('choose-task-date')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('${today.day}').last);
    await tester.pumpAndSettle();

    Future<void> saveAndWaitForWarning() async {
      await tester.ensureVisible(find.byKey(const ValueKey('save-task')));
      await tester.tap(find.byKey(const ValueKey('save-task')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('Thời gian đã có công việc'), findsOneWidget);
      expect(find.text('Existing task'), findsOneWidget);
      expect(find.text('Completed task'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.textContaining('9:00'),
        ),
        findsNWidgets(2),
      );
    }

    await saveAndWaitForWarning();
    await tester.tap(find.text('Quay lại chỉnh sửa'));
    await tester.pumpAndSettle();
    expect(find.text('Thời gian đã có công việc'), findsNothing);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('task-title')))
          .controller!
          .text,
      'New task',
    );
    expect(repository.createdTasks, isEmpty);

    await saveAndWaitForWarning();
    await tester.tap(find.text('Vẫn thêm công việc'));
    await tester.pumpAndSettle();
    expect(repository.createdTasks, hasLength(1));
    expect(repository.createdTasks.single.title, 'New task');
    expect(
      repository.createdTasks.single.dueDate,
      DateTime(today.year, today.month, today.day, 9),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('editing excludes itself but warns about another matching task', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final dueDate = DateTime(2026, 11, 6, 9, 30);
    final editingTask = _task('editing', 'Editing task', dueDate);
    final repository = _FormRepository([
      editingTask,
      _task('other', 'Other matching task', dueDate, isCompleted: true),
    ]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskRepositoryProvider.overrideWithValue(repository),
          taskReminderCoordinatorProvider.overrideWithValue(_FakeCoordinator()),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: TaskFormScreen(task: editingTask),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('save-task')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('Thời gian đã có công việc'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Other matching task'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Editing task'),
      ),
      findsNothing,
    );
    expect(find.text('Vẫn lưu thay đổi'), findsOneWidget);
    await tester.tap(find.text('Vẫn lưu thay đổi'));
    await tester.pumpAndSettle();
    expect(repository.updatedTasks, hasLength(1));
    expect(repository.createdTasks, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('editing preserves repeat limit and selected end date', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final editingTask =
        _task(
          'recurring',
          'Recurring task',
          DateTime(2026, 11, 25, 9),
        ).copyWith(
          repeat: const TaskRepeatConfig(
            enabled: true,
            frequency: TaskRepeatFrequency.weekly,
            weekdays: [3],
            anchorDate: '2026-11-25',
            anchorDay: 25,
            endType: TaskRepeatEndType.afterOccurrences,
            maxOccurrences: 6,
          ),
        );
    final repository = _FormRepository([editingTask]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskRepositoryProvider.overrideWithValue(repository),
          taskReminderCoordinatorProvider.overrideWithValue(_FakeCoordinator()),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: TaskFormScreen(task: editingTask),
        ),
      ),
    );

    await tester.drag(find.byType(ListView).first, const Offset(0, -420));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Hằng tuần'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hằng ngày'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Kết thúc lặp lại'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vào ngày'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chọn ngày'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('26').last);
    await tester.pumpAndSettle();
    expect(find.text('Ngày 26/11/2026'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('save-task')));
    await tester.pumpAndSettle();

    expect(repository.updatedTasks, hasLength(1));
    expect(
      repository.updatedTasks.single.repeat.frequency,
      TaskRepeatFrequency.daily,
    );
    expect(
      repository.updatedTasks.single.repeat.endType,
      TaskRepeatEndType.onDate,
    );
    expect(repository.updatedTasks.single.repeat.endDate, '2026-11-26');
    expect(repository.updatedTasks.single.repeat.maxOccurrences, 6);
    expect(tester.takeException(), isNull);
  });
}

TaskModel _task(
  String id,
  String title,
  DateTime? dueDate, {
  bool isCompleted = false,
}) => TaskModel(
  id: id,
  title: title,
  description: '',
  dueDate: dueDate,
  priority: TaskPriority.medium,
  category: 'Cá nhân',
  isCompleted: isCompleted,
);

final class _FormRepository implements TaskRepository {
  _FormRepository(this.tasks);

  final List<TaskModel> tasks;
  final createdTasks = <TaskModel>[];
  final updatedTasks = <TaskModel>[];
  final uploadAttempts = <String>[];
  String? failUploadName;
  bool _failedConfiguredUpload = false;

  @override
  Future<List<TaskModel>> getTasks() async => tasks;

  @override
  Future<TaskPageModel> getTaskPage({
    int page = 1,
    int limit = 20,
    String? search,
    bool? isCompleted,
    String? priority,
    String? dueFrom,
    String? dueBefore,
    String sort = 'createdAtDesc',
  }) async => TaskPageModel(
    items: tasks,
    page: 1,
    limit: limit,
    totalItems: tasks.length,
    totalPages: 1,
    hasNextPage: false,
  );

  @override
  Future<TaskModel> createTask(TaskModel task) async {
    createdTasks.add(task);
    return task.copyWith(id: 'created-${createdTasks.length}');
  }

  @override
  Future<TaskAttachment> uploadTaskAttachment({
    required String path,
    required String name,
  }) async {
    uploadAttempts.add(name);
    if (name == failUploadName && !_failedConfiguredUpload) {
      _failedConfiguredUpload = true;
      throw StateError('Upload failed');
    }

    return TaskAttachment(
      name: name,
      url: 'https://cdn.example.test/$name',
      publicId: 'taskflow/users/user/$name',
      mimeType: 'image/jpeg',
      sizeBytes: 4,
    );
  }

  @override
  Future<TaskModel> updateTask(TaskModel task) async {
    updatedTasks.add(task);
    return task;
  }

  @override
  Future<void> updateTaskCompletion(String taskId, bool isCompleted) async {}

  @override
  Future<void> deleteTask(String taskId) async {}

  @override
  Future<Map<String, dynamic>> getRecurringSeries() async => {};
  @override
  Future<Map<String, dynamic>> getRecurringSeriesById(String id) async => {};
  @override
  Future<Map<String, dynamic>> updateRecurringSeries(
    String id,
    TaskRepeatConfig repeat,
  ) async => {};
  @override
  Future<Map<String, dynamic>> stopRecurringSeries(String id) async => {};

  @override
  Future<TaskModel> getTaskById(String taskId) async => tasks.first;

  @override
  Future<TaskOverviewModel> getTaskOverview({
    String? date,
    String timeZone = 'Asia/Ho_Chi_Minh',
  }) async => throw UnimplementedError();
}

Future<void> _pickTaskImage(WidgetTester tester, Finder addButton) async {
  await tester.ensureVisible(addButton);
  await tester.tap(addButton);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Chọn ảnh'));
  await tester.pumpAndSettle();
}

const _pngSignature = [
  0x89,
  0x50,
  0x4e,
  0x47,
  0x0d,
  0x0a,
  0x1a,
  0x0a,
];

final class _FixtureImagePickerPlatform extends ImagePickerPlatform {
  _FixtureImagePickerPlatform(List<XFile> images) : images = List.of(images);

  final List<XFile> images;

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async => images.removeAt(0);
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() condition) async {
  for (var attempt = 0; attempt < 50 && !condition(); attempt++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(condition(), isTrue);
}

final class _FakeCoordinator implements TaskReminderCoordinatorContract {
  @override
  Future<NotificationSettingsSnapshot> readSettings() async =>
      const NotificationSettingsSnapshot(
        enabled: false,
        permissionGranted: true,
      );

  @override
  Future<NotificationSettingsSnapshot?>
  requestInitialPermissionIfNeeded() async => null;

  @override
  Future<NotificationSettingsSnapshot> enable() async =>
      const NotificationSettingsSnapshot(
        enabled: true,
        permissionGranted: true,
      );

  @override
  Future<NotificationSettingsSnapshot> enableForTasks(
    List<TaskModel> tasks,
  ) async => const NotificationSettingsSnapshot(
    enabled: true,
    permissionGranted: true,
  );

  @override
  Future<void> disable() async {}

  @override
  Future<void> syncTask(TaskModel task) async {}

  @override
  Future<void> syncTasks(List<TaskModel> tasks, {int? restoreRevision}) async {}

  @override
  int captureRestoreRevision() => 0;

  @override
  Future<void> cancelTask(String taskId) async {}

  @override
  Future<void> openSettings() async {}
}
