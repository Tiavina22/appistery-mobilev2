import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme_selection_screen.dart';

class LanguageSelectionScreen extends StatefulWidget {
  const LanguageSelectionScreen({super.key});

  @override
  State<LanguageSelectionScreen> createState() =>
      _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  String? _selectedLanguage;

  final List<Map<String, String>> _languages = [
    {'code': 'en', 'name': 'English', 'flag': '🇬🇧'},
    {'code': 'fr', 'name': 'Français', 'flag': '🇫🇷'},
    {'code': 'mg', 'name': 'Malagasy', 'flag': '🇲🇬'},
  ];

  Future<void> _selectLanguage(BuildContext context) async {
    if (_selectedLanguage == null) return;
    
    final locale = Locale(_selectedLanguage!);
    await context.setLocale(locale);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('language_selected', true);

    if (context.mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const ThemeSelectionScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                children: [
                  // Logo
                  Image.asset(
                    'assets/logo/logo-appistery-no.png',
                    width: 40,
                    height: 40,
                  ),
                  const SizedBox(width: 12),
                  
                ],
              ),
            ),
            
            // Main content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Spacer(flex: 1),
                    
                    // Title
                    const Text(
                      'Choose your',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w300,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                    const Text(
                      'language',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Select your preferred language to continue',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[500],
                      ),
                    ),
                    
                    const SizedBox(height: 40),
                    
                    // Language options
                    ..._languages.map((lang) => _buildLanguageOption(lang)),
                    
                    const Spacer(flex: 2),
                  ],
                ),
              ),
            ),
            
            // Bottom button
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              child: ElevatedButton(
                onPressed: _selectedLanguage != null 
                    ? () => _selectLanguage(context)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selectedLanguage != null 
                      ? const Color(0xFF1DB954)
                      : Colors.grey[800],
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey[900],
                  disabledForegroundColor: Colors.grey[600],
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Continue',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageOption(Map<String, String> lang) {
    final isSelected = _selectedLanguage == lang['code'];
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedLanguage = lang['code'];
            });
          },
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected 
                  ? const Color(0xFF1DB954).withOpacity(0.15)
                  : Colors.grey[900],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected 
                    ? const Color(0xFF1DB954)
                    : Colors.transparent,
                width: 2,
              ),
            ),
            child: Row(
              children: [
                // Flag
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      lang['flag']!,
                      style: const TextStyle(fontSize: 28),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Language name
                Expanded(
                  child: Text(
                    lang['name']!,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ),
                // Checkmark
                if (isSelected)
                  Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      color: Color(0xFF1DB954),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
