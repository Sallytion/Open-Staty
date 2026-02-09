import 'package:flutter/material.dart';
import '../services/chat_storage.dart';
import '../models/chat_analytics.dart';
import '../widgets/summary/time_of_day_widget.dart';
import '../widgets/summary/weekday_chart_widget.dart';
import '../widgets/summary/word_cloud_widget.dart';
import '../widgets/summary/activity_heatmap_widget.dart';
import '../widgets/summary/top_periods_widget.dart';
import '../widgets/summary/share_card_dialog.dart';

import '../l10n/app_localizations.dart';

class ChatSummaryPage extends StatelessWidget {
  final String chatName;
  final int wordCount;
  final double readingTimeMinutes;
  final DateTime? importedAt;
  final ChatAnalytics? analytics;

  const ChatSummaryPage({
    super.key,
    required this.chatName,
    required this.wordCount,
    required this.readingTimeMinutes,
    this.importedAt,
    this.analytics,
  });

  factory ChatSummaryPage.fromChat(SavedChat chat) {
    return ChatSummaryPage(
      chatName: chat.name,
      wordCount: chat.wordCount,
      readingTimeMinutes: chat.readingTimeMinutes,
      importedAt: chat.importedAt,
      analytics: chat.analytics,
    );
  }

  String _formatReadingTime(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    if (readingTimeMinutes >= 1440) {
      return loc.translate('reading_time_days').replaceAll('{days}', (readingTimeMinutes / 1440).toStringAsFixed(1));
    } else if (readingTimeMinutes >= 60) {
      return loc.translate('reading_time_hours').replaceAll('{hours}', (readingTimeMinutes / 60).toStringAsFixed(1));
    } else if (readingTimeMinutes >= 1) {
      return loc.translate('reading_time_min').replaceAll('{min}', readingTimeMinutes.toStringAsFixed(1));
    } else {
      return loc.translate('reading_time_sec').replaceAll('{sec}', (readingTimeMinutes * 60).toStringAsFixed(0));
    }
  }

  String _fmtNum(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  void _showShareCard(BuildContext context, ChatAnalytics a, String name, int wordCount, bool isDark, Color primary) {
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
  
  Widget _statTile(String label, String value, IconData icon, Color primary, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: primary),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 11)),
            ],
          ),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : Colors.white;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF7F7F7);
    final subtleText = isDark ? Colors.grey[500]! : Colors.grey[500]!;
    final bodyText = isDark ? Colors.grey[300]! : Colors.grey[700]!;
    final headingColor = isDark ? Colors.white : Colors.black;
    final dividerColor = isDark ? Colors.grey[800]! : Colors.grey[200]!;
    final primary = Theme.of(context).colorScheme.primary;

    final a = analytics;

    return Scaffold(
      backgroundColor: bgColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: bgColor,
            elevation: 0,
            scrolledUnderElevation: 0,
            pinned: true,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: headingColor),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              AppLocalizations.of(context)!.translate('summary'),
              style: TextStyle(
                color: headingColor,
                fontSize: 17,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3,
              ),
            ),
            centerTitle: true,
            actions: [
              if (a != null)
                IconButton(
                  icon: Icon(Icons.share_rounded, color: primary),
                  tooltip: AppLocalizations.of(context)!.translate('share_stats'),
                  onPressed: () => _showShareCard(context, a, chatName, wordCount, isDark, primary),
                ),
            ],
          ),

          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 8),

                // Chat name
                Text(
                  chatName.replaceAll('.zip', '').replaceAll('.txt', ''),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: headingColor,
                    letterSpacing: -0.5,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),

                if (importedAt != null)
                  Text(
                    '${AppLocalizations.of(context)!.translate('analyzed_on')} ${_formatDate(importedAt!)}',
                    style: TextStyle(fontSize: 14, color: subtleText),
                  ),
                if (a?.firstMessageDate != null && a?.lastMessageDate != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${_formatDate(a!.firstMessageDate!)} - ${_formatDate(a.lastMessageDate!)}',
                      style: TextStyle(fontSize: 13, color: subtleText),
                    ),
                  ),

                const SizedBox(height: 32),
                Divider(color: dividerColor, height: 1),
                const SizedBox(height: 32),

                // Hero stats
                _buildHeroStat(AppLocalizations.of(context)!.translate('total_words'), _fmtNum(wordCount), Icons.text_fields_rounded, headingColor, subtleText, primary),
                const SizedBox(height: 32),
                _buildHeroStat(AppLocalizations.of(context)!.translate('reading_time'), _formatReadingTime(context), Icons.schedule_rounded, headingColor, subtleText, primary),
                const SizedBox(height: 32),
                if (a != null) ...[
                  _buildHeroStat(AppLocalizations.of(context)!.translate('total_messages'), _fmtNum(a.totalMessages), Icons.chat_rounded, headingColor, subtleText, primary),
                  const SizedBox(height: 40),
                ],

                // Streak cards
                if (a != null) ...[
                  Row(
                    children: [
                      Expanded(child: _buildClickableStreakCard(
                        context,
                        AppLocalizations.of(context)!.translate('longest_streak'), 
                        '${a.longestStreak} d', 
                        Icons.local_fire_department_rounded, 
                        cardColor, headingColor, bodyText, primary, subtleText,
                        a.longestStreakStart, 
                        a.longestStreakEnd,
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: _buildClickableStreakCard(
                        context,
                        AppLocalizations.of(context)!.translate('current_streak'), 
                        '${a.currentStreak} d', 
                        Icons.bolt_rounded, 
                        cardColor, headingColor, bodyText, primary, subtleText,
                        a.currentStreakStart, 
                        a.currentStreakEnd,
                      )),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildStatCard(AppLocalizations.of(context)!.translate('active_days'), '${a.activityMap.length}', Icons.calendar_today_rounded, cardColor, headingColor, bodyText, primary)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildStatCard(AppLocalizations.of(context)!.translate('pages_book'), (wordCount / 250).toStringAsFixed(1), Icons.menu_book_rounded, cardColor, headingColor, bodyText, primary)),
                    ],
                  ),
                  const SizedBox(height: 40),
                ],

                // Fun Facts
                _buildSectionCard(
                  AppLocalizations.of(context)!.translate('fun_facts'),
                  Icons.lightbulb_outline_rounded,
                  cardColor,
                  subtleText,
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFunFact(
                        AppLocalizations.of(context)!.translate('pages_book_fact').replaceAll('{count}', (wordCount / 250).toStringAsFixed(0)),
                        bodyText,
                      ),
                      const SizedBox(height: 12),
                      _buildFunFact(_getTimeComparison(context), bodyText),
                      const SizedBox(height: 12),
                      _buildFunFact(
                        AppLocalizations.of(context)!.translate('blog_posts_fact').replaceAll('{count}', (wordCount / 500).toStringAsFixed(0)),
                        bodyText,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // ===== ANNIVERSARY & CHAT AGE =====
                if (a != null && a.firstMessageDate != null) ...[
                  _buildAnniversarySection(context, a, cardColor, headingColor, bodyText, subtleText, primary, isDark),
                  const SizedBox(height: 40),
                ],

                // ===== WHO WOULD WIN =====
                if (a != null && a.personStats.length == 2) ...[
                  _buildWhoWouldWinSection(context, a, cardColor, headingColor, bodyText, subtleText, primary, isDark),
                  const SizedBox(height: 40),
                ],

                // ===== CHAT MILESTONES =====
                if (a != null) ...[
                  _buildMilestonesSection(context, a, cardColor, headingColor, bodyText, subtleText, primary, isDark),
                  const SizedBox(height: 40),
                ],

                // ===== PREDICTIONS =====
                if (a != null && a.firstMessageDate != null) ...[
                  _buildPredictionsSection(context, a, cardColor, headingColor, bodyText, subtleText, primary, isDark),
                  const SizedBox(height: 40),
                ],

                // ===== TOP WORDS SECTION =====
                if (a != null && a.totalWordFrequency.isNotEmpty) ...[
                  _buildTopWordsSection(context, a, cardColor, headingColor, bodyText, subtleText, primary, isDark),
                  const SizedBox(height: 40),
                ],

                // ===== WORD CLOUD =====
                if (a != null && a.totalWordFrequency.isNotEmpty) ...[
                  _buildWordCloudSection(context, a, cardColor, headingColor, subtleText, primary, isDark),
                  const SizedBox(height: 40),
                ],

                // ===== QUICK STATS PER PERSON =====
                if (a != null && a.personStats.isNotEmpty) ...[
                  _buildPersonStatsSection(context, a, cardColor, headingColor, bodyText, subtleText, primary, isDark),
                  const SizedBox(height: 40),
                ],

                // ===== WHO WAITS LONGER =====
                if (a != null && a.personStats.isNotEmpty) ...[
                  _buildWhoWaitsLongerSection(context, a, cardColor, headingColor, bodyText, subtleText, primary, isDark),
                  const SizedBox(height: 40),
                ],

                // ===== WHO STARTS CONVERSATIONS =====
                if (a != null && a.personStats.isNotEmpty) ...[
                  _buildWhoStartsSection(context, a, cardColor, headingColor, bodyText, subtleText, primary, isDark),
                  const SizedBox(height: 40),
                ],

                // ===== MESSAGES BY TIME OF DAY =====
                if (a != null && a.hourlyActivityMap.isNotEmpty) ...[
                  _buildTimeOfDaySection(context, a, cardColor, headingColor, subtleText, primary, isDark),
                  const SizedBox(height: 40),
                ],

                // ===== MESSAGES BY WEEKDAY =====
                if (a != null && a.weekdayActivityMap.isNotEmpty) ...[
                  _buildWeekdaySection(context, a, cardColor, headingColor, subtleText, primary, isDark),
                  const SizedBox(height: 40),
                ],

                // ===== TOP PERIODS =====
                if (a != null && a.activityMap.length > 7) ...[
                  _buildTopPeriodsSection(context, a, cardColor, headingColor, subtleText, primary, isDark),
                  const SizedBox(height: 40),
                ],

                // ===== ACTIVITY HEATMAP =====
                if (a != null && a.activityMap.isNotEmpty) ...[
                  _buildActivityHeatmap(context, a, cardColor, headingColor, subtleText, primary, isDark),
                  const SizedBox(height: 40),
                ],

                // Thank you
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [primary, primary.withOpacity(0.7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.favorite_rounded, size: 32, color: Colors.white),
                      const SizedBox(height: 12),
                      const Text(
                        'Open Staty',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Thanks for analyzing your chats',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 48),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== TOP WORDS ====================
  Widget _buildTopWordsSection(BuildContext context, ChatAnalytics a, Color cardColor, Color headingColor, Color bodyText, Color subtleText, Color primary, bool isDark) {
    final persons = a.personNames;
    final tabs = [AppLocalizations.of(context)!.translate('total'), ...persons];

    return _buildSectionCard(
      AppLocalizations.of(context)!.translate('top_words'),
      Icons.sort_by_alpha_rounded,
      cardColor,
      subtleText,
      _TopWordsWidget(
        analytics: a,
        tabs: tabs,
        headingColor: headingColor,
        bodyText: bodyText,
        subtleText: subtleText,
        primary: primary,
        isDark: isDark,
        cardColor: cardColor,
      ),
    );
  }

  // ==================== PERSON STATS ====================
  Widget _buildPersonStatsSection(BuildContext context, ChatAnalytics a, Color cardColor, Color headingColor, Color bodyText, Color subtleText, Color primary, bool isDark) {
    return _buildSectionCard(
      AppLocalizations.of(context)!.translate('quick_stats'),
      Icons.people_outline_rounded,
      cardColor,
      subtleText,
      Column(
        children: [
          for (int i = 0; i < a.personNames.length; i++) ...[
            if (i > 0) const SizedBox(height: 16),
            _buildPersonCard(context, a.personStats[a.personNames[i]]!, headingColor, bodyText, subtleText, primary, isDark),
          ],
        ],
      ),
    );
  }

  Widget _buildPersonCard(BuildContext context, PersonStats ps, Color headingColor, Color bodyText, Color subtleText, Color primary, bool isDark) {
    final stats = [
      _QuickStat(AppLocalizations.of(context)!.translate('messages'), _fmtNum(ps.messages), Icons.chat_bubble_outline_rounded),
      _QuickStat(AppLocalizations.of(context)!.translate('words'), _fmtNum(ps.words), Icons.text_fields_rounded),
      _QuickStat(AppLocalizations.of(context)!.translate('letters'), _fmtNum(ps.letters), Icons.abc_rounded),
      _QuickStat(AppLocalizations.of(context)!.translate('media'), _fmtNum(ps.media), Icons.image_outlined),
      _QuickStat(AppLocalizations.of(context)!.translate('links'), _fmtNum(ps.links), Icons.link_rounded),
      _QuickStat(AppLocalizations.of(context)!.translate('emojis'), _fmtNum(ps.emojis), Icons.emoji_emotions_outlined),
      _QuickStat(AppLocalizations.of(context)!.translate('deleted'), _fmtNum(ps.deleted), Icons.delete_outline_rounded),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          ps.name,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: headingColor),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: stats.map((s) => _buildQuickStatChip(s, isDark, primary)).toList(),
        ),
      ],
    );
  }

  Widget _buildQuickStatChip(_QuickStat stat, bool isDark, Color primary) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(stat.icon, size: 14, color: primary.withOpacity(0.7)),
          const SizedBox(width: 6),
          Text(
            '${stat.label}: ',
            style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
          ),
          Text(
            stat.value,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black),
          ),
        ],
      ),
    );
  }

  // ==================== WHO WAITS LONGER ====================
  Widget _buildWhoWaitsLongerSection(BuildContext context, ChatAnalytics a, Color cardColor, Color headingColor, Color bodyText, Color subtleText, Color primary, bool isDark) {
    // Get persons with response data
    final personsWithResponses = a.personStats.values
        .where((ps) => ps.responseCount > 0)
        .toList()
      ..sort((x, y) => y.averageResponseTimeMinutes.compareTo(x.averageResponseTimeMinutes));

    if (personsWithResponses.isEmpty) {
      return const SizedBox.shrink();
    }

    final maxTime = personsWithResponses
        .map((p) => p.averageResponseTimeMinutes)
        .reduce((a, b) => a > b ? a : b);

    String _formatTime(double minutes) {
      if (minutes >= 60) {
        final hours = minutes / 60;
        return '${hours.toStringAsFixed(1)}h';
      }
      return '${minutes.toStringAsFixed(0)}m';
    }

    return _buildSectionCard(
      AppLocalizations.of(context)!.translate('who_waits_longer'),
      Icons.hourglass_empty_rounded,
      cardColor,
      subtleText,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context)!.translate('avg_response_time'),
            style: TextStyle(fontSize: 13, color: subtleText),
          ),
          const SizedBox(height: 16),
          ...personsWithResponses.map((ps) {
            final ratio = maxTime > 0 ? ps.averageResponseTimeMinutes / maxTime : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          ps.name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: headingColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        _formatTime(ps.averageResponseTimeMinutes),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: ratio,
                      minHeight: 8,
                      backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation(primary),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.translate('lower_quicker'),
            style: TextStyle(fontSize: 11, color: subtleText, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  // ==================== WHO STARTS CONVERSATIONS ====================
  Widget _buildWhoStartsSection(BuildContext context, ChatAnalytics a, Color cardColor, Color headingColor, Color bodyText, Color subtleText, Color primary, bool isDark) {
    // Get persons with conversation starts
    final personsWithStarts = a.personStats.values
        .where((ps) => ps.conversationsStarted > 0)
        .toList()
      ..sort((x, y) => y.conversationsStarted.compareTo(x.conversationsStarted));

    if (personsWithStarts.isEmpty) {
      return const SizedBox.shrink();
    }

    final totalConversations = personsWithStarts
        .map((p) => p.conversationsStarted)
        .reduce((a, b) => a + b);

    final colors = [
      primary,
      Colors.amber[700]!,
      Colors.teal,
      Colors.orange[600]!,
      Colors.pink[400]!,
    ];

    return _buildSectionCard(
      AppLocalizations.of(context)!.translate('who_starts'),
      Icons.record_voice_over_rounded,
      cardColor,
      subtleText,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context)!.translate('conversations_detected').replaceAll('{count}', '$totalConversations'),
            style: TextStyle(fontSize: 13, color: subtleText),
          ),
          const SizedBox(height: 16),
          // Stacked bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 24,
              child: Row(
                children: List.generate(personsWithStarts.length, (i) {
                  final ps = personsWithStarts[i];
                  final ratio = totalConversations > 0 
                      ? ps.conversationsStarted / totalConversations 
                      : 0.0;
                  return Expanded(
                    flex: (ratio * 100).round().clamp(1, 100),
                    child: Container(
                      color: colors[i % colors.length],
                    ),
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Legend
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: List.generate(personsWithStarts.length, (i) {
              final ps = personsWithStarts[i];
              final percentage = totalConversations > 0 
                  ? (ps.conversationsStarted / totalConversations * 100).round()
                  : 0;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: colors[i % colors.length],
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${ps.name}: ${ps.conversationsStarted} ($percentage%)',
                    style: TextStyle(fontSize: 13, color: bodyText),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  // ==================== ACTIVITY HEATMAP ====================
  // ==================== MESSAGES BY TIME OF DAY ====================
  Widget _buildTimeOfDaySection(BuildContext context, ChatAnalytics a, Color cardColor, Color headingColor, Color subtleText, Color primary, bool isDark) {
    final tabs = [AppLocalizations.of(context)!.translate('total'), ...a.personNames];
    
    return _buildSectionCard(
      AppLocalizations.of(context)!.translate('time_of_day'),
      Icons.access_time_rounded,
      cardColor,
      subtleText,
      TimeOfDayWidget(
        analytics: a,
        tabs: tabs,
        headingColor: headingColor,
        subtleText: subtleText,
        primary: primary,
        isDark: isDark,
        cardColor: cardColor,
      ),
    );
  }

  Widget _buildActivityHeatmap(BuildContext context, ChatAnalytics a, Color cardColor, Color headingColor, Color subtleText, Color primary, bool isDark) {
    return _buildSectionCard(
      AppLocalizations.of(context)!.translate('activity'),
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
    );
  }

  // ==================== MESSAGES BY WEEKDAY ====================
  Widget _buildWeekdaySection(BuildContext context, ChatAnalytics a, Color cardColor, Color headingColor, Color subtleText, Color primary, bool isDark) {
    return _buildSectionCard(
      AppLocalizations.of(context)!.translate('weekly_activity'),
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
    );
  }

  // ==================== TOP PERIODS ====================
  Widget _buildTopPeriodsSection(BuildContext context, ChatAnalytics a, Color cardColor, Color headingColor, Color subtleText, Color primary, bool isDark) {
    return _buildSectionCard(
      AppLocalizations.of(context)!.translate('top_activity_periods'),
      Icons.trending_up_rounded,
      cardColor,
      subtleText,
      TopPeriodsWidget(
        activityMap: a.activityMap,
        primary: primary,
        isDark: isDark,
        headingColor: headingColor,
        subtleText: subtleText,
        fmtNum: _fmtNum,
      ),
    );
  }

  // ==================== WORD CLOUD ====================
  Widget _buildWordCloudSection(BuildContext context, ChatAnalytics a, Color cardColor, Color headingColor, Color subtleText, Color primary, bool isDark) {
    return _buildSectionCard(
      AppLocalizations.of(context)!.translate('global_word_cloud'),
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
    );
  }

  // ==================== ANNIVERSARY & CHAT AGE ====================
  Widget _buildAnniversarySection(BuildContext context, ChatAnalytics a, Color cardColor, Color headingColor, Color bodyText, Color subtleText, Color primary, bool isDark) {
    final firstDate = a.firstMessageDate!;
    final now = DateTime.now();
    final diff = now.difference(firstDate);
    final days = diff.inDays;
    final years = days ~/ 365;
    final months = (days % 365) ~/ 30;
    final remainingDays = (days % 365) % 30;
    
    // Check if anniversary is this week
    final thisYear = DateTime(now.year, firstDate.month, firstDate.day);
    final daysUntilAnniversary = thisYear.difference(now).inDays;
    final isAnniversarySoon = daysUntilAnniversary >= 0 && daysUntilAnniversary <= 7;
    final isAnniversaryToday = daysUntilAnniversary == 0;
    
    return _buildSectionCard(
      AppLocalizations.of(context)!.translate('chat_anniversary'),
      Icons.cake_rounded,
      cardColor,
      subtleText,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Anniversary badge
          if (isAnniversaryToday)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [primary, primary.withOpacity(0.7)]),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.celebration, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(AppLocalizations.of(context)!.translate('anniversary_today'), style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
            )
          else if (isAnniversarySoon)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: primary.withOpacity(0.3)),
              ),
              child: Text(
                AppLocalizations.of(context)!.translate('anniversary_in_days').replaceAll('{days}', '$daysUntilAnniversary'),
                style: TextStyle(color: primary, fontWeight: FontWeight.w600)
              ),
            ),
          
          // Chat age
          Row(
            children: [
              Icon(Icons.access_time_rounded, color: primary, size: 20),
              const SizedBox(width: 8),
              Text(
                AppLocalizations.of(context)!.translate('chatting_for'), 
                style: TextStyle(color: bodyText, fontSize: 15)
              ),
              Text(
                years > 0 
                    ? AppLocalizations.of(context)!.translate('years_count').replaceAll('{years}', '$years').replaceAll('{months}', '$months').replaceAll('{days}', '$remainingDays')
                    : months > 0 
                        ? AppLocalizations.of(context)!.translate('months_count').replaceAll('{months}', '$months').replaceAll('{days}', '$remainingDays')
                        : AppLocalizations.of(context)!.translate('days_count').replaceAll('{days}', '$days'),
                style: TextStyle(color: primary, fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.calendar_today_rounded, color: subtleText, size: 16),
              const SizedBox(width: 8),
              Text(
                AppLocalizations.of(context)!.translate('first_message_date').replaceAll('{date}', '${firstDate.day}/${firstDate.month}/${firstDate.year}'),
                style: TextStyle(color: subtleText, fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== WHO WOULD WIN ====================
  // ==================== WHO WOULD WIN / LEADERBOARD ====================
  Widget _buildWhoWouldWinSection(BuildContext context, ChatAnalytics a, Color cardColor, Color headingColor, Color bodyText, Color subtleText, Color primary, bool isDark) {
    final names = a.personStats.keys.toList();
    if (names.isEmpty) return const SizedBox.shrink();
    
    // 2-Person Head-to-Head (Keep existing style)
    if (names.length == 2) {
      final p1 = a.personStats[names[0]]!;
      final p2 = a.personStats[names[1]]!;
      
      return _buildSectionCard(
        AppLocalizations.of(context)!.translate('who_would_win'),
        Icons.emoji_events_rounded,
        cardColor,
        subtleText,
        Column(
          children: [
            _buildComparisonRow(AppLocalizations.of(context)!.translate('most_messages'), names[0], p1.messages, names[1], p2.messages, Icons.chat_bubble, primary, bodyText, subtleText, isDark),
            const SizedBox(height: 12),
            _buildComparisonRow(AppLocalizations.of(context)!.translate('most_words'), names[0], p1.words, names[1], p2.words, Icons.text_fields, primary, bodyText, subtleText, isDark),
            const SizedBox(height: 12),
            _buildComparisonRow(AppLocalizations.of(context)!.translate('most_emojis'), names[0], p1.emojis, names[1], p2.emojis, Icons.emoji_emotions, primary, bodyText, subtleText, isDark),
            const SizedBox(height: 12),
            _buildComparisonRow(AppLocalizations.of(context)!.translate('most_media'), names[0], p1.media, names[1], p2.media, Icons.photo, primary, bodyText, subtleText, isDark),
            const SizedBox(height: 12),
            _buildComparisonRow(AppLocalizations.of(context)!.translate('most_links'), names[0], p1.links, names[1], p2.links, Icons.link, primary, bodyText, subtleText, isDark),
          ],
        ),
      );
    }

    // N-Person Leaderboard
    return _buildSectionCard(
      AppLocalizations.of(context)!.translate('leaderboard'),
      Icons.leaderboard_rounded,
      cardColor,
      subtleText,
      Column(
        children: [
          _buildRankedList(a, AppLocalizations.of(context)!.translate('most_messages'), (p) => p.messages, Icons.chat_bubble, primary, bodyText, subtleText, isDark),
          const SizedBox(height: 16),
          _buildRankedList(a, AppLocalizations.of(context)!.translate('most_words'), (p) => p.words, Icons.text_fields, primary, bodyText, subtleText, isDark),
          const SizedBox(height: 16),
          _buildRankedList(a, AppLocalizations.of(context)!.translate('most_emojis'), (p) => p.emojis, Icons.emoji_emotions, primary, bodyText, subtleText, isDark),
          const SizedBox(height: 16),
          _buildRankedList(a, AppLocalizations.of(context)!.translate('most_media'), (p) => p.media, Icons.photo, primary, bodyText, subtleText, isDark),
        ],
      ),
    );
  }

  Widget _buildRankedList(ChatAnalytics a, String title, int Function(PersonStats) getter, IconData icon, Color primary, Color bodyText, Color subtleText, bool isDark) {
    final sorted = a.personStats.values.toList()
      ..sort((a, b) => getter(b).compareTo(getter(a)));
    final top3 = sorted.take(3).toList();
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
  
  Widget _buildComparisonRow(String title, String name1, int val1, String name2, int val2, IconData icon, Color primary, Color bodyText, Color subtleText, bool isDark) {
    final winner = val1 > val2 ? 1 : val1 < val2 ? 2 : 0;
    final total = val1 + val2;
    final pct1 = total > 0 ? (val1 / total * 100).round() : 50;
    final pct2 = total > 0 ? (val2 / total * 100).round() : 50;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: primary),
              const SizedBox(width: 6),
              Text(title, style: TextStyle(color: subtleText, fontSize: 12, fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // Person 1
              Expanded(
                child: Row(
                  children: [
                    if (winner == 1) Icon(Icons.emoji_events, color: Colors.amber, size: 16),
                    if (winner == 1) const SizedBox(width: 4),
                    Flexible(child: Text(_shortenName(name1), style: TextStyle(color: winner == 1 ? primary : bodyText, fontWeight: winner == 1 ? FontWeight.bold : FontWeight.normal, fontSize: 13), overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: 4),
                    Text('$pct1%', style: TextStyle(color: subtleText, fontSize: 11)),
                  ],
                ),
              ),
              Text('vs', style: TextStyle(color: subtleText, fontSize: 11)),
              // Person 2
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text('$pct2%', style: TextStyle(color: subtleText, fontSize: 11)),
                    const SizedBox(width: 4),
                    Flexible(child: Text(_shortenName(name2), style: TextStyle(color: winner == 2 ? primary : bodyText, fontWeight: winner == 2 ? FontWeight.bold : FontWeight.normal, fontSize: 13), overflow: TextOverflow.ellipsis)),
                    if (winner == 2) const SizedBox(width: 4),
                    if (winner == 2) Icon(Icons.emoji_events, color: Colors.amber, size: 16),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Row(
              children: [
                Expanded(flex: pct1, child: Container(height: 6, color: winner == 1 ? primary : primary.withOpacity(0.4))),
                Expanded(flex: pct2, child: Container(height: 6, color: winner == 2 ? Colors.teal : Colors.teal.withOpacity(0.4))),
              ],
            ),
          ),
        ],
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

  // ==================== CHAT MILESTONES ====================
  Widget _buildMilestonesSection(BuildContext context, ChatAnalytics a, Color cardColor, Color headingColor, Color bodyText, Color subtleText, Color primary, bool isDark) {
    final milestones = [100, 500, 1000, 5000, 10000, 25000, 50000, 100000];
    final achieved = milestones.where((m) => a.totalMessages >= m).toList();
    final nextMilestone = milestones.firstWhere((m) => a.totalMessages < m, orElse: () => a.totalMessages * 2);
    final progress = a.totalMessages / nextMilestone;
    
    return _buildSectionCard(
      AppLocalizations.of(context)!.translate('milestones'),
      Icons.military_tech_rounded,
      cardColor,
      subtleText,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Achieved milestones
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: achieved.map((m) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Colors.amber.shade400, Colors.orange]),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.amber.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle, color: Colors.white, size: 14),
                  const SizedBox(width: 4),
                  Text(_fmtMilestone(m), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
            )).toList(),
          ),
          const SizedBox(height: 16),
          // Progress to next
          Text(AppLocalizations.of(context)!.translate('next_milestone').replaceAll('{count}', _fmtMilestone(nextMilestone)), style: TextStyle(color: bodyText, fontSize: 13)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation(primary),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 4),
          Text(AppLocalizations.of(context)!.translate('milestone_progress').replaceAll('{percent}', (progress * 100).toStringAsFixed(1)).replaceAll('{remaining}', '${nextMilestone - a.totalMessages}'), style: TextStyle(color: subtleText, fontSize: 11)),
        ],
      ),
    );
  }
  
  String _fmtMilestone(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(0)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)}K';
    return n.toString();
  }

  // ==================== PREDICTIONS ====================
  Widget _buildPredictionsSection(BuildContext context, ChatAnalytics a, Color cardColor, Color headingColor, Color bodyText, Color subtleText, Color primary, bool isDark) {
    final firstDate = a.firstMessageDate!;
    final now = DateTime.now();
    final daysSinceStart = now.difference(firstDate).inDays.clamp(1, 999999);
    final messagesPerDay = a.totalMessages / daysSinceStart;
    
    // Predict future milestones
    final predictions = <String, String>{};
    final futureMilestones = [100000, 500000, 1000000];
    for (final target in futureMilestones) {
      if (a.totalMessages < target) {
        final daysNeeded = ((target - a.totalMessages) / messagesPerDay).ceil();
        final predictedDate = now.add(Duration(days: daysNeeded));
        predictions['${_fmtMilestone(target)} messages'] = '${predictedDate.day}/${predictedDate.month}/${predictedDate.year}';
      }
    }
    
    return _buildSectionCard(
      AppLocalizations.of(context)!.translate('future_predictions'),
      Icons.auto_awesome,
      cardColor,
      subtleText,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: primary.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.speed, color: primary),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(AppLocalizations.of(context)!.translate('current_rate'), style: TextStyle(color: subtleText, fontSize: 11)),
                    Text(AppLocalizations.of(context)!.translate('msgs_per_day').replaceAll('{count}', messagesPerDay.toStringAsFixed(1)), style: TextStyle(color: primary, fontWeight: FontWeight.bold, fontSize: 15)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (predictions.isNotEmpty) ...[
            Text(AppLocalizations.of(context)!.translate('at_this_rate'), style: TextStyle(color: bodyText, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            ...predictions.entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(Icons.flag, size: 16, color: Colors.amber),
                  const SizedBox(width: 8),
                  Text(e.key, style: TextStyle(color: bodyText, fontSize: 13)),
                  const Spacer(),
                  Text(AppLocalizations.of(context)!.translate('by_date').replaceAll('{date}', e.value), style: TextStyle(color: primary, fontWeight: FontWeight.w600, fontSize: 13)),
                ],
              ),
            )),
          ] else
            Text(AppLocalizations.of(context)!.translate('all_milestones_hit'), style: TextStyle(color: primary, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ==================== SHARED WIDGETS ====================
  Widget _buildHeroStat(String label, String value, IconData icon, Color headingColor, Color subtleText, Color primary) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 22, color: primary),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: subtleText,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: headingColor,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color cardColor, Color headingColor, Color bodyText, Color primary) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: primary.withOpacity(0.7)),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: headingColor,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 13, color: bodyText)),
        ],
      ),
    );
  }

  Widget _buildClickableStreakCard(
    BuildContext context,
    String label, 
    String value, 
    IconData icon, 
    Color cardColor, 
    Color headingColor, 
    Color bodyText, 
    Color primary,
    Color subtleText,
    DateTime? startDate,
    DateTime? endDate,
  ) {
    return GestureDetector(
      onTap: () => _showStreakDates(context, label, startDate, endDate, headingColor, subtleText, primary),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, size: 20, color: primary.withOpacity(0.7)),
                Icon(Icons.touch_app_rounded, size: 14, color: subtleText.withOpacity(0.5)),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: headingColor,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 13, color: bodyText)),
          ],
        ),
      ),
    );
  }

  void _showStreakDates(BuildContext context, String label, DateTime? startDate, DateTime? endDate, Color headingColor, Color subtleText, Color primary) {
    const months = ['January', 'February', 'March', 'April', 'May', 'June', 
                    'July', 'August', 'September', 'October', 'November', 'December'];
    
    String formatDate(DateTime d) => '${months[d.month - 1]} ${d.day}, ${d.year}';
    
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Title
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: headingColor,
                  ),
                ),
                const SizedBox(height: 24),
                // Date range card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF7F7F7),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      if (startDate != null && endDate != null) ...[
                        Icon(
                          Icons.calendar_month_rounded,
                          size: 48,
                          color: primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          formatDate(startDate),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: headingColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Icon(Icons.arrow_downward_rounded, size: 24, color: subtleText),
                        const SizedBox(height: 8),
                        Text(
                          formatDate(endDate),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: headingColor,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: primary.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            AppLocalizations.of(context)!.translate('consecutive_days').replaceAll('{count}', '${endDate.difference(startDate).inDays + 1}'),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: primary,
                            ),
                          ),
                        ),
                      ] else ...[
                        Icon(
                          Icons.hourglass_empty_rounded,
                          size: 48,
                          color: subtleText,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          AppLocalizations.of(context)!.translate('no_streak_data'),
                          style: TextStyle(
                            fontSize: 16,
                            color: subtleText,
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

  Widget _buildSectionCard(String title, IconData icon, Color cardColor, Color subtleText, Widget child) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: subtleText),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: subtleText,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildFunFact(String text, Color textColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('•', style: TextStyle(fontSize: 16, color: textColor, height: 1.4)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: TextStyle(fontSize: 15, color: textColor, height: 1.4)),
        ),
      ],
    );
  }

  String _getTimeComparison(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    if (readingTimeMinutes >= 120) {
      return loc.translate('time_comparison_movies').replaceAll('{count}', (readingTimeMinutes / 120).toStringAsFixed(0));
    } else if (readingTimeMinutes >= 45) {
      return loc.translate('time_comparison_podcasts').replaceAll('{count}', (readingTimeMinutes / 45).toStringAsFixed(0));
    } else if (readingTimeMinutes >= 3) {
      return loc.translate('time_comparison_coffee').replaceAll('{min}', readingTimeMinutes.toStringAsFixed(0));
    } else {
      return loc.translate('time_comparison_short');
    }
  }
}

// ==================== Helper class ====================
class _QuickStat {
  final String label;
  final String value;
  final IconData icon;
  const _QuickStat(this.label, this.value, this.icon);
}

// ==================== TOP WORDS WIDGET (Stateful for tab switching) ====================
class _TopWordsWidget extends StatefulWidget {
  final ChatAnalytics analytics;
  final List<String> tabs;
  final Color headingColor, bodyText, subtleText, primary, cardColor;
  final bool isDark;

  const _TopWordsWidget({
    required this.analytics,
    required this.tabs,
    required this.headingColor,
    required this.bodyText,
    required this.subtleText,
    required this.primary,
    required this.isDark,
    required this.cardColor,
  });

  @override
  State<_TopWordsWidget> createState() => _TopWordsWidgetState();
}

class _TopWordsWidgetState extends State<_TopWordsWidget> {
  int _selectedTab = 0;
  bool _filterByLength = false;
  int _wordLength = 4; // The target word length (1-12, where 12 means 12+)

  List<MapEntry<String, int>> _getWords() {
    List<MapEntry<String, int>> words;
    
    if (_filterByLength) {
      // Use optimized length-based methods - filters at source
      final isMinLength = _wordLength >= 12;
      final length = isMinLength ? 12 : _wordLength;
      
      if (_selectedTab == 0) {
        words = widget.analytics.totalTopWordsByLength(10, length, isMinLength: isMinLength);
      } else {
        final name = widget.tabs[_selectedTab];
        final ps = widget.analytics.personStats[name];
        words = ps?.topWordsByLength(10, length, isMinLength: isMinLength) ?? [];
      }
    } else {
      // No filter - just get top 10 words
      if (_selectedTab == 0) {
        words = widget.analytics.totalTopWords(10);
      } else {
        final name = widget.tabs[_selectedTab];
        final ps = widget.analytics.personStats[name];
        words = ps?.topWords(10) ?? [];
      }
    }
    
    return words;
  }

  String _fmtNum(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }

  @override
  Widget build(BuildContext context) {
    final words = _getWords();
    final colors = [
      widget.primary,
      widget.primary.withOpacity(0.7),
      Colors.amber[700]!,
      Colors.teal,
      Colors.orange[600]!,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tab chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(widget.tabs.length, (i) {
              final selected = _selectedTab == i;
              return Padding(
                padding: EdgeInsets.only(right: i < widget.tabs.length - 1 ? 8 : 0),
                child: GestureDetector(
                  onTap: () => setState(() => _selectedTab = i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected
                          ? (colors[i % colors.length]).withOpacity(0.15)
                          : widget.isDark
                              ? const Color(0xFF2A2A2A)
                              : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected
                            ? colors[i % colors.length]
                            : widget.isDark
                                ? Colors.grey[700]!
                                : Colors.grey[300]!,
                        width: selected ? 1.5 : 1,
                      ),
                    ),
                    child: Text(
                      widget.tabs[i],
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected ? colors[i % colors.length] : widget.bodyText,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 16),
        
        // By Length toggle
        Row(
          children: [
            Text(
              AppLocalizations.of(context)!.translate('by_length'),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: widget.subtleText,
              ),
            ),
            const SizedBox(width: 8),
            Transform.scale(
              scale: 0.8,
              child: Switch(
                value: _filterByLength,
                onChanged: (v) => setState(() => _filterByLength = v),
                activeColor: widget.primary,
                activeTrackColor: widget.primary.withOpacity(0.4),
                inactiveThumbColor: widget.isDark ? Colors.grey[400] : Colors.grey[600],
                inactiveTrackColor: widget.isDark ? Colors.grey[700] : Colors.grey[300],
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            if (_filterByLength) ...[
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: widget.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _wordLength >= 12 
                      ? AppLocalizations.of(context)!.translate('chars_12_plus')
                      : AppLocalizations.of(context)!.translate('chars_count').replaceAll('{count}', '$_wordLength'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: widget.primary,
                  ),
                ),
              ),
            ],
          ],
        ),
        
        // Length slider (only visible when toggle is on)
        if (_filterByLength) ...[
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
              activeTrackColor: widget.primary,
              inactiveTrackColor: widget.isDark ? Colors.grey[700] : Colors.grey[300],
              thumbColor: widget.primary,
              overlayColor: widget.primary.withOpacity(0.2),
            ),
            child: Slider(
              value: _wordLength.toDouble(),
              min: 1,
              max: 12,
              divisions: 11,
              onChanged: (v) => setState(() => _wordLength = v.round()),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('1', style: TextStyle(fontSize: 11, color: widget.subtleText)),
              Text('12+', style: TextStyle(fontSize: 11, color: widget.subtleText)),
            ],
          ),
        ],
        
        const SizedBox(height: 16),

        // Word grid
        if (words.isEmpty)
          Text(
            _filterByLength 
                ? (_wordLength >= 12 
                    ? AppLocalizations.of(context)!.translate('no_words_12_plus')
                    : AppLocalizations.of(context)!.translate('no_words_length').replaceAll('{count}', '$_wordLength'))
                : AppLocalizations.of(context)!.translate('no_words_found'), 
            style: TextStyle(color: widget.subtleText, fontSize: 14),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: words.map((entry) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: widget.isDark ? const Color(0xFF2A2A2A) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: widget.isDark ? Colors.grey[800]! : Colors.grey[200]!,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      entry.key,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: widget.headingColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: widget.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _fmtNum(entry.value),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: widget.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}

