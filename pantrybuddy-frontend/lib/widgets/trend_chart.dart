import 'package:flutter/material.dart';
import '../models/insights_data.dart';

/// User Story 5.3's trend chart — three lines (consumed/wasted/stored)
/// over the selected period's days. Deliberately dependency-free (plain
/// CustomPainter) rather than pulling in a charting package.
class TrendChart extends StatelessWidget {
  const TrendChart({super.key, required this.points, this.height = 180});
  final List<TrendPoint> points;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return SizedBox(height: height, child: const Center(child: Text('No data yet')));
    }
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(painter: _TrendPainter(points)),
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter(this.points);
  final List<TrendPoint> points;

  static const _consumedColor = Color(0xFF2E7D4F);
  static const _wastedColor = Color(0xFFD32F2F);

  @override
  void paint(Canvas canvas, Size size) {
    const leftPad = 28.0;
    const bottomPad = 20.0;
    final chartWidth = size.width - leftPad;
    final chartHeight = size.height - bottomPad;

    final maxVal = points
        .expand((p) => [p.consumed, p.wasted])
        .fold<int>(1, (m, v) => v > m ? v : m);

    final gridPaint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 1;
    final labelStyle = TextStyle(color: Colors.grey.shade600, fontSize: 9);

    // Horizontal gridlines + y-axis labels (0, mid, max).
    for (final fraction in [0.0, 0.5, 1.0]) {
      final y = chartHeight - (chartHeight * fraction);
      canvas.drawLine(Offset(leftPad, y), Offset(size.width, y), gridPaint);
      final value = (maxVal * fraction).round();
      final tp = TextPainter(
        text: TextSpan(text: '$value', style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(leftPad - tp.width - 4, y - tp.height / 2));
    }

    double xFor(int i) => points.length == 1
        ? leftPad + chartWidth / 2
        : leftPad + (chartWidth * i / (points.length - 1));
    double yFor(int value) => chartHeight - (chartHeight * value / maxVal);

    void drawLine(List<int> values, Color color) {
      final paint = Paint()
        ..color = color
        ..strokeWidth = 2.2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      final path = Path();
      for (var i = 0; i < values.length; i++) {
        final point = Offset(xFor(i), yFor(values[i]));
        if (i == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      canvas.drawPath(path, paint);
      final dotPaint = Paint()..color = color;
      for (var i = 0; i < values.length; i++) {
        canvas.drawCircle(Offset(xFor(i), yFor(values[i])), 2.8, dotPaint);
      }
    }

    drawLine(points.map((p) => p.consumed).toList(), _consumedColor);
    drawLine(points.map((p) => p.wasted).toList(), _wastedColor);

    // X-axis day labels — thin out if there are many points (monthly view)
    // so labels don't overlap.
    const weekdayShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final step = (points.length / 7).ceil().clamp(1, points.length);
    for (var i = 0; i < points.length; i += step) {
      final date = points[i].date;
      final label = points.length <= 10 ? weekdayShort[date.weekday - 1] : '${date.day}';
      final tp = TextPainter(
        text: TextSpan(text: label, style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(xFor(i) - tp.width / 2, chartHeight + 4));
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) => oldDelegate.points != points;
}
