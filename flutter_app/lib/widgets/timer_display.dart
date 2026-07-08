import 'dart:math' show pi, cos, sin;
import 'package:flutter/material.dart';

/// ============================================================
/// TimerDisplay: 倒计时圆环组件
/// 使用 CustomPainter 绘制环形进度, 中心显示 MM:SS
/// 颜色由调用方传入 (green=专注, blue=休息, orange=训练, red=组间休息)
/// ============================================================

class TimerDisplay extends StatelessWidget {
  final int totalSeconds;
  final int remainingSeconds;
  final Color color;
  final double size;
  final double strokeWidth;

  const TimerDisplay({
    super.key,
    required this.totalSeconds,
    required this.remainingSeconds,
    this.color = Colors.green,
    this.size = 200,
    this.strokeWidth = 12,
  });

  /// 格式化秒为 MM:SS
  String get _formattedTime {
    final mins = (remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final secs = (remainingSeconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  /// 进度比例 (0.0 ~ 1.0)
  double get _progress {
    if (totalSeconds <= 0) return 0.0;
    final elapsed = totalSeconds - remainingSeconds;
    return (elapsed / totalSeconds).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 圆环
          CustomPaint(
            size: Size(size, size),
            painter: _TimerRingPainter(
              progress: _progress,
              color: color,
              strokeWidth: strokeWidth,
              trackColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
          // 中心文字
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _formattedTime,
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w300,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: color,
                ),
              ),
              if (totalSeconds > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '/ ${totalSeconds ~/ 60}:${(totalSeconds % 60).toString().padLeft(2, '0')}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// ============================================================
/// _TimerRingPainter: 环形进度绘制器
/// ============================================================

class _TimerRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;
  final Color trackColor;

  _TimerRingPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // 背景轨道
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    // 进度弧 (从顶部开始, 顺时针)
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    const startAngle = -pi / 2; // 12点钟方向
    final sweepAngle = 2 * pi * progress;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      progressPaint,
    );

    // 进度终点小圆点 (高亮)
    if (progress > 0.001 && progress < 0.999) {
      final dotAngle = startAngle + sweepAngle;
      final dotCenter = Offset(
        center.dx + radius * cos(dotAngle),
        center.dy + radius * sin(dotAngle),
      );
      final dotPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      canvas.drawCircle(dotCenter, strokeWidth / 2, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TimerRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
