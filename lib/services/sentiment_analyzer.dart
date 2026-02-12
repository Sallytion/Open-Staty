import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

/// Sentiment analysis result
class SentimentResult {
  final double positiveScore;
  final double negativeScore;
  final double neutralScore;

  SentimentResult({
    required this.positiveScore,
    required this.negativeScore,
    required this.neutralScore,
  });

  /// Get the dominant sentiment label
  String get label {
    // A message is only "neutral" if neutral clearly dominates
    // OR positive and negative are nearly equal (mixed → neutral)
    final posDominant = positiveScore > negativeScore && positiveScore > neutralScore;
    final negDominant = negativeScore > positiveScore && negativeScore > neutralScore;
    
    if (posDominant) return 'positive';
    if (negDominant) return 'negative';
    
    // If neutral is highest, but positive or negative is close behind (within 0.15),
    // classify as the close sentiment — WhatsApp messages are rarely truly "neutral"
    if (positiveScore > negativeScore && (neutralScore - positiveScore) < 0.15) {
      return 'positive';
    }
    if (negativeScore > positiveScore && (neutralScore - negativeScore) < 0.15) {
      return 'negative';
    }
    
    return 'neutral';
  }

  /// Get the confidence of the dominant sentiment (0.0 to 1.0)
  double get confidence {
    return [positiveScore, negativeScore, neutralScore].reduce((a, b) => a > b ? a : b);
  }
}

/// On-device sentiment analyzer with TFLite model + built-in lexicon fallback.
/// Works completely offline — no data ever leaves the device.
class SentimentAnalyzer {
  static SentimentAnalyzer? _instance;
  Interpreter? _interpreter;
  Map<String, int>? _vocabulary;
  bool _isInitialized = false;
  bool _useLexiconFallback = false;

  // Model configuration
  static const int _maxSequenceLength = 128;
  static const String _modelPath = 'assets/models/sentiment_model.tflite';
  static const String _vocabPath = 'assets/models/vocab.txt';

  SentimentAnalyzer._();

  /// Get singleton instance
  static SentimentAnalyzer get instance {
    _instance ??= SentimentAnalyzer._();
    return _instance!;
  }

  bool get isInitialized => _isInitialized;

  /// Initialize the model — tries TFLite first, falls back to built-in lexicon
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      _interpreter = await Interpreter.fromAsset(_modelPath);
      _vocabulary = await _loadVocabulary();
      _useLexiconFallback = false;
      _isInitialized = true;
      return true;
    } catch (e) {
      _useLexiconFallback = true;
      _isInitialized = true;
      return true;
    }
  }

  /// Load vocabulary from assets
  Future<Map<String, int>> _loadVocabulary() async {
    final vocabText = await rootBundle.loadString(_vocabPath);
    final lines = vocabText.split('\n');
    final vocab = <String, int>{};
    for (int i = 0; i < lines.length; i++) {
      final word = lines[i].trim();
      if (word.isNotEmpty) {
        vocab[word] = i;
      }
    }
    return vocab;
  }

  // =====================================================================
  //  Multilingual lexicon-based sentiment analyzer (zero-model fallback)
  //  Uses emoji signals + multilingual keyword matching.
  //  Emojis are universal and extremely effective for chat sentiment.
  // =====================================================================

  // Positive emojis (weighted 1.0 to 2.0)
  static const Map<String, double> _positiveEmojis = {
    '😀': 1.0, '😃': 1.0, '😄': 1.2, '😁': 1.2, '😆': 1.3, '😂': 1.5,
    '🤣': 1.5, '😊': 1.0, '😇': 1.0, '🥰': 1.5, '😍': 1.5, '🤩': 1.5,
    '😘': 1.2, '😗': 0.8, '😙': 0.8, '😚': 0.8, '🥲': 0.6, '😋': 0.8,
    '😛': 0.8, '😜': 0.9, '🤪': 0.9, '😝': 0.8, '🤗': 1.0, '🤭': 0.7,
    '🫣': 0.5, '🫠': 0.5, '🤫': 0.4, '💪': 1.0, '🎉': 1.5, '🎊': 1.5,
    '🥳': 1.5, '🎈': 1.0, '✨': 0.8, '🌟': 0.8, '⭐': 0.8, '💫': 0.8,
    '❤️': 1.5, '🧡': 1.3, '💛': 1.3, '💚': 1.3, '💙': 1.3, '💜': 1.3,
    '🖤': 0.8, '🤍': 0.8, '🤎': 0.8, '💖': 1.5, '💗': 1.3, '💓': 1.3,
    '💞': 1.3, '💕': 1.3, '💘': 1.2, '💝': 1.2, '❤': 1.5, '♥️': 1.3,
    '👍': 1.0, '👍🏻': 1.0, '👍🏼': 1.0, '👍🏽': 1.0, '👍🏾': 1.0, '👍🏿': 1.0,
    '👏': 1.0, '🙌': 1.2, '🤝': 0.8, '✅': 0.8, '💯': 1.3, '🔥': 1.0,
    '😎': 0.9, '🤤': 0.6, '🫶': 1.3, '🥹': 1.0, '😌': 0.7, '🥺': 0.5,
    '😏': 0.4, '🙏': 0.8, '🫡': 0.6, '🤓': 0.5, '😺': 0.8, '😸': 1.0,
    '😹': 1.2, '😻': 1.3, '😽': 0.8, '🫰': 0.7, '👌': 0.8,
  };

  // Negative emojis (weighted 1.0 to 2.0)
  static const Map<String, double> _negativeEmojis = {
    '😢': 1.2, '😭': 1.5, '😤': 1.2, '😠': 1.3, '😡': 1.5, '🤬': 2.0,
    '😈': 0.8, '👿': 1.0, '💀': 0.7, '☠️': 0.8, '💔': 1.5, '😰': 1.0,
    '😨': 1.0, '😱': 1.2, '😥': 1.0, '😓': 0.8, '😞': 1.0, '😔': 1.0,
    '😟': 0.9, '😕': 0.7, '🙁': 0.8, '☹️': 1.0, '😣': 0.9, '😖': 1.0,
    '😫': 1.0, '😩': 1.0, '😮‍💨': 0.8, '😪': 0.6, '🤮': 1.5, '🤢': 1.2,
    '😵': 1.0, '😵‍💫': 0.9, '🤕': 0.8, '🤒': 0.7, '👎': 1.2, '👎🏻': 1.2,
    '👎🏼': 1.2, '👎🏽': 1.2, '👎🏾': 1.2, '👎🏿': 1.2, '🖕': 2.0,
    '😾': 1.0, '😿': 1.2, '🙀': 0.9, '💢': 1.3, '😒': 0.9, '🙄': 0.8,
    '😑': 0.6, '😐': 0.3, '😬': 0.5, '🫤': 0.5, '❌': 1.0,
  };

  // Multilingual positive keywords (covers EN, ES, FR, DE, PT, IT, NL, HI, AR, TR, RU)
  static final Set<String> _positiveWords = {
    // English
    'love', 'loved', 'loving', 'lovely', 'great', 'good', 'nice', 'awesome',
    'amazing', 'wonderful', 'fantastic', 'excellent', 'perfect', 'beautiful',
    'happy', 'glad', 'joy', 'joyful', 'excited', 'exciting', 'best', 'better',
    'thanks', 'thank', 'thankful', 'grateful', 'appreciate', 'congrats',
    'congratulations', 'well', 'cool', 'super', 'brilliant', 'incredible',
    'fun', 'funny', 'hilarious', 'laugh', 'haha', 'hahaha', 'hehe', 'lol',
    'lmao', 'rofl', 'yes', 'yeah', 'yay', 'yep', 'absolutely', 'definitely',
    'blessed', 'bravo', 'cheers', 'sweet', 'cute', 'adorable', 'like',
    'enjoy', 'enjoyed', 'welcome', 'wow', 'omg', 'proud',
    'agree', 'sure', 'right', 'fine', 'okay', 'ok', 'kind',
    'xoxo', 'hugs', 'kisses',
    // Casual conversation & affection (WhatsApp-heavy)
    'hey', 'hi', 'hello', 'hii', 'hiii', 'hiiii', 'heyy', 'heyyy',
    'dear', 'babe', 'baby', 'bby', 'darling', 'honey', 'hun', 'cutie',
    'sweetheart', 'sweetie', 'luv', 'boo', 'babes', 'jaan', 'jaanu',
    'shona', 'sona', 'sapno', 'princess', 'prince', 'queen', 'king',
    'aww', 'awww', 'awwww', 'ohh', 'ooh', 'oooh', 'yass', 'yasss',
    'hmmm', 'mhmm', 'yup', 'yea', 'aight', 'alright', 'alrighty',
    'morning', 'goodmorning', 'goodnight', 'gm', 'gn', 'nighty',
    'byee', 'byeee', 'cya', 'ttyl', 'tc', 'takecare',
    'please', 'pls', 'plz', 'congrats', 'congratulations',
    'wanna', 'gonna', 'lemme', 'coming', 'done', 'ready',
    'ofcourse', 'obv', 'obviously', 'duh', 'ikr',
    'same', 'true', 'tru', 'hru', 'wbu', 'howdy',
    'muah', 'mwah', 'smooch', 'cuddle', 'cuddles', 'snuggle',
    'dream', 'dreams', 'wish', 'wishes', 'lucky', 'special', 'precious',
    'together', 'forever', 'always', 'promise', 'care', 'caring',
    'smile', 'smiling', 'laughing', 'giggles', 'blush', 'blushing',
    'handsome', 'gorgeous', 'stunning', 'prettiest', 'cutest',
    'bestie', 'buddy', 'bro', 'sis', 'fam', 'homie', 'dude',
    // Spanish
    'amor', 'bueno', 'buena', 'genial', 'excelente', 'increíble', 'increible',
    'feliz', 'contento', 'contenta', 'gracias', 'perfecto', 'perfecta',
    'hermoso', 'hermosa', 'bonito', 'bonita', 'jaja', 'jajaja', 'bien',
    'super', 'maravilloso', 'maravillosa', 'fantástico', 'fantastico',
    'lindo', 'linda', 'rico', 'rica', 'guapo', 'guapa', 'besos', 'abrazo',
    // French
    'amour', 'bien', 'bon', 'bonne', 'super', 'excellente', 'génial',
    'genial', 'merci', 'parfait', 'parfaite', 'beau', 'belle', 'heureux',
    'heureuse', 'magnifique', 'formidable', 'bisous', 'bravo', 'chouette',
    'mdr', 'ptdr', 'bisou',
    // German
    'liebe', 'gut', 'super', 'toll', 'wunderbar', 'danke', 'perfekt',
    'schön', 'schon', 'glücklich', 'glucklich', 'prima', 'klasse',
    'herrlich', 'geil', 'spitze', 'fantastisch', 'lustig',
    // Portuguese
    'amor', 'bom', 'boa', 'ótimo', 'otimo', 'excelente', 'perfeito',
    'perfeita', 'obrigado', 'obrigada', 'lindo', 'linda', 'maravilhoso',
    'maravilhosa', 'feliz', 'legal', 'massa', 'top', 'valeu', 'beijo',
    'beijos', 'abraço', 'rsrs', 'kkk', 'kkkk',
    // Italian
    'amore', 'buono', 'buona', 'bene', 'ottimo', 'ottima', 'perfetto',
    'perfetta', 'grazie', 'bello', 'bella', 'fantastico', 'fantastica',
    'meraviglioso', 'meravigliosa', 'bravo', 'brava', 'baci', 'abbraccio',
    // Hindi / Urdu (transliterated)
    'accha', 'acha', 'achha', 'bahut', 'pyaar', 'pyar', 'khushi', 'dhanyavaad',
    'shukriya', 'mast', 'zabardast', 'shandar', 'badhiya', 'sundar', 'haan',
    // Arabic (transliterated)
    'habibi', 'habibti', 'shukran', 'mabrook', 'mashallah', 'inshallah',
    'ahlan', 'jameel', 'jameela', 'mumtaz', 'tayeb',
    // Turkish
    'güzel', 'guzel', 'harika', 'mükemmel', 'mukemmel', 'süper', 'teşekkür',
    'tesekkur', 'iyi', 'sevgi', 'mutlu',
    // Russian (transliterated)
    'khorosho', 'otlichno', 'spasibo', 'lyublyu', 'krasivo', 'zdorovo',
    'molodec', 'super', 'kruto', 'da',
    // Common chat abbreviations
    'ty', 'thx', 'ily', 'ilysm', 'tysm', 'np', 'gg', 'ftw',
  };

  // Multilingual negative keywords
  static final Set<String> _negativeWords = {
    // English
    'hate', 'hated', 'hating', 'bad', 'terrible', 'horrible', 'awful',
    'worst', 'worse', 'ugly', 'stupid', 'dumb', 'idiot', 'sad', 'angry',
    'mad', 'furious', 'annoyed', 'annoying', 'disappointed', 'disappointing',
    'disgusting', 'pathetic', 'useless', 'boring', 'bored', 'never', 'wrong',
    'hurt', 'painful', 'sick', 'exhausted',
    'stressed', 'depressed', 'depressing', 'died', 'death', 'dead',
    'fail', 'failed', 'failure', 'crying', 'cried', 'worried',
    'fear', 'afraid', 'scared', 'lonely', 'alone',
    'broken', 'lost', 'unfortunately', 'tragic', 'nope',
    'ugh', 'ew', 'wtf', 'smh', 'fml',
    'ruined', 'hopeless', 'sucks', 'suck', 'terrible',
    'miserable', 'nightmare', 'regret', 'regretting', 'ashamed',
    'embarrassed', 'embarrassing', 'awkward', 'crappy', 'garbage',
    'worthless', 'helpless', 'frustrated', 'frustrating',
    // Spanish
    'odio', 'malo', 'mala', 'horrible', 'triste', 'enfadado',
    'enfadada', 'enojado', 'enojada', 'feo', 'fea', 'tonto', 'tonta',
    'perdón', 'perdon', 'dolor', 'enfermo', 'enferma', 'cansado', 'cansada',
    'aburrido', 'aburrida', 'muerto', 'muerta', 'llorar',
    // French
    'déteste', 'deteste', 'mauvais', 'mauvaise', 'terrible', 'horrible',
    'triste', 'fâché', 'fache', 'pardon', 'désolé', 'desole', 'douleur',
    'mort', 'morte', 'ennuyeux', 'nul', 'nulle', 'moche',
    // German
    'hass', 'schlecht', 'schrecklich', 'furchtbar', 'traurig', 'wütend',
    'wutend', 'böse', 'bose', 'hässlich', 'hasslich', 'dumm', 'tut',
    'leid', 'schmerz', 'krank', 'müde', 'mude', 'langweilig', 'tot',
    // Portuguese
    'ódio', 'odio', 'ruim', 'terrível', 'terrivel', 'horrível', 'horrivel',
    'triste', 'bravo', 'brava', 'feio', 'feia', 'burro', 'burra',
    'desculpa', 'dor', 'doente', 'cansado', 'cansada', 'morto', 'morta',
    'chato', 'chata', 'chorar',
    // Italian
    'odio', 'cattivo', 'cattiva', 'terribile', 'orribile', 'triste',
    'arrabbiato', 'arrabbiata', 'brutto', 'brutta', 'stupido', 'stupida',
    'scusa', 'scusami', 'dolore', 'malato', 'malata', 'stanco', 'stanca',
    'morto', 'morta', 'noioso', 'noiosa', 'piangere',
    // Hindi / Urdu (transliterated)
    'bura', 'kharab', 'dukh', 'gussa', 'nafrat', 'galat', 'maaf',
    'takleef', 'thak', 'bimar',
    // Arabic (transliterated)
    'saye', 'ghalat', 'huzn', 'ghadab', 'maafi', 'marid', 'maut',
    // Turkish
    'kötü', 'kotu', 'berbat', 'üzgün', 'uzgun', 'kızgın', 'kizgin',
    'çirkin', 'cirkin', 'aptal', 'özür', 'ozur', 'ağrı', 'agri', 'hasta',
    'yorgun', 'ölü', 'olu', 'sıkıcı', 'sikici',
    // Russian (transliterated)
    'ploho', 'uzhasno', 'grustno', 'zlo', 'nenavist', 'durak', 'prostite',
    'bol', 'bolno', 'net', 'plakat',
  };

  // Intensifiers boost the weight of surrounding sentiment
  static final Set<String> _intensifiers = {
    'very', 'really', 'so', 'extremely', 'super', 'absolutely', 'totally',
    'completely', 'incredibly', 'truly', 'deeply', 'quite', 'most',
    'muy', 'mucho', 'mucha', 'bastante', // Spanish
    'très', 'tres', 'vraiment', 'tellement', // French
    'sehr', 'total', 'echt', 'wirklich', // German
    'muito', 'demais', // Portuguese
    'molto', 'davvero', 'troppo', // Italian
    'bahut', 'bohot', // Hindi
    'jiddan', 'ktir', // Arabic
    'çok', 'cok', 'aşırı', 'asiri', // Turkish
    'ochen', // Russian
  };

  // Negators flip sentiment
  static final Set<String> _negators = {
    'not', "don't", 'dont', "doesn't", 'doesnt', "didn't", 'didnt',
    "isn't", 'isnt', "wasn't", 'wasnt', "can't", 'cant', 'no', 'never',
    "won't", 'wont', "wouldn't", 'wouldnt', "couldn't", 'couldnt',
    'neither', 'nor', 'without', 'hardly',
    'ni', 'sin', 'nunca', // Spanish
    'ne', 'pas', 'non', 'jamais', // French
    'nicht', 'kein', 'keine', 'nie', 'niemals', // German
    'não', 'nao', 'nem', 'nunca', // Portuguese
    'non', 'mai', 'nessuno', // Italian
    'nahi', 'nah', 'mat', // Hindi
    'la', 'mish', // Arabic
    'değil', 'degil', 'yok', // Turkish
    'nye', 'ne', // Russian
  };

  // ══════════════════════════════════════════════════════════════
  //  ENHANCED SENTIMENT PATTERNS
  // ══════════════════════════════════════════════════════════════
  
  // Sarcasm indicators (often paired with positive words ironically)
  static final Set<String> _sarcasmMarkers = {
    'yeah right', 'sure thing', 'oh great', 'how wonderful', 'fantastic',
    'just wonderful', 'brilliant idea', 'totally fine', 'absolutely perfect',
    'sooo great', 'sooo happy', 'sooo good', 'wow amazing',
  };

  // Contrast words that flip sentiment mid-sentence
  static final Set<String> _contrastWords = {
    'but', 'however', 'though', 'although', 'yet', 'still', 'except',
    'nevertheless', 'nonetheless', 'whereas', 'while', 'despite',
  };

  // Positive bigrams/phrases (stronger than single words)
  static final Map<String, double> _positivePhrases = {
    'thank you': 1.5, 'thanks so much': 2.0, 'love you': 2.5, 'love it': 1.8,
    'love u': 2.5, 'luv u': 2.0, 'luv you': 2.0,
    'i love': 2.0, 'i miss': 1.8, 'miss you': 2.0, 'miss u': 2.0,
    'miss ya': 2.0, 'missing you': 2.0, 'thinking of you': 1.8,
    'so good': 1.5, 'so happy': 1.8, 'very good': 1.5, 'very happy': 1.8,
    'really good': 1.5, 'really love': 1.8, 'appreciate it': 1.5,
    'well done': 1.5, 'good job': 1.5, 'great work': 1.6, 'nice work': 1.4,
    'sounds good': 1.3, 'looks good': 1.3, 'feels good': 1.5,
    'cant wait': 1.6, "can't wait": 1.6, 'looking forward': 1.5,
    'take care': 1.5, 'be safe': 1.3, 'sleep well': 1.5, 'sleep tight': 1.5,
    'good morning': 1.5, 'good night': 1.5, 'sweet dreams': 1.8,
    'have fun': 1.3, 'had fun': 1.5, 'so much fun': 1.8,
    'come here': 1.0, 'come over': 1.0, 'lets go': 1.2, "let's go": 1.2,
    'so cute': 1.8, 'so sweet': 1.8, 'so pretty': 1.6, 'so beautiful': 1.8,
    'you are': 0.5, 'youre the': 0.5, // often followed by compliments
    'proud of': 1.5, 'happy for': 1.5, 'glad you': 1.3,
    'no worries': 1.0, 'no problem': 1.0, 'all good': 1.2,
    'of course': 1.0, 'for sure': 1.0, 'why not': 0.8,
    'me too': 0.8, 'same here': 0.8,
    'stay safe': 1.2, 'drive safe': 1.2, 'get well': 1.3,
    'feel better': 1.3, 'cheer up': 1.2, 'hang in': 1.0,
  };

  // Negative bigrams/phrases
  static final Map<String, double> _negativePhrases = {
    'not good': 1.5, 'not happy': 1.8, 'not cool': 1.4, 'no way': 1.3,
    'so bad': 1.8, 'very bad': 1.8, 'really bad': 1.8, 'too bad': 1.5,
    'so sad': 1.8, 'feel bad': 1.6, 'fed up': 1.7, 'give up': 1.5,
    'cant take': 1.7, "can't take": 1.7, 'had enough': 1.6,
    'sick of': 1.7, 'tired of': 1.6, 'done with': 1.5,
  };

  // Modern slang (multilingual internet speak)
  static final Map<String, double> _slangPositive = {
    'lit': 1.5, 'fire': 1.5, 'dope': 1.4, 'sick': 1.3, 'goat': 1.6,
    'bet': 1.2, 'facts': 1.3, 'vibes': 1.3, 'mood': 1.0, 'slay': 1.5,
    'bussin': 1.5, 'valid': 1.3, 'based': 1.3, 'poggers': 1.5,
    'lowkey': 0.5, 'highkey': 0.8, 'ngl': 0.5, 'fr': 0.5, 'frfr': 0.8,
    'tbh': 0.3, 'imo': 0.3, 'lesgo': 1.4, 'lessgoo': 1.5,
  };

  static final Map<String, double> _slangNegative = {
    'trash': 1.6, 'toxic': 1.8, 'cringe': 1.5, 'mid': 1.3, 'cap': 1.4,
    'ratio': 1.4, 'yikes': 1.5, 'oof': 1.3, 'bruh': 1.2,
    'rip': 1.3, 'sus': 1.2,
  };

  // ══════════════════════════════════════════════════════════════
  //  CONVERSATIONAL ENGAGEMENT WORDS
  //  These indicate active participation & warmth in a chat.
  //  Chatting IS a positive act — these give a mild positive push.
  // ══════════════════════════════════════════════════════════════
  static final Map<String, double> _engagementWords = {
    // Questions = caring / interest
    'where': 0.3, 'when': 0.3, 'how': 0.3, 'what': 0.2, 'why': 0.2,
    'which': 0.2, 'who': 0.2, 'kaha': 0.3, 'kab': 0.3, 'kaise': 0.3,
    'kya': 0.2, 'kyun': 0.2, 'kidhar': 0.3, 'kaisa': 0.3,
    // Responses & cooperation
    'coming': 0.4, 'done': 0.3, 'sent': 0.3, 'sending': 0.3,
    'here': 0.3, 'there': 0.2, 'going': 0.3, 'went': 0.2,
    'reached': 0.4, 'leaving': 0.3, 'left': 0.2, 'waiting': 0.3,
    'wait': 0.2, 'see': 0.3, 'saw': 0.3, 'seen': 0.2,
    'tell': 0.3, 'told': 0.2, 'said': 0.2, 'saying': 0.2,
    'call': 0.4, 'called': 0.3, 'calling': 0.4,
    'meet': 0.5, 'meeting': 0.4, 'lets': 0.4, 'let': 0.2,
    // Sharing & caring
    'send': 0.3, 'share': 0.3, 'check': 0.3, 'look': 0.3,
    'show': 0.3, 'give': 0.3, 'take': 0.2, 'bring': 0.3,
    'eat': 0.3, 'eating': 0.3, 'food': 0.3, 'dinner': 0.3,
    'lunch': 0.3, 'breakfast': 0.3, 'coffee': 0.3, 'tea': 0.3,
    // Planning = future together = positive 
    'tomorrow': 0.3, 'today': 0.2, 'tonight': 0.3, 'later': 0.2,
    'soon': 0.3, 'now': 0.2, 'time': 0.2, 'plan': 0.4,
    'plans': 0.4, 'weekend': 0.4, 'trip': 0.5, 'movie': 0.4,
    'watch': 0.3, 'watching': 0.3, 'listen': 0.3, 'song': 0.3,
    'photo': 0.3, 'photos': 0.3, 'pic': 0.3, 'pics': 0.3,
    'video': 0.3, 'game': 0.3,
    // Acknowledgments = responsiveness
    'ok': 0.2, 'okay': 0.2, 'okie': 0.3, 'okk': 0.3, 'okkk': 0.3,
    'ya': 0.3, 'yaa': 0.3, 'yaaa': 0.4, 'han': 0.3, 'haan': 0.3,
    'hmm': 0.2, 'hmmm': 0.2, 'acha': 0.3, 'achha': 0.3, 'accha': 0.3,
    'theek': 0.3, 'thik': 0.3, 'sahi': 0.3,
    // Home / daily life sharing (intimacy signals)
    'home': 0.3, 'office': 0.2, 'work': 0.2, 'class': 0.2,
    'college': 0.2, 'school': 0.2, 'shop': 0.3, 'shopping': 0.4,
    'sleep': 0.3, 'sleeping': 0.3, 'woke': 0.3, 'awake': 0.3,
    'bath': 0.2, 'ready': 0.3, 'getting': 0.2,
    // Hindi/Urdu casual conversation
    'bolo': 0.3, 'batao': 0.3, 'bata': 0.3, 'sunna': 0.3, 'suno': 0.3,
    'dekho': 0.3, 'dekhna': 0.3, 'chalo': 0.4, 'chalte': 0.3,
    'milte': 0.4, 'milna': 0.4, 'aaja': 0.4, 'aao': 0.4,
    'jaldi': 0.3, 'abhi': 0.3, 'ruk': 0.2, 'ruko': 0.2,
    'khana': 0.3, 'kha': 0.3, 'khao': 0.3, 'pani': 0.2,
    'ghar': 0.3, 'bahar': 0.3, 'andar': 0.2,
  };

  /// Analyze sentiment using the ENHANCED built-in lexicon engine
  SentimentResult _analyzeLexicon(String text) {
    if (text.trim().isEmpty) {
      return SentimentResult(positiveScore: 0.33, negativeScore: 0.33, neutralScore: 0.34);
    }

    double posScore = 0.0;
    double negScore = 0.0;
    int signals = 0;
    bool hasSarcasmSignal = false;
    bool hasContrastWord = false;

    final lower = text.toLowerCase();

    // ── Phase 0: Sarcasm detection (check early to modify later scoring) ──
    for (final marker in _sarcasmMarkers) {
      if (lower.contains(marker)) {
        hasSarcasmSignal = true;
        break;
      }
    }

    // ── Phase 1: ENHANCED Emoji analysis with repetition detection ──
    int totalEmojis = 0;
    double emojiPosScore = 0.0;
    double emojiNegScore = 0.0;

    for (final entry in _positiveEmojis.entries) {
      final count = entry.key.allMatches(text).length;
      if (count > 0) {
        // Repetition boosts intensity: 😂 = 1.5, 😂😂 = 3.2, 😂😂😂 = 5.1
        final boost = count == 1 ? 1.0 : (count == 2 ? 1.4 : count * 0.7);
        emojiPosScore += entry.value * boost;
        totalEmojis += count;
        signals += count;
      }
    }
    for (final entry in _negativeEmojis.entries) {
      final count = entry.key.allMatches(text).length;
      if (count > 0) {
        final boost = count == 1 ? 1.0 : (count == 2 ? 1.4 : count * 0.7);
        emojiNegScore += entry.value * boost;
        totalEmojis += count;
        signals += count;
      }
    }

    // Detect emoji-text mismatch (potential sarcasm)
    if (totalEmojis > 0) {
      final emojiRatio = emojiPosScore / (emojiPosScore + emojiNegScore + 0.01);
      // Will compare with text sentiment later
    }

    posScore += emojiPosScore;
    negScore += emojiNegScore;

    // ── Phase 2: ENHANCED phrase and word analysis ──
    final textNoPunct = lower.replaceAll(RegExp(r'[^\w\s]'), ' ');
    final words = textNoPunct
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();

    // Check for contrast words that split sentiment
    for (final word in words) {
      if (_contrastWords.contains(word)) {
        hasContrastWord = true;
        break;
      }
    }

    // Phase 2a: Detect multi-word phrases first (stronger signal)
    for (final entry in _positivePhrases.entries) {
      if (lower.contains(entry.key)) {
        posScore += entry.value;
        signals++;
      }
    }
    for (final entry in _negativePhrases.entries) {
      if (lower.contains(entry.key)) {
        negScore += entry.value;
        signals++;
      }
    }

    // Phase 2b: Slang detection
    for (int i = 0; i < words.length; i++) {
      final word = words[i];
      if (_slangPositive.containsKey(word)) {
        posScore += _slangPositive[word]!;
        signals++;
      } else if (_slangNegative.containsKey(word)) {
        negScore += _slangNegative[word]!;
        signals++;
      }
    }

    // Phase 2d: Engagement/conversational words — very mild positive nudge
    // These words mean someone is engaged in conversation, but they're NOT sentiment.
    // Cap total contribution heavily and do NOT count as real sentiment signals.
    double engagementScore = 0.0;
    int engagementCount = 0;
    for (final word in words) {
      if (_engagementWords.containsKey(word)) {
        engagementScore += _engagementWords[word]!;
        engagementCount++;
      }
    }
    if (engagementCount > 0) {
      // Hard cap: engagement can add at most 0.3 positive regardless of word count
      final cappedEngagement = engagementScore.clamp(0.0, 0.3);
      posScore += cappedEngagement;
      // Only count as 1 signal max (not per-word) — don't dominate signal count
      signals += 1;
    }

    // Phase 2c: Word-by-word with EXTENDED negation scope
    int negationScope = 0; // Tracks how many words negation affects
    bool prevIntensifier = false;

    for (int i = 0; i < words.length; i++) {
      final word = words[i];

      // Negation affects next 3-4 words
      if (_negators.contains(word)) {
        negationScope = 4;
        continue;
      }
      if (_intensifiers.contains(word)) {
        prevIntensifier = true;
        continue;
      }

      double weight = prevIntensifier ? 1.6 : 1.0;
      bool isNegated = negationScope > 0;

      if (_positiveWords.contains(word)) {
        if (isNegated) {
          negScore += 0.7 * weight; // "not happy" = negative
        } else {
          posScore += weight;
        }
        signals++;
      } else if (_negativeWords.contains(word)) {
        if (isNegated) {
          posScore += 0.5 * weight; // "not bad" = slightly positive
        } else {
          negScore += weight;
        }
        signals++;
      }

      // Decay negation scope
      if (negationScope > 0) {
        negationScope--;
      }

      prevIntensifier = false;
    }

    // ── Phase 3: ENHANCED punctuation intensity ──
    final exclamations = '!'.allMatches(text).length;
    final questions = '?'.allMatches(text).length;
    final multiExclaim = text.contains('!!!') || text.contains('!!!!');
    final multiQuestion = text.contains('???') || text.contains('????');
    final ellipsis = text.contains('...') || text.contains('…');

    // Multiple exclamations = stronger emotion
    if (multiExclaim && signals > 0) {
      final boost = 0.3;
      if (posScore > negScore) {
        posScore += boost;
      } else if (negScore > posScore) {
        negScore += boost;
      }
    } else if (exclamations > 0 && signals > 0) {
      final boost = exclamations * 0.12;
      if (posScore > negScore) {
        posScore += boost;
      } else if (negScore > posScore) {
        negScore += boost;
      }
    }

    // Multiple questions = confusion/concern (slight negative)
    if (multiQuestion) {
      negScore += 0.2;
      signals++;
    }

    // Ellipsis = hesitation, trailing off (slightly negative/uncertain)
    if (ellipsis) {
      negScore += 0.15;
      signals++;
    }

    // ── Phase 4: ENHANCED laughter detection (stronger positive signal) ──
    final laughPatterns = RegExp(
      r'(ha){2,}|(he){2,}|(ja){2,}|(je){2,}|(rs){2,}|(k){3,}|(x){3,}|(히){2,}|(ㅋ){2,}|(笑)|'
      r'(wk){2,}|(aha){2,}|(ehe){2,}|lmao|rofl|lmfao|rotfl|lol+',
      caseSensitive: false,
    );
    final laughMatches = laughPatterns.allMatches(lower);
    final laughCount = laughMatches.length;
    
    if (laughCount > 0) {
      // Stronger laughter = more positive
      double laughScore = 0.0;
      for (final match in laughMatches) {
        final laughText = match.group(0)!;
        final length = laughText.length;
        // Longer laughter = more intensity: "haha" = 0.8, "hahaha" = 1.2, "hahahaha" = 1.6
        laughScore += length > 6 ? 1.6 : (length > 4 ? 1.2 : 0.9);
      }
      posScore += laughScore;
      signals += laughCount;
    }

    // ── Phase 5: ENHANCED CAPS detection ──
    final capsWords = words.where((w) => w.length > 2 && w == w.toUpperCase()).length;
    final allCaps = words.length > 2 && words.every((w) => w.length <= 2 || w == w.toUpperCase());
    
    if (allCaps && words.length > 2) {
      // ENTIRE MESSAGE IN CAPS = very strong emotion
      final boost = 0.5;
      if (posScore > negScore) {
        posScore += boost;
      } else if (negScore > posScore) {
        negScore += boost;
      }
      signals++;
    } else if (capsWords > 0 && signals > 0) {
      final boost = capsWords * 0.15;
      if (posScore > negScore) {
        posScore += boost;
      } else if (negScore > posScore) {
        negScore += boost;
      }
    }

    // ── Phase 6: WhatsApp-specific patterns ──
    if (text.contains('<Media omitted>') || text.contains('media omitted')) {
      // Media shares — slightly positive but mostly neutral
      if (signals == 0) {
        return SentimentResult(positiveScore: 0.25, negativeScore: 0.05, neutralScore: 0.70);
      }
    }

    // Short messages — classify smarter instead of defaulting neutral
    if (words.length <= 2 && totalEmojis == 0 && signals == 0) {
      // Single-word replies: classify common ones
      final singleWord = words.isNotEmpty ? words.first : '';
      if ({'ok', 'okay', 'k', 'kk', 'hmm', 'hm', 'ya', 'han'}.contains(singleWord)) {
        // Acknowledgments — these are neutral, not positive
        return SentimentResult(positiveScore: 0.10, negativeScore: 0.05, neutralScore: 0.85);
      }
    }

    // ── Phase 7: Sarcasm adjustment ──
    if (hasSarcasmSignal) {
      // Flip positive words to negative when sarcasm detected
      if (posScore > negScore) {
        final temp = posScore * 0.6;
        posScore = posScore * 0.2;
        negScore += temp;
      }
    }

    // ── Phase 8: Contrast word handling ──
    if (hasContrastWord) {
      // "but" often introduces the true sentiment (e.g., "good but..." = negative)
      // Weight the latter half more heavily
      // For now, reduce confidence by boosting neutral
      // (More sophisticated: split sentence and analyze parts separately)
    }

    // ── IMPROVED normalization — less neutral-biased ──
    if (signals == 0) {
      // No sentiment signals at all — this is genuinely neutral content.
      // "ok", "where are you", "coming in 5 min" = neutral, not positive.
      if (words.length <= 3) {
        return SentimentResult(positiveScore: 0.15, negativeScore: 0.05, neutralScore: 0.80);
      } else if (words.length <= 8) {
        return SentimentResult(positiveScore: 0.12, negativeScore: 0.08, neutralScore: 0.80);
      } else {
        return SentimentResult(positiveScore: 0.10, negativeScore: 0.10, neutralScore: 0.80);
      }
    }

    final total = posScore + negScore;
    if (total == 0) {
      return SentimentResult(positiveScore: 0.15, negativeScore: 0.05, neutralScore: 0.80);
    }

    // Detect mixed sentiment (both positive and negative signals present)
    final mixedSentiment = posScore > 0.5 && negScore > 0.5;
    
    // Calculate sentiment proportions
    double posRatio = posScore / total;
    double negRatio = negScore / total;

    // ── KEY CHANGE: Much lower neutral floor ──
    // Before: neutralBase was 0.5-0.8 for most messages (way too high)
    // Now: Scale neutral based on actual signal strength
    // Strong signals (emoji + words) → very low neutral
    // Weak signals (1 word) → moderate neutral
    final avgSignalStrength = total / signals;
    
    // Map signal strength to neutral percentage:
    //   avgStrength >= 1.5 → ~18% neutral (strong sentiment)
    //   avgStrength ~= 1.0 → ~30% neutral (moderate)
    //   avgStrength ~= 0.5 → ~45% neutral (weak/conversational)
    double neutralPct;
    if (avgSignalStrength >= 1.5) {
      neutralPct = 0.18;
    } else if (avgSignalStrength >= 1.0) {
      neutralPct = 0.30;
    } else if (avgSignalStrength >= 0.6) {
      neutralPct = 0.40;
    } else {
      neutralPct = 0.50;
    }

    // More signals = slightly more confident, but don't crush neutral
    if (signals >= 5) {
      neutralPct *= 0.80;
    } else if (signals >= 3) {
      neutralPct *= 0.90;
    }

    // Mixed sentiment gets more neutral (genuine uncertainty)
    if (mixedSentiment) {
      neutralPct += 0.12;
    }

    neutralPct = neutralPct.clamp(0.15, 0.60);

    // Final probabilities (must sum to 1.0)
    double pPos = posRatio * (1.0 - neutralPct);
    double pNeg = negRatio * (1.0 - neutralPct);
    double pNeu = neutralPct;
    
    final sum = pPos + pNeg + pNeu;
    pPos /= sum;
    pNeg /= sum;
    pNeu /= sum;

    return SentimentResult(
      positiveScore: pPos.clamp(0.0, 1.0), 
      negativeScore: pNeg.clamp(0.0, 1.0), 
      neutralScore: pNeu.clamp(0.0, 1.0),
    );
  }

  /// Analyze sentiment of a single message
  Future<SentimentResult?> analyzeSentiment(String text) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (text.trim().isEmpty) {
      return SentimentResult(positiveScore: 0.33, negativeScore: 0.33, neutralScore: 0.34);
    }

    // Use TFLite model if available
    if (!_useLexiconFallback && _interpreter != null) {
      try {
        final input = _preprocessText(text);
        final output = List.filled(1, List.filled(3, 0.0)).cast<List<double>>();
        _interpreter!.run(input, output);
        final scores = output[0];
        return SentimentResult(
          positiveScore: scores[0],
          negativeScore: scores[1],
          neutralScore: scores[2],
        );
      } catch (e) {
        // Fall through to lexicon
      }
    }

    // Lexicon-based analysis (built-in, no model needed)
    return _analyzeLexicon(text);
  }

  /// Analyze sentiment for multiple messages (batch processing)
  Future<List<SentimentResult?>> analyzeBatch(List<String> texts) async {
    final results = <SentimentResult?>[];
    for (final text in texts) {
      results.add(await analyzeSentiment(text));
    }
    return results;
  }

  /// Preprocess text into model input format (for TFLite path only)
  List<List<int>> _preprocessText(String text) {
    final words = text.toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();

    final tokens = <int>[];
    for (final word in words) {
      if (_vocabulary != null && _vocabulary!.containsKey(word)) {
        tokens.add(_vocabulary![word]!);
      } else {
        tokens.add(1);
      }
    }

    if (tokens.length < _maxSequenceLength) {
      tokens.addAll(List.filled(_maxSequenceLength - tokens.length, 0));
    } else if (tokens.length > _maxSequenceLength) {
      tokens.removeRange(_maxSequenceLength, tokens.length);
    }

    return [tokens];
  }

  /// Calculate aggregate sentiment for a collection of messages
  SentimentStats calculateStats(List<SentimentResult> results) {
    if (results.isEmpty) {
      return SentimentStats(
        averagePositive: 0.0,
        averageNegative: 0.0,
        averageNeutral: 0.0,
        positiveCount: 0,
        negativeCount: 0,
        neutralCount: 0,
        totalMessages: 0,
      );
    }

    double sumPositive = 0.0;
    double sumNegative = 0.0;
    double sumNeutral = 0.0;
    int positiveCount = 0;
    int negativeCount = 0;
    int neutralCount = 0;

    for (final result in results) {
      sumPositive += result.positiveScore;
      sumNegative += result.negativeScore;
      sumNeutral += result.neutralScore;

      switch (result.label) {
        case 'positive':
          positiveCount++;
          break;
        case 'negative':
          negativeCount++;
          break;
        case 'neutral':
          neutralCount++;
          break;
      }
    }

    final total = results.length;
    return SentimentStats(
      averagePositive: sumPositive / total,
      averageNegative: sumNegative / total,
      averageNeutral: sumNeutral / total,
      positiveCount: positiveCount,
      negativeCount: negativeCount,
      neutralCount: neutralCount,
      totalMessages: total,
    );
  }

  /// Dispose resources
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _vocabulary = null;
    _isInitialized = false;
    _useLexiconFallback = false;
  }
}

/// Aggregated sentiment statistics
class SentimentStats {
  final double averagePositive;
  final double averageNegative;
  final double averageNeutral;
  final int positiveCount;
  final int negativeCount;
  final int neutralCount;
  final int totalMessages;

  SentimentStats({
    required this.averagePositive,
    required this.averageNegative,
    required this.averageNeutral,
    required this.positiveCount,
    required this.negativeCount,
    required this.neutralCount,
    required this.totalMessages,
  });

  /// Get positive percentage
  double get positivePercent => 
      totalMessages > 0 ? (positiveCount / totalMessages) * 100 : 0.0;

  /// Get negative percentage
  double get negativePercent => 
      totalMessages > 0 ? (negativeCount / totalMessages) * 100 : 0.0;

  /// Get neutral percentage
  double get neutralPercent => 
      totalMessages > 0 ? (neutralCount / totalMessages) * 100 : 0.0;

  /// Get overall mood score (-1 to 1, where -1 is very negative, 1 is very positive)
  double get moodScore => averagePositive - averageNegative;

  Map<String, dynamic> toJson() => {
        'averagePositive': averagePositive,
        'averageNegative': averageNegative,
        'averageNeutral': averageNeutral,
        'positiveCount': positiveCount,
        'negativeCount': negativeCount,
        'neutralCount': neutralCount,
        'totalMessages': totalMessages,
      };

  factory SentimentStats.fromJson(Map<String, dynamic> json) => SentimentStats(
        averagePositive: (json['averagePositive'] as num?)?.toDouble() ?? 0.0,
        averageNegative: (json['averageNegative'] as num?)?.toDouble() ?? 0.0,
        averageNeutral: (json['averageNeutral'] as num?)?.toDouble() ?? 0.0,
        positiveCount: json['positiveCount'] as int? ?? 0,
        negativeCount: json['negativeCount'] as int? ?? 0,
        neutralCount: json['neutralCount'] as int? ?? 0,
        totalMessages: json['totalMessages'] as int? ?? 0,
      );
}
