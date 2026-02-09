import 'package:flutter/material.dart';
import '../../models/chat_analytics.dart';
import '../../l10n/app_localizations.dart';

/// Bar chart showing messages by day of week (Mon-Sun) with per-person tabs
class WeekdayChartWidget extends StatefulWidget {
  final ChatAnalytics analytics;
  final Color primary;
  final bool isDark;
  final Color headingColor;
  final Color subtleText;

  const WeekdayChartWidget({
    super.key,
    required this.analytics,
    required this.primary,
    required this.isDark,
    required this.headingColor,
    required this.subtleText,
  });

  @override
  State<WeekdayChartWidget> createState() => _WeekdayChartWidgetState();
}

class _WeekdayChartWidgetState extends State<WeekdayChartWidget> {
  int _selectedTab = 0;

  List<String> _getWeekdays(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return [
      loc.translate('mon'), loc.translate('tue'), loc.translate('wed'), 
      loc.translate('thu'), loc.translate('fri'), loc.translate('sat'), loc.translate('sun')
    ];
  }

  Map<int, int> _getDataForTab() {
    final a = widget.analytics;
    if (_selectedTab == 0) {
      return a.weekdayActivityMap;
    } else {
      final names = a.personStats.keys.toList();
      if (_selectedTab <= names.length) {
        return a.personStats[names[_selectedTab - 1]]?.weekdayActivityMap ?? {};
      }
      return {};
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final weekdays = _getWeekdays(context);
    final names = widget.analytics.personStats.keys.toList();
    final data = _getDataForTab();
    final maxCount = data.values.fold(0, (a, b) => a > b ? a : b);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tabs
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildTab(loc.translate('total'), 0),
              const SizedBox(width: 8),
              ...List.generate(names.length, (i) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _buildTab(_shortenName(names[i]), i + 1),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 16),
        
        // Bar Chart
        SizedBox(
          height: 165,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(7, (i) {
              final weekday = i + 1;
              final count = data[weekday] ?? 0;
              final height = maxCount > 0 ? (count / maxCount * 100).clamp(4.0, 100.0) : 4.0;
              final isMax = count == maxCount && count > 0;
              
              return Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        count > 0 ? _fmtNum(count) : '',
                        style: TextStyle(
                          fontSize: 10,
                          color: isMax ? widget.primary : widget.subtleText,
                          fontWeight: isMax ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Tooltip(
                      message: '$count ${loc.translate('messages')}',
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: height,
                        width: 28,
                        decoration: BoxDecoration(
                          color: isMax ? widget.primary : widget.primary.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      weekdays[i],
                      style: TextStyle(
                        fontSize: 11,
                        color: isMax ? widget.primary : widget.subtleText,
                        fontWeight: isMax ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 12),
        
        // Peak day label
        if (maxCount > 0)
          Text(
            '📅 ${loc.translate('most_active')}: ${_getPeakDay(data, context)}',
            style: TextStyle(fontSize: 12, color: widget.subtleText),
          ),
      ],
    );
  }
  
  String _getPeakDay(Map<int, int> data, BuildContext context) {
    int maxDay = 1;
    int maxCount = 0;
    data.forEach((day, count) {
      if (count > maxCount) {
        maxCount = count;
        maxDay = day;
      }
    });
    
    final loc = AppLocalizations.of(context)!;
    final fullDays = [
      loc.translate('monday'), loc.translate('tuesday'), loc.translate('wednesday'), 
      loc.translate('thursday'), loc.translate('friday'), loc.translate('saturday'), loc.translate('sunday')
    ];
    return fullDays[maxDay - 1];
  }
  
  String _shortenName(String name) {
    if (name.length <= 12) return name;
    // Special handling for phone numbers starting with +
    if (name.startsWith('+')) {
       return '${name.substring(0, 12)}..';
    }
    // For normal names, try splitting first name
    final first = name.split(' ').first;
    if (first.length > 12) {
      return '${first.substring(0, 11)}..';
    }
    return first;
  }
  
  String _fmtNum(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }

  Widget _buildTab(String label, int index) {
    final selected = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? widget.primary : (widget.isDark ? Colors.white.withOpacity(0.08) : Colors.grey.withOpacity(0.1)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: selected ? Colors.white : widget.subtleText,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
