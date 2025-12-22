import 'dart:math' as math;
import 'package:flutter/material.dart';

// Small epsilon to prevent seams between adjacent arcs
const double _arcEpsilon = 0.001; // radians

class DonutChartWidget extends StatelessWidget {
  final double proteinPercent;
  final double carbPercent;
  final double fatPercent;
  final double size;

  const DonutChartWidget({
    super.key,
    required this.proteinPercent,
    required this.carbPercent,
    required this.fatPercent,
    this.size = 200,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _DonutChartPainter(
          proteinPercent: proteinPercent,
          carbPercent: carbPercent,
          fatPercent: fatPercent,
        ),
      ),
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  final double proteinPercent;
  final double carbPercent;
  final double fatPercent;

  _DonutChartPainter({
    required this.proteinPercent,
    required this.carbPercent,
    required this.fatPercent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final innerRadius = radius * 0.6; // Donut hole

    // Colors for each macro
    const proteinColor = Color(0xFF4CAF50); // Green
    const carbColor = Color(0xFF2196F3); // Blue
    const fatColor = Color(0xFFFF9800); // Orange

    // Guard against non-finite or invalid values
    final safeProtein = proteinPercent.isFinite && proteinPercent > 0
        ? proteinPercent
        : 0.0;
    final safeCarb = carbPercent.isFinite && carbPercent > 0
        ? carbPercent
        : 0.0;
    final safeFat = fatPercent.isFinite && fatPercent > 0
        ? fatPercent
        : 0.0;

    // Compute sweep angles using percent/100 * 2π (radians directly)
    // This avoids precision issues from degree-to-radian conversion
    final proteinSweep = (safeProtein / 100.0) * (2 * math.pi);
    final carbSweep = (safeCarb / 100.0) * (2 * math.pi);
    final fatSweep = (safeFat / 100.0) * (2 * math.pi);

    // Debug assertion to ensure macro total is ~100% in debug mode
    assert(() {
      final total = proteinPercent + carbPercent + fatPercent;
      if ((total - 100.0).abs() > 1.0) {
        debugPrint(
          '⚠️ DonutChart: Macro total is ${total.toStringAsFixed(1)}% (expected ~100%)',
        );
      }
      return true;
    }());

    // Start from top (-π/2 radians = -90 degrees)
    double startAngle = -math.pi / 2;

    // Draw Protein segment
    if (safeProtein > 0 && proteinSweep > _arcEpsilon) {
      _drawArc(
        canvas,
        center,
        radius,
        innerRadius,
        startAngle,
        proteinSweep,
        proteinColor,
      );
      // Add small epsilon to prevent seams between adjacent arcs
      startAngle += proteinSweep + _arcEpsilon;
    }

    // Draw Carb segment
    if (safeCarb > 0 && carbSweep > _arcEpsilon) {
      _drawArc(
        canvas,
        center,
        radius,
        innerRadius,
        startAngle,
        carbSweep,
        carbColor,
      );
      // Add small epsilon to prevent seams between adjacent arcs
      startAngle += carbSweep + _arcEpsilon;
    }

    // Draw Fat segment
    if (safeFat > 0 && fatSweep > _arcEpsilon) {
      _drawArc(
        canvas,
        center,
        radius,
        innerRadius,
        startAngle,
        fatSweep,
        fatColor,
      );
    }
  }

  void _drawArc(
    Canvas canvas,
    Offset center,
    double outerRadius,
    double innerRadius,
    double startAngle,
    double sweepAngle,
    Color color,
  ) {
    // Use anti-aliasing for smooth edges
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final path = Path();

    // Outer arc
    path.addArc(
      Rect.fromCircle(center: center, radius: outerRadius),
      startAngle,
      sweepAngle,
    );

    // Line to inner arc
    final endAngle = startAngle + sweepAngle;
    final endX = center.dx + innerRadius * math.cos(endAngle);
    final endY = center.dy + innerRadius * math.sin(endAngle);
    path.lineTo(endX, endY);

    // Inner arc (reverse direction)
    path.addArc(
      Rect.fromCircle(center: center, radius: innerRadius),
      endAngle,
      -sweepAngle,
    );

    // Close path
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_DonutChartPainter oldDelegate) {
    return oldDelegate.proteinPercent != proteinPercent ||
        oldDelegate.carbPercent != carbPercent ||
        oldDelegate.fatPercent != fatPercent;
  }
}
