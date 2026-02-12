import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:external_app_launcher/external_app_launcher.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import '../services/chat_storage.dart';
import '../models/chat_analytics.dart';
import '../services/sentiment_analyzer.dart';
import 'chat_summary_page.dart';
import 'settings_page.dart';
import '../l10n/app_localizations.dart';
import '../main.dart';

class ImportAnalyzePage extends StatefulWidget {
  const ImportAnalyzePage({super.key});

  @override
  State<ImportAnalyzePage> createState() => ImportAnalyzePageState();
}

class ImportAnalyzePageState extends State<ImportAnalyzePage> {
  VoidCallback? onChatSaved;

  Future<void> _saveCurrentChat(String chatName, ChatAnalytics analytics) async {
    final chat = SavedChat(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: chatName,
      wordCount: analytics.totalWords,
      readingTimeMinutes: analytics.readingTimeMinutes,
      importedAt: DateTime.now(),
      analytics: analytics,
    );
    await ChatStorage.saveChat(chat);
    onChatSaved?.call();
  }

  void _navigateToSummary(String chatName, ChatAnalytics analytics) {
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatSummaryPage(
          chatName: chatName,
          wordCount: analytics.totalWords,
          readingTimeMinutes: analytics.readingTimeMinutes,
          importedAt: DateTime.now(),
          analytics: analytics,
        ),
      ),
    );
  }

  /// Shows a progress dialog that updates as parsing proceeds
  void _showProgressDialog(String fileName, ValueNotifier<double> progress) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return ValueListenableBuilder<double>(
          valueListenable: progress,
          builder: (_, value, __) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(28.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      AppLocalizations.of(context)?.translate('analyzing') ?? 'Analyzing',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      fileName.replaceAll('.zip', '').replaceAll('.txt', ''),
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey[400] : Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 24),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: value > 0 ? value : null,
                        minHeight: 6,
                        backgroundColor: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey[800] : Colors.grey[200],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      value > 0 
                          ? '${(value * 100).toInt()}%' 
                          : (AppLocalizations.of(context)?.translate('preparing') ?? 'Preparing...'),
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey[500] : Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Called from MainScreen when a file is shared to the app
  Future<void> processSharedFile(String filePath) async {
    print('📨 Processing shared file: $filePath');
    final progress = ValueNotifier<double>(0.0);
    
    try {
      final fileName = filePath.split('/').last.split('\\').last;
      
      if (mounted) {
        _showProgressDialog(fileName, progress);
      }

      String? chatContent;
      progress.value = 0.1;

      if (filePath.endsWith('.zip')) {
        print('📦 Extracting shared ZIP file...');
        chatContent = await _extractAndReadZip(filePath);
        progress.value = 0.3;
      } else if (filePath.endsWith('.txt')) {
        print('📖 Reading shared TXT file...');
        final file = File(filePath);
        chatContent = await file.readAsString();
        progress.value = 0.3;
      } else {
        try {
          final file = File(filePath);
          chatContent = await file.readAsString();
          progress.value = 0.3;
        } catch (e) {
          print('❌ Cannot read file as text: $e');
        }
      }

      if (chatContent != null && chatContent.isNotEmpty) {
        print('🔬 Parsing shared chat content (${chatContent.length} chars)...');
        final analytics = await _parseWhatsAppChat(chatContent, progress: progress);
        
        if (mounted) {
          Navigator.of(context).pop(); // close progress dialog
        }
        
        if (mounted) {
          await _saveCurrentChat(fileName, analytics);
          _navigateToSummary(fileName, analytics);
          print('✨ Shared file processed successfully!');
        }
      }
    } catch (e, stackTrace) {
      print('❌ ERROR processing shared file: $e');
      print('📚 Stack trace: $stackTrace');
      if (mounted) {
        try { Navigator.of(context).pop(); } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context)?.translate('error_processing_file')}: $e')),
        );
      }
    } finally {
      progress.dispose();
    }
  }

  void _showImportDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
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
                  AppLocalizations.of(context)?.translate('import_chat_title') ?? 'Import Chat',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                _buildOptionButton(
                  context,
                  icon: Icons.chat,
                  title: AppLocalizations.of(context)?.translate('import_whatsapp') ?? 'Import from WhatsApp',
                  onTap: () {
                    Navigator.pop(context);
                    _showWhatsAppStepsDialog(this.context);
                  },
                ),
                const SizedBox(height: 12),
                _buildOptionButton(
                  context,
                  icon: Icons.file_upload,
                  title: AppLocalizations.of(context)?.translate('import_file') ?? 'Import from file',
                  onTap: () {
                    Navigator.pop(context);
                    _pickFile();
                  },
                ),
                const SizedBox(height: 12),
                _buildOptionButton(
                  context,
                  icon: Icons.play_circle_outline,
                  title: AppLocalizations.of(context)?.translate('show_example') ?? 'Show example',
                  onTap: () {
                    Navigator.pop(context);
                    _openExample();
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOptionButton(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.grey[700]!
                : Colors.grey[300]!,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16),
          ],
        ),
      ),
    );
  }

  void _showWhatsAppStepsDialog(BuildContext context) {
    final loc = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  loc?.translate('import_whatsapp') ?? 'Import from WhatsApp',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                _buildStep('1', loc?.translate('wa_step_1') ?? 'Click "Open WhatsApp" button below'),
                const SizedBox(height: 16),
                _buildStep('2', loc?.translate('wa_step_2') ?? 'Open the chat you want to analyse'),
                const SizedBox(height: 16),
                _buildStep('3', loc?.translate('wa_step_3') ?? 'Click on ⋮ > More > Export Chat > Without Media'),
                const SizedBox(height: 16),
                _buildStep('4', loc?.translate('wa_step_4') ?? 'Share with Open Staty app'),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _openWhatsApp(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.open_in_new),
                        const SizedBox(width: 8),
                        Text(
                          loc?.translate('open_whatsapp') ?? 'Open WhatsApp',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
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

  Widget _buildStep(String stepNumber, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFF25D366).withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              stepNumber,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF25D366),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              description,
              style: const TextStyle(fontSize: 15),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openWhatsApp() async {
    await LaunchApp.openApp(
      androidPackageName: 'com.whatsapp',
      iosUrlScheme: 'whatsapp://',
      openStore: true,
    );
  }

  Future<void> _pickFile() async {
    final progress = ValueNotifier<double>(0.0);
    try {
      print('🔍 Opening file picker...');
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt', 'zip'],
      );

      print('📁 File picker result: ${result != null}');
      
      if (result != null && result.files.single.path != null) {
        String filePath = result.files.single.path!;
        String fileName = result.files.single.name;
        
        print('📄 Selected file: $fileName');

        if (mounted) {
          _showProgressDialog(fileName, progress);
        }

        String? chatContent;
        progress.value = 0.1;

        if (fileName.endsWith('.zip')) {
          print('📦 Extracting ZIP file...');
          chatContent = await _extractAndReadZip(filePath);
          progress.value = 0.3;
        } else if (fileName.endsWith('.txt')) {
          print('📖 Reading TXT file...');
          final file = File(filePath);
          chatContent = await file.readAsString();
          progress.value = 0.3;
        }

        if (chatContent != null && chatContent.isNotEmpty) {
          final analytics = await _parseWhatsAppChat(chatContent, progress: progress);
          
          // Close progress dialog
          if (mounted) Navigator.of(context).pop();
          
          if (mounted) {
            await _saveCurrentChat(fileName, analytics);
            _navigateToSummary(fileName, analytics);
          }
        } else {
          if (mounted) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(AppLocalizations.of(context)?.translate('failed_read_file') ?? 'Failed to read chat file')),
            );
          }
        }
      }
    } catch (e, stackTrace) {
      print('❌ ERROR in _pickFile: $e');
      print('📚 Stack trace: $stackTrace');
      if (mounted) {
        try { Navigator.of(context).pop(); } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context)?.translate('error_processing')}: $e')),
        );
      }
    } finally {
      progress.dispose();
    }
  }

  Future<String?> _extractAndReadZip(String zipPath) async {
    try {
      print('📦 Reading ZIP file from: $zipPath');
      // Read the zip file
      final bytes = File(zipPath).readAsBytesSync();
      print('📦 ZIP file size: ${bytes.length} bytes');
      
      final archive = ZipDecoder().decodeBytes(bytes);
      print('📦 ZIP contains ${archive.length} files');

      // Find the .txt file in the archive
      for (final file in archive) {
        print('📄 Found file in ZIP: ${file.name} (isFile: ${file.isFile})');
        if (file.isFile && file.name.endsWith('.txt')) {
          print('✅ Extracting TXT file: ${file.name}');
          // Extract and decode as UTF-8 (WhatsApp exports are always UTF-8)
          final content = file.content as List<int>;
          final text = utf8.decode(content, allowMalformed: true);
          print('✅ Extracted ${text.length} characters');
          return text;
        }
      }
      print('❌ No .txt file found in ZIP');
      return null;
    } catch (e, stackTrace) {
      print('❌ ERROR in _extractAndReadZip: $e');
      print('📚 Stack trace: $stackTrace');
      return null;
    }
  }

  /// Emoji detection regex
  static final _emojiRegex = RegExp(
    r'[\u{1F600}-\u{1F64F}]|[\u{1F300}-\u{1F5FF}]|[\u{1F680}-\u{1F6FF}]|[\u{1F1E0}-\u{1F1FF}]|[\u{2600}-\u{26FF}]|[\u{2700}-\u{27BF}]|[\u{FE00}-\u{FE0F}]|[\u{1F900}-\u{1F9FF}]|[\u{1FA00}-\u{1FA6F}]|[\u{1FA70}-\u{1FAFF}]|[\u{200D}]|[\u{20E3}]|[\u{E0020}-\u{E007F}]',
    unicode: true,
  );

  /// Link detection regex
  static final _linkRegex = RegExp(
    r'https?://\S+',
    caseSensitive: false,
  );

  /// Punctuation-stripping regex for word frequency
  static final _punctuationStripRegex = RegExp(
    r'^[^\p{L}\p{N}]+|[^\p{L}\p{N}]+$',
    unicode: true,
  );

  /// Tags to strip from message text (keep remaining text)
  static final _editedTagRegex = RegExp(
    r'<This message was edited>',
    caseSensitive: false,
  );

  Future<ChatAnalytics> _parseWhatsAppChat(String chatContent, {ValueNotifier<double>? progress}) async {
    print('🔬 Starting chat parsing... content length: ${chatContent.length}');

    // ── DEBUG: Print char codes of first 200 chars ────────────────
    final snippet = chatContent.substring(0, chatContent.length < 400 ? chatContent.length : 400);
    final codes = snippet.codeUnits.map((c) => 'U+${c.toRadixString(16).toUpperCase().padLeft(4, '0')}').join(' ');
    print('🔍 FIRST 400 CHAR CODES: $codes');

    // ── Step 0: Normalize content ────────────────────────────────────
    // 0a) Strip carriage returns
    chatContent = chatContent.replaceAll('\r', '');

    // 0b) Replace all special-width spaces with normal space
    chatContent = chatContent.replaceAll('\u00A0', ' ')
        .replaceAll('\u202F', ' ')
        .replaceAll('\u2007', ' ')
        .replaceAll(RegExp(r'[\u2000-\u200A\u205F\u3000\u1680]'), ' ');

    // 0c) AGGRESSIVELY remove ALL Unicode format/invisible characters
    //     Individual calls first for most common ones (guaranteed to work),
    //     then regex for remaining ranges.
    chatContent = chatContent
        .replaceAll('\u200E', '')   // LTR mark (most common in WhatsApp)
        .replaceAll('\u200F', '')   // RTL mark
        .replaceAll('\u200B', '')   // zero-width space
        .replaceAll('\u200C', '')   // zero-width non-joiner
        .replaceAll('\u200D', '')   // zero-width joiner
        .replaceAll('\u2060', '')   // word joiner
        .replaceAll('\uFEFF', '')   // BOM
        .replaceAll('\u00AD', '')   // soft hyphen
        .replaceAll('\u034F', '')   // combining grapheme joiner
        .replaceAll('\u061C', '')   // arabic letter mark
        .replaceAll('\u180E', '')   // mongolian vowel separator
        .replaceAll(RegExp(r'[\u2028-\u202E\u2061-\u2069]'), '');

    final lines = chatContent.split('\n');
    print('📝 Total lines: ${lines.length}');

    // ── DEBUG: Print first 5 non-empty lines after normalization ──
    int debugCount = 0;
    for (int d = 0; d < lines.length && debugCount < 5; d++) {
      final l = lines[d].trim();
      if (l.isEmpty) continue;
      debugCount++;
      final sample = l.length > 100 ? l.substring(0, 100) : l;
      final lineCodes = sample.codeUnits.map((c) => c < 128 ? String.fromCharCode(c) : 'U+${c.toRadixString(16).toUpperCase().padLeft(4, '0')}').join('');
      print('📋 Line $d text: "$sample"');
      print('📋 Line $d codes: $lineCodes');
    }

    // ── Step 1: Build flexible regex patterns ────────────────────────
    // Matches most WhatsApp export formats worldwide:
    //   dd/mm/yy, h:mm am -    (India / UK)
    //   mm/dd/yy, h:mm AM -    (US)
    //   dd/mm/yy, HH:mm -      (24-hour)
    //   [dd/mm/yy, h:mm:ss AM] (bracketed)
    //   dd.mm.yy, h:mm -       (dot-separated dates)
    //   dd-mm-yy, h:mm -       (dash-separated dates)
    final messagePattern = RegExp(
      r'^\[?'                                        // optional [
      r'(\d{1,2}[/.\-]\d{1,2}[/.\-]\d{2,4})'       // date group
      r'[,\s]+'                                      // separator
      r'\d{1,2}[.:]\d{2}(?:[.:]\d{2})?'             // time (h:mm or h:mm:ss)
      r'\s*(?:am|pm)?'                               // optional am/pm
      r'\s*\]?\s*'                                   // optional ] and spaces
      r'[-–—]\s+'                                    // dash separator
      r'(.+?):\s*'                                   // sender (non-greedy) + colon
      r'(.*)',                                       // message body (CAN be empty)
      caseSensitive: false,
    );

    // Date extractor – works with / . -  separators
    final dateExtractPattern = RegExp(
      r'(\d{1,2})[/.\-](\d{1,2})[/.\-](\d{2,4})',
    );

    // Time extractor – extracts hour, minute, and optional am/pm
    final timeExtractPattern = RegExp(
      r'(\d{1,2})[.:](\d{2})(?:[.:](\d{2}))?\s*(am|pm)?',
      caseSensitive: false,
    );

    // System line detector: any line that starts with a date+time pattern
    // (used to skip date-prefixed lines in the multi-line handler)
    final systemPattern = RegExp(
      r'^\[?\d{1,2}[/.\-]\d{1,2}[/.\-]\d{2,4}[,\s]+\d{1,2}[.:]\d{2}',
    );

    // ── Step 2: Tracking variables ───────────────────────────────────
    int totalWords = 0;
    int totalMessages = 0;
    final Map<String, PersonStats> personStats = {};
    final Map<String, int> totalWordFreq = {};
    final Map<String, int> totalEmojiFreq = {};  // emoji -> count (global)
    final Map<String, int> activityMap = {};   // yyyy-MM-dd → count
    final Map<int, int> hourlyActivityMap = {};  // hour (0-23) → count
    final Map<int, int> weekdayActivityMap = {};  // weekday (1=Mon to 7=Sun) → count
    final Set<DateTime> activeDates = {};
    DateTime? firstDate;
    DateTime? lastDate;
    String? lastSender;
    DateTime? lastMessageTime;  // Full timestamp for response time calculation
    final List<String> allMessageTexts = [];  // For overall sentiment analysis
    final Map<String, List<String>> personMessages = {};  // Per-person messages for sentiment

    final totalLines = lines.length;
    int matchedLines = 0;

    // ── Helper: count words in a text and attribute to a person ──────
    void countWords(String text, PersonStats? ps) {
      // Strip the "<This message was edited>" tag but keep the rest
      text = text.replaceAll(_editedTagRegex, '').trim();
      if (text.isEmpty) return;

      if (ps != null) {
        // Links
        ps.links += _linkRegex.allMatches(text).length;
        // Emojis - count per person
        ps.emojis += _emojiRegex.allMatches(text).length;
        // Letters (non-whitespace characters)
        ps.letters += text.replaceAll(RegExp(r'\s'), '').length;
      }

      // Extract emojis globally
      final emojiMatches = _emojiRegex.allMatches(text);
      for (final match in emojiMatches) {
        final emoji = match.group(0);
        if (emoji != null) {
          totalEmojiFreq[emoji] = (totalEmojiFreq[emoji] ?? 0) + 1;
          if (ps != null) {
            ps.emojiFrequency[emoji] = (ps.emojiFrequency[emoji] ?? 0) + 1;
          }
        }
      }

      // Words
      final words = text.split(RegExp(r'\s+'));
      for (final w in words) {
        if (w.isEmpty) continue;
        totalWords++;
        ps?.words++;
        final cleaned = w.toLowerCase().replaceAll(_punctuationStripRegex, '');
        if (cleaned.isNotEmpty) {
          // Debug: Track long words
          if (cleaned.length >= 9) {
            print('🔤 Long word found: "$cleaned" (${cleaned.length} chars)');
          }
          if (ps != null) {
            ps.wordFrequency[cleaned] = (ps.wordFrequency[cleaned] ?? 0) + 1;
          }
          totalWordFreq[cleaned] = (totalWordFreq[cleaned] ?? 0) + 1;
        }
      }
    }

    // ── Step 3: Parse lines ──────────────────────────────────────────
    for (int i = 0; i < totalLines; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      // Progress reporting (0.3 → 0.95)
      if (i % 500 == 0) {
        if (progress != null) {
          progress.value = 0.3 + (i / totalLines) * 0.65;
        }
        // Yield to UI thread to allow progress bar to update
        await Future.delayed(Duration.zero);
      }

      final match = messagePattern.firstMatch(line);

      if (match != null && match.groupCount >= 3) {
        // ── Matched a sender:message line ──
        matchedLines++;
        final sender = match.group(2)!.trim();
        var message = match.group(3)!.trim();

        // Parse date and time for activity tracking and response time
        DateTime? currentMessageTime;
        final dm = dateExtractPattern.firstMatch(line);
        final tm = timeExtractPattern.firstMatch(line);
        if (dm != null) {
          final d1 = int.parse(dm.group(1)!);
          final d2 = int.parse(dm.group(2)!);
          int yr = int.parse(dm.group(3)!);
          if (yr < 100) yr += 2000;
          // dd/mm/yy (day first) — standard for Indian/UK WhatsApp
          final day = d1;
          final month = d2;
          
          // Parse time
          int hour = 0, minute = 0;
          if (tm != null) {
            hour = int.parse(tm.group(1)!);
            minute = int.parse(tm.group(2)!);
            final ampm = tm.group(4)?.toLowerCase();
            if (ampm == 'pm' && hour < 12) hour += 12;
            if (ampm == 'am' && hour == 12) hour = 0;
          }
          
          try {
            final date = DateTime(yr, month, day);
            currentMessageTime = DateTime(yr, month, day, hour, minute);
            final key = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
            activityMap[key] = (activityMap[key] ?? 0) + 1;
            hourlyActivityMap[hour] = (hourlyActivityMap[hour] ?? 0) + 1;
            final weekday = date.weekday; // 1=Monday, 7=Sunday
            weekdayActivityMap[weekday] = (weekdayActivityMap[weekday] ?? 0) + 1;
            activeDates.add(DateTime(yr, month, day));
            firstDate ??= date;
            lastDate = date;
          } catch (_) {}
        }

        // Ensure person exists
        personStats.putIfAbsent(sender, () => PersonStats(name: sender));
        final ps = personStats[sender]!;
        ps.messages++;
        totalMessages++;
        
        // Track per-person hourly activity
        if (currentMessageTime != null) {
          final hour = currentMessageTime.hour;
          ps.hourlyActivityMap[hour] = (ps.hourlyActivityMap[hour] ?? 0) + 1;
          final weekday = currentMessageTime.weekday;
          ps.weekdayActivityMap[weekday] = (ps.weekdayActivityMap[weekday] ?? 0) + 1;
        }
        
        // Calculate response time and detect conversation starters
        if (currentMessageTime != null) {
          if (lastMessageTime == null) {
            // First message of the chat - this person started a conversation
            ps.conversationsStarted++;
          } else {
            final gap = currentMessageTime.difference(lastMessageTime);
            final gapMinutes = gap.inMinutes.abs();
            
            // New conversation if gap > 4 hours (240 minutes)
            if (gapMinutes > 240) {
              ps.conversationsStarted++;
            } else if (lastSender != null && lastSender != sender) {
              // This is a response - sender changed and within 4 hours
              ps.totalResponseTimeMinutes += gapMinutes.toDouble();
              ps.responseCount++;
            }
          }
          lastMessageTime = currentMessageTime;
        }
        
        lastSender = sender;

        // Deleted messages
        if (message == 'This message was deleted' ||
            message == 'You deleted this message') {
          ps.deleted++;
          continue;
        }

        // Media
        if (message.contains('<Media omitted>')) {
          ps.media++;
          continue;
        }

        // Skip pure system info
        if (message.contains('end-to-end encrypted') || message.isEmpty) {
          continue;
        }

        // Strip "<This message was edited>" tag but KEEP remaining text
        message = message.replaceAll(_editedTagRegex, '').trim();
        if (message.isEmpty) continue;

        countWords(message, ps);
        
        // Collect message text for sentiment analysis
        if (message.isNotEmpty && !message.startsWith('<Media omitted>')) {
          allMessageTexts.add(message);
          personMessages.putIfAbsent(sender, () => []).add(message);
        }
      } else {
        // ── Multi-line continuation ──
        if (line.isNotEmpty &&
            !systemPattern.hasMatch(line) &&
            !line.contains('<Media omitted>')) {
          // Strip "<This message was edited>" tag, keep remaining text
          final cleaned = line.replaceAll(_editedTagRegex, '').trim();
          if (cleaned.isNotEmpty && !cleaned.contains('end-to-end encrypted')) {
            final ps = lastSender != null ? personStats[lastSender] : null;
            countWords(cleaned, ps);
            
            // Collect for sentiment analysis
            if (cleaned.isNotEmpty && lastSender != null) {
              allMessageTexts.add(cleaned);
              personMessages.putIfAbsent(lastSender, () => []).add(cleaned);
            }
          }
        }
      }
    }

    // ── Step 4: Calculate streaks ────────────────────────────────────
    final sortedDates = activeDates.toList()..sort();
    int longestStreak = 0;
    int currentStreak = 0;
    DateTime? longestStreakStart;
    DateTime? longestStreakEnd;
    DateTime? currentStreakStart;
    DateTime? currentStreakEnd;

    if (sortedDates.isNotEmpty) {
      int streak = 1;
      int streakStartIdx = 0;
      int bestStreakStartIdx = 0;
      int bestStreakEndIdx = 0;
      longestStreak = 1; // At minimum, we have 1 day
      
      for (int i = 1; i < sortedDates.length; i++) {
        final diff = sortedDates[i].difference(sortedDates[i - 1]).inDays;
        if (diff == 1) {
          streak++;
        } else if (diff > 1) {
          if (streak > longestStreak) {
            longestStreak = streak;
            bestStreakStartIdx = streakStartIdx;
            bestStreakEndIdx = i - 1;
          }
          streak = 1;
          streakStartIdx = i;
        }
      }
      // Check final streak
      if (streak > longestStreak) {
        longestStreak = streak;
        bestStreakStartIdx = streakStartIdx;
        bestStreakEndIdx = sortedDates.length - 1;
      }
      
      // Set longest streak dates (always set if we have any active days)
      longestStreakStart = sortedDates[bestStreakStartIdx];
      longestStreakEnd = sortedDates[bestStreakEndIdx];

      // Current streak: count back from last active date
      final today = DateTime.now();
      final todayDate = DateTime(today.year, today.month, today.day);
      final lastActiveDate = sortedDates.last;
      final daysSinceLast = todayDate.difference(lastActiveDate).inDays;

      if (daysSinceLast <= 1) {
        currentStreak = 1;
        currentStreakEnd = sortedDates.last;
        int currentStreakStartIdx = sortedDates.length - 1;
        
        for (int i = sortedDates.length - 2; i >= 0; i--) {
          final diff = sortedDates[i + 1].difference(sortedDates[i]).inDays;
          if (diff == 1) {
            currentStreak++;
            currentStreakStartIdx = i;
          } else {
            break;
          }
        }
        currentStreakStart = sortedDates[currentStreakStartIdx];
      }
    }

    // ── Step 5: Finalize ─────────────────────────────────────────────
    final readingTimeMinutes = (totalWords * 0.27) / 60;

    print('📊 Parsing summary:');
    print('   - Regex matched lines: $matchedLines / $totalLines');
    print('   - Messages: $totalMessages');
    print('   - Words: $totalWords');
    print('   - Persons: ${personStats.keys.join(', ')}');
    print('   - Longest streak: $longestStreak days');
    print('   - Current streak: $currentStreak days');
    print('   - Active days: ${activeDates.length}');
    for (int d = 0; d < lines.length && d < 5; d++) {
      final sample = lines[d].length > 80 ? lines[d].substring(0, 80) : lines[d];
      print('   📋 Line $d: "$sample"');
      print('      matched: ${messagePattern.hasMatch(lines[d].trim())}');
    }

    progress?.value = 1.0;

    // Debug: Print word length distribution
    final lengthCounts = <int, int>{};
    for (final word in totalWordFreq.keys) {
      final len = word.length;
      lengthCounts[len] = (lengthCounts[len] ?? 0) + 1;
    }
    print('📊 Word length distribution (unique words): $lengthCounts');
    print('📊 Sample 9+ char words: ${totalWordFreq.keys.where((w) => w.length >= 9).take(10).toList()}');

    // ── Step 6: Perform Sentiment Analysis ───────────────────────────
    SentimentStats? overallSentiment;
    if (allMessageTexts.isNotEmpty) {
      print('🧠 Analyzing sentiment for ${allMessageTexts.length} messages...');
      try {
        final analyzer = SentimentAnalyzer.instance;
        await analyzer.initialize();
        
        // Analyze all overall messages
        final results = await analyzer.analyzeBatch(allMessageTexts);
        
        double totalPositive = 0;
        double totalNegative = 0;
        double totalNeutral = 0;
        int positiveCount = 0;
        int negativeCount = 0;
        int neutralCount = 0;
        int analyzedCount = 0;
        
        for (final result in results) {
          if (result != null) {
            totalPositive += result.positiveScore;
            totalNegative += result.negativeScore;
            totalNeutral += result.neutralScore;
            analyzedCount++;
            
            final label = result.label;
            if (label == 'positive') {
              positiveCount++;
            } else if (label == 'negative') {
              negativeCount++;
            } else {
              neutralCount++;
            }
          }
        }
        
        if (analyzedCount > 0) {
          overallSentiment = SentimentStats(
            averagePositive: totalPositive / analyzedCount,
            averageNegative: totalNegative / analyzedCount,
            averageNeutral: totalNeutral / analyzedCount,
            positiveCount: positiveCount,
            negativeCount: negativeCount,
            neutralCount: neutralCount,
            totalMessages: analyzedCount,
          );
          print('✅ Overall sentiment analysis complete: ${overallSentiment.positivePercent.toStringAsFixed(1)}% positive');
        }
        
        // Analyze per-person sentiment
        print('🧠 Analyzing per-person sentiment...');
        for (final entry in personMessages.entries) {
          final personName = entry.key;
          final messages = entry.value;
          
          if (messages.isEmpty) continue;
          
          // Analyze all messages for this person
          final personResults = await analyzer.analyzeBatch(messages);
          
          double personPositive = 0;
          double personNegative = 0;
          double personNeutral = 0;
          int personPosCount = 0;
          int personNegCount = 0;
          int personNeuCount = 0;
          int personAnalyzedCount = 0;
          
          for (final result in personResults) {
            if (result != null) {
              personPositive += result.positiveScore;
              personNegative += result.negativeScore;
              personNeutral += result.neutralScore;
              personAnalyzedCount++;
              
              final label = result.label;
              if (label == 'positive') {
                personPosCount++;
              } else if (label == 'negative') {
                personNegCount++;
              } else {
                personNeuCount++;
              }
            }
          }
          
          if (personAnalyzedCount > 0 && personStats.containsKey(personName)) {
            personStats[personName]!.sentimentStats = SentimentStats(
              averagePositive: personPositive / personAnalyzedCount,
              averageNegative: personNegative / personAnalyzedCount,
              averageNeutral: personNeutral / personAnalyzedCount,
              positiveCount: personPosCount,
              negativeCount: personNegCount,
              neutralCount: personNeuCount,
              totalMessages: personAnalyzedCount,
            );
            print('  ✅ $personName: ${personStats[personName]!.sentimentStats!.positivePercent.toStringAsFixed(1)}% positive');
          }
        }
      } catch (e) {
        print('⚠️ Sentiment analysis failed: $e');
      }
    }

    print('📊 Total emojis found: ${totalEmojiFreq.length} unique, ${totalEmojiFreq.values.fold(0, (a, b) => a + b)} total');

    return ChatAnalytics(
      totalWords: totalWords,
      readingTimeMinutes: readingTimeMinutes,
      totalMessages: totalMessages,
      longestStreak: longestStreak,
      currentStreak: currentStreak,
      personStats: personStats,
      activityMap: activityMap,
      totalWordFrequency: totalWordFreq,
      totalEmojiFrequency: totalEmojiFreq,
      hourlyActivityMap: hourlyActivityMap,
      weekdayActivityMap: weekdayActivityMap,
      firstMessageDate: firstDate,
      lastMessageDate: lastDate,
      longestStreakStart: longestStreakStart,
      longestStreakEnd: longestStreakEnd,
      currentStreakStart: currentStreakStart,
      currentStreakEnd: currentStreakEnd,
      overallSentiment: overallSentiment,
    );
  }

  Future<void> _openExample() async {
    // Example WhatsApp chat
    const exampleChat = '''23/01/26, 11:23 am - Messages and calls are end-to-end encrypted. Only people in this chat can read, listen to, or share them. Learn more.
23/01/26, 11:30 am - 
23/01/26, 11:30 am - +91 88909 55667: Hi
23/01/26, 11:40 am - Yash Tekwani: Mai bhejta documents
23/01/26, 11:40 am - Yash Tekwani: <Media omitted>
23/01/26, 11:41 am - Yash Tekwani: <Media omitted>
23/01/26, 11:47 am - Yash Tekwani: <Media omitted>
23/01/26, 11:48 am - Yash Tekwani: sallytionmakes@gmail.com
23/01/26, 11:48 am - Yash Tekwani: 8107649477
23/01/26, 11:49 am - +91 88909 55667: Pan card ki photo wali image bhej skte ho kya aap.
23/01/26, 11:49 am - Yash Tekwani: Bhejta ruko
23/01/26, 11:50 am - Yash Tekwani: <Media omitted>
23/01/26, 11:51 am - Yash Tekwani: <Media omitted>
23/01/26, 11:52 am - Yash Tekwani: <Media omitted>
23/01/26, 11:53 am - Yash Tekwani: <Media omitted>
23/01/26, 11:53 am - Yash Tekwani: Aur kuch?
23/01/26, 11:57 am - +91 88909 55667: Nominee Name- Rajesh Tekwani
Nominee DOB - <This message was edited>
23/01/26, 12:12 pm - +91 88909 55667: Mil gyi DOB mujhe ignore this
23/01/26, 1:48 pm - Yash Tekwani: Thik
23/01/26, 4:32 pm - +91 88909 55667: Pls share otp
23/01/26, 4:35 pm - +91 88909 55667: ICICI Prudential Life Insurance Company Limited
1st Floor, Harey Kishanam Tower, Bank Lane, above Bank of India, Bundi, 323001, RJ, IN
http://www.iciciprulife.com/
23/01/26, 4:37 pm - +91 88909 55667: ICICI Prudential Life Insurance 
1st Floor, Above Bank of India <This message was edited>
23/01/26, 4:39 pm - Yash Tekwani: Aata 30 min me mai
23/01/26, 4:40 pm - +91 88909 55667: Ok.
23/01/26, 5:24 pm - Yash Tekwani: 8107649477@yescred
30/01/26, 9:00 am - +91 88909 55667: Exam 2 feb ke baad karwa le na
30/01/26, 9:00 am - Yash Tekwani: Thike
30/01/26, 9:00 am - Yash Tekwani: Karwa do, mai chala jaunga attend karne
30/01/26, 9:03 am - +91 88909 55667: Okay .. aap Vellore aa gaye
30/01/26, 9:03 am - Yash Tekwani: Haa
03/02/26, 2:43 pm - +91 88909 55667: Bhaiya,
8-10 tak aayega exam schedule
03/02/26, 3:00 pm - Yash Tekwani: Okay
06/02/26, 1:44 pm - +91 88909 55667: IRDA urn se koi msg aya kya
06/02/26, 1:53 pm - Yash Tekwani: Nahi abhi tak toh nahi aaya
06/02/26, 4:10 pm - Yash Tekwani: <Media omitted>
06/02/26, 4:16 pm - +91 88909 55667: 12 ko hai
06/02/26, 5:40 pm - +91 88909 55667: <Media omitted>
06/02/26, 5:43 pm - +91 88909 55667: <Media omitted>
06/02/26, 7:44 pm - Yash Tekwani: Thike
07/02/26, 5:00 am - +91 88909 55667: हर question को ध्यान से पढ़ेंगे तो answer का idea आ जाएगा।
सभी 50 questions attempt karne hai. Aur last mein submit ka option ayega uske baad apna result pass dikh jayega..
07/02/26, 5:01 am - +91 88909 55667: https://youtu.be/7Q5o8tDJIbM?si=H7IGU8HXQ1w6OGRW
07/02/26, 5:01 am - +91 88909 55667: Isko dekh lena jab time mile
07/02/26, 5:01 am - +91 88909 55667: 10-15 min
07/02/26, 8:56 am - Yash Tekwani: Thik
07/02/26, 11:48 pm - Yash Tekwani: ''';

    print('📘 Processing example chat...');
    final analytics = await _parseWhatsAppChat(exampleChat);
    
    print('✨ Example chat parsed successfully!');
    await _saveCurrentChat('Example Chat', analytics);
    _navigateToSummary('Example Chat', analytics);
  }

  Widget _buildFeatureCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  color.withOpacity(0.2),
                  color.withOpacity(0.05),
                ]
              : [
                  color.withOpacity(0.12),
                  color.withOpacity(0.04),
                ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(isDark ? 0.3 : 0.2),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(isDark ? 0.25 : 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: color,
                size: 26,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Privacy Trust Signal
                    Container(
                      padding: const EdgeInsets.all(20),
                      margin: const EdgeInsets.only(top: 45, bottom: 40),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark 
                            ? Colors.green.withOpacity(0.1) 
                            : Colors.green.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.green.withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.lock_outline_rounded,
                              color: Colors.green,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppLocalizations.of(context)?.translate('privacy_title') ?? '100% Private & Offline',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  AppLocalizations.of(context)?.translate('privacy_desc') ?? 
                                      'Your chat data never leaves this device. All processing is done locally.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Theme.of(context).brightness == Brightness.dark 
                                        ? Colors.green[100] 
                                        : Colors.green[800],
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Main CTA
                    ElevatedButton(
                      onPressed: () => _showImportDialog(context),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        elevation: 4,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.add_circle_outline_rounded, size: 32),
                          const SizedBox(height: 12),
                          Text(
                            AppLocalizations.of(context)?.translate('cta_import') ?? 'Import Chat to Analyze',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),

                    // "What You Get" Feature Grid
                    Text(
                      AppLocalizations.of(context)?.translate('what_you_get') ?? 'What You\'ll Discover',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).brightness == Brightness.dark 
                            ? Colors.white 
                            : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.3,
                      children: [
                        _buildFeatureCard(
                          context,
                          icon: Icons.cloud_rounded,
                          title: AppLocalizations.of(context)?.translate('feature_word_cloud') ?? 'Word Clouds',
                          color: Colors.purple,
                        ),
                        _buildFeatureCard(
                          context,
                          icon: Icons.grid_view_rounded,
                          title: AppLocalizations.of(context)?.translate('feature_heatmaps') ?? 'Activity Heatmaps',
                          color: Colors.orange,
                        ),
                        _buildFeatureCard(
                          context,
                          icon: Icons.emoji_emotions_rounded,
                          title: AppLocalizations.of(context)?.translate('feature_emoji') ?? 'Emoji Analysis',
                          color: Colors.pink,
                        ),
                        _buildFeatureCard(
                          context,
                          icon: Icons.local_fire_department_rounded,
                          title: AppLocalizations.of(context)?.translate('feature_streaks') ?? 'Activity Streaks',
                          color: Colors.red,
                        ),
                        _buildFeatureCard(
                          context,
                          icon: Icons.bar_chart_rounded,
                          title: AppLocalizations.of(context)?.translate('feature_time_analysis') ?? 'Time Analysis',
                          color: Colors.teal,
                        ),
                        _buildFeatureCard(
                          context,
                          icon: Icons.leaderboard_rounded,
                          title: AppLocalizations.of(context)?.translate('feature_leaderboard') ?? 'Leaderboards',
                          color: Colors.blue,
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            
            // Settings Button (Top Right)
            Positioned(
              top: 16,
              right: 16,
              child: IconButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsPage()),
                  );
                },
                icon: const Icon(Icons.settings_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  padding: const EdgeInsets.all(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

}
