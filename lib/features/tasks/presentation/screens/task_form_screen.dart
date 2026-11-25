import 'dart:io';

import 'package:image_picker/image_picker.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:task_flow_v2/core/time/app_time_zone.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:task_flow_v2/core/theme/app_theme.dart';
import 'package:task_flow_v2/features/tasks/data/models/task_model.dart';
import 'package:task_flow_v2/features/tasks/data/validation/task_attachment_file_validator.dart';
import 'package:task_flow_v2/features/tasks/presentation/widgets/tasks/task_category_label.dart';
import 'package:task_flow_v2/features/tasks/presentation/widgets/tasks/task_due_date_reminder_section.dart';
import 'package:task_flow_v2/features/tasks/presentation/widgets/tasks/priority_badge.dart';
import 'package:task_flow_v2/features/tasks/presentation/widgets/common/vietnamese_date.dart';
import 'package:task_flow_v2/features/tasks/presentation/widgets/common/app_svg_icon.dart';

import '../providers/task_provider.dart';
import '../widgets/common/task_flow_background.dart';

String _formatDateOnly(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

String _repeatDisplayLabel(TaskRepeatConfig config) {
  if (config.frequency == TaskRepeatFrequency.monthly &&
      config.interval >= 12 &&
      config.interval % 12 == 0) {
    final years = config.interval ~/ 12;
    return years == 1 ? 'Hằng năm' : 'Mỗi $years năm';
  }
  return config.label;
}

class TaskFormScreen extends ConsumerStatefulWidget {
  const TaskFormScreen({super.key, this.task});

  final TaskModel? task;

  @override
  ConsumerState<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends ConsumerState<TaskFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;

  late TaskPriority _priority;
  late String _category;

  TaskDueDateType _dueDateType = TaskDueDateType.none;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  DateTime? get _dueDate => _selectedDate == null
      ? null
      : appTimeFromComponents(
          year: _selectedDate!.year,
          month: _selectedDate!.month,
          day: _selectedDate!.day,
          hour: _dueDateType == TaskDueDateType.dateTime
              ? _selectedTime!.hour
              : 0,
          minute: _dueDateType == TaskDueDateType.dateTime
              ? _selectedTime!.minute
              : 0,
        );
  TaskRepeatConfig _repeatConfig = const TaskRepeatConfig.disabled();
  final List<_PendingAttachment> _attachments = [];
  String? _uploadingAttachmentPath;

  bool _isSaving = false;
  bool _isUrgent = false;

  List<String> get _categoryOptions {
    const standard = ['Công việc', 'Cá nhân', 'Học tập'];

    return standard.contains(_category) ? standard : [_category, ...standard];
  }

  int _reminderSelection = 0;

  void _selectRepeatFrequency(TaskRepeatFrequency? frequency) {
    if (frequency == null) {
      setState(() {
        _repeatConfig = const TaskRepeatConfig.disabled();
      });
      return;
    }
    final anchorDate = _dueDate ?? nowInAppTime();
    setState(() {
      _repeatConfig = TaskRepeatConfig(
        enabled: true,
        frequency: frequency,
        weekdays: frequency == TaskRepeatFrequency.weekly
            ? (_repeatConfig.frequency == TaskRepeatFrequency.weekly &&
                      _repeatConfig.weekdays.isNotEmpty
                  ? _repeatConfig.weekdays
                  : [anchorDate.weekday % 7])
            : const [],
        anchorDate: _formatDateOnly(anchorDate),
        anchorDay: anchorDate.day,
        endType: _repeatConfig.enabled
            ? _repeatConfig.endType
            : TaskRepeatEndType.never,
        endDate:
            _repeatConfig.enabled &&
                _repeatConfig.endType == TaskRepeatEndType.onDate
            ? _repeatConfig.endDate
            : null,
        maxOccurrences: _repeatConfig.maxOccurrences,
        // Editing/creating repeat is an explicit recurrence change. New
        // recurrence schedules always use the business timezone.
        timeZone: appTimeZone,
      );
    });
  }

  void _chooseRepeatEndType(TaskRepeatEndType selected) {
    if (mounted) {
      setState(() {
        _repeatConfig = TaskRepeatConfig(
          enabled: _repeatConfig.enabled,
          frequency: _repeatConfig.frequency,
          interval: _repeatConfig.interval,
          weekdays: _repeatConfig.weekdays,
          anchorDate: _repeatConfig.anchorDate,
          anchorDay: _repeatConfig.anchorDay,
          endType: selected,
          endDate: selected == TaskRepeatEndType.onDate
              ? _repeatConfig.endDate
              : null,
          maxOccurrences: _repeatConfig.maxOccurrences,
          timeZone: _repeatConfig.timeZone,
        );
      });
    }
  }

  void _selectRepeatEndDate(DateTime selected) {
    setState(
      () => _repeatConfig = _repeatConfig.copyWith(
        endType: TaskRepeatEndType.onDate,
        endDate: _formatDateOnly(selected),
      ),
    );
  }

  Future<void> _addAttachment() async {
    if (_attachments.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bạn chỉ có thể thêm tối đa 5 ảnh.')),
      );
      return;
    }

    final source = await showModalBottomSheet<_AttachmentSource>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const _AttachmentSourceSheet(),
    );

    if (!mounted || source == null) return;

    if (source == _AttachmentSource.scanDocument) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Tính năng quét tài liệu sẽ được kết nối ở bước tiếp theo.',
          ),
        ),
      );
      return;
    }

    final image = await ImagePicker().pickImage(
      source: source == _AttachmentSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      imageQuality: 85,
    );

    if (image == null || !mounted) return;

    if (_attachments.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bạn chỉ có thể thêm tối đa 5 ảnh.')),
      );
      return;
    }

    if (_attachments.any((attachment) => attachment.path == image.path)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tệp này đã được thêm rồi.')),
      );
      return;
    }

    try {
      final sizeBytes = await image.length();
      final header = await image
          .openRead(0, 16)
          .fold<List<int>>([], (bytes, chunk) => bytes..addAll(chunk));
      TaskAttachmentFileValidator.validate(
        sizeBytes: sizeBytes,
        header: header,
      );
      if (!mounted) return;

      if (_attachments.length >= 5) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bạn chỉ có thể thêm tối đa 5 ảnh.')),
        );
        return;
      }
      if (_attachments.any((attachment) => attachment.path == image.path)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tệp này đã được thêm rồi.')),
        );
        return;
      }

      setState(() {
        _attachments.add(
          _PendingAttachment(name: image.name, path: image.path),
        );
      });
    } on TaskAttachmentValidationException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể đọc ảnh đã chọn.')),
      );
    }
  }

  void _removeAttachment(_PendingAttachment attachment) {
    setState(() => _attachments.remove(attachment));
  }

  @override
  void initState() {
    super.initState();

    final task = widget.task;

    _titleController = TextEditingController(text: task?.title ?? '');

    _descriptionController = TextEditingController(
      text: task?.description ?? '',
    );

    _priority = task?.priority ?? TaskPriority.medium;
    _category = taskCategoryLabel(task?.category ?? 'Công việc');
    _dueDateType = task?.dueDateType ?? TaskDueDateType.none;
    if (_dueDateType == TaskDueDateType.date && task?.dueDateDate != null) {
      final parts = task!.dueDateDate!.split('-').map(int.parse).toList();
      _selectedDate = DateTime(parts[0], parts[1], parts[2]);
    } else if (task?.dueDate != null) {
      _selectedDate = task!.dueDate!;
      _selectedTime = TimeOfDay.fromDateTime(_selectedDate!);
    }
    _reminderSelection = task?.reminderMinutesBefore ?? 0;
    _repeatConfig = task?.repeat ?? const TaskRepeatConfig.disabled();
    _attachments.addAll(
      task?.attachments.map(_PendingAttachment.saved) ?? const [],
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.task != null;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final fieldColor = theme.cardTheme.color ?? colors.surface;
    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: BorderSide(
        color: colors.outlineVariant.withValues(alpha: .8),
      ),
    );
    final isCompact = MediaQuery.sizeOf(context).width < 360;

    return TaskFlowBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          toolbarHeight: isCompact ? 96 : 88,
          systemOverlayStyle: theme.brightness == Brightness.dark
              ? SystemUiOverlayStyle.light
              : SystemUiOverlayStyle.dark,
          titleSpacing: AppSpace.md,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(isEditing ? 'Chỉnh sửa công việc' : 'Thêm công việc'),
              const SizedBox(height: AppSpace.xxs),
              Text(
                'Ghi lại để được nhắc đúng lúc nhé!',
                maxLines: 2,
                overflow: TextOverflow.fade,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          leading: IconButton(
            tooltip: 'Quay lại',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        body: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Form(
                key: _formKey,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () => FocusScope.of(context).unfocus(),
                  child: ListView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(
                      AppSpace.md,
                      AppSpace.xs,
                      AppSpace.md,
                      AppSpace.xl,
                    ),
                    children: [
                      _TaskContentCard(
                        titleController: _titleController,
                        descriptionController: _descriptionController,
                        titleValidator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Vui lòng nhập tên công việc.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpace.md),
                      TaskDueDateReminderSection(
                        dueDate: _dueDate,
                        dueDateType: _dueDateType,
                        selectedTime: _selectedTime,
                        isUrgent: _isUrgent,
                        onDateToggled: _toggleDate,
                        onDateSelected: _selectDate,
                        onTimeChanged: _updateTime,
                        onTimeToggled: (enabled) {
                          if (!enabled &&
                              _dueDateType == TaskDueDateType.dateTime) {
                            setState(() {
                              _dueDateType = TaskDueDateType.date;
                              _selectedTime = null;
                              _reminderSelection = 0;
                            });
                          }
                        },
                        onUrgencyChanged: (value) {
                          setState(() => _isUrgent = value);
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpace.sm,
                          AppSpace.xs,
                          AppSpace.sm,
                          0,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              size: 16,
                              color: colors.onSurfaceVariant,
                            ),
                            const SizedBox(width: AppSpace.xs),
                            Expanded(
                              child: Text(
                                _isUrgent
                                    ? 'Lời nhắc đã được đánh dấu là khẩn cấp.'
                                    : 'Đánh dấu lời nhắc này là khẩn cấp để đặt cảnh báo.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpace.md),
                      TaskRepeatReminderSection(
                        repeatLabel: _repeatDisplayLabel(_repeatConfig),
                        repeatEnabled: _repeatConfig.enabled,
                        endTypeLabel:
                            _repeatConfig.endType == TaskRepeatEndType.onDate
                            ? 'Vào ngày'
                            : 'Không',
                        endDate:
                            _repeatConfig.enabled &&
                                _repeatConfig.endType ==
                                    TaskRepeatEndType.onDate &&
                                _repeatConfig.endDate != null
                            ? DateTime.tryParse(_repeatConfig.endDate!) == null
                                  ? _repeatConfig.endDate
                                  : VietnameseDate.numeric(
                                      DateTime.parse(_repeatConfig.endDate!),
                                    )
                            : null,
                        endDateValue:
                            DateTime.tryParse(_repeatConfig.endDate ?? '') ??
                            _dueDate ??
                            nowInAppTime(),
                        repeatConfig: _repeatConfig,
                        onRepeatChanged: _selectRepeatFrequency,
                        onEndTypeChanged: (value) => _chooseRepeatEndType(
                          value == 'Vào ngày'
                              ? TaskRepeatEndType.onDate
                              : TaskRepeatEndType.never,
                        ),
                        onEndDateSelected: _selectRepeatEndDate,
                        reminderSelection: _reminderSelection,
                        reminderEnabled:
                            _dueDateType == TaskDueDateType.dateTime,
                        onReminderChanged: (value) {
                          setState(() => _reminderSelection = value);
                        },
                      ),

                      const SizedBox(height: AppSpace.sm),
                      _AttachmentSection(
                        attachments: _attachments,
                        onAdd: _addAttachment,
                        onRemove: _removeAttachment,
                        uploadingPath: _uploadingAttachmentPath,
                        enabled: !_isSaving,
                      ),

                      const SizedBox(height: AppSpace.sm),

                      _FormSectionHeading(
                        iconName: 'flag-01',
                        title: 'Mức độ ưu tiên',
                      ),

                      const SizedBox(height: AppSpace.xs),

                      _PrioritySelector(
                        selected: _priority,
                        onChanged: (priority) {
                          setState(() => _priority = priority);
                        },
                      ),

                      const SizedBox(height: AppSpace.md),

                      _FormSectionHeading(
                        iconName: 'dashboard-square-01',
                        title: 'Danh mục',
                      ),
                      const SizedBox(height: AppSpace.xs),
                      DropdownButtonFormField<String>(
                        initialValue: _category,
                        decoration: InputDecoration(
                          prefixIcon: Padding(
                            padding: const EdgeInsets.all(AppSpace.sm),
                            child: AppSvgIcon(
                              name: 'folder-01',
                              size: 20,
                              color: colors.primary,
                            ),
                          ),
                          prefixIconConstraints: const BoxConstraints(
                            minWidth: 48,
                            minHeight: 48,
                          ),
                          filled: true,
                          fillColor: fieldColor,
                          enabledBorder: fieldBorder,
                          border: fieldBorder,
                          focusedBorder: fieldBorder.copyWith(
                            borderSide: BorderSide(
                              color: colors.primary,
                              width: 1.5,
                            ),
                          ),
                        ),
                        items: [
                          for (final category in _categoryOptions)
                            DropdownMenuItem(
                              value: category,
                              child: Text(taskCategoryLabel(category)),
                            ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;

                          setState(() => _category = value);

                          // TODO: Lấy danh mục từ API hoặc provider.
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // Các nút ở cuối màn hình
        bottomNavigationBar: SafeArea(
          top: false,
          minimum: const EdgeInsets.only(top: AppSpace.xs),
          child: Align(
            alignment: Alignment.center,
            heightFactor: 1,
            child: Material(
              color: Colors.transparent,
              elevation: 0,
              shadowColor: Colors.transparent,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: colors.outlineVariant.withValues(alpha: .55),
                    ),
                  ),
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 620),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpace.md,
                      0,
                      AppSpace.md,
                      0,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 9,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(52),
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpace.xs,
                              ),
                              foregroundColor: colors.onSurfaceVariant,
                              side: BorderSide(
                                color: colors.outline.withValues(alpha: .7),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.md,
                                ),
                              ),
                              textStyle: theme.textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            onPressed: () => Navigator.of(context).maybePop(),
                            icon: const Icon(Icons.close_rounded, size: 19),
                            label: const Text('Hủy'),
                          ),
                        ),
                        const SizedBox(width: AppSpace.sm),
                        Expanded(
                          flex: 16,
                          child: FilledButton.icon(
                            key: const ValueKey('save-task'),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(52),
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpace.sm,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.md,
                                ),
                              ),
                              elevation: 2,
                              shadowColor: colors.primary.withValues(alpha: .3),
                              textStyle: theme.textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            onPressed: _isSaving ? null : _save,
                            icon: _isSaving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.check_rounded, size: 20),
                            label: Text(
                              _isSaving
                                  ? 'Đang lưu...'
                                  : isEditing
                                  ? 'Lưu thay đổi'
                                  : 'Lưu công việc',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _toggleDate(bool enabled) {
    if (enabled) {
      final now = nowInAppTime();
      setState(() {
        _selectedDate = DateTime(now.year, now.month, now.day);
        _selectedTime = null;
        _dueDateType = TaskDueDateType.date;
      });
      return;
    }

    setState(() {
      _selectedDate = null;
      _selectedTime = null;
      _dueDateType = TaskDueDateType.none;
      _reminderSelection = 0;
    });
  }

  void _selectDate(DateTime selected) {
    setState(() {
      _selectedDate = DateTime(selected.year, selected.month, selected.day);
    });
  }

  Future<void> _save() async {
    // Kiểm tra dữ liệu hợp lệ và tránh gửi request nhiều lần.
    if (!_formKey.currentState!.validate() || _isSaving) {
      return;
    }

    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final dateTimeChanged = _dateTimeChangedFromOriginal();
    final deviceTimeZoneId =
        _dueDate != null && (widget.task == null || dateTimeChanged)
        ? appTimeZone
        : null;
    final candidateTask = TaskModel(
      id: widget.task?.id ?? '',
      title: title,
      description: description,
      dueDate: _dueDate,
      dueDateType: _dueDateType,
      dueDateDate: _dueDateType == TaskDueDateType.date
          ? _formatDateOnly(_selectedDate!)
          : null,
      timeZoneId: _dueDateType == TaskDueDateType.dateTime
          ? deviceTimeZoneId ?? widget.task?.timeZoneId
          : null,
      legacyDateTime: widget.task?.legacyDateTime ?? false,
      priority: _priority,
      category: _category,
      isCompleted: widget.task?.isCompleted ?? false,
      reminderMinutesBefore: _dueDate == null ? null : _reminderSelection,
      recurrenceId: widget.task?.recurrenceId,
      occurrenceIndex: widget.task?.occurrenceIndex,
      repeat: _repeatConfig,
    );

    if (_repeatConfig.enabled && _dueDateType != TaskDueDateType.dateTime) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn ngày nhắc để lặp công việc.'),
        ),
      );
      return;
    }

    if (_repeatConfig.enabled && _repeatConfig.frequency == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn chu kỳ lặp.')),
      );
      return;
    }

    if (_repeatConfig.frequency == TaskRepeatFrequency.weekly &&
        _repeatConfig.weekdays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn ít nhất một ngày trong tuần.'),
        ),
      );
      return;
    }

    if (_repeatConfig.enabled &&
        _repeatConfig.endType == TaskRepeatEndType.afterOccurrences &&
        (_repeatConfig.maxOccurrences == null ||
            _repeatConfig.maxOccurrences! < 1 ||
            _repeatConfig.maxOccurrences! > 3650)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Số lần lặp phải từ 1 đến 3650.')),
      );
      return;
    }

    if (_repeatConfig.enabled &&
        _repeatConfig.endType == TaskRepeatEndType.onDate &&
        _repeatConfig.endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn ngày kết thúc lặp.')),
      );
      return;
    }

    if (_repeatConfig.enabled &&
        _repeatConfig.endType == TaskRepeatEndType.onDate &&
        _repeatConfig.endDate != null &&
        _dueDate != null &&
        _repeatConfig.endDate!.compareTo(_formatDateOnly(_dueDate!)) < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ngày kết thúc lặp phải sau ngày nhắc.')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final notifier = ref.read(taskProvider.notifier);
      final bool success;

      if (candidateTask.dueDate != null) {
        final conflicts = await notifier.findScheduleConflicts(candidateTask);

        if (!mounted) return;

        if (conflicts == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Không thể kiểm tra lịch hiện có. Vui lòng thử lại.',
              ),
            ),
          );
          return;
        }

        if (conflicts.isNotEmpty) {
          final shouldContinue = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => _DuplicateTaskDialog(
              conflicts: conflicts,
              isEditing: widget.task != null,
            ),
          );

          if (!mounted || shouldContinue != true) return;
        }
      }

      final uploadedAttachments = <TaskAttachment>[];
      for (final attachment in _attachments) {
        var metadata = attachment.uploadedAttachment;
        if (metadata == null) {
          setState(() => _uploadingAttachmentPath = attachment.path);
          try {
            metadata = await notifier.uploadTaskAttachment(
              path: attachment.path,
              name: attachment.name,
            );
            attachment.uploadedAttachment = metadata;
          } on TaskAttachmentValidationException catch (error) {
            if (!mounted) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(error.message)));
            return;
          } catch (_) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Không thể tải ảnh lên. Kiểm tra kết nối rồi thử lại.',
                ),
              ),
            );
            return;
          } finally {
            if (mounted) {
              setState(() => _uploadingAttachmentPath = null);
            }
          }
        }
        uploadedAttachments.add(metadata);
      }

      final taskWithAttachments = candidateTask.copyWith(
        attachments: uploadedAttachments,
      );
      if (widget.task == null) {
        success = await notifier.createTask(taskWithAttachments);
      } else {
        // CẬP NHẬT CÔNG VIỆC HIỆN CÓ.
        final updatedTask = taskWithAttachments.copyWith(
          clearReminderMinutesBefore: _dueDate == null,
          clearDueDate: _dueDateType == TaskDueDateType.none,
          markDateTimeChanged: dateTimeChanged,
        );

        final timer = Stopwatch()..start();

        success = await notifier.updateTask(
          updatedTask,
          allowMissingFromSharedState: true,
        );

        debugPrint('updateTask tổng: ${timer.elapsedMilliseconds} ms');
      }

      if (!mounted) return;

      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.task == null
                  ? 'Không thể tạo công việc. Vui lòng thử lại.'
                  : 'Không thể cập nhật công việc. Vui lòng thử lại.',
            ),
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.task == null
                ? 'Tạo công việc thành công.'
                : 'Cập nhật công việc thành công.',
          ),
        ),
      );

      // Chỉ đóng form sau khi API thành công.
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.task == null
                ? 'Đã xảy ra lỗi khi tạo công việc. Vui lòng thử lại.'
                : 'Đã xảy ra lỗi khi cập nhật công việc. Vui lòng thử lại.',
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  bool _dateTimeChangedFromOriginal() {
    final original = widget.task;
    if (original == null) return _dueDateType != TaskDueDateType.none;
    if (original.dueDateType != _dueDateType) return true;
    if (_dueDateType == TaskDueDateType.date) {
      return original.dueDateDate != _formatDateOnly(_selectedDate!);
    }
    if (_dueDateType == TaskDueDateType.dateTime) {
      return original.dueDate?.millisecondsSinceEpoch !=
          _dueDate?.millisecondsSinceEpoch;
    }
    return false;
  }

  void _updateTime(TimeOfDay selectedTime) {
    if (_selectedDate == null) return;
    setState(() {
      _selectedTime = selectedTime;
      _dueDateType = TaskDueDateType.dateTime;
    });
  }
}

class _PrioritySelector extends StatelessWidget {
  const _PrioritySelector({required this.selected, required this.onChanged});

  final TaskPriority selected;
  final ValueChanged<TaskPriority> onChanged;

  @override
  Widget build(BuildContext context) {
    final options = [
      (TaskPriority.low, 'Thấp', 'star'),
      (TaskPriority.medium, 'Trung bình', 'checkmark-circle-01'),
      (TaskPriority.high, 'Cao', 'flag-01'),
    ];

    return Row(
      children: [
        for (var index = 0; index < options.length; index++) ...[
          if (index > 0) const SizedBox(width: AppSpace.xs),
          Expanded(
            child: _PriorityOption(
              priority: options[index].$1,
              label: options[index].$2,
              iconName: options[index].$3,
              selected: selected == options[index].$1,
              onTap: () => onChanged(options[index].$1),
            ),
          ),
        ],
      ],
    );
  }
}

class _PriorityOption extends StatelessWidget {
  const _PriorityOption({
    required this.priority,
    required this.label,
    required this.iconName,
    required this.selected,
    required this.onTap,
  });

  final TaskPriority priority;
  final String label;
  final String iconName;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = PriorityBadge.accentColor(context, priority);
    final colors = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      selected: selected,
      label: 'Mức độ ưu tiên $label',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 54,
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.xs),
            decoration: BoxDecoration(
              color: selected ? color.withValues(alpha: .16) : colors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: selected ? color : colors.outlineVariant,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AppSvgIcon(name: iconName, color: color, size: 19),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: selected ? color : colors.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
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

class _FormActionTile extends StatelessWidget {
  const _FormActionTile({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.md,
            vertical: AppSpace.sm,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Row(
            children: [
              AppSvgIcon(name: 'image-add-01', color: colors.primary, size: 22),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: colors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _TaskContentCard extends StatelessWidget {
  const _TaskContentCard({
    required this.titleController,
    required this.descriptionController,
    required this.titleValidator,
  });

  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final FormFieldValidator<String> titleValidator;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.md,
              AppSpace.sm,
              AppSpace.md,
              0,
            ),
            child: TextFormField(
              key: const ValueKey('task-title'),
              controller: titleController,
              keyboardType: TextInputType.text,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              maxLength: 90,
              validator: titleValidator,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: 'Tiêu đề',
                hintStyle: theme.textTheme.titleLarge?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                counterText: '',
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.md,
              0,
              AppSpace.md,
              AppSpace.md,
            ),
            child: TextFormField(
              controller: descriptionController,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 3,
              minLines: 2,
              maxLength: 400,
              style: theme.textTheme.bodyLarge,
              decoration: InputDecoration(
                hintText: 'Ghi chú & URL',
                hintStyle: theme.textTheme.bodyLarge?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                counterText: '',
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttachmentSection extends StatelessWidget {
  const _AttachmentSection({
    required this.attachments,
    required this.onAdd,
    required this.onRemove,
    required this.uploadingPath,
    required this.enabled,
  });

  final List<_PendingAttachment> attachments;
  final VoidCallback onAdd;
  final ValueChanged<_PendingAttachment> onRemove;
  final String? uploadingPath;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      children: [
        if (attachments.isEmpty)
          _FormActionTile(
            title: 'Thêm hình ảnh',
            subtitle: 'Chụp hoặc chọn ảnh',
            onTap: enabled ? onAdd : null,
          )
        else ...[
          for (final attachment in attachments)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.xs),
              child: Container(
                constraints: const BoxConstraints(minHeight: 56),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.sm,
                  vertical: AppSpace.xs,
                ),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: colors.outlineVariant),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          child: _AttachmentPreview(
                            attachment: attachment,
                            color: colors.primary,
                          ),
                        ),
                        const SizedBox(width: AppSpace.sm),
                        Expanded(
                          child: Text(
                            attachment.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: colors.onSurface,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Xóa ảnh',
                          onPressed: enabled ? () => onRemove(attachment) : null,
                          icon: AppSvgIcon(
                            name: 'delete-01',
                            color: colors.error,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                    if (uploadingPath == attachment.path)
                      const Padding(
                        padding: EdgeInsets.only(top: AppSpace.xs),
                        child: LinearProgressIndicator(),
                      ),
                  ],
                ),
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: enabled ? onAdd : null,
              icon: AppSvgIcon(name: 'add-02', color: colors.primary, size: 18),
              label: const Text('Thêm ảnh'),
            ),
          ),
        ],
      ],
    );
  }
}

class _AttachmentPreview extends StatelessWidget {
  const _AttachmentPreview({
    required this.attachment,
    required this.color,
  });

  final _PendingAttachment attachment;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final uploadedAttachment = attachment.uploadedAttachment;
    final fallback = AppSvgIcon(name: 'image-01', color: color, size: 22);
    final image = uploadedAttachment == null
        ? Image.file(
            File(attachment.path),
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => fallback,
          )
        : Image.network(
            uploadedAttachment.url,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => fallback,
          );

    return SizedBox(width: 48, height: 48, child: image);
  }
}

enum _AttachmentSource { camera, gallery, scanDocument }

class _AttachmentSourceSheet extends StatelessWidget {
  const _AttachmentSourceSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(
              'Chọn cách thêm ảnh',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          ListTile(
            leading: AppSvgIcon(
              name: 'camera-01',
              color: Theme.of(context).colorScheme.primary,
            ),
            title: const Text('Chụp ảnh'),
            onTap: () => Navigator.of(context).pop(_AttachmentSource.camera),
          ),
          ListTile(
            leading: AppSvgIcon(
              name: 'image-01',
              color: Theme.of(context).colorScheme.primary,
            ),
            title: const Text('Chọn ảnh'),
            onTap: () => Navigator.of(context).pop(_AttachmentSource.gallery),
          ),
          ListTile(
            leading: AppSvgIcon(
              name: 'document-validation',
              color: Theme.of(context).colorScheme.primary,
            ),
            title: const Text('Quét tài liệu'),
            onTap: () =>
                Navigator.of(context).pop(_AttachmentSource.scanDocument),
          ),
          const SizedBox(height: AppSpace.xs),
        ],
      ),
    );
  }
}

class _PendingAttachment {
  _PendingAttachment({
    required this.name,
    required this.path,
    this.uploadedAttachment,
  });

  factory _PendingAttachment.saved(TaskAttachment attachment) =>
      _PendingAttachment(
        name: attachment.name,
        path: '',
        uploadedAttachment: attachment,
      );

  final String name;
  final String path;
  TaskAttachment? uploadedAttachment;
}

class _FormSectionHeading extends StatelessWidget {
  const _FormSectionHeading({required this.iconName, required this.title});

  final String iconName;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Row(
      children: [
        AppSvgIcon(name: iconName, size: 20, color: colors.primary),
        const SizedBox(width: AppSpace.xs),
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: colors.onSurface,
          ),
        ),
      ],
    );
  }
}

class _DuplicateTaskDialog extends StatelessWidget {
  const _DuplicateTaskDialog({
    required this.conflicts,
    required this.isEditing,
  });

  final List<TaskModel> conflicts;
  final bool isEditing;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: const Text('Thời gian đã có công việc'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Bạn đã có công việc được lên lịch vào thời gian này:'),
          const SizedBox(height: AppSpace.sm),
          for (var index = 0; index < conflicts.length; index++) ...[
            if (index > 0) const SizedBox(height: AppSpace.xs),
            _DuplicateTaskItem(task: conflicts[index]),
          ],
          const SizedBox(height: AppSpace.sm),
          Text(
            isEditing
                ? 'Bạn vẫn muốn lưu thay đổi chứ?'
                : 'Bạn vẫn muốn thêm công việc mới chứ?',
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Quay lại chỉnh sửa'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(isEditing ? 'Vẫn lưu thay đổi' : 'Vẫn thêm công việc'),
        ),
      ],
    );
  }
}

class _DuplicateTaskItem extends StatelessWidget {
  const _DuplicateTaskItem({required this.task});

  final TaskModel task;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final localDate = task.dueDate!;
    final time = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay(hour: localDate.hour, minute: localDate.minute),
    );

    return Container(
      padding: const EdgeInsets.all(AppSpace.sm),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(task.title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpace.xxs),
          Text(
            '${VietnameseDate.numeric(localDate)} · $time',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _CupertinoTimePickerDialog extends StatefulWidget {
  const _CupertinoTimePickerDialog({required this.initialTime});

  final TimeOfDay initialTime;

  @override
  State<_CupertinoTimePickerDialog> createState() =>
      _CupertinoTimePickerDialogState();
}

class _CupertinoTimePickerDialogState
    extends State<_CupertinoTimePickerDialog> {
  late DateTime _selectedTime;

  @override
  void initState() {
    super.initState();
    final now = nowInAppTime();
    _selectedTime = DateTime(
      now.year,
      now.month,
      now.day,
      widget.initialTime.hour,
      widget.initialTime.minute,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final quickTimes = [
      const TimeOfDay(hour: 9, minute: 0),
      const TimeOfDay(hour: 12, minute: 0),
      const TimeOfDay(hour: 18, minute: 0),
    ];

    return Material(
      color: colors.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.lg,
          AppSpace.sm,
          AppSpace.lg,
          AppSpace.xs,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: colors.outlineVariant,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
            const SizedBox(height: AppSpace.md),
            Row(
              children: [
                AppSvgIcon(name: 'clock-01', color: colors.primary, size: 22),
                const SizedBox(width: AppSpace.xs),
                Expanded(
                  child: Text(
                    'Chọn giờ nhắc',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Đóng',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            Text(
              MaterialLocalizations.of(context).formatTimeOfDay(
                TimeOfDay.fromDateTime(_selectedTime),
                alwaysUse24HourFormat: true,
              ),
              style: theme.textTheme.headlineMedium?.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpace.md),
            Row(
              children: [
                for (var index = 0; index < quickTimes.length; index++) ...[
                  if (index > 0) const SizedBox(width: AppSpace.xs),
                  Expanded(
                    child: _QuickTimeButton(
                      time: quickTimes[index],
                      selected:
                          _selectedTime.hour == quickTimes[index].hour &&
                          _selectedTime.minute == quickTimes[index].minute,
                      onPressed: () => setState(() {
                        _selectedTime = DateTime(
                          _selectedTime.year,
                          _selectedTime.month,
                          _selectedTime.day,
                          quickTimes[index].hour,
                          quickTimes[index].minute,
                        );
                      }),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSpace.md),
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest.withValues(alpha: .55),
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: SizedBox(
                height: 180,
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  use24hFormat: true,
                  initialDateTime: _selectedTime,
                  onDateTimeChanged: (value) {
                    setState(() => _selectedTime = value);
                  },
                ),
              ),
            ),
            const SizedBox(height: AppSpace.md),
            SafeArea(
              top: false,
              minimum: EdgeInsets.zero,
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                      child: const Text('Hủy'),
                    ),
                  ),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(
                        TimeOfDay(
                          hour: _selectedTime.hour,
                          minute: _selectedTime.minute,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                      child: const Text('Xác nhận'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickTimeButton extends StatelessWidget {
  const _QuickTimeButton({
    required this.time,
    required this.selected,
    required this.onPressed,
  });

  final TimeOfDay time;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final label = MaterialLocalizations.of(context)
        .formatTimeOfDay(time, alwaysUse24HourFormat: true);

    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(44),
        backgroundColor: selected ? colors.primaryContainer : colors.surface,
        foregroundColor: selected
            ? colors.onPrimaryContainer
            : colors.onSurfaceVariant,
        side: BorderSide(
          color: selected ? colors.primary : colors.outlineVariant,
          width: selected ? 1.5 : 1,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      child: Text(label),
    );
  }
}

class _QuickDateButton extends StatelessWidget {
  const _QuickDateButton({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(44),
        backgroundColor: selected ? colors.primaryContainer : colors.surface,
        foregroundColor: selected
            ? colors.onPrimaryContainer
            : colors.onSurfaceVariant,
        side: BorderSide(
          color: selected ? colors.primary : colors.outlineVariant,
          width: selected ? 1.5 : 1,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      child: Text(label),
    );
  }
}

// Date picker tiếng Việt
class _VietnameseDatePicker extends StatefulWidget {
  const _VietnameseDatePicker({required this.initialDate, required this.today});

  final DateTime initialDate;
  final DateTime today;

  @override
  State<_VietnameseDatePicker> createState() => _VietnameseDatePickerState();
}

class _VietnameseDatePickerState extends State<_VietnameseDatePicker> {
  late DateTime _selectedDate = widget.initialDate;

  late DateTime _visibleMonth = DateTime(
    widget.initialDate.year,
    widget.initialDate.month,
  );

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(_visibleMonth.year, _visibleMonth.month);

    final gridStart = firstDay.subtract(Duration(days: firstDay.weekday - 1));

    final firstAllowed = DateTime(widget.today.year - 1);
    final lastAllowed = DateTime(widget.today.year + 5, 12, 31);

    final colors = Theme.of(context).colorScheme;
    final isToday = _sameDay(_selectedDate, widget.today);
    final tomorrow = DateTime(
      widget.today.year,
      widget.today.month,
      widget.today.day + 1,
    );

    return Material(
      color: colors.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.lg,
          AppSpace.lg,
          AppSpace.lg,
          AppSpace.xs,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: colors.outlineVariant,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
            const SizedBox(height: AppSpace.md),
            Row(
              children: [
                AppSvgIcon(
                  name: 'calendar-01',
                  color: colors.primary,
                  size: 22,
                ),
                const SizedBox(width: AppSpace.xs),
                Expanded(
                  child: Text(
                    'Chọn ngày nhắc',
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  tooltip: 'Đóng',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                VietnameseDate.full(_selectedDate),
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: colors.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: AppSpace.md),
            Row(
              children: [
                Expanded(
                  child: _QuickDateButton(
                    label: 'Hôm nay',
                    selected: isToday,
                    onPressed: () => setState(() {
                      _selectedDate = widget.today;
                      _visibleMonth = DateTime(
                        widget.today.year,
                        widget.today.month,
                      );
                    }),
                  ),
                ),
                const SizedBox(width: AppSpace.sm),
                Expanded(
                  child: _QuickDateButton(
                    label: 'Ngày mai',
                    selected: _sameDay(_selectedDate, tomorrow),
                    onPressed: () => setState(() {
                      _selectedDate = tomorrow;
                      _visibleMonth = DateTime(tomorrow.year, tomorrow.month);
                    }),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.lg),
            Row(
              children: [
                Expanded(
                  child: Text(
                    VietnameseDate.monthYear(_visibleMonth),
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  tooltip: 'Tháng trước',
                  onPressed:
                      firstDay.isAfter(
                        DateTime(firstAllowed.year, firstAllowed.month),
                      )
                      ? () => _changeMonth(-1)
                      : null,
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                IconButton(
                  tooltip: 'Tháng sau',
                  onPressed:
                      DateTime(
                        _visibleMonth.year,
                        _visibleMonth.month + 1,
                      ).isBefore(
                        DateTime(lastAllowed.year, lastAllowed.month + 1),
                      )
                      ? () => _changeMonth(1)
                      : null,
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
            Row(
              children: List.generate(
                7,
                (index) => Expanded(
                  child: Center(
                    child: Text(
                      VietnameseDate.shortWeekday(index),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpace.xs),
            SizedBox(
              height: 288,
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 42,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisExtent: 48,
                ),
                itemBuilder: (context, index) {
                  final day = gridStart.add(Duration(days: index));
                  final allowed =
                      !day.isBefore(firstAllowed) && !day.isAfter(lastAllowed);
                  final selected = _sameDay(day, _selectedDate);
                  final today = _sameDay(day, widget.today);
                  final inMonth = day.month == _visibleMonth.month;

                  return Semantics(
                    button: true,
                    selected: selected,
                    label: VietnameseDate.full(day),
                    child: Center(
                      child: SizedBox.square(
                        dimension: 42,
                        child: TextButton(
                          onPressed: allowed
                              ? () => setState(() => _selectedDate = day)
                              : null,
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            backgroundColor: selected ? colors.primary : null,
                            foregroundColor: selected
                                ? colors.onPrimary
                                : inMonth
                                ? colors.onSurface
                                : colors.onSurfaceVariant.withValues(
                                    alpha: .45,
                                  ),
                            side: today && !selected
                                ? BorderSide(color: colors.primary, width: 1.5)
                                : null,
                            shape: const CircleBorder(),
                          ),
                          child: Text('${day.day}'),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpace.sm),
            SafeArea(
              top: false,
              minimum: EdgeInsets.zero,
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpace.md,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                      child: const Text('Hủy'),
                    ),
                  ),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(_selectedDate),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpace.md,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                      child: const Text('Chọn ngày nhắc'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _changeMonth(int offset) {
    setState(() {
      _visibleMonth = DateTime(
        _visibleMonth.year,
        _visibleMonth.month + offset,
      );
    });
  }

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
