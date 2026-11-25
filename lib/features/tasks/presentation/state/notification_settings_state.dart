class NotificationSettingsState {
  const NotificationSettingsState({
    this.isLoading = false,
    this.isUpdating = false,
    this.enabled = false,
    this.permissionGranted = false,
    this.badgePermissionGranted = true,
    this.requiresSettingsHelp = false,
    this.errorMessage,
  });

  final bool isLoading;
  final bool isUpdating;
  final bool enabled;
  final bool permissionGranted;
  final bool badgePermissionGranted;
  final bool requiresSettingsHelp;
  final String? errorMessage;

  NotificationSettingsState copyWith({
    bool? isLoading,
    bool? isUpdating,
    bool? enabled,
    bool? permissionGranted,
    bool? badgePermissionGranted,
    bool? requiresSettingsHelp,
    String? errorMessage,
    bool clearError = false,
  }) {
    return NotificationSettingsState(
      isLoading: isLoading ?? this.isLoading,
      isUpdating: isUpdating ?? this.isUpdating,
      enabled: enabled ?? this.enabled,
      permissionGranted: permissionGranted ?? this.permissionGranted,
      badgePermissionGranted:
          badgePermissionGranted ?? this.badgePermissionGranted,
      requiresSettingsHelp: requiresSettingsHelp ?? this.requiresSettingsHelp,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}
