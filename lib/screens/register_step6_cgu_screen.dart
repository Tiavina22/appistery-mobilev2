import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

class RegisterStep6CGUScreen extends StatefulWidget {
  final String email;
  final String username;
  final String password;
  final String telephone;
  final String? avatar;
  final int? countryId;

  const RegisterStep6CGUScreen({
    super.key,
    required this.email,
    required this.username,
    required this.password,
    required this.telephone,
    this.avatar,
    this.countryId,
  });

  @override
  State<RegisterStep6CGUScreen> createState() => _RegisterStep6CGUScreenState();
}

class _RegisterStep6CGUScreenState extends State<RegisterStep6CGUScreen> {
  Map<String, dynamic>? _cgu;
  bool _cguAccepted = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Utiliser Future.delayed pour laisser le contexte se charger
    Future.delayed(Duration.zero, () {
      _loadCGU();
    });
  }

  Future<void> _loadCGU() async {
    final authService = AuthService();
    // Obtenir la langue de manière plus robuste
    final localization = EasyLocalization.of(context);
    final language = localization?.locale.languageCode.toUpperCase() == 'FR'
        ? 'FR'
        : 'EN';

    final result = await authService.getCGU(language);

    if (result['success'] == true && mounted) {
      setState(() {
        _cgu = result['data'];
      });
    } else if (mounted) {
      // Fallback: si erreur, essayer avec FR
      final fallbackResult = await authService.getCGU('FR');
      if (fallbackResult['success'] == true && mounted) {
        setState(() {
          _cgu = fallbackResult['data'];
        });
      }
    }
  }

  void _showCGU() {
    if (_cgu == null) {
      setState(() {
        _errorMessage = 'loading_cgu'.tr();
      });
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: Text(
            _cgu!['title'] ?? 'CGU',
            style: const TextStyle(color: Color(0xFF1DB954)),
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: MediaQuery.of(context).size.height * 0.6,
            child: SingleChildScrollView(
              child: Text(
                _cgu!['content'] ?? '',
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                tr('close'),
                style: const TextStyle(color: Color(0xFF1DB954)),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleCompleteRegistration() async {
    if (!_cguAccepted) {
      setState(() {
        _errorMessage = 'cgu_acceptance_required'.tr();
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authService = AuthService();
    final result = await authService.completeRegistration(
      email: widget.email,
      username: widget.username,
      password: widget.password,
      telephone: widget.telephone,
      avatar: widget.avatar,
      countryId: widget.countryId,
      cguAccepted: _cguAccepted,
    );

    setState(() {
      _isLoading = false;
    });

    if (result['success'] == true && mounted) {
      // Afficher dialogue de succès
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          final themeProvider = Provider.of<ThemeProvider>(context);
          final isDark = themeProvider.isDarkMode;
          final bgColor = isDark ? const Color(0xFF181818) : Colors.white;
          final textColor = isDark ? Colors.white : Colors.black;

          return Dialog(
            backgroundColor: bgColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1DB954).withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle,
                      color: Color(0xFF1DB954),
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'success'.tr(),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'registration_success'.tr(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: textColor.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LoginScreen(),
                          ),
                          (route) => false,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1DB954),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'login'.tr(),
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
          );
        },
      );
    } else if (mounted) {
      setState(() {
        _errorMessage = result['message'] ?? 'registration_error'.tr();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final bgColor = isDark ? const Color(0xFF000000) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final accentColor = const Color(0xFF1DB954);

    return Scaffold(
      backgroundColor: bgColor,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Container(height: 3, color: accentColor)),
                  const SizedBox(width: 8),
                  Expanded(child: Container(height: 3, color: accentColor)),
                  const SizedBox(width: 8),
                  Expanded(child: Container(height: 3, color: accentColor)),
                  const SizedBox(width: 8),
                  Expanded(child: Container(height: 3, color: accentColor)),
                  const SizedBox(width: 8),
                  Expanded(child: Container(height: 3, color: accentColor)),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'Conditions d\'utilisation',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Veuillez lire et accepter nos conditions',
                style: TextStyle(
                  fontSize: 14,
                  color: textColor.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 24),
              // Affichage du contenu CGU
              if (_cgu != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: textColor.withOpacity(0.2)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _cgu!['title'] ?? 'CGU',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: accentColor,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 250,
                        child: SingleChildScrollView(
                          child: Text(
                            _cgu!['content'] ?? '',
                            style: TextStyle(
                              fontSize: 12,
                              color: textColor.withOpacity(0.8),
                              height: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Center(
                  child: Column(
                    children: [
                      const CircularProgressIndicator(color: Color(0xFF1DB954)),
                      const SizedBox(height: 16),
                      Text(
                        'loading_conditions'.tr(),
                        style: TextStyle(color: textColor.withOpacity(0.7)),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
              // Checkbox d'acceptation
              CheckboxListTile(
                value: _cguAccepted,
                onChanged: (value) {
                  setState(() {
                    _cguAccepted = value ?? false;
                  });
                },
                title: Text(
                  'cgu_acceptance'.tr(),
                  style: TextStyle(color: textColor),
                ),
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: accentColor,
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _showCGU,
                child: Text(
                  'view_cgu'.tr(),
                  style: const TextStyle(
                    color: Color(0xFF1DB954),
                    decoration: TextDecoration.underline,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Error message (Netflix style)
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (_errorMessage != null) const SizedBox(height: 24),
              if (_errorMessage == null) const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleCompleteRegistration,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.black,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'create_account'.tr(),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
