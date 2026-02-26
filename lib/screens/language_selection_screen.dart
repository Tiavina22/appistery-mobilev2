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

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> with SingleTickerProviderStateMixin {
  String? _selectedLanguage;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final List<Map<String, String>> _languages = [
    {
      'code': 'en',
      'name': 'English',
      'flag': '🇬🇧',
      'nativeName': 'English',
      'description': 'United Kingdom'
    },
    {
      'code': 'fr',
      'name': 'Français',
      'flag': '🇫🇷',
      'nativeName': 'Français',
      'description': 'France'
    },
    {
      'code': 'mg',
      'name': 'Malagasy',
      'flag': '🇲🇬',
      'nativeName': 'Malagasy',
      'description': 'Madagascar'
    },
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

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
    final size = MediaQuery.of(context).size;
    final w = size.width;
    final h = size.height;
    // Scale factor based on reference width 375 (iPhone X)
    final s = (w / 375).clamp(0.75, 1.3);
    final verticalS = (h / 812).clamp(0.7, 1.3);
    final hPad = (w * 0.064).clamp(16.0, 32.0); // ~24 on 375

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.black,
              const Color(0xFF0D0D0D),
              const Color(0xFF1A1A1A).withOpacity(0.5),
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Column(
                children: [
                  // Header avec logo
                  Padding(
                    padding: EdgeInsets.all(hPad),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Hero(
                          tag: 'app_logo',
                          child: Image.asset(
                            'assets/logo/logo-appistery-no.png',
                            width: 50 * s,
                            height: 50 * s,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Contenu principal
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(horizontal: hPad),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 16 * verticalS),
                          
                          // Titre avec animation
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0.0, end: 1.0),
                            duration: const Duration(milliseconds: 600),
                            builder: (context, value, child) {
                              return Opacity(
                                opacity: value,
                                child: Transform.translate(
                                  offset: Offset(0, 20 * (1 - value)),
                                  child: child,
                                ),
                              );
                            },
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                RichText(
                                  text: TextSpan(
                                    children: [
                                      TextSpan(
                                        text: 'Welcome to\n',
                                        style: TextStyle(
                                          fontSize: (28 * s).clamp(22.0, 40.0),
                                          fontWeight: FontWeight.w300,
                                          color: Colors.white70,
                                          height: 1.2,
                                        ),
                                      ),
                                      TextSpan(
                                        text: 'Appistery',
                                        style: TextStyle(
                                          fontSize: (36 * s).clamp(28.0, 50.0),
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          height: 1.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: 10 * verticalS),
                                Container(
                                  width: 50 * s,
                                  height: 3.5,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFFFC3C44), Colors.transparent],
                                    ),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                SizedBox(height: 12 * verticalS),
                                Text(
                                  'Choose your preferred language',
                                  style: TextStyle(
                                    fontSize: (14 * s).clamp(12.0, 18.0),
                                    color: Colors.grey[400],
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          SizedBox(height: 28 * verticalS),
                          
                          // Options de langue avec animations échelonnées
                          ..._languages.asMap().entries.map((entry) {
                            final index = entry.key;
                            final lang = entry.value;
                            return TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0.0, end: 1.0),
                              duration: Duration(milliseconds: 400 + (index * 100)),
                              builder: (context, value, child) {
                                return Opacity(
                                  opacity: value,
                                  child: Transform.translate(
                                    offset: Offset(30 * (1 - value), 0),
                                    child: child,
                                  ),
                                );
                              },
                              child: _buildLanguageOption(lang, s, verticalS),
                            );
                          }),
                          
                          SizedBox(height: 24 * verticalS),
                        ],
                      ),
                    ),
                  ),
                  
                  // Bouton continuer
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 16 * verticalS),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black,
                          Colors.black.withOpacity(0.8),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        child: ElevatedButton(
                          onPressed: _selectedLanguage != null 
                              ? () => _selectLanguage(context)
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _selectedLanguage != null 
                                ? const Color(0xFFFC3C44)
                                : Colors.grey[800],
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.grey[900],
                            disabledForegroundColor: Colors.grey[600],
                            padding: EdgeInsets.symmetric(
                              vertical: (12 * s).clamp(10.0, 16.0),
                              horizontal: (28 * s).clamp(20.0, 40.0),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: _selectedLanguage != null ? 6 : 0,
                            shadowColor: _selectedLanguage != null 
                                ? const Color(0xFFFC3C44).withOpacity(0.4)
                                : null,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Continue',
                                style: TextStyle(
                                  fontSize: (14 * s).clamp(12.0, 18.0),
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              SizedBox(width: 6 * s),
                              Icon(
                                Icons.arrow_forward_rounded,
                                size: (16 * s).clamp(14.0, 22.0),
                                color: _selectedLanguage != null 
                                    ? Colors.white 
                                    : Colors.grey[600],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageOption(Map<String, String> lang, double s, double verticalS) {
    final isSelected = _selectedLanguage == lang['code'];
    final flagSize = (52 * s).clamp(40.0, 72.0);
    final checkSize = (30 * s).clamp(24.0, 40.0);
    
    return Padding(
      padding: EdgeInsets.only(bottom: 12 * verticalS),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedLanguage = lang['code'];
            });
          },
          borderRadius: BorderRadius.circular(18 * s),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            padding: EdgeInsets.all((16 * s).clamp(12.0, 24.0)),
            decoration: BoxDecoration(
              gradient: isSelected 
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFFFC3C44).withOpacity(0.2),
                        const Color(0xFFFC3C44).withOpacity(0.05),
                      ],
                    )
                  : null,
              color: isSelected ? null : const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(18 * s),
              border: Border.all(
                color: isSelected 
                    ? const Color(0xFFFC3C44)
                    : Colors.grey[800]!,
                width: isSelected ? 2.5 : 1.5,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: const Color(0xFFFC3C44).withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: -5,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                // Flag avec effet
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: flagSize,
                  height: flagSize,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isSelected
                          ? [
                              const Color(0xFFFC3C44).withOpacity(0.15),
                              const Color(0xFFFC3C44).withOpacity(0.05),
                            ]
                          : [
                              Colors.grey[850]!,
                              Colors.grey[900]!,
                            ],
                    ),
                    borderRadius: BorderRadius.circular(14 * s),
                    border: Border.all(
                      color: isSelected 
                          ? const Color(0xFFFC3C44).withOpacity(0.5)
                          : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      lang['flag']!,
                      style: TextStyle(fontSize: (28 * s).clamp(22.0, 40.0)),
                    ),
                  ),
                ),
                SizedBox(width: 16 * s),
                // Infos langue
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lang['nativeName']!,
                        style: TextStyle(
                          fontSize: (17 * s).clamp(14.0, 24.0),
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                      ),
                      SizedBox(height: 3 * s),
                      Row(
                        children: [
                          Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: isSelected 
                                  ? const Color(0xFFFC3C44)
                                  : Colors.grey[600],
                              shape: BoxShape.circle,
                            ),
                          ),
                          SizedBox(width: 6 * s),
                          Flexible(
                            child: Text(
                              lang['description']!,
                              style: TextStyle(
                                fontSize: (13 * s).clamp(11.0, 16.0),
                                color: isSelected 
                                    ? Colors.grey[300]
                                    : Colors.grey[500],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Indicateur de sélection
                AnimatedScale(
                  scale: isSelected ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutBack,
                  child: Container(
                    width: checkSize,
                    height: checkSize,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFFFC3C44),
                          Color(0xFFE63946),
                        ],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFC3C44).withOpacity(0.5),
                          blurRadius: 12,
                          spreadRadius: -2,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: (18 * s).clamp(14.0, 24.0),
                    ),
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
