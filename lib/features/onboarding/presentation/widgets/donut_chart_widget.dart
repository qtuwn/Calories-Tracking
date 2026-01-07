import 'dart:math' as math;
import 'package:flutter/material.dart';

// Small epsilon to prevent seams between adjacent arcs
const double _arcEpsilon = 0.001; // radians

class DonutChartWidget extends StatelessWidget {
  final double proteinPercent;
  final double carbPercent;
  final double fatPercent;
  final double? size;

  const DonutChartWidget({
    super.key,
    required this.proteinPercent,
    required this.carbPercent,
    required this.fatPercent,
    this.size,
  });

  @override
  Widget build(BuildContext context) {
    if (size != null) {
      // Legacy fixed size support
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

    // Responsive sizing - fill available space
    return LayoutBuilder(
      builder: (context, constraints) {
        final chartSize = constraints.biggest.shortestSide.clamp(120.0, 300.0);
        return SizedBox(
          width: chartSize,
          height: chartSize,
          child: CustomPaint(
            painter: _DonutChartPainter(
              proteinPercent: proteinPercent,
              carbPercent: carbPercent,
              fatPercent: fatPercent,
            ),
          ),
        );
      },
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
    
    // Use stroke width to create donut hole effect (matches previous ~0.6 radius inner hole)
    final strokeWidth = radius * 0.40;
    
    // Define rect centered on the donut ring (radius adjusted for stroke width)
    final rect = Rect.fromCircle(
      center: center,
      radius: radius - strokeWidth / 2,
    );

    // Colors for each macro
    const proteinColor = Color(0xFF4CAF50); // Green
    const carbColor = Color(0xFF2196F3); // Blue
    const fatColor = Color(0xFFFF9800); // Orange

    // Guard against non-finite or invalid values
    final safeProtein = proteinPercent.isFinite && proteinPercent > 0
        ? proteinPercent.clamp(0.0, 100.0)
        : 0.0;
    final safeCarb = carbPercent.isFinite && carbPercent > 0
        ? carbPercent.clamp(0.0, 100.0)
        : 0.0;
    final safeFat = fatPercent.isFinite && fatPercent > 0
        ? fatPercent.clamp(0.0, 100.0)
        : 0.0;

    // Compute sweeps in radians using tau (2π)
    const tau = 2 * math.pi;
    final proteinSweep = (safeProtein / 100.0) * tau;
    final carbSweep = (safeCarb / 100.0) * tau;
    // Fat sweep is the remainder to ensure total sweep equals tau exactly
    final fatSweep = (tau - proteinSweep - carbSweep).clamp(0.0, tau);

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
      final effectiveSweep = (proteinSweep - _arcEpsilon).clamp(0.0, tau);
      _drawStrokeArc(
        canvas,
        rect,
        startAngle,
        effectiveSweep,
        proteinColor,
        strokeWidth,
      );
      startAngle += proteinSweep; // No epsilon added to startAngle
    }

    // Draw Carb segment
    if (safeCarb > 0 && carbSweep > _arcEpsilon) {
      final effectiveSweep = (carbSweep - _arcEpsilon).clamp(0.0, tau);
      _drawStrokeArc(
        canvas,
        rect,
        startAngle,
        effectiveSweep,
        carbColor,
        strokeWidth,
      );
      startAngle += carbSweep; // No epsilon added to startAngle
    }

    // Draw Fat segment
    if (safeFat > 0 && fatSweep > _arcEpsilon) {
      final effectiveSweep = (fatSweep - _arcEpsilon).clamp(0.0, tau);
      _drawStrokeArc(
        canvas,
        rect,
        startAngle,
        effectiveSweep,
        fatColor,
        strokeWidth,
      );
    }
  }

  /// Draw a donut segment using stroke-based rendering
  /// 
  /// This approach prevents tearing/seam artifacts by using stroke instead of filled paths.
  void _drawStrokeArc(
    Canvas canvas,
    Rect rect,
    double startAngle,
    double sweepAngle,
    Color color,
    double strokeWidth,
  ) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt // Preferred to avoid seams
      ..isAntiAlias = true;

    canvas.drawArc(
      rect,
      startAngle,
      sweepAngle,
      false, // useCenter = false for arc, not pie slice
      paint,
    );
  }

  @override
  bool shouldRepaint(_DonutChartPainter oldDelegate) {
    return oldDelegate.proteinPercent != proteinPercent ||
        oldDelegate.carbPercent != carbPercent ||
        oldDelegate.fatPercent != fatPercent;
  }
}
