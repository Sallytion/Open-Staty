import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../l10n/app_localizations.dart';

/// GitHub-style activity heatmap widget
class ActivityHeatmapWidget extends StatefulWidget {
  final Map<String, int> activityMap;
  final Color primary;
  final bool isDark;
  final Color headingColor;
  final Color subtleText;

  const ActivityHeatmapWidget({
    super.key,
    required this.activityMap,
    required this.primary,
    required this.isDark,
    required this.headingColor,
    required this.subtleText,
  });

  @override
  State<ActivityHeatmapWidget> createState() => _ActivityHeatmapWidgetState();
}

class _ActivityHeatmapWidgetState extends State<ActivityHeatmapWidget> {
  static const double _cellSize = 16;
  static const double _cellMargin = 1.5;
  static const double _dayLabelWidth = 32;

  @override
  Widget build(BuildContext context) {
    if (widget.activityMap.isEmpty) return const SizedBox.shrink();

    final loc = AppLocalizations.of(context)!;
    final dates = widget.activityMap.keys.map((k) => DateTime.parse(k)).toList()..sort();
    final firstDate = dates.first;
    final lastDate = dates.last;

    final rangeStart = lastDate.subtract(const Duration(days: 364));
    final start = firstDate.isAfter(rangeStart) ? firstDate : rangeStart;
    final startMonday = start.subtract(Duration(days: start.weekday - 1));

    final totalDays = lastDate.difference(startMonday).inDays + 1;
    final weeks = (totalDays / 7).ceil();
    final maxCount = widget.activityMap.values.fold<int>(0, (a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Month labels
              Padding(
                padding: const EdgeInsets.only(left: _dayLabelWidth + 4),
                child: Row(children: _buildMonthLabels(startMonday, weeks)),
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Day labels
                  Column(
                    children: [
                      _dayLabel(''),
                      _dayLabel(loc.translate('mon')),
                      _dayLabel(''),
                      _dayLabel(loc.translate('wed')),
                      _dayLabel(''),
                      _dayLabel(loc.translate('fri')),
                      _dayLabel(''),
                    ],
                  ),
                  const SizedBox(width: 4),
                  // Grid
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: List.generate(weeks, (weekIdx) {
                      return Column(
                        children: List.generate(7, (dayIdx) {
                          final date = startMonday.add(Duration(days: weekIdx * 7 + dayIdx));
                          if (date.isAfter(lastDate)) {
                            return _buildCell(0, maxCount, null);
                          }
                          final key = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                          final count = widget.activityMap[key] ?? 0;
                          return _buildCell(count, maxCount, date);
                        }),
                      );
                    }),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Legend
        Row(
          children: [
            Text(loc.translate('less'), style: TextStyle(fontSize: 12, color: widget.subtleText)),
            const SizedBox(width: 8),
            ...List.generate(5, (i) {
              final opacity = i == 0 ? 0.0 : (i / 4);
              return Container(
                width: 14,
                height: 14,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: i == 0
                      ? (widget.isDark ? const Color(0xFF2A2A2A) : Colors.grey[200])
                      : widget.primary.withOpacity(opacity),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
            const SizedBox(width: 8),
            Text(loc.translate('more'), style: TextStyle(fontSize: 12, color: widget.subtleText)),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          loc.translate('tap_details'),
          style: TextStyle(fontSize: 11, color: widget.subtleText, fontStyle: FontStyle.italic),
        ),
      ],
    );
  }

  Widget _dayLabel(String text) {
    return SizedBox(
      height: _cellSize + _cellMargin * 2,
      width: _dayLabelWidth,
      child: text.isEmpty 
          ? null 
          : Align(
              alignment: Alignment.centerLeft,
              child: Text(text, style: TextStyle(fontSize: 11, color: widget.subtleText)),
            ),
    );
  }

  List<Widget> _buildMonthLabels(DateTime startMonday, int weeks) {
    final labels = <Widget>[];
    int lastMonth = -1;

    for (int w = 0; w < weeks; w++) {
      final date = startMonday.add(Duration(days: w * 7));
      if (date.month != lastMonth) {
        labels.add(SizedBox(
          width: _cellSize + _cellMargin * 2,
          child: Text(DateFormat('MMM').format(date), style: TextStyle(fontSize: 11, color: widget.subtleText)),
        ));
        lastMonth = date.month;
      } else {
        labels.add(const SizedBox(width: _cellSize + _cellMargin * 2));
      }
    }
    return labels;
  }

  Widget _buildCell(int count, int maxCount, DateTime? date) {
    Color color;
    if (date == null) {
      color = Colors.transparent;
    } else if (count == 0) {
      color = widget.isDark ? const Color(0xFF2A2A2A) : Colors.grey[200]!;
    } else {
      final intensity = (count / maxCount).clamp(0.2, 1.0);
      color = widget.primary.withOpacity(intensity);
    }

    return GestureDetector(
      onTap: date != null ? () => _showDayStats(date, count) : null,
      child: Container(
        width: _cellSize,
        height: _cellSize,
        margin: const EdgeInsets.all(_cellMargin),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }

  void _showDayStats(DateTime date, int count) {
    final loc = AppLocalizations.of(context)!;
    
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text(
                  DateFormat('EEEE').format(date),
                  style: TextStyle(fontSize: 14, color: widget.subtleText),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat.yMMMMd().format(date),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: widget.headingColor,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: widget.isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF7F7F7),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        count > 0 ? Icons.chat_bubble_rounded : Icons.chat_bubble_outline_rounded,
                        size: 48,
                        color: count > 0 ? widget.primary : widget.subtleText,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '$count',
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w700,
                          color: widget.headingColor,
                        ),
                      ),
                      Text(
                        loc.translate('messages'),
                        style: TextStyle(fontSize: 16, color: widget.subtleText),
                      ),
                      if (count > 0) ...[
                        const SizedBox(height: 12),
                        Text(
                          count >= 100 
                              ? loc.translate('very_active')
                              : count >= 50 
                                  ? loc.translate('active_day')
                                  : count >= 10 
                                      ? loc.translate('regular_day')
                                      : loc.translate('quiet_day'),
                          style: TextStyle(
                            fontSize: 14,
                            color: widget.subtleText,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }
}
