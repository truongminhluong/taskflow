
import 'package:flutter/material.dart';

class TaskFlowBackground extends StatelessWidget {
  const TaskFlowBackground({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark =
        Theme.of(context).brightness == Brightness.dark;

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: TaskFlowBackgroundPaint(isDark: isDark),
          ),
        ),
        child,
      ],
    );
  }
}

class TaskFlowBackgroundPaint extends StatelessWidget {
  const TaskFlowBackgroundPaint({
    required this.isDark,
    super.key,
  });

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _TaskFlowBackgroundPainter(isDark: isDark),
      child: const SizedBox.expand(),
    );
  }
}

class _TaskFlowBackgroundPainter extends CustomPainter {
  const _TaskFlowBackgroundPainter({
    required this.isDark,
  });

  final bool isDark;

  Color get blue => isDark
      ? const Color(0xFF438AFF)
      : const Color(0xFF5B91ED);

  Color get purple => isDark
      ? const Color(0xFF7865E8)
      : const Color(0xFF9C8BEF);

  Color get lineColor => isDark
      ? const Color(0xFF8CB8FF)
      : const Color(0xFF7099DB);

  double get visibility => isDark ? 1.0 : 0.65;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final w = size.width;
    final h = size.height;

    // 1. Base gradient.
    _drawBackground(canvas, size);

    // 2. Large ambient light sources.
    _drawAmbientLights(canvas, size);

    // 3. Large abstract wave layers.
    _drawWaveLayers(canvas, size);

    // 4. Orbital rings in the top-right.
    _drawOrbitalRings(canvas, size);

    // 5. Multiple flowing contour lines.
    _drawContourLines(canvas, size);

    // 6. Geometric diagonal accents.
    _drawGeometricAccents(canvas, size);

    // 7. Dot matrix decorations.
    _drawDotMatrix(
      canvas,
      Offset(w * 0.76, h * 0.34),
      spacing: 13,
      rows: 6,
      columns: 8,
    );

    _drawDotMatrix(
      canvas,
      Offset(w * 0.08, h * 0.72),
      spacing: 13,
      rows: 5,
      columns: 7,
    );

    // 8. Decorative stars.
    _drawStars(canvas, size);

    // 9. Bottom atmosphere.
    _drawBottomGlow(canvas, size);
  }

  // --------------------------------------------------
  // 1. BACKGROUND
  // --------------------------------------------------

  void _drawBackground(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? const [
          Color(0xFF070D1A),
          Color(0xFF101A30),
          Color(0xFF111B35),
          Color(0xFF090F20),
        ]
            : const [
          Color(0xFFF9FBFF),
          Color(0xFFEFF4FF),
          Color(0xFFF3F5FF),
          Color(0xFFFAFBFF),
        ],
      ).createShader(rect);

    canvas.drawRect(rect, paint);

    // Subtle central dark layer.
    final centerPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.transparent,
          (isDark ? Colors.black : const Color(0xFFDCE6F9))
              .withValues(alpha: isDark ? 0.0 : 0.12),
        ],
      ).createShader(
        Rect.fromLTWH(
          size.width * 0.1,
          size.height * 0.2,
          size.width * 0.8,
          size.height * 0.7,
        ),
      );

    canvas.drawRect(rect, centerPaint);
  }

  // --------------------------------------------------
  // 2. AMBIENT LIGHTS
  // --------------------------------------------------

  void _drawAmbientLights(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    _glow(
      canvas,
      Offset(w * 0.95, h * 0.02),
      w * 0.78,
      blue,
      0.30,
    );

    _glow(
      canvas,
      Offset(w * 1.08, h * 0.34),
      w * 0.55,
      purple,
      0.18,
    );

    _glow(
      canvas,
      Offset(-w * 0.12, h * 0.88),
      w * 0.70,
      blue,
      0.22,
    );

    _glow(
      canvas,
      Offset(w * 1.04, h * 0.94),
      w * 0.62,
      purple,
      0.20,
    );
  }

  void _glow(
      Canvas canvas,
      Offset center,
      double radius,
      Color color,
      double opacity,
      ) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: opacity * visibility),
          color.withValues(alpha: opacity * 0.45 * visibility),
          Colors.transparent,
        ],
        stops: const [0.0, 0.48, 1.0],
      ).createShader(
        Rect.fromCircle(
          center: center,
          radius: radius,
        ),
      );

    canvas.drawCircle(center, radius, paint);
  }

  // --------------------------------------------------
  // 3. ABSTRACT WAVE LAYERS
  // --------------------------------------------------

  void _drawWaveLayers(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Top-right large wave.
    final topWave = Path()
      ..moveTo(w * 0.48, -h * 0.02)
      ..cubicTo(
        w * 0.32, h * 0.12,
        w * 0.48, h * 0.24,
        w * 0.75, h * 0.19,
      )
      ..cubicTo(
        w * 0.91, h * 0.16,
        w * 0.96, h * 0.06,
        w * 1.08, h * 0.00,
      )
      ..lineTo(w * 1.08, h * 0.28)
      ..cubicTo(
        w * 0.86, h * 0.37,
        w * 0.68, h * 0.30,
        w * 0.51, h * 0.34,
      )
      ..cubicTo(
        w * 0.30, h * 0.36,
        w * 0.25, h * 0.17,
        w * 0.48, -h * 0.02,
      )
      ..close();

    _drawFilledWave(
      canvas,
      topWave,
      [
        blue.withValues(alpha: 0.20 * visibility),
        const Color(0xFF536FD0)
            .withValues(alpha: 0.10 * visibility),
        purple.withValues(alpha: 0.03 * visibility),
      ],
    );

    // Right-side flowing wave.
    final rightWave = Path()
      ..moveTo(w * 1.05, h * 0.24)
      ..cubicTo(
        w * 0.79, h * 0.28,
        w * 0.72, h * 0.43,
        w * 0.89, h * 0.52,
      )
      ..cubicTo(
        w * 0.98, h * 0.58,
        w * 1.04, h * 0.57,
        w * 1.08, h * 0.61,
      )
      ..lineTo(w * 1.08, h * 0.22)
      ..close();

    _drawFilledWave(
      canvas,
      rightWave,
      [
        purple.withValues(alpha: 0.16 * visibility),
        blue.withValues(alpha: 0.08 * visibility),
        Colors.transparent,
      ],
    );

    // Bottom-left large wave.
    final bottomWave = Path()
      ..moveTo(-w * 0.12, h * 0.73)
      ..cubicTo(
        w * 0.13, h * 0.67,
        w * 0.22, h * 0.82,
        w * 0.37, h * 0.88,
      )
      ..cubicTo(
        w * 0.52, h * 0.94,
        w * 0.57, h * 0.99,
        w * 0.60, h * 1.05,
      )
      ..lineTo(-w * 0.12, h * 1.05)
      ..close();

    _drawFilledWave(
      canvas,
      bottomWave,
      [
        blue.withValues(alpha: 0.16 * visibility),
        purple.withValues(alpha: 0.08 * visibility),
        Colors.transparent,
      ],
    );

    // Bottom-right wave.
    final bottomRight = Path()
      ..moveTo(w * 0.75, h * 1.04)
      ..cubicTo(
        w * 0.77, h * 0.88,
        w * 0.91, h * 0.82,
        w * 1.08, h * 0.70,
      )
      ..lineTo(w * 1.08, h * 1.04)
      ..close();

    _drawFilledWave(
      canvas,
      bottomRight,
      [
        purple.withValues(alpha: 0.17 * visibility),
        blue.withValues(alpha: 0.08 * visibility),
        Colors.transparent,
      ],
    );
  }

  void _drawFilledWave(
      Canvas canvas,
      Path path,
      List<Color> colors,
      ) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: colors,
      ).createShader(path.getBounds());

    canvas.drawPath(path, paint);

    // Fine edge highlight.
    final edgePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = lineColor.withValues(
        alpha: 0.13 * visibility,
      );

    canvas.drawPath(path, edgePaint);
  }

  // --------------------------------------------------
  // 4. ORBITAL RINGS
  // --------------------------------------------------

  void _drawOrbitalRings(Canvas canvas, Size size) {
    final center = Offset(
      size.width * 0.88,
      size.height * 0.10,
    );

    final radii = [
      size.width * 0.24,
      size.width * 0.34,
      size.width * 0.44,
      size.width * 0.55,
    ];

    for (var i = 0; i < radii.length; i++) {
      final radius = radii[i];

      final rect = Rect.fromCircle(
        center: center,
        radius: radius,
      );

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = i == 0 ? 1.3 : 0.8
        ..color = lineColor.withValues(
          alpha: (0.20 - i * 0.035) * visibility,
        );

      canvas.drawArc(
        rect,
        0.25 + i * 0.12,
        2.25 + i * 0.10,
        false,
        paint,
      );
    }

    // Small orbital nodes.
    for (final angle in [0.75, 2.3, 3.8]) {
      final radius = size.width * 0.34;

      final point = Offset(
        center.dx + radius * 0.72 * _cos(angle),
        center.dy + radius * 0.72 * _sin(angle),
      );

      canvas.drawCircle(
        point,
        2.2,
        Paint()..color = blue.withValues(alpha: 0.75 * visibility),
      );

      canvas.drawCircle(
        point,
        6,
        Paint()
          ..color = blue.withValues(alpha: 0.15 * visibility)
          ..maskFilter = const MaskFilter.blur(
            BlurStyle.normal,
            5,
          ),
      );
    }
  }

  double _cos(double value) {
    // Angles used here are fixed, so convert degrees.
    return switch (value) {
      0.75 => 0.731,
      2.3 => -0.666,
      3.8 => -0.791,
      _ => 1.0,
    };
  }

  double _sin(double value) {
    return switch (value) {
      0.75 => 0.682,
      2.3 => 0.746,
      3.8 => -0.612,
      _ => 0.0,
    };
  }

  // --------------------------------------------------
  // 5. CONTOUR LINES
  // --------------------------------------------------

  void _drawContourLines(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Top contour lines.
    for (var i = 0; i < 7; i++) {
      final offset = i * 0.025;

      final path = Path()
        ..moveTo(w * (0.42 + offset), -h * 0.01)
        ..cubicTo(
          w * (0.30 + offset),
          h * 0.11,
          w * (0.52 + offset),
          h * 0.22,
          w * (0.91 + offset * 0.5),
          h * 0.17,
        );

      _drawContour(canvas, path, 0.22 - i * 0.018);
    }

    // Right contour lines.
    for (var i = 0; i < 6; i++) {
      final offset = i * 0.035;

      final path = Path()
        ..moveTo(w * (0.98 + offset), h * (0.26 + offset))
        ..cubicTo(
          w * (0.76 + offset),
          h * (0.35 + offset),
          w * (0.79 + offset),
          h * (0.47 + offset),
          w * (1.08 + offset),
          h * (0.53 + offset),
        );

      _drawContour(canvas, path, 0.17 - i * 0.015);
    }

    // Bottom-left contour lines.
    for (var i = 0; i < 7; i++) {
      final offset = i * 0.025;

      final path = Path()
        ..moveTo(-w * 0.08, h * (0.76 + offset))
        ..cubicTo(
          w * 0.12,
          h * (0.67 + offset),
          w * (0.27 + offset),
          h * (0.86 + offset),
          w * 0.53,
          h * (0.91 + offset),
        );

      _drawContour(canvas, path, 0.18 - i * 0.016);
    }

    // Bottom-right contour lines.
    for (var i = 0; i < 5; i++) {
      final offset = i * 0.025;

      final path = Path()
        ..moveTo(w * (0.71 + offset), h * 1.04)
        ..cubicTo(
          w * (0.78 + offset),
          h * (0.88 + offset),
          w * 0.96,
          h * (0.86 + offset),
          w * 1.10,
          h * (0.73 + offset),
        );

      _drawContour(canvas, path, 0.18 - i * 0.02);
    }
  }

  void _drawContour(
      Canvas canvas,
      Path path,
      double opacity,
      ) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.85
      ..strokeCap = StrokeCap.round
      ..color = lineColor.withValues(
        alpha: opacity * visibility,
      );

    canvas.drawPath(path, paint);
  }

  // --------------------------------------------------
  // 6. GEOMETRIC ACCENTS
  // --------------------------------------------------

  void _drawGeometricAccents(
      Canvas canvas,
      Size size,
      ) {
    final w = size.width;
    final h = size.height;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = lineColor.withValues(
        alpha: 0.18 * visibility,
      );

    // Diagonal lines, upper right.
    for (var i = 0; i < 5; i++) {
      final x = w * (0.72 + i * 0.045);

      canvas.drawLine(
        Offset(x, 0),
        Offset(x - w * 0.15, h * 0.13),
        paint,
      );
    }

    // Small geometric diamond.
    _drawDiamond(
      canvas,
      Offset(w * 0.12, h * 0.30),
      5,
    );

    _drawDiamond(
      canvas,
      Offset(w * 0.88, h * 0.61),
      4,
    );

    _drawDiamond(
      canvas,
      Offset(w * 0.28, h * 0.95),
      5,
    );

    // Short decorative lines.
    canvas.drawLine(
      Offset(w * 0.06, h * 0.38),
      Offset(w * 0.16, h * 0.38),
      paint,
    );

    canvas.drawLine(
      Offset(w * 0.06, h * 0.395),
      Offset(w * 0.12, h * 0.395),
      paint,
    );
  }

  void _drawDiamond(
      Canvas canvas,
      Offset center,
      double radius,
      ) {
    final path = Path()
      ..moveTo(center.dx, center.dy - radius)
      ..lineTo(center.dx + radius, center.dy)
      ..lineTo(center.dx, center.dy + radius)
      ..lineTo(center.dx - radius, center.dy)
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..color = blue.withValues(alpha: 0.55 * visibility),
    );
  }

  // --------------------------------------------------
  // 7. DOT MATRIX
  // --------------------------------------------------

  void _drawDotMatrix(
      Canvas canvas,
      Offset origin, {
        required double spacing,
        required int rows,
        required int columns,
      }) {
    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < columns; col++) {
        final distance = row + col;
        final opacity = (0.25 - distance * 0.018)
            .clamp(0.06, 0.25)
            .toDouble();

        final point = Offset(
          origin.dx + col * spacing,
          origin.dy + row * spacing,
        );

        canvas.drawCircle(
          point,
          1.15,
          Paint()
            ..color = lineColor.withValues(
              alpha: opacity * visibility,
            ),
        );
      }
    }
  }

  // --------------------------------------------------
  // 8. DECORATIVE STARS
  // --------------------------------------------------

  void _drawStars(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    _drawStar(canvas, Offset(w * 0.82, h * 0.29), 6);
    _drawStar(canvas, Offset(w * 0.94, h * 0.38), 4);
    _drawStar(canvas, Offset(w * 0.13, h * 0.60), 5);
    _drawStar(canvas, Offset(w * 0.68, h * 0.70), 4);
    _drawStar(canvas, Offset(w * 0.35, h * 0.12), 3);
  }

  void _drawStar(
      Canvas canvas,
      Offset center,
      double radius,
      ) {
    final path = Path()
      ..moveTo(center.dx, center.dy - radius)
      ..quadraticBezierTo(
        center.dx + radius * 0.20,
        center.dy - radius * 0.20,
        center.dx + radius,
        center.dy,
      )
      ..quadraticBezierTo(
        center.dx + radius * 0.20,
        center.dy + radius * 0.20,
        center.dx,
        center.dy + radius,
      )
      ..quadraticBezierTo(
        center.dx - radius * 0.20,
        center.dy + radius * 0.20,
        center.dx - radius,
        center.dy,
      )
      ..quadraticBezierTo(
        center.dx - radius * 0.20,
        center.dy - radius * 0.20,
        center.dx,
        center.dy - radius,
      )
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..color = blue.withValues(alpha: 0.75 * visibility),
    );
  }

  // --------------------------------------------------
  // 9. BOTTOM ATMOSPHERE
  // --------------------------------------------------

  void _drawBottomGlow(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      0,
      size.height * 0.65,
      size.width,
      size.height * 0.35,
    );

    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isDark
            ? [
          Colors.transparent,
          const Color(0xFF162B54).withValues(alpha: 0.12),
          const Color(0xFF283F7B).withValues(alpha: 0.18),
        ]
            : [
          Colors.transparent,
          const Color(0xFFE4ECFF).withValues(alpha: 0.12),
          const Color(0xFFD5E2FF).withValues(alpha: 0.25),
        ],
      ).createShader(rect);

    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(
      covariant _TaskFlowBackgroundPainter oldDelegate,
      ) {
    return oldDelegate.isDark != isDark;
  }
}
