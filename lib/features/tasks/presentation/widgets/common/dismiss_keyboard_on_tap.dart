import 'package:flutter/material.dart';

class DismissKeyboardOnTap extends StatelessWidget {
  const DismissKeyboardOnTap({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TapRegion(
      onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
      child: child,
    );
  }
}
