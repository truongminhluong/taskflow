import 'package:flutter/material.dart';

class KeyboardDismissibleScrollBehavior extends StatelessWidget {
  const KeyboardDismissibleScrollBehavior({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollUpdateNotification>(
      onNotification: (_) {
        FocusManager.instance.primaryFocus?.unfocus();
        return false;
      },
      child: child,
    );
  }
}
