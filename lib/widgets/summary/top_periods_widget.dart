import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../l10n/app_localizations.dart';

/// Top Activity Periods widget showing clustered high-activity periods
class TopPeriodsWidget extends StatelessWidget {
  final Map<String, int> activityMap;
  final Color primary;
  final bool isDark;
  final Color headingColor;
  final Color subtleText;
  final String Function(int) fmtNum;

  const TopPeriodsWidget({
    super.key,
    required this.activityMap,
    required this.primary,
    required this.isDark,
    required this.headingColor,
    required this.subtleText,
    required this.fmtNum,
  });

  @override
  Widget build(BuildContext context) {
    final periods = _findTopPeriods(activityMap);
    final loc = AppLocalizations.of(context)!;
    
    if (periods.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          loc.translate('most_active_periods'),
          style: TextStyle(color: subtleText, fontSize: 12),
        ),
        const SizedBox(height: 16),
        ...periods.take(5).map((p) => _buildPeriodCard(p, context)).toList(),
      ],
    );
  }
  
  List<_ActivityPeriod> _findTopPeriods(Map<String, int> activityMap) {
    if (activityMap.isEmpty) return [];
    
    final entries = activityMap.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    
    final avgCount = entries.fold(0, (sum, e) => sum + e.value) / entries.length;
    final threshold = avgCount * 1.5;
    
    final periods = <_ActivityPeriod>[];
    DateTime? periodStart;
    DateTime? periodEnd;
    int periodMessages = 0;
    int periodDays = 0;
    
    for (int i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final date = DateTime.parse(entry.key);
      final count = entry.value;
      
      if (count >= threshold) {
        if (periodStart == null) {
          periodStart = date;
          periodEnd = date;
          periodMessages = count;
          periodDays = 1;
        } else {
          final gap = date.difference(periodEnd!).inDays;
          if (gap <= 2) {
            periodEnd = date;
            periodMessages += count;
            periodDays++;
          } else {
            periods.add(_ActivityPeriod(periodStart, periodEnd, periodMessages, periodDays));
            periodStart = date;
            periodEnd = date;
            periodMessages = count;
            periodDays = 1;
          }
        }
      } else if (periodStart != null) {
        periods.add(_ActivityPeriod(periodStart, periodEnd!, periodMessages, periodDays));
        periodStart = null;
        periodEnd = null;
        periodMessages = 0;
        periodDays = 0;
      }
    }
    
    if (periodStart != null) {
      periods.add(_ActivityPeriod(periodStart, periodEnd!, periodMessages, periodDays));
    }
    
    periods.sort((a, b) => b.messages.compareTo(a.messages));
    return periods;
  }
  
  Widget _buildPeriodCard(_ActivityPeriod p, BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final dateFormat = DateFormat.yMMMd().format(p.start);
    final endFormat = p.start == p.end ? '' : ' - ${DateFormat.yMMMd().format(p.end)}';
    final dayLabel = p.days > 1 ? loc.translate('days') : loc.translate('day');
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.local_fire_department, color: primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$dateFormat$endFormat',
                  style: TextStyle(color: headingColor, fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  '${fmtNum(p.messages)} ${loc.translate('messages')} • ${p.days} $dayLabel',
                  style: TextStyle(color: subtleText, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '🔥 ${(p.messages / p.days).round()}${loc.translate('per_day')}',
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityPeriod {
  final DateTime start;
  final DateTime end;
  final int messages;
  final int days;
  
  _ActivityPeriod(this.start, this.end, this.messages, this.days);
}
