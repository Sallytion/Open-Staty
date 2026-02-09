import 'dart:convert';

/// Per-person statistics
class PersonStats {
  final String name;
  int messages;
  int words;
  int letters;
  int media;
  int deleted;
  int links;
  int emojis;
  Map<String, int> wordFrequency;
  
  // Response time tracking
  double totalResponseTimeMinutes;
  int responseCount;
  int conversationsStarted;
  
  // Hourly activity tracking
  Map<int, int> hourlyActivityMap; // hour (0-23) -> message count
  
  // Weekday activity tracking
  Map<int, int> weekdayActivityMap; // weekday (1=Monday to 7=Sunday) -> message count

  PersonStats({
    required this.name,
    this.messages = 0,
    this.words = 0,
    this.letters = 0,
    this.media = 0,
    this.deleted = 0,
    this.links = 0,
    this.emojis = 0,
    Map<String, int>? wordFrequency,
    this.totalResponseTimeMinutes = 0.0,
    this.responseCount = 0,
    this.conversationsStarted = 0,
    Map<int, int>? hourlyActivityMap,
    Map<int, int>? weekdayActivityMap,
  }) : wordFrequency = wordFrequency ?? {},
       hourlyActivityMap = hourlyActivityMap ?? {},
       weekdayActivityMap = weekdayActivityMap ?? {};

  /// Average response time in minutes
  double get averageResponseTimeMinutes =>
      responseCount > 0 ? totalResponseTimeMinutes / responseCount : 0.0;

  /// Top N words sorted by frequency
  List<MapEntry<String, int>> topWords(int n) {
    final sorted = wordFrequency.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(n).toList();
  }

  /// Top N words of exact length (or >= length if isMinLength is true)
  List<MapEntry<String, int>> topWordsByLength(int n, int length, {bool isMinLength = false}) {
    final filtered = wordFrequency.entries.where((e) =>
        isMinLength ? e.key.length >= length : e.key.length == length);
    final sorted = filtered.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(n).toList();
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'messages': messages,
        'words': words,
        'letters': letters,
        'media': media,
        'deleted': deleted,
        'links': links,
        'emojis': emojis,
        'wordFrequency': wordFrequency,
        'totalResponseTimeMinutes': totalResponseTimeMinutes,
        'responseCount': responseCount,
        'conversationsStarted': conversationsStarted,
        'hourlyActivityMap': hourlyActivityMap.map((k, v) => MapEntry(k.toString(), v)),
        'weekdayActivityMap': weekdayActivityMap.map((k, v) => MapEntry(k.toString(), v)),
      };

  factory PersonStats.fromJson(Map<String, dynamic> json) => PersonStats(
        name: json['name'] as String,
        messages: json['messages'] as int? ?? 0,
        words: json['words'] as int? ?? 0,
        letters: json['letters'] as int? ?? 0,
        media: json['media'] as int? ?? 0,
        deleted: json['deleted'] as int? ?? 0,
        links: json['links'] as int? ?? 0,
        emojis: json['emojis'] as int? ?? 0,
        wordFrequency: (json['wordFrequency'] as Map<String, dynamic>?)
                ?.map((k, v) => MapEntry(k, v as int)) ??
            {},
        totalResponseTimeMinutes: (json['totalResponseTimeMinutes'] as num?)?.toDouble() ?? 0.0,
        responseCount: json['responseCount'] as int? ?? 0,
        conversationsStarted: json['conversationsStarted'] as int? ?? 0,
        hourlyActivityMap: json['hourlyActivityMap'] != null
            ? (json['hourlyActivityMap'] as Map<String, dynamic>)
                .map((k, v) => MapEntry(int.parse(k), (v as num).toInt()))
            : {},
        weekdayActivityMap: json['weekdayActivityMap'] != null
            ? (json['weekdayActivityMap'] as Map<String, dynamic>)
                .map((k, v) => MapEntry(int.parse(k), (v as num).toInt()))
            : {},
      );
}


/// Full analytics for a chat
class ChatAnalytics {
  final int totalWords;
  final double readingTimeMinutes;
  final int totalMessages;
  final int longestStreak;
  final int currentStreak;
  final Map<String, PersonStats> personStats; // name -> stats
  final Map<String, int> activityMap; // "yyyy-MM-dd" -> message count
  final Map<String, int> totalWordFrequency; // word -> count (combined)
  final Map<int, int> hourlyActivityMap; // hour (0-23) -> message count
  final Map<int, int> weekdayActivityMap; // weekday (1=Monday to 7=Sunday) -> message count
  final DateTime? firstMessageDate;
  final DateTime? lastMessageDate;
  
  // Streak date ranges
  final DateTime? longestStreakStart;
  final DateTime? longestStreakEnd;
  final DateTime? currentStreakStart;
  final DateTime? currentStreakEnd;

  ChatAnalytics({
    required this.totalWords,
    required this.readingTimeMinutes,
    required this.totalMessages,
    required this.longestStreak,
    required this.currentStreak,
    required this.personStats,
    required this.activityMap,
    required this.totalWordFrequency,
    this.hourlyActivityMap = const {},
    this.weekdayActivityMap = const {},
    this.firstMessageDate,
    this.lastMessageDate,
    this.longestStreakStart,
    this.longestStreakEnd,
    this.currentStreakStart,
    this.currentStreakEnd,
  });

  List<String> get personNames => personStats.keys.toList();

  List<MapEntry<String, int>> totalTopWords(int n) {
    final sorted = totalWordFrequency.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(n).toList();
  }

  /// Top N words of exact length (or >= length if isMinLength is true)
  List<MapEntry<String, int>> totalTopWordsByLength(int n, int length, {bool isMinLength = false}) {
    final filtered = totalWordFrequency.entries.where((e) =>
        isMinLength ? e.key.length >= length : e.key.length == length);
    final sorted = filtered.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(n).toList();
  }

  Map<String, dynamic> toJson() => {
        'totalWords': totalWords,
        'readingTimeMinutes': readingTimeMinutes,
        'totalMessages': totalMessages,
        'longestStreak': longestStreak,
        'currentStreak': currentStreak,
        'personStats':
            personStats.map((k, v) => MapEntry(k, v.toJson())),
        'activityMap': activityMap,
        'totalWordFrequency': totalWordFrequency,
        'hourlyActivityMap': hourlyActivityMap.map((k, v) => MapEntry(k.toString(), v)),
        'weekdayActivityMap': weekdayActivityMap.map((k, v) => MapEntry(k.toString(), v)),
        'firstMessageDate': firstMessageDate?.toIso8601String(),
        'lastMessageDate': lastMessageDate?.toIso8601String(),
        'longestStreakStart': longestStreakStart?.toIso8601String(),
        'longestStreakEnd': longestStreakEnd?.toIso8601String(),
        'currentStreakStart': currentStreakStart?.toIso8601String(),
        'currentStreakEnd': currentStreakEnd?.toIso8601String(),
      };

  factory ChatAnalytics.fromJson(Map<String, dynamic> json) {
    return ChatAnalytics(
      totalWords: json['totalWords'] as int,
      readingTimeMinutes: (json['readingTimeMinutes'] as num).toDouble(),
      totalMessages: json['totalMessages'] as int? ?? 0,
      longestStreak: json['longestStreak'] as int? ?? 0,
      currentStreak: json['currentStreak'] as int? ?? 0,
      personStats: (json['personStats'] as Map<String, dynamic>?)
              ?.map((k, v) =>
                  MapEntry(k, PersonStats.fromJson(v as Map<String, dynamic>))) ??
          {},
      activityMap: (json['activityMap'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, v as int)) ??
          {},
      totalWordFrequency: (json['totalWordFrequency'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, v as int)) ??
          {},
      hourlyActivityMap: json['hourlyActivityMap'] != null
              ? (json['hourlyActivityMap'] as Map<String, dynamic>)
                  .map((k, v) => MapEntry(int.parse(k), (v as num).toInt()))
              : {},
      weekdayActivityMap: json['weekdayActivityMap'] != null
              ? (json['weekdayActivityMap'] as Map<String, dynamic>)
                  .map((k, v) => MapEntry(int.parse(k), (v as num).toInt()))
              : {},
      firstMessageDate: json['firstMessageDate'] != null
          ? DateTime.parse(json['firstMessageDate'] as String)
          : null,
      lastMessageDate: json['lastMessageDate'] != null
          ? DateTime.parse(json['lastMessageDate'] as String)
          : null,
      longestStreakStart: json['longestStreakStart'] != null
          ? DateTime.parse(json['longestStreakStart'] as String)
          : null,
      longestStreakEnd: json['longestStreakEnd'] != null
          ? DateTime.parse(json['longestStreakEnd'] as String)
          : null,
      currentStreakStart: json['currentStreakStart'] != null
          ? DateTime.parse(json['currentStreakStart'] as String)
          : null,
      currentStreakEnd: json['currentStreakEnd'] != null
          ? DateTime.parse(json['currentStreakEnd'] as String)
          : null,
    );
  }

  String encode() => json.encode(toJson());
  static ChatAnalytics decode(String s) =>
      ChatAnalytics.fromJson(json.decode(s) as Map<String, dynamic>);
}
