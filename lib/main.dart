import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'l10n/app_localizations.dart';
import 'pages/chats_page.dart';
import 'pages/import_analyze_page.dart';
import 'pages/total_stats_page.dart';
import 'pages/onboarding_page.dart';

void main() {
  runApp(const MyApp());
}

class ProcessingLock {
  static String? _lastPath;
  static DateTime? _lastTime;
  static bool _isProcessing = false;

  static bool canProcess(String path) {
    if (_isProcessing) {
      print('🔒 ProcessingLock: Denied "$path" because _isProcessing is true');
      return false;
    }
    
    final now = DateTime.now();
    // Normalize path just in case
    final normalizedPath = path.replaceAll('\\', '/').toLowerCase();
    
    // Check if same path processed recently
    if (_lastPath == normalizedPath && 
        _lastTime != null) {
       final diff = now.difference(_lastTime!).inSeconds;
       if (diff < 10) {
         print('🔒 ProcessingLock: Denied "$path" because it matches last path and diff is ${diff}s (<10s)');
         return false;
       }
    }
    
    print('🔓 ProcessingLock: Allowed "$path". Setting lock.');
    _isProcessing = true;
    _lastPath = normalizedPath;
    _lastTime = now;
    
    // Auto-release lock after 10 seconds just in case
    Future.delayed(const Duration(seconds: 10), () {
      if (_isProcessing) {
        print('🔓 ProcessingLock: Auto-released lock after 10s timeout');
        _isProcessing = false;
      }
    });
    
    return true;
  }
  
  static void release() {
    print('🔓 ProcessingLock: Released manually');
    _isProcessing = false;
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  static void setLocale(BuildContext context, Locale newLocale) {
    _MyAppState? state = context.findAncestorStateOfType<_MyAppState>();
    state?.setLocale(newLocale);
  }

  static void setThemeMode(BuildContext context, ThemeMode mode) {
    _MyAppState? state = context.findAncestorStateOfType<_MyAppState>();
    state?.setThemeMode(mode);
  }

  static ThemeMode getThemeMode(BuildContext context) {
    _MyAppState? state = context.findAncestorStateOfType<_MyAppState>();
    return state?._themeMode ?? ThemeMode.system;
  }

  static void setThemeColor(BuildContext context, Color color) {
    _MyAppState? state = context.findAncestorStateOfType<_MyAppState>();
    state?.setThemeColor(color);
  }

  static Color getThemeColor(BuildContext context) {
    _MyAppState? state = context.findAncestorStateOfType<_MyAppState>();
    return state?._themeColor ?? Colors.deepPurple;
  }

  static void setFontFamily(BuildContext context, String fontFamily) {
    _MyAppState? state = context.findAncestorStateOfType<_MyAppState>();
    state?.setFontFamily(fontFamily);
  }

  static String getFontFamily(BuildContext context) {
    _MyAppState? state = context.findAncestorStateOfType<_MyAppState>();
    return state?._fontFamily ?? 'System';
  }

  /// Returns the list of available font families
  static List<Map<String, String>> get availableFonts => [
    {'id': 'System', 'name': 'System Default'},
    {'id': 'Inter', 'name': 'Inter'},
    {'id': 'Poppins', 'name': 'Poppins'},
    {'id': 'Roboto', 'name': 'Roboto'},
    {'id': 'Nunito', 'name': 'Nunito'},
    {'id': 'Outfit', 'name': 'Outfit'},
    {'id': 'Montserrat', 'name': 'Montserrat'},
  ];

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Locale? _locale;
  ThemeMode _themeMode = ThemeMode.system;
  Color _themeColor = Colors.deepPurple;
  String _fontFamily = 'System';

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      // Load theme mode
      final themeModeStr = prefs.getString('themeMode') ?? 'system';
      _themeMode = themeModeStr == 'light' 
          ? ThemeMode.light 
          : themeModeStr == 'dark' 
              ? ThemeMode.dark 
              : ThemeMode.system;

      // Load theme color
      final colorValue = prefs.getInt('themeColor') ?? Colors.deepPurple.value;
      _themeColor = Color(colorValue);

      // Load font family
      _fontFamily = prefs.getString('fontFamily') ?? 'System';

      // Load locale
      final localeCode = prefs.getString('locale');
      if (localeCode != null) {
        _locale = Locale(localeCode);
      }
    });
  }

  void setLocale(Locale locale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('locale', locale.languageCode);
    setState(() {
      _locale = locale;
    });
  }

  void setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeMode', mode == ThemeMode.light ? 'light' : mode == ThemeMode.dark ? 'dark' : 'system');
    setState(() {
      _themeMode = mode;
    });
  }

  void setThemeColor(Color color) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('themeColor', color.value);
    setState(() {
      _themeColor = color;
    });
  }

  void setFontFamily(String fontFamily) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fontFamily', fontFamily);
    setState(() {
      _fontFamily = fontFamily;
    });
  }

  TextTheme _getTextTheme(TextTheme base) {
    switch (_fontFamily) {
      case 'Inter':
        return GoogleFonts.interTextTheme(base);
      case 'Poppins':
        return GoogleFonts.poppinsTextTheme(base);
      case 'Roboto':
        return GoogleFonts.robotoTextTheme(base);
      case 'Nunito':
        return GoogleFonts.nunitoTextTheme(base);
      case 'Outfit':
        return GoogleFonts.outfitTextTheme(base);
      case 'Montserrat':
        return GoogleFonts.montserratTextTheme(base);
      default:
        return base; // System default
    }
  }

  @override
  Widget build(BuildContext context) {
    final lightBase = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: _themeColor, brightness: Brightness.light),
      useMaterial3: true,
    );
    final darkBase = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: _themeColor, brightness: Brightness.dark),
      useMaterial3: true,
    );

    return MaterialApp(
      title: 'OpenStaty',
      debugShowCheckedModeBanner: false,
      locale: _locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', ''), // English
        Locale('hi', ''), // Hindi
        Locale('es', ''), // Spanish
        Locale('fr', ''), // French
        Locale('de', ''), // German
        Locale('zh', ''), // Chinese
        Locale('ja', ''), // Japanese
        Locale('ru', ''), // Russian
        Locale('pt', ''), // Portuguese
        Locale('ar', ''), // Arabic
      ],
      theme: lightBase.copyWith(
        textTheme: _getTextTheme(lightBase.textTheme),
      ),
      darkTheme: darkBase.copyWith(
        textTheme: _getTextTheme(darkBase.textTheme),
      ),
      themeMode: _themeMode,
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  static const _channel = MethodChannel('com.example.open_staty/share');
  final GlobalKey<ImportAnalyzePageState> _importKey = GlobalKey<ImportAnalyzePageState>();
  final GlobalKey<ChatsPageState> _chatsKey = GlobalKey<ChatsPageState>();
  
  bool _isLoading = true;
  bool _showOnboarding = false;

  late final List<Widget> _pages = [
    ImportAnalyzePage(key: _importKey),
    ChatsPage(key: _chatsKey),
    const TotalStatsPage(),
  ];

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
    _setupShareListener();
    _checkInitialShare();
    // Wire up callback so ChatsPage refreshes after import
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _importKey.currentState?.onChatSaved = () {
        _chatsKey.currentState?.loadChats();
      };
    });
  }

  Future<void> _checkOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    final completed = prefs.getBool('onboarding_complete') ?? false;
    if (mounted) {
      setState(() {
        _showOnboarding = !completed;
        _isLoading = false;
      });
    }
  }

  void _onOnboardingComplete() {
    setState(() {
      _showOnboarding = false;
    });
  }

  void _setupShareListener() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onSharedFile') {
        final String filePath = call.arguments as String;
        print('📨 Received shared file: $filePath');
        _handleSharedFile(filePath);
      }
    });
  }

  Future<void> _checkInitialShare() async {
    try {
      final String? filePath = await _channel.invokeMethod('getSharedFile');
      if (filePath != null) {
        print('📨 Initial shared file found: $filePath');
        _handleSharedFile(filePath);
      }
    } catch (e) {
      print('⚠️ No initial shared file: $e');
    }
  }

  void _handleSharedFile(String filePath) {
    print('🔍 _handleSharedFile called with: $filePath');
    
    if (!ProcessingLock.canProcess(filePath)) {
      print('⚠️ Skipping duplicate share: $filePath');
      return;
    }
    
    print('🚀 Handling shared file: $filePath');

    // Switch to Import & Analyze tab
    setState(() {
      _selectedIndex = 0;
    });
    // Give the page a moment to build if needed, then process the file
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _importKey.currentState?.processSharedFile(filePath).then((_) {
        ProcessingLock.release();
      }).catchError((_) {
        ProcessingLock.release();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    // Show loading while checking onboarding status
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      );
    }

    // Show onboarding if first launch
    if (_showOnboarding) {
      return OnboardingPage(onComplete: _onOnboardingComplete);
    }

    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark 
              ? Colors.grey[900] 
              : Colors.white,
          boxShadow: [
            BoxShadow(
              blurRadius: 20,
              color: Colors.black.withOpacity(.1),
            )
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 12),
            child: GNav(
              rippleColor: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey[800]!
                  : Colors.grey[300]!,
              hoverColor: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey[700]!
                  : Colors.grey[100]!,
              gap: 8,
              activeColor: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black,
              iconSize: 26,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              duration: const Duration(milliseconds: 400),
              tabBackgroundColor: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey[800]!
                  : Colors.grey[100]!,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey[400]!
                  : Colors.black,
              tabs: const [
                GButton(
                  icon: Icons.analytics,
                  text: 'Import & Analyze',
                ),
                GButton(
                  icon: Icons.chat,
                  text: 'Chats',
                ),
                GButton(
                  icon: Icons.bar_chart,
                  text: 'Total Stats',
                ),
              ],
              selectedIndex: _selectedIndex,
              onTabChange: (index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
            ),
          ),
        ),
      ),
    );
  }
}
