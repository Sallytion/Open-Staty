import '../models/chat_analytics.dart';
import 'chat_storage.dart';

class StatsAggregator {
  /// Aggregates a list of saved chats into a single ChatAnalytics object
  static ChatAnalytics aggregate(List<SavedChat> chats) {
    if (chats.isEmpty) {
      return ChatAnalytics(
        totalWords: 0,
        readingTimeMinutes: 0,
        totalMessages: 0,
        longestStreak: 0,
        currentStreak: 0,
        personStats: {},
        activityMap: {},
        totalWordFrequency: {},
      );
    }

    int totalWords = 0;
    double totalReadingTime = 0;
    int totalMessages = 0;
    
    // Maps for aggregation
    final Map<String, PersonStats> personStatsMap = {};
    final Map<String, int> activityMap = {};
    final Map<String, int> totalWordFrequency = {};
    final Map<int, int> hourlyActivityMap = {};
    final Map<int, int> weekdayActivityMap = {};
    
    // Dates for global range
    DateTime? firstMessageDate;
    DateTime? lastMessageDate;

    for (final chat in chats) {
      final a = chat.analytics;
      if (a == null) continue;

      totalWords += a.totalWords;
      totalReadingTime += a.readingTimeMinutes;
      totalMessages += a.totalMessages;

      // Update date range
      if (a.firstMessageDate != null) {
        if (firstMessageDate == null || a.firstMessageDate!.isBefore(firstMessageDate)) {
          firstMessageDate = a.firstMessageDate;
        }
      }
      if (a.lastMessageDate != null) {
        if (lastMessageDate == null || a.lastMessageDate!.isAfter(lastMessageDate)) {
          lastMessageDate = a.lastMessageDate;
        }
      }

      // Aggregate Activity Map
      a.activityMap.forEach((date, count) {
        activityMap[date] = (activityMap[date] ?? 0) + count;
      });

      // Aggregate Hourly Activity
      a.hourlyActivityMap.forEach((hour, count) {
        hourlyActivityMap[hour] = (hourlyActivityMap[hour] ?? 0) + count;
      });

      // Aggregate Weekday Activity
      a.weekdayActivityMap.forEach((day, count) {
        weekdayActivityMap[day] = (weekdayActivityMap[day] ?? 0) + count;
      });

      // Aggregate Word Frequency
      a.totalWordFrequency.forEach((word, count) {
        totalWordFrequency[word] = (totalWordFrequency[word] ?? 0) + count;
      });

      // Aggregate Person Stats
      a.personStats.forEach((name, stats) {
        if (!personStatsMap.containsKey(name)) {
          personStatsMap[name] = PersonStats(name: name);
        }
        
        final existing = personStatsMap[name]!;
        
        // Sum simple counters
        existing.messages += stats.messages;
        existing.words += stats.words;
        existing.letters += stats.letters;
        existing.media += stats.media;
        existing.deleted += stats.deleted;
        existing.links += stats.links;
        existing.emojis += stats.emojis;
        existing.responseCount += stats.responseCount;
        existing.conversationsStarted += stats.conversationsStarted;
        
        // Weighted average for response time (approximation)
        // totalTime = avg * count. New avg = (totalTime1 + totalTime2) / (count1 + count2)
        existing.totalResponseTimeMinutes += stats.totalResponseTimeMinutes;
        
        // Merge person's word frequency
        stats.wordFrequency.forEach((w, c) {
          existing.wordFrequency[w] = (existing.wordFrequency[w] ?? 0) + c;
        });

        // Merge person's hourly/weekday activity
        stats.hourlyActivityMap.forEach((h, c) {
          existing.hourlyActivityMap[h] = (existing.hourlyActivityMap[h] ?? 0) + c;
        });
        
        stats.weekdayActivityMap.forEach((d, c) {
          existing.weekdayActivityMap[d] = (existing.weekdayActivityMap[d] ?? 0) + c;
        });
      });
    }

    // Recalculate Streaks based on combined activityMap
    final streaks = _calculateStreaks(activityMap);

    return ChatAnalytics(
      totalWords: totalWords,
      readingTimeMinutes: totalReadingTime,
      totalMessages: totalMessages,
      longestStreak: streaks['longest'] ?? 0,
      currentStreak: streaks['current'] ?? 0,
      personStats: personStatsMap,
      activityMap: activityMap,
      totalWordFrequency: totalWordFrequency,
      hourlyActivityMap: hourlyActivityMap,
      weekdayActivityMap: weekdayActivityMap,
      firstMessageDate: firstMessageDate,
      lastMessageDate: lastMessageDate,
    );
  }

  static Map<String, int> _calculateStreaks(Map<String, int> activityMap) {
    if (activityMap.isEmpty) return {'longest': 0, 'current': 0};

    final sortedDates = activityMap.keys
        .map((e) => DateTime.parse(e))
        .toList()
      ..sort();

    int maxStreak = 0;
    int currentStreak = 0;
    int tempStreak = 0;
    DateTime? lastDate;

    for (final date in sortedDates) {
      if (lastDate == null) {
        tempStreak = 1;
      } else {
        final diff = date.difference(lastDate).inDays;
        if (diff == 1) {
          tempStreak++;
        } else if (diff > 1) {
          if (tempStreak > maxStreak) maxStreak = tempStreak;
          tempStreak = 1;
        }
      }
      lastDate = date;
    }
    if (tempStreak > maxStreak) maxStreak = tempStreak;

    // Check if current streak is active (last message was today or yesterday)
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastMsgDate = sortedDates.last;
    
    if (lastMsgDate.isAtSameMomentAs(today) || 
        lastMsgDate.isAtSameMomentAs(today.subtract(const Duration(days: 1)))) {
      currentStreak = tempStreak;
    } else {
      currentStreak = 0;
    }

    return {'longest': maxStreak, 'current': currentStreak};
  }
}
