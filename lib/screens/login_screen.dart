import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/theme_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/story_provider.dart';
import '../providers/notification_provider.dart';
import 'home_screen.dart';
import 'register_step1_email_screen.dart';
import 'forgot_password_email_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  String? _emailError;
  String? _passwordError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    // Clear previous errors
    setState(() {
      _emailError = null;
      _passwordError = null;
    });

    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final success = await authProvider.login(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (success && mounted) {
        // Marquer l'onboarding comme complété pour ne plus revenir au login au redémarrage
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('onboarding_completed', true);

        // Pré-charger les stories et notifications comme dans le splash screen
        final storyProvider = Provider.of<StoryProvider>(context, listen: false);
        final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
        
        await Future.wait([
          storyProvider.loadStories(),
          storyProvider.loadGenres(),
          storyProvider.loadAuthors(),
          notificationProvider.loadNotifications(),
        ]);

        setState(() {
          _isLoading = false;
        });

        // Rediriger vers HomeScreen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      } else if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        // Parser l'erreur selon le champ
        final errorCode = authProvider.errorCode;
        final errorField = authProvider.errorField;
        
        String errorMessage = authProvider.errorMessage ?? 'login_error'.tr();
        
        // Mapper les error_code aux clés de traduction
        if (errorCode == 'INVALID_EMAIL_FORMAT') {
          errorMessage = 'invalid_email_format'.tr();
        } else if (errorCode == 'EMAIL_NOT_FOUND') {
          errorMessage = 'email_not_found'.tr();
        } else if (errorCode == 'INCORRECT_PASSWORD') {
          errorMessage = 'incorrect_password'.tr();
        }

        // Assigner l'erreur au bon champ
        setState(() {
          if (errorField == 'email') {
            _emailError = errorMessage;
          } else if (errorField == 'password') {
            _passwordError = errorMessage;
          } else {
            // Erreur générale - afficher sur l'email par défaut
            _emailError = errorMessage;
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final bgColor = isDark ? const Color(0xFF000000) : Colors.white;
    final cardColor = isDark
        ? const Color(0xFF181818)
        : const Color(0xFFF5F5F5);
    final textColor = isDark ? Colors.white : Colors.black;
    final accentColor = const Color(0xFF1DB954);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Image.asset('assets/logo/logo-appistery-no.png', height: 60),
                const SizedBox(height: 32),

                // Titre
                Text(
                  'welcome_back'.tr(),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'login_subtitle'.tr(),
                  style: TextStyle(
                    fontSize: 14,
                    color: textColor.withOpacity(0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Formulaire
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Email
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: TextStyle(color: textColor),
                        onChanged: (value) {
                          // Clear error when user types
                          if (_emailError != null) {
                            setState(() {
                              _emailError = null;
                            });
                          }
                        },
                        decoration: InputDecoration(
                          labelText: 'email'.tr(),
                          labelStyle: TextStyle(
                            color: textColor.withOpacity(0.7),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: cardColor,
                          prefixIcon: Icon(
                            Icons.email_outlined,
                            color: textColor.withOpacity(0.7),
                          ),
                          errorStyle: const TextStyle(height: 0, fontSize: 0),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'email_required'.tr();
                          }
                          if (!value.contains('@')) {
                            return 'email_invalid'.tr();
                          }
                          return null;
                        },
                      ),
                      // Error message for email (Netflix style)
                      if (_emailError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0, left: 12.0),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: Colors.red,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  _emailError!,
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 12),

                      // Mot de passe
                      TextFormField(
                        controller: _passwordController,
                        obscureText: !_isPasswordVisible,
                        style: TextStyle(color: textColor),
                        onChanged: (value) {
                          // Clear error when user types
                          if (_passwordError != null) {
                            setState(() {
                              _passwordError = null;
                            });
                          }
                        },
                        decoration: InputDecoration(
                          labelText: 'password'.tr(),
                          labelStyle: TextStyle(
                            color: textColor.withOpacity(0.7),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: cardColor,
                          prefixIcon: Icon(
                            Icons.lock_outline,
                            color: textColor.withOpacity(0.7),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isPasswordVisible
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: textColor.withOpacity(0.7),
                            ),
                            onPressed: () {
                              setState(() {
                                _isPasswordVisible = !_isPasswordVisible;
                              });
                            },
                          ),
                          errorStyle: const TextStyle(height: 0, fontSize: 0),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'password_required'.tr();
                          }
                          if (value.length < 6) {
                            return 'password_too_short'.tr();
                          }
                          return null;
                        },
                      ),
                      // Error message for password (Netflix style)
                      if (_passwordError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0, left: 12.0),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: Colors.red,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  _passwordError!,
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 8),

                      // Mot de passe oublié
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const ForgotPasswordEmailScreen(),
                              ),
                            );
                          },
                          child: Text(
                            'forgot_password'.tr(),
                            style: TextStyle(
                              color: accentColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Bouton de connexion
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  'sign_in'.tr(),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Divider
                Row(
                  children: [
                    Expanded(child: Divider(color: textColor.withOpacity(0.2))),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'or'.tr(),
                        style: TextStyle(color: textColor.withOpacity(0.5)),
                      ),
                    ),
                    Expanded(child: Divider(color: textColor.withOpacity(0.2))),
                  ],
                ),
                const SizedBox(height: 16),

                // Bouton S'inscrire
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const RegisterStep1EmailScreen(),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: textColor,
                      side: BorderSide(
                        color: textColor.withOpacity(0.3),
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: Text(
                      'create_account'.tr(),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
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
