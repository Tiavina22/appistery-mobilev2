import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import 'onboarding_screen.dart';

class ThemeSelectionScreen extends StatefulWidget {
  const ThemeSelectionScreen({super.key});

  @override
  State<ThemeSelectionScreen> createState() => _ThemeSelectionScreenState();
}

class _ThemeSelectionScreenState extends State<ThemeSelectionScreen>
    with SingleTickerProviderStateMixin {
  bool _selectedTheme = true;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _confirmTheme(BuildContext context) async {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    await themeProvider.setTheme(
      _selectedTheme ? ThemeMode.dark : ThemeMode.light,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('theme_selected', true);

    if (context.mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const OnboardingScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final w = size.width;
    final h = size.height;

    final s = (w / 375).clamp(0.75, 1.3);
    final verticalS = (h / 812).clamp(0.7, 1.3);
    final hPad = (w * 0.064).clamp(16.0, 32.0);
    final isSmallPhone = w < 360;

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
            child: Column(
              children: [
                /// Logo
                Padding(
                  padding: EdgeInsets.all(hPad),
                  child: Center(
                    child: Hero(
                      tag: 'app_logo',
                      child: Image.asset(
                        'assets/logo/logo-appistery-no.png',
                        width: 50 * s,
                        height: 50 * s,
                      ),
                    ),
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(horizontal: hPad),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 16 * verticalS),

                        /// Animation titre
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: 1),
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
                              Text(
                                'Choose your',
                                style: TextStyle(
                                  fontSize: (28 * s).clamp(22.0, 40.0),
                                  fontWeight: FontWeight.w300,
                                  color: Colors.white70,
                                ),
                              ),
                              Text(
                                'Theme',
                                style: TextStyle(
                                  fontSize: (36 * s).clamp(28.0, 50.0),
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),

                              SizedBox(height: 10 * verticalS),

                              /// Trait bleu comme ton ancien code
                              Container(
                                width: 50 * s,
                                height: 5,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color.fromARGB(255, 10, 213, 196),
                                      Colors.transparent
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),

                              SizedBox(height: 12 * verticalS),

                              Text(
                                'Select your preferred appearance',
                                style: TextStyle(
                                  fontSize: (14 * s).clamp(12.0, 18.0),
                                  color: Colors.grey[400],
                                ),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: 28 * verticalS),

                        /// Dark Mode Animation
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: 1),
                          duration: const Duration(milliseconds: 500),
                          builder: (context, value, child) {
                            return Opacity(
                              opacity: value,
                              child: Transform.translate(
                                offset: Offset(30 * (1 - value), 0),
                                child: child,
                              ),
                            );
                          },
                          child: _buildThemeOption(
                            isDark: true,
                            title: 'Dark Mode',
                            description: 'Easy on the eyes',
                            icon: Icons.dark_mode_rounded,
                            s: s,
                            isSmallPhone: isSmallPhone,
                          ),
                        ),

                        SizedBox(height: 16 * verticalS),

                        /// Light Mode Animation
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: 1),
                          duration: const Duration(milliseconds: 600),
                          builder: (context, value, child) {
                            return Opacity(
                              opacity: value,
                              child: Transform.translate(
                                offset: Offset(30 * (1 - value), 0),
                                child: child,
                              ),
                            );
                          },
                          child: _buildThemeOption(
                            isDark: false,
                            title: 'Light Mode',
                            description: 'Clear and bright',
                            icon: Icons.light_mode_rounded,
                            s: s,
                            isSmallPhone: isSmallPhone,
                          ),
                        ),

                        SizedBox(height: 24 * verticalS),
                      ],
                    ),
                  ),
                ),

                /// Bouton Continue
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: hPad,
                    vertical: 16 * verticalS,
                  ),
                  child: ElevatedButton(
                    onPressed: () => _confirmTheme(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFC3C44),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        vertical: (12 * s).clamp(10.0, 16.0),
                        horizontal: (28 * s).clamp(20.0, 40.0),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Continue',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 6),
                        Icon(Icons.arrow_forward_rounded),
                      ],
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

  Widget _buildThemeOption({
    required bool isDark,
    required String title,
    required String description,
    required IconData icon,
    required double s,
    required bool isSmallPhone,
  }) {
    final isSelected = _selectedTheme == isDark;
    final previewSize = isSmallPhone ? 60.0 : 75.0;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedTheme = isDark;
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: EdgeInsets.all(16 * s),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                isSelected ? const Color(0xFFFC3C44) : Colors.grey.shade800,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: previewSize,
              height: previewSize,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF1A1A1A), const Color(0xFF0D0D0D)]
                      : [Colors.white, const Color(0xFFF5F5F5)],
                ),
              ),
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 6,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color:
                                isDark ? Colors.white24 : Colors.black26,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          height: 5,
                          width: 30,
                          decoration: BoxDecoration(
                            color:
                                isDark ? Colors.white24 : Colors.black26,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const Spacer(),
                        Row(
                          children: List.generate(
                            3,
                            (index) => Container(
                              margin: const EdgeInsets.only(right: 4),
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: index == 0
                                    ? const Color(0xFFFC3C44)
                                    : (isDark
                                        ? Colors.white24
                                        : Colors.black26),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Center(
                    child: Icon(
                      icon,
                      size: 26,
                      color: isDark
                          ? Colors.white.withOpacity(0.4)
                          : Colors.black.withOpacity(0.4),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(width: 14 * s),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: (17 * s).clamp(14.0, 22.0),
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    description,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: (13 * s).clamp(11.0, 16.0),
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ),

            AnimatedScale(
              scale: isSelected ? 1 : 0,
              duration: const Duration(milliseconds: 300),
              child: const Icon(
                Icons.check_circle,
                color: Color(0xFFFC3C44),
              ),
            ),
          ],
        ),
      ),
    );
  }
}