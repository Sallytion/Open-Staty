import 'package:flutter/material.dart';
import '../models/chat_analytics.dart';
import '../services/chat_storage.dart';
import '../services/stats_aggregator.dart';
import '../widgets/summary/activity_heatmap_widget.dart';
import '../widgets/summary/share_card_dialog.dart';
import '../widgets/summary/time_of_day_widget.dart';
import '../widgets/summary/weekday_chart_widget.dart';
import '../widgets/summary/word_cloud_widget.dart';
import '../l10n/app_localizations.dart';

class TotalStatsPage extends StatefulWidget {
  const TotalStatsPage({super.key});

  @override
  State<TotalStatsPage> createState() => _TotalStatsPageState();
}

class _TotalStatsPageState extends State<TotalStatsPage> {
  bool _isLoading = true;
  ChatAnalytics? _totalAnalytics;
  int _chatCount = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final chats = await ChatStorage.loadChats();
    if (chats.isNotEmpty) {
      final aggregated = StatsAggregator.aggregate(chats);
      if (mounted) {
        setState(() {
          _chatCount = chats.length;
          _totalAnalytics = aggregated;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _chatCount = 0;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final loc = AppLocalizations.of(context)!;

    if (_chatCount == 0 || _totalAnalytics == null) {
      return Scaffold(
        appBar: AppBar(title: Text(loc.translate('Total Stats'))),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.analytics_outlined, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                loc.translate('no_chats_imported'),
                style: TextStyle(color: Colors.grey[600], fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(loc.translate('import_chats_to_see_stats')),
            ],
          ),
        ),
      );
    }

    final a = _totalAnalytics!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final headingColor = isDark ? Colors.white : Colors.black87;
    final subtleText = isDark ? Colors.grey[400]! : Colors.grey[600]!;
    final bodyText = isDark ? Colors.grey[300]! : Colors.black87;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F7),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(loc.translate('Total Stats'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text(
              loc.translate('across_chats').replaceAll('{count}', '$_chatCount'),
              style: TextStyle(fontSize: 12, color: subtleText, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _showShareCard(context, a, loc.translate('My Chat Stats'), a.totalWords, isDark, primary),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Hero Stats
              _buildHeroStats(a, isDark, primary, headingColor, subtleText, context),
              const SizedBox(height: 24),

              // Global Leaderboard
              _buildSectionCard(
                loc.translate('global_leaderboard'),
                Icons.leaderboard_rounded,
                cardColor,
                subtleText,
                Column(
                  children: [
                    _buildRankedList(a, loc.translate('most_messages'), (p) => p.messages, Icons.chat_bubble, primary, bodyText, subtleText, isDark),
                    const SizedBox(height: 16),
                    _buildRankedList(a, loc.translate('most_words'), (p) => p.words, Icons.text_fields, primary, bodyText, subtleText, isDark),
                  ],
                ),
              ),
              
              // Activity Heatmap
              _buildSectionCard(
                loc.translate('global_activity'),
                Icons.grid_on_rounded,
                cardColor,
                subtleText,
                ActivityHeatmapWidget(
                  activityMap: a.activityMap,
                  primary: primary,
                  isDark: isDark,
                  headingColor: headingColor,
                  subtleText: subtleText,
                ),
              ),

              // Time of Day
              _buildSectionCard(
                loc.translate('messages_by_time'),
                Icons.access_time_rounded,
                cardColor,
                subtleText,
                TimeOfDayWidget(
                  analytics: a,
                  tabs: [loc.translate('total'), ...a.personNames], // Aggregator names are unique
                  headingColor: headingColor,
                  subtleText: subtleText,
                  primary: primary,
                  isDark: isDark,
                  cardColor: cardColor,
                ),
              ),

              // Weekday Chart
              _buildSectionCard(
                loc.translate('messages_by_weekday'),
                Icons.calendar_view_week_rounded,
                cardColor,
                subtleText,
                WeekdayChartWidget(
                  analytics: a,
                  primary: primary,
                  isDark: isDark,
                  headingColor: headingColor,
                  subtleText: subtleText,
                ),
              ),

              // Word Cloud
              _buildSectionCard(
                loc.translate('global_word_cloud'),
                Icons.cloud_rounded,
                cardColor,
                subtleText,
                WordCloudWidget(
                  analytics: a,
                  primary: primary,
                  isDark: isDark,
                  headingColor: headingColor,
                  subtleText: subtleText,
                ),
              ),
              
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroStats(ChatAnalytics a, bool isDark, Color primary, Color headingColor, Color subtleText, BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _statItem(loc.translate('total_messages'), _fmtNum(a.totalMessages), Icons.forum_rounded, primary, headingColor, subtleText)),
              Container(width: 1, height: 40, color: subtleText.withOpacity(0.2)),
              Expanded(child: _statItem(loc.translate('total_words'), _fmtNum(a.totalWords), Icons.text_fields_rounded, Colors.orange, headingColor, subtleText)),
            ],
          ),
          const SizedBox(height: 20),
          Divider(color: subtleText.withOpacity(0.1)),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _statItem(loc.translate('longest_streak'), '${a.longestStreak} ${loc.translate('days')}', Icons.local_fire_department_rounded, Colors.red, headingColor, subtleText)),
              Container(width: 1, height: 40, color: subtleText.withOpacity(0.2)),
              Expanded(child: _statItem(loc.translate('reading_time_label'), _fmtDuration(a.readingTimeMinutes, context), Icons.timer_rounded, Colors.teal, headingColor, subtleText)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, IconData icon, Color color, Color headingColor, Color subtleText) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: headingColor)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: subtleText)),
      ],
    );
  }
  
  Widget _buildSectionCard(String title, IconData icon, Color cardColor, Color subtleText, Widget child) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: subtleText.withOpacity(0.7), size: 20),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(color: subtleText, fontSize: 12, fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  // Reuse logic from ChatSummaryPage for leaderboard
  Widget _buildRankedList(ChatAnalytics a, String title, int Function(PersonStats) getter, IconData icon, Color primary, Color bodyText, Color subtleText, bool isDark) {
    final sorted = a.personStats.values.toList()
      ..sort((a, b) => getter(b).compareTo(getter(a)));
    final top3 = sorted.take(5).toList(); // Top 5 for global
    if (top3.isEmpty) return const SizedBox.shrink();
    final maxVal = getter(top3.first);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: primary),
            const SizedBox(width: 8),
            Text(title, style: TextStyle(color: subtleText, fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        ),
        const SizedBox(height: 8),
        ...top3.asMap().entries.map((e) {
          final idx = e.key;
          final item = e.value;
          final val = getter(item);
          final ratio = maxVal > 0 ? val / maxVal : 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  child: Text(
                    '#${idx + 1}',
                    style: TextStyle(color: idx == 0 ? Colors.amber : subtleText, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              _shortenName(item.name),
                              style: TextStyle(color: bodyText, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(_fmtNum(val), style: TextStyle(color: idx == 0 ? primary : subtleText, fontWeight: idx == 0 ? FontWeight.bold : FontWeight.normal, fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 2),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: ratio,
                          minHeight: 4,
                          backgroundColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.1),
                          valueColor: AlwaysStoppedAnimation(idx == 0 ? primary : primary.withOpacity(0.5)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  void _showShareCard(BuildContext context, ChatAnalytics a, String name, int wordCount, bool isDark, Color primary) {
    final loc = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => ShareCardDialog(
        analytics: a,
        chatName: name,
        wordCount: wordCount,
        isDark: isDark,
        primary: primary,
        fmtNum: _fmtNum,
      ),
    );
  }

  String _shortenName(String name) {
    if (name.length <= 12) return name;
    if (name.startsWith('+')) {
       return '${name.substring(0, 12)}..';
    }
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
  
  String _fmtDuration(double minutes, BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final duration = Duration(minutes: minutes.round());
    if (duration.inHours > 24) {
      return '${(duration.inHours / 24).toStringAsFixed(1)} ${loc.translate('days')}';
    } else if (duration.inHours > 0) {
      return '${duration.inHours} ${loc.translate('hours')}';
    } else {
      return '${duration.inMinutes} ${loc.translate('mins')}';
    }
  }
}
