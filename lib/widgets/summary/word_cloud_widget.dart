import 'package:flutter/material.dart';
import '../../models/chat_analytics.dart';
import '../../l10n/app_localizations.dart';

/// Word cloud widget displaying top words with varying sizes
class WordCloudWidget extends StatelessWidget {
  final ChatAnalytics analytics;
  final Color primary;
  final bool isDark;
  final Color headingColor;
  final Color subtleText;

  const WordCloudWidget({
    super.key,
    required this.analytics,
    required this.primary,
    required this.isDark,
    required this.headingColor,
    required this.subtleText,
  });

  static const List<Color> _cloudColors = [
    Color(0xFFFF6B6B),
    Color(0xFF4ECDC4),
    Color(0xFFFFE66D),
    Color(0xFF95E1D3),
    Color(0xFFA8E6CF),
    Color(0xFFDCEDC1),
    Color(0xFFFFD3B6),
    Color(0xFFFFAAA5),
    Color(0xFFFF8B94),
    Color(0xFFA0CED9),
  ];

  @override
  Widget build(BuildContext context) {
    final words = analytics.totalTopWords(40);
    final loc = AppLocalizations.of(context)!;
    
    if (words.isEmpty) {
      return Text(loc.translate('no_words'), style: TextStyle(color: subtleText));
    }

    final maxCount = words.first.value;
    final minCount = words.last.value;
    final range = (maxCount - minCount).clamp(1, double.infinity);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF8F8F8),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: words.asMap().entries.map((entry) {
              final idx = entry.key;
              final word = entry.value.key;
              final count = entry.value.value;
              
              final normalizedSize = ((count - minCount) / range).clamp(0.0, 1.0);
              final fontSize = 12.0 + normalizedSize * 20;
              final color = _cloudColors[idx % _cloudColors.length];
              
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(
                  word,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: normalizedSize > 0.5 ? FontWeight.bold : FontWeight.normal,
                    color: isDark ? color : color.withOpacity(0.85),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          loc.translate('top_words_sized').replaceAll('{count}', '40'),
          style: TextStyle(fontSize: 12, color: subtleText),
        ),
      ],
    );
  }
}
