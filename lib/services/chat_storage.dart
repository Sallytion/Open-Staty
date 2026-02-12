import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/chat_analytics.dart';

class SavedChat {
  final String id;
  final String name;
  final int wordCount;
  final double readingTimeMinutes;
  final DateTime importedAt;
  final ChatAnalytics? analytics;

  SavedChat({
    required this.id,
    required this.name,
    required this.wordCount,
    required this.readingTimeMinutes,
    required this.importedAt,
    this.analytics,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'wordCount': wordCount,
        'readingTimeMinutes': readingTimeMinutes,
        'importedAt': importedAt.toIso8601String(),
        'analytics': analytics?.toJson(),
      };

  factory SavedChat.fromJson(Map<String, dynamic> json) => SavedChat(
        id: json['id'] as String,
        name: json['name'] as String,
        wordCount: json['wordCount'] as int,
        readingTimeMinutes: (json['readingTimeMinutes'] as num).toDouble(),
        importedAt: DateTime.parse(json['importedAt'] as String),
        analytics: json['analytics'] != null
            ? ChatAnalytics.fromJson(json['analytics'] as Map<String, dynamic>)
            : null,
      );
}

class ChatStorage {
  static const _fileName = 'saved_chats.json';

  static Future<File> _getFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  static Future<List<SavedChat>> loadChats() async {
    try {
      final file = await _getFile();
      if (!await file.exists()) return [];
      final contents = await file.readAsString();
      final List<dynamic> jsonList = json.decode(contents);
      return jsonList.map((j) => SavedChat.fromJson(j)).toList();
    } catch (e) {
      return [];
    }
  }

  static Future<void> saveChat(SavedChat chat) async {
    final chats = await loadChats();
    chats.insert(0, chat); // newest first
    await _writeChats(chats);
  }

  static Future<void> deleteChat(String id) async {
    final chats = await loadChats();
    chats.removeWhere((c) => c.id == id);
    await _writeChats(chats);
  }

  static Future<void> renameChat(String id, String newName) async {
    final chats = await loadChats();
    final index = chats.indexWhere((c) => c.id == id);
    if (index != -1) {
      final old = chats[index];
      chats[index] = SavedChat(
        id: old.id,
        name: newName,
        wordCount: old.wordCount,
        readingTimeMinutes: old.readingTimeMinutes,
        importedAt: old.importedAt,
        analytics: old.analytics,
      );
      await _writeChats(chats);
    }
  }

  static Future<void> _writeChats(List<SavedChat> chats) async {
    final file = await _getFile();
    final jsonString = json.encode(chats.map((c) => c.toJson()).toList());
    await file.writeAsString(jsonString);
  }
}
