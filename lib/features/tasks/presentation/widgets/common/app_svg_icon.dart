import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Renders a bundled Hugeicons asset using the current theme color.
class AppSvgIcon extends StatelessWidget {
  const AppSvgIcon({
    required this.name,
    required this.color,
    this.size = 24,
    this.semanticsLabel,
    super.key,
  });

  final String name;
  final Color color;
  final double size;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/icons/$name.svg',
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      excludeFromSemantics: semanticsLabel == null,
      semanticsLabel: semanticsLabel,
    );
  }
}
