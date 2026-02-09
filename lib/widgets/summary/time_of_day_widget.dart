import 'package:flutter/material.dart';
import '../../models/chat_analytics.dart';
import '../../l10n/app_localizations.dart';

/// Time of Day chart widget showing message activity across 24 hours
class TimeOfDayWidget extends StatefulWidget {
  final ChatAnalytics analytics;
  final List<String> tabs;
  final Color headingColor;
  final Color subtleText;
  final Color primary;
  final bool isDark;
  final Color cardColor;

  const TimeOfDayWidget({
    super.key,
    required this.analytics,
    required this.tabs,
    required this.headingColor,
    required this.subtleText,
    required this.primary,
    required this.isDark,
    required this.cardColor,
  });

  @override
  State<TimeOfDayWidget> createState() => _TimeOfDayWidgetState();
}

class _TimeOfDayWidgetState extends State<TimeOfDayWidget> {
  int _selectedTab = 0;
  double? _touchX;
  int? _selectedHour;

  Map<int, int> _getHourlyData() {
    if (_selectedTab == 0) {
      return widget.analytics.hourlyActivityMap;
    } else {
      final personName = widget.tabs[_selectedTab];
      return widget.analytics.personStats[personName]?.hourlyActivityMap ?? {};
    }
  }

  void _handleDrag(double x, double chartWidth) {
    final hourFraction = x / chartWidth;
    final hour = (hourFraction * 23).round().clamp(0, 23);
    setState(() {
      _touchX = x.clamp(0, chartWidth);
      _selectedHour = hour;
    });
  }

  void _endDrag() {
    setState(() {
      _touchX = null;
      _selectedHour = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hourlyData = _getHourlyData();
    final maxCount = hourlyData.values.isEmpty 
        ? 1 
        : hourlyData.values.reduce((a, b) => a > b ? a : b);
    final values = List.generate(24, (h) => (hourlyData[h] ?? 0).toDouble());
    
    int peakHour = 0;
    int peakCount = 0;
    for (int h = 0; h < 24; h++) {
      if ((hourlyData[h] ?? 0) > peakCount) {
        peakCount = hourlyData[h] ?? 0;
        peakHour = h;
      }
    }
    
    String formatHour(int h) {
      if (h == 0) return '12AM';
      if (h < 12) return '${h}AM';
      if (h == 12) return '12PM';
      return '${h - 12}PM';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tab chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(widget.tabs.length, (i) {
              final isSelected = _selectedTab == i;
              return Padding(
                padding: EdgeInsets.only(right: i < widget.tabs.length - 1 ? 8 : 0),
                child: ChoiceChip(
                  label: Text(
                    widget.tabs[i],
                    style: TextStyle(
                      fontSize: 12,
                      color: isSelected ? Colors.white : widget.subtleText,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: widget.primary,
                  backgroundColor: widget.isDark ? const Color(0xFF2D2D2D) : const Color(0xFFF0F0F0),
                  onSelected: (_) => setState(() => _selectedTab = i),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 16),
        // Peak time indicator
        Row(
          children: [
            Icon(
              _selectedHour != null ? Icons.touch_app_rounded : Icons.trending_up_rounded, 
              size: 16, 
              color: widget.primary,
            ),
            const SizedBox(width: 6),
            Text(
              _selectedHour != null 
                  ? '${formatHour(_selectedHour!)} — ${hourlyData[_selectedHour] ?? 0} ${AppLocalizations.of(context)!.translate('messages')}'
                  : (peakCount > 0 ? '${AppLocalizations.of(context)!.translate('peak_time')}: ${formatHour(peakHour)} ($peakCount ${AppLocalizations.of(context)!.translate('messages')})' : AppLocalizations.of(context)!.translate('no_activity')),
              style: TextStyle(
                fontSize: 13, 
                color: _selectedHour != null ? widget.headingColor : widget.subtleText,
                fontWeight: _selectedHour != null ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        // Chart
        LayoutBuilder(
          builder: (context, constraints) {
            final chartWidth = constraints.maxWidth;
            return GestureDetector(
              onPanStart: (d) => _handleDrag(d.localPosition.dx, chartWidth),
              onPanUpdate: (d) => _handleDrag(d.localPosition.dx, chartWidth),
              onPanEnd: (_) => _endDrag(),
              onTapUp: (d) {
                _handleDrag(d.localPosition.dx, chartWidth);
                Future.delayed(const Duration(seconds: 2), () {
                  if (mounted) _endDrag();
                });
              },
              child: SizedBox(
                height: 160,
                child: CustomPaint(
                  size: Size(chartWidth, 160),
                  painter: _TimeOfDayChartPainter(
                    values: values,
                    maxValue: maxCount.toDouble(),
                    lineColor: widget.primary,
                    fillColor: widget.primary.withOpacity(0.3),
                    isDark: widget.isDark,
                    subtleText: widget.subtleText,
                    touchX: _touchX,
                    selectedHour: _selectedHour,
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        // Hour labels
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('00:00', style: TextStyle(fontSize: 11, color: widget.subtleText)),
            Text('06:00', style: TextStyle(fontSize: 11, color: widget.subtleText)),
            Text('12:00', style: TextStyle(fontSize: 11, color: widget.subtleText)),
            Text('18:00', style: TextStyle(fontSize: 11, color: widget.subtleText)),
            Text('24:00', style: TextStyle(fontSize: 11, color: widget.subtleText)),
          ],
        ),
      ],
    );
  }
}

class _TimeOfDayChartPainter extends CustomPainter {
  final List<double> values;
  final double maxValue;
  final Color lineColor;
  final Color fillColor;
  final bool isDark;
  final Color subtleText;
  final double? touchX;
  final int? selectedHour;

  _TimeOfDayChartPainter({
    required this.values,
    required this.maxValue,
    required this.lineColor,
    required this.fillColor,
    required this.isDark,
    required this.subtleText,
    this.touchX,
    this.selectedHour,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2 || maxValue == 0) return;

    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [fillColor, fillColor.withOpacity(0.05)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    // Grid lines
    final gridPaint = Paint()
      ..color = subtleText.withOpacity(0.15)
      ..strokeWidth = 1;

    for (int i = 1; i < 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Build path
    final linePath = Path();
    final fillPath = Path();
    final pointCount = values.length;
    final xStep = size.width / (pointCount - 1);

    for (int i = 0; i < pointCount; i++) {
      final x = i * xStep;
      final normalized = values[i] / maxValue;
      final y = size.height - (normalized * size.height * 0.9);

      if (i == 0) {
        linePath.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        final prevX = (i - 1) * xStep;
        final prevNormalized = values[i - 1] / maxValue;
        final prevY = size.height - (prevNormalized * size.height * 0.9);
        final controlX = (prevX + x) / 2;
        linePath.quadraticBezierTo(controlX, prevY, (prevX + x) / 2, (prevY + y) / 2);
        linePath.quadraticBezierTo((controlX + x) / 2, y, x, y);
        fillPath.quadraticBezierTo(controlX, prevY, (prevX + x) / 2, (prevY + y) / 2);
        fillPath.quadraticBezierTo((controlX + x) / 2, y, x, y);
      }
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(linePath, paint);

    // Draw touch indicator
    if (touchX != null && selectedHour != null && selectedHour! >= 0 && selectedHour! < values.length) {
      final indicatorX = selectedHour! * xStep;
      final normalized = values[selectedHour!] / maxValue;
      final indicatorY = size.height - (normalized * size.height * 0.9);

      final indicatorLinePaint = Paint()
        ..color = lineColor.withOpacity(0.6)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      canvas.drawLine(Offset(indicatorX, 0), Offset(indicatorX, size.height), indicatorLinePaint);

      final dotPaint = Paint()
        ..color = lineColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(indicatorX, indicatorY), 6, dotPaint);

      final centerDotPaint = Paint()
        ..color = isDark ? const Color(0xFF1E1E1E) : Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(indicatorX, indicatorY), 3, centerDotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
