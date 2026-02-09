import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../main.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Check device's system dark mode setting
    final deviceIsDark = MediaQuery.of(context).platformBrightness == Brightness.dark;
    final loc = AppLocalizations.of(context);
    final headingColor = isDark ? Colors.white : Colors.black;
    final subtleText = isDark ? Colors.grey[400]! : Colors.grey[600]!;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF7F7F7);
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: headingColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          loc?.translate('settings') ?? 'Settings',
          style: TextStyle(
            color: headingColor,
            fontSize: 17,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Appearance Section Header
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              loc?.translate('appearance') ?? 'Appearance',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: primary,
                letterSpacing: 0.5,
              ),
            ),
          ),

          // Dark/Light Mode Toggle
          Builder(
            builder: (context) {
              final currentMode = MyApp.getThemeMode(context);
              // If ThemeMode.system, use device's dark mode setting; otherwise use explicit setting
              final toggleValue = currentMode == ThemeMode.system 
                  ? deviceIsDark 
                  : currentMode == ThemeMode.dark;
              
              return _buildSettingCard(
                context,
                icon: isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                iconColor: isDark ? Colors.amber : Colors.orange,
                title: loc?.translate('dark_mode') ?? 'Dark Mode',
                subtitle: loc?.translate('dark_mode_desc') ?? 'Switch between light and dark themes',
                trailing: Switch.adaptive(
                  value: toggleValue,
                  onChanged: (value) {
                    MyApp.setThemeMode(context, value ? ThemeMode.dark : ThemeMode.light);
                  },
                  activeColor: primary,
                ),
                cardColor: cardColor,
                headingColor: headingColor,
                subtleText: subtleText,
              );
            },
          ),

          const SizedBox(height: 12),

          // App Theme Color
          _buildSettingCard(
            context,
            icon: Icons.palette_rounded,
            iconColor: primary,
            title: loc?.translate('app_theme') ?? 'App Theme',
            subtitle: loc?.translate('app_theme_desc') ?? 'Choose your accent color',
            trailing: const Icon(Icons.chevron_right_rounded, size: 24),
            onTap: () => _showThemeColorDialog(context, loc),
            cardColor: cardColor,
            headingColor: headingColor,
            subtleText: subtleText,
          ),

          const SizedBox(height: 12),

          // Font Style
          _buildSettingCard(
            context,
            icon: Icons.font_download_rounded,
            iconColor: Colors.pink,
            title: loc?.translate('font_style') ?? 'Font Style',
            subtitle: _getFontDisplayName(MyApp.getFontFamily(context)),
            trailing: const Icon(Icons.chevron_right_rounded, size: 24),
            onTap: () => _showFontDialog(context, loc),
            cardColor: cardColor,
            headingColor: headingColor,
            subtleText: subtleText,
          ),


          // Language Section Header
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              loc?.translate('language_section') ?? 'Language',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: primary,
                letterSpacing: 0.5,
              ),
            ),
          ),

          // Language Selector
          _buildSettingCard(
            context,
            icon: Icons.language_rounded,
            iconColor: Colors.blue,
            title: loc?.translate('language') ?? 'Language',
            subtitle: _getLanguageName(Localizations.localeOf(context).languageCode),
            trailing: const Icon(Icons.chevron_right_rounded, size: 24),
            onTap: () => _showLanguageDialog(context, loc),
            cardColor: cardColor,
            headingColor: headingColor,
            subtleText: subtleText,
          ),

          const SizedBox(height: 32),

          // App Info
          Center(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [primary, primary.withOpacity(0.7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.analytics_rounded, color: Colors.white, size: 32),
                ),
                const SizedBox(height: 12),
                Text(
                  'Open Staty',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: headingColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'v1.0.0',
                  style: TextStyle(
                    fontSize: 13,
                    color: subtleText,
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // GitHub Repo Link
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () async {
                      final url = Uri.parse('https://github.com/Sallytion/Open-Staty');
                      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
                        if (context.mounted) {
                           ScaffoldMessenger.of(context).showSnackBar(
                             const SnackBar(content: Text('Could not open GitHub link')),
                           );
                        }
                      }
                    },
                    borderRadius: BorderRadius.circular(50),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(50),
                        border: Border.all(
                          color: isDark ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.1),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.code_rounded, size: 20, color: headingColor),
                          const SizedBox(width: 12),
                          Text(
                            'Open Source on GitHub',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: headingColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingCard(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Widget trailing,
    VoidCallback? onTap,
    required Color cardColor,
    required Color headingColor,
    required Color subtleText,
  }) {
    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: headingColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: subtleText,
                      ),
                    ),
                  ],
                ),
              ),
              trailing,
            ],
          ),
        ),
      ),
    );
  }

  String _getLanguageName(String code) {
    switch (code) {
      case 'en': return 'English';
      case 'hi': return 'हिंदी (Hindi)';
      case 'es': return 'Español (Spanish)';
      case 'fr': return 'Français (French)';
      case 'de': return 'Deutsch (German)';
      case 'zh': return '中文 (Chinese)';
      case 'ja': return '日本語 (Japanese)';
      case 'ru': return 'Русский (Russian)';
      case 'pt': return 'Português (Portuguese)';
      case 'ar': return 'العربية (Arabic)';
      default: return 'English';
    }
  }

  void _showLanguageDialog(BuildContext context, AppLocalizations? loc) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final currentCode = Localizations.localeOf(context).languageCode;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final primary = Theme.of(context).colorScheme.primary;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[700] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  loc?.translate('select_language') ?? 'Select Language',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _buildLanguageChip(context, 'English', 'en', currentCode, primary),
                    _buildLanguageChip(context, 'हिंदी', 'hi', currentCode, primary),
                    _buildLanguageChip(context, 'Español', 'es', currentCode, primary),
                    _buildLanguageChip(context, 'Français', 'fr', currentCode, primary),
                    _buildLanguageChip(context, 'Deutsch', 'de', currentCode, primary),
                    _buildLanguageChip(context, '中文', 'zh', currentCode, primary),
                    _buildLanguageChip(context, '日本語', 'ja', currentCode, primary),
                    _buildLanguageChip(context, 'Русский', 'ru', currentCode, primary),
                    _buildLanguageChip(context, 'Português', 'pt', currentCode, primary),
                    _buildLanguageChip(context, 'العربية', 'ar', currentCode, primary),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLanguageChip(
    BuildContext context,
    String name,
    String code,
    String currentCode,
    Color primary,
  ) {
    final isSelected = currentCode == code;
    return ChoiceChip(
      label: Text(name),
      selected: isSelected,
      onSelected: (_) {
        MyApp.setLocale(context, Locale(code));
        Navigator.pop(context);
      },
      selectedColor: primary.withOpacity(0.2),
      labelStyle: TextStyle(
        color: isSelected ? primary : null,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(
        color: isSelected ? primary : Colors.grey.withOpacity(0.3),
      ),
    );
  }

  void _showThemeColorDialog(BuildContext context, AppLocalizations? loc) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final currentColor = MyApp.getThemeColor(context);

        final themeColors = [
          {'name': 'Purple', 'color': Colors.deepPurple},
          {'name': 'Blue', 'color': Colors.blue},
          {'name': 'Teal', 'color': Colors.teal},
          {'name': 'Green', 'color': Colors.green},
          {'name': 'Orange', 'color': Colors.orange},
        ];

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[700] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  loc?.translate('app_theme') ?? 'App Theme',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: themeColors.map((theme) {
                    final color = theme['color'] as Color;
                    final isSelected = currentColor.value == color.value;
                    return GestureDetector(
                      onTap: () {
                        MyApp.setThemeColor(context, color);
                        Navigator.pop(context);
                      },
                      child: Column(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: isSelected ? 56 : 48,
                            height: isSelected ? 56 : 48,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [color, color.withOpacity(0.7)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                              border: isSelected
                                  ? Border.all(color: isDark ? Colors.white : Colors.black, width: 3)
                                  : null,
                              boxShadow: [
                                BoxShadow(
                                  color: color.withOpacity(0.4),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: isSelected
                                ? const Icon(Icons.check_rounded, color: Colors.white, size: 28)
                                : null,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            theme['name'] as String,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getFontDisplayName(String fontId) {
    final fonts = MyApp.availableFonts;
    final font = fonts.firstWhere(
      (f) => f['id'] == fontId,
      orElse: () => {'id': 'System', 'name': 'System Default'},
    );
    return font['name']!;
  }

  void _showFontDialog(BuildContext context, AppLocalizations? loc) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allow the sheet to be taller
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final primary = Theme.of(context).colorScheme.primary;
        final currentFont = MyApp.getFontFamily(context);
        final fonts = MyApp.availableFonts;

        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[700] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    loc?.translate('font_style') ?? 'Font Style',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    loc?.translate('font_style_desc') ?? 'Choose your preferred font',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: fonts.length,
                      itemBuilder: (context, index) {
                        final font = fonts[index];
                        final isSelected = currentFont == font['id'];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Material(
                            color: isSelected
                                ? primary.withOpacity(0.15)
                                : (isDark ? Colors.grey[850] : Colors.grey[100]),
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              onTap: () {
                                MyApp.setFontFamily(context, font['id']!);
                                Navigator.pop(context);
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? primary.withOpacity(0.2)
                                            : (isDark ? Colors.grey[800] : Colors.grey[200]),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Center(
                                        child: Text(
                                          'Aa',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: isSelected ? primary : (isDark ? Colors.white : Colors.black),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            font['name']!,
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                              color: isSelected ? primary : (isDark ? Colors.white : Colors.black),
                                            ),
                                          ),
                                          Text(
                                            'The quick brown fox jumps',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isDark ? Colors.grey[500] : Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isSelected)
                                      Icon(Icons.check_circle_rounded, color: primary, size: 24),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
