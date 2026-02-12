import 'package:flutter/material.dart';
import '../models/chat_analytics.dart';
import '../services/sentiment_analyzer.dart';

/// Widget to display sentiment analysis results
class SentimentCard extends StatelessWidget {
  final SentimentStats? sentiment;
  final String title;

  const SentimentCard({
    super.key,
    required this.sentiment,
    this.title = 'Sentiment Analysis',
  });

  @override
  Widget build(BuildContext context) {
    if (sentiment == null) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.sentiment_neutral),
          title: Text(title),
          subtitle: const Text('Sentiment data not available'),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getMoodIcon(sentiment!.moodScore),
                  color: _getMoodColor(sentiment!.moodScore),
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Mood Score
            _buildMoodIndicator(context),
            const SizedBox(height: 16),
            
            // Sentiment Breakdown
            _buildSentimentBar(context, 'Positive', sentiment!.positivePercent, Colors.green),
            const SizedBox(height: 8),
            _buildSentimentBar(context, 'Neutral', sentiment!.neutralPercent, Colors.grey),
            const SizedBox(height: 8),
            _buildSentimentBar(context, 'Negative', sentiment!.negativePercent, Colors.red),
            const SizedBox(height: 16),
            
            // Stats
            Text(
              '${sentiment!.totalMessages} messages analyzed',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoodIndicator(BuildContext context) {
    final moodScore = sentiment!.moodScore;
    final moodText = _getMoodText(moodScore);
    final moodColor = _getMoodColor(moodScore);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Overall Mood',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  gradient: const LinearGradient(
                    colors: [Colors.red, Colors.grey, Colors.green],
                    stops: [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Negative', style: TextStyle(fontSize: 12)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: moodColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: moodColor),
              ),
              child: Text(
                moodText,
                style: TextStyle(
                  color: moodColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            const Text('Positive', style: TextStyle(fontSize: 12)),
          ],
        ),
      ],
    );
  }

  Widget _buildSentimentBar(BuildContext context, String label, double percent, Color color) {
    return Row(
      children: [
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              Container(
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              FractionallySizedBox(
                widthFactor: percent / 100,
                child: Container(
                  height: 24,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 50,
          child: Text(
            '${percent.toStringAsFixed(1)}%',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  String _getMoodText(double moodScore) {
    if (moodScore > 0.3) return 'Very Positive';
    if (moodScore > 0.1) return 'Positive';
    if (moodScore > -0.1) return 'Neutral';
    if (moodScore > -0.3) return 'Negative';
    return 'Very Negative';
  }

  Color _getMoodColor(double moodScore) {
    if (moodScore > 0.2) return Colors.green;
    if (moodScore > 0) return Colors.lightGreen;
    if (moodScore > -0.2) return Colors.grey;
    if (moodScore > -0.4) return Colors.orange;
    return Colors.red;
  }

  IconData _getMoodIcon(double moodScore) {
    if (moodScore > 0.2) return Icons.sentiment_very_satisfied;
    if (moodScore > 0) return Icons.sentiment_satisfied;
    if (moodScore > -0.2) return Icons.sentiment_neutral;
    if (moodScore > -0.4) return Icons.sentiment_dissatisfied;
    return Icons.sentiment_very_dissatisfied;
  }
}

/// Compact sentiment indicator for list items
class SentimentIndicator extends StatelessWidget {
  final SentimentStats? sentiment;

  const SentimentIndicator({super.key, this.sentiment});

  @override
  Widget build(BuildContext context) {
    if (sentiment == null) return const SizedBox.shrink();

    final moodScore = sentiment!.moodScore;
    final color = _getMoodColor(moodScore);
    final icon = _getMoodIcon(moodScore);

    return Tooltip(
      message: _getMoodText(moodScore),
      child: Icon(icon, color: color, size: 20),
    );
  }

  String _getMoodText(double moodScore) {
    if (moodScore > 0.3) return 'Very Positive';
    if (moodScore > 0.1) return 'Positive';
    if (moodScore > -0.1) return 'Neutral';
    if (moodScore > -0.3) return 'Negative';
    return 'Very Negative';
  }

  Color _getMoodColor(double moodScore) {
    if (moodScore > 0.2) return Colors.green;
    if (moodScore > 0) return Colors.lightGreen;
    if (moodScore > -0.2) return Colors.grey;
    if (moodScore > -0.4) return Colors.orange;
    return Colors.red;
  }

  IconData _getMoodIcon(double moodScore) {
    if (moodScore > 0.2) return Icons.sentiment_very_satisfied;
    if (moodScore > 0) return Icons.sentiment_satisfied;
    if (moodScore > -0.2) return Icons.sentiment_neutral;
    if (moodScore > -0.4) return Icons.sentiment_dissatisfied;
    return Icons.sentiment_very_dissatisfied;
  }
}
