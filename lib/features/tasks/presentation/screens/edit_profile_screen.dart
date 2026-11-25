import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../widgets/common/task_flow_background.dart';
import '../widgets/common/app_svg_icon.dart';
import '../widgets/common/dismiss_keyboard_on_tap.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key, required this.name, required this.email});

  final String name;
  final String email;

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  XFile? _selectedAvatar;
  bool _isPickingAvatar = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    final name = value?.trim() ?? '';

    if (name.isEmpty) return 'Vui lòng nhập họ tên.';
    if (name.length > 100) return 'Tên không được vượt quá 100 ký tự.';

    return null;
  }

  Future<void> _pickAvatar() async {
    if (_isPickingAvatar) return;

    setState(() => _isPickingAvatar = true);

    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
        requestFullMetadata: false,
      );

      if (!mounted || image == null) return;
      setState(() => _selectedAvatar = image);
    } on PlatformException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không mở được thư viện ảnh. Vui lòng thử lại.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isPickingAvatar = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await ref
        .read(authProvider.notifier)
        .updateCurrentUser(name: _nameController.text);

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã cập nhật trang cá nhân.')),
      );
    } else {
      final message = ref.read(authProvider).errorMessage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message ?? 'Cập nhật thất bại. Vui lòng thử lại.'),
        ),
      );
    }
  }

  String _avatarInitials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2);

    final initials = parts
        .map((part) => String.fromCharCode(part.runes.first))
        .join()
        .toUpperCase();

    return initials.isEmpty ? 'T' : initials;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return DismissKeyboardOnTap(
      child: TaskFlowBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: const Text('Sửa trang cá nhân'),
            backgroundColor: Colors.transparent,
          ),
          body: SafeArea(
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.all(AppSpace.lg),
              children: [
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Thông tin cá nhân',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSpace.md),

                      Column(
                        children: [
                          ValueListenableBuilder<TextEditingValue>(
                            valueListenable: _nameController,
                            builder: (context, value, _) {
                              final avatar = _selectedAvatar;

                              return CircleAvatar(
                                radius: 48,
                                backgroundColor: colors.primaryContainer,
                                foregroundColor: colors.onPrimaryContainer,
                                backgroundImage: avatar == null
                                    ? null
                                    : FileImage(File(avatar.path)),
                                child: avatar == null
                                    ? Text(
                                        _avatarInitials(value.text),
                                        style: theme.textTheme.headlineSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                            ),
                                      )
                                    : null,
                              );
                            },
                          ),
                          const SizedBox(height: AppSpace.sm),
                          Text(
                            'Ảnh đại diện',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: AppSpace.xs),
                          OutlinedButton.icon(
                            onPressed: _isPickingAvatar ? null : _pickAvatar,
                            icon: _isPickingAvatar
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : AppSvgIcon(
                                    name: 'edit-01',
                                    size: 18,
                                    color: colors.primary,
                                  ),
                            label: Text(
                              _isPickingAvatar
                                  ? 'Đang mở thư viện…'
                                  : 'Thay ảnh',
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: AppSpace.lg),

                      TextFormField(
                        controller: _nameController,
                        validator: _validateName,
                        decoration: InputDecoration(
                          labelText: 'Họ và tên',
                          hintText: 'Nhập họ và tên',
                          prefixIcon: Padding(
                            padding: const EdgeInsets.all(14),
                            child: AppSvgIcon(
                              name: 'user-circle',
                              size: 20,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: AppSpace.md),

                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpace.md,
                          vertical: AppSpace.sm,
                        ),
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Row(
                          children: [
                            AppSvgIcon(
                              name: 'mail-01',
                              size: 20,
                              color: colors.onSurfaceVariant,
                            ),
                            const SizedBox(width: AppSpace.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Email',
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(
                                          color: colors.onSurfaceVariant,
                                        ),
                                  ),
                                  const SizedBox(height: AppSpace.xxs),
                                  Text(
                                    widget.email.trim().isEmpty
                                        ? 'Chưa có email'
                                        : widget.email,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodyLarge,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: AppSpace.xl),

                      FilledButton(
                        onPressed: _saveProfile,
                        child: const Text('Lưu thay đổi'),
                      ),
                    ],
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
