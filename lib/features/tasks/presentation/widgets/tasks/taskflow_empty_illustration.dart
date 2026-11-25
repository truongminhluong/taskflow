import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Empty-state illustration for TaskFlow's Home screen.
class TaskFlowEmptyIllustration extends StatelessWidget {
  const TaskFlowEmptyIllustration({
    super.key,
    this.width = 360,
    this.height = 310,
  });

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: height,
    child: SvgPicture.asset(
      'assets/images/taskflow_empty_illustration.svg',
      fit: BoxFit.contain,
      semanticsLabel: 'Minh hoạ bảng công việc, cây xanh và máy bay giấy',
    ),
  );
}
