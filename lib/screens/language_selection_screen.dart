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
  String _selectedLanguage = 'en';

  Future<void> _selectLanguage(
    BuildContext context,
    String languageCode,
  ) async {
    final locale = Locale(languageCode);
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
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo
                Image.asset(
                  'assets/logo/logo-appistery-no.png',
                  width: 80,
                  height: 80,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Appistery',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Select Your Language\nChoisissez votre langue\nSafidio ny fiteny',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 40),
                // Dropdown pour sélection de langue
                Container(
                  width: 280,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF181818),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedLanguage,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF181818),
                      icon: const Icon(
                        Icons.keyboard_arrow_down,
                        color: Color(0xFF1DB954),
                        size: 24,
                      ),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'en',
                          child: Row(
                            children: [
                              Text('🇬🇧', style: TextStyle(fontSize: 28)),
                              SizedBox(width: 12),
                              Text('English'),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'fr',
                          child: Row(
                            children: [
                              Text('🇫🇷', style: TextStyle(fontSize: 28)),
                              SizedBox(width: 12),
                              Text('Français'),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'mg',
                          child: Row(
                            children: [
                              Text('🇲🇬', style: TextStyle(fontSize: 28)),
                              SizedBox(width: 12),
                              Text('Malagasy'),
                            ],
                          ),
                        ),
                      ],
                      onChanged: (String? value) {
                        if (value != null) {
                          setState(() {
                            _selectedLanguage = value;
                          });
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                // Bouton de confirmation
                ElevatedButton(
                  onPressed: () => _selectLanguage(context, _selectedLanguage),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1DB954),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 32,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
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
