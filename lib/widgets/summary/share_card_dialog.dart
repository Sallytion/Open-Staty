import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/chat_analytics.dart';
import '../../l10n/app_localizations.dart';

/// Shareable summary card dialog with customization options
class ShareCardDialog extends StatefulWidget {
  final ChatAnalytics analytics;
  final String chatName;
  final int wordCount;
  final bool isDark;
  final Color primary;
  final String Function(int) fmtNum;

  const ShareCardDialog({
    super.key,
    required this.analytics,
    required this.chatName,
    required this.wordCount,
    required this.isDark,
    required this.primary,
    required this.fmtNum,
  });

  @override
  State<ShareCardDialog> createState() => _ShareCardDialogState();
}

class _ShareCardDialogState extends State<ShareCardDialog> {
  final _cardKey = GlobalKey();
  
  bool _showMessages = true;
  bool _showWords = true;
  bool _showDaysActive = true;
  bool _showStreak = true;
  bool _showEmojis = false;
  bool _showMedia = false;
  bool _showChatName = true;
  bool _showMessageRate = false;
  bool _showTopWords = false;
  bool _showPeakTime = false;
  bool _showSentiment = false;
  bool _showTopEmojis = false;

  String _getPeakHour() {
    final a = widget.analytics;
    if (a.hourlyActivityMap.isEmpty) return 'N/A';
    int maxHour = 0;
    int maxCount = 0;
    a.hourlyActivityMap.forEach((hour, count) {
      if (count > maxCount) {
        maxCount = count;
        maxHour = hour;
      }
    });
    final h = maxHour % 12 == 0 ? 12 : maxHour % 12;
    final ampm = maxHour < 12 ? 'AM' : 'PM';
    return '$h $ampm';
  }
  
  String _getTopWordsText() {
    final words = widget.analytics.totalTopWords(3);
    if (words.isEmpty) return 'N/A';
    return words.map((e) => e.key).join(', ');
  }
  
  String _getMessageRate() {
    final a = widget.analytics;
    if (a.firstMessageDate == null) return 'N/A';
    final days = DateTime.now().difference(a.firstMessageDate!).inDays.clamp(1, 999999);
    final rate = a.totalMessages / days;
    return '${rate.toStringAsFixed(1)}/day';
  }

  String _getSentimentText() {
    final sentiment = widget.analytics.overallSentiment;
    if (sentiment == null) return 'N/A';
    final pos = sentiment.positivePercent.toStringAsFixed(0);
    final neg = sentiment.negativePercent.toStringAsFixed(0);
    final neu = sentiment.neutralPercent.toStringAsFixed(0);
    return '😊$pos% 😐$neu% 😞$neg%';
  }

  String _getTopEmojisText() {
    final emojis = widget.analytics.totalTopEmojis(5);
    if (emojis.isEmpty) return 'N/A';
    return emojis.map((e) => e.key).join(' ');
  }



  Map<String, List<Widget>> _buildActiveStats() {
    final regularStats = <Widget>[];
    final wideStats = <Widget>[];
    final a = widget.analytics;
    final loc = AppLocalizations.of(context)!;
      
    if (_showMessages) regularStats.add(_statTile(loc.translate('messages'), widget.fmtNum(a.totalMessages), Icons.chat_bubble));
    if (_showWords) regularStats.add(_statTile(loc.translate('words'), widget.fmtNum(widget.wordCount), Icons.text_fields));
    if (_showDaysActive) regularStats.add(_statTile(loc.translate('active_days'), '${a.activityMap.length}', Icons.calendar_today));
    if (_showStreak) regularStats.add(_statTile(loc.translate('longest_streak').replaceAll('Longest ', ''), '${a.longestStreak}d', Icons.local_fire_department));
    if (_showEmojis) {
      final totalEmojis = a.personStats.values.fold(0, (sum, ps) => sum + ps.emojis);
      regularStats.add(_statTile(loc.translate('emojis'), widget.fmtNum(totalEmojis), Icons.emoji_emotions));
    }
    if (_showMedia) {
      final totalMedia = a.personStats.values.fold(0, (sum, ps) => sum + ps.media);
      regularStats.add(_statTile(loc.translate('media'), widget.fmtNum(totalMedia), Icons.photo));
    }
    if (_showMessageRate) regularStats.add(_statTile('Rate', _getMessageRate(), Icons.speed));
    if (_showPeakTime) regularStats.add(_statTile('Peak Time', _getPeakHour(), Icons.access_time));
    if (_showTopWords) wideStats.add(_statTile(loc.translate('top_words'), _getTopWordsText(), Icons.abc, isWide: true));
    if (_showSentiment) wideStats.add(_statTile('Sentiment', _getSentimentText(), Icons.psychology, isWide: true));
    if (_showTopEmojis) wideStats.add(_statTile('Top Emojis', _getTopEmojisText(), Icons.emoji_emotions, isWide: true));
      
    return {'regular': regularStats, 'wide': wideStats};
  }
    
    Widget _statTile(String label, String value, IconData icon, {bool isWide = false}) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: widget.isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: widget.primary),
                const SizedBox(width: 4),
                Text(label, style: TextStyle(color: widget.isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 11)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value, 
              style: TextStyle(
                color: widget.isDark ? Colors.white : Colors.black, 
                fontSize: isWide ? 14 : 18, 
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );
    }
  
    @override
    Widget build(BuildContext context) {
      final loc = AppLocalizations.of(context)!;
      final statsMap = _buildActiveStats();
      final regularStats = statsMap['regular']!;
      final wideStats = statsMap['wide']!;
      final hasStats = regularStats.isNotEmpty || wideStats.isNotEmpty;
      final rows = <Widget>[];
      
      // Build regular stats in pairs
      for (int i = 0; i < regularStats.length; i += 2) {
        if (i + 1 < regularStats.length) {
          rows.add(Row(children: [
            Expanded(child: regularStats[i]),
            const SizedBox(width: 12),
            Expanded(child: regularStats[i + 1]),
          ]));
        } else {
          rows.add(Row(children: [
            Expanded(child: regularStats[i]),
            const Spacer(),
          ]));
        }
        if (i + 2 < regularStats.length || wideStats.isNotEmpty) {
          rows.add(const SizedBox(height: 12));
        }
      }
      
      // Add wide stats as full-width rows
      for (int i = 0; i < wideStats.length; i++) {
        rows.add(wideStats[i]);
        if (i + 1 < wideStats.length) rows.add(const SizedBox(height: 12));
      }
      
      return Dialog(
        backgroundColor: Colors.transparent,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Customization toggles
              Container(
                width: 320,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: widget.isDark ? const Color(0xFF2D2D2D) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(loc.translate('customize_card'), style: TextStyle(color: widget.isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildToggleChip('Chat Name', _showChatName, (v) => setState(() => _showChatName = v)),
                        _buildToggleChip(loc.translate('messages'), _showMessages, (v) => setState(() => _showMessages = v)),
                        _buildToggleChip(loc.translate('words'), _showWords, (v) => setState(() => _showWords = v)),
                        _buildToggleChip(loc.translate('active_days'), _showDaysActive, (v) => setState(() => _showDaysActive = v)),
                        _buildToggleChip(loc.translate('longest_streak').replaceAll('Longest ', ''), _showStreak, (v) => setState(() => _showStreak = v)),
                        _buildToggleChip(loc.translate('emojis'), _showEmojis, (v) => setState(() => _showEmojis = v)),
                        _buildToggleChip(loc.translate('media'), _showMedia, (v) => setState(() => _showMedia = v)),
                        _buildToggleChip('Rate', _showMessageRate, (v) => setState(() => _showMessageRate = v)),
                        _buildToggleChip('Peak Time', _showPeakTime, (v) => setState(() => _showPeakTime = v)),
                        _buildToggleChip(loc.translate('top_words'), _showTopWords, (v) => setState(() => _showTopWords = v)),
                        _buildToggleChip('Sentiment', _showSentiment, (v) => setState(() => _showSentiment = v)),
                        _buildToggleChip('Top Emojis', _showTopEmojis, (v) => setState(() => _showTopEmojis = v)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              
              // Preview label
              Text(loc.translate('preview'), style: TextStyle(color: widget.isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 12)),
              const SizedBox(height: 8),
              
              // Card preview
              RepaintBoundary(
                key: _cardKey,
                child: Container(
                  width: 320,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: widget.isDark 
                          ? [const Color(0xFF1A1A2E), const Color(0xFF16213E)]
                          : [Colors.white, const Color(0xFFF8F9FA)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: widget.primary.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.chat_bubble_rounded, color: widget.primary, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (_showChatName) Text(
                                  widget.chatName,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: widget.isDark ? Colors.white : Colors.black,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  loc.translate('chat_stats'),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: widget.isDark ? Colors.grey[400] : Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      
                      // Stats grid
                      if (hasStats) ...rows,
                      
                      const SizedBox(height: 16),
                      
                      // Branding
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.analytics_rounded, size: 14, color: widget.primary),
                          const SizedBox(width: 4),
                          Text(
                            'Open Staty',
                            style: TextStyle(
                              fontSize: 12,
                              color: widget.isDark ? Colors.grey[500] : Colors.grey[400],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Share button
              ElevatedButton.icon(
                onPressed: hasStats ? _shareCard : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
                icon: const Icon(Icons.share_rounded),
                label: Text(hasStats ? loc.translate('share_card') : loc.translate('select_stat')),
              ),
            ],
          ),
        ),
      );
    }
    
    Widget _buildToggleChip(String label, bool value, Function(bool) onChanged) {
      return FilterChip(
        label: Text(label, style: TextStyle(fontSize: 12, color: value ? Colors.white : (widget.isDark ? Colors.grey[300] : Colors.grey[700]))),
        selected: value,
        onSelected: onChanged,
        selectedColor: widget.primary,
        checkmarkColor: Colors.white,
        backgroundColor: widget.isDark ? Colors.grey[800] : Colors.grey[200],
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
        visualDensity: VisualDensity.compact,
      );
    }
    
    Future<void> _shareCard() async {
      try {
        final boundary = _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
        if (boundary == null) return;
        
        final image = await boundary.toImage(pixelRatio: 3.0);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData == null) return;
        
        final pngBytes = byteData.buffer.asUint8List();
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/chat_stats.png');
        await file.writeAsBytes(pngBytes);
        
        await Share.shareXFiles([XFile(file.path)], text: 'My chat stats from Open Staty! 📊');
      } catch (e) {
        debugPrint('Error sharing card: $e');
      }
    }
  }
