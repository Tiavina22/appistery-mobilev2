import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../services/auth_service.dart';
import 'register_step6_cgu_screen.dart';

class RegisterStep5CountryPhoneScreen extends StatefulWidget {
  final String email;
  final String username;
  final String password;
  final String? avatar;

  const RegisterStep5CountryPhoneScreen({
    super.key,
    required this.email,
    required this.username,
    required this.password,
    this.avatar,
  });

  @override
  State<RegisterStep5CountryPhoneScreen> createState() =>
      _RegisterStep5CountryPhoneScreenState();
}

class _RegisterStep5CountryPhoneScreenState
    extends State<RegisterStep5CountryPhoneScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  List<Map<String, dynamic>> _countries = [];
  Map<String, dynamic>? _selectedCountry;

  @override
  void initState() {
    super.initState();
    _loadCountries();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadCountries() async {
    final authService = AuthService();
    final result = await authService.getCountries();

    if (result['success'] == true && mounted) {
      setState(() {
        _countries = List<Map<String, dynamic>>.from(result['data']);
        // Définir Madagascar par défaut
        _selectedCountry = _countries.firstWhere(
          (c) => c['code'] == 'MG',
          orElse: () => _countries.isNotEmpty ? _countries.first : {},
        );
      });
    }
  }

  void _handleContinue() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RegisterStep6CGUScreen(
          email: widget.email,
          username: widget.username,
          password: widget.password,
          telephone: _phoneController.text,
          avatar: widget.avatar,
          countryId: _selectedCountry?['id'],
        ),
      ),
    );
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
          child: Form(
            key: _formKey,
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
                    Expanded(
                      child: Container(
                        height: 3,
                        color: Colors.grey.withOpacity(0.3),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        height: 3,
                        color: Colors.grey.withOpacity(0.3),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'Votre localisation',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sélectionnez votre pays et numéro de téléphone',
                  style: TextStyle(
                    fontSize: 14,
                    color: textColor.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 32),
                // Sélecteur de pays
                DropdownButtonFormField<Map<String, dynamic>>(
                  value: _selectedCountry,
                  decoration: InputDecoration(
                    labelText: 'country'.tr(),
                    labelStyle: TextStyle(color: textColor.withOpacity(0.6)),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: textColor.withOpacity(0.2)),
                    ),
                    focusedBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: Color(0xFF1DB954),
                        width: 2,
                      ),
                    ),
                  ),
                  dropdownColor: isDark
                      ? const Color(0xFF181818)
                      : Colors.white,
                  style: TextStyle(color: textColor),
                  items: _countries.map((country) {
                    return DropdownMenuItem<Map<String, dynamic>>(
                      value: country,
                      child: Text(
                        '${country['flag']} ${country['name']}',
                        style: TextStyle(color: textColor),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedCountry = value;
                    });
                  },
                  validator: (value) {
                    if (value == null) {
                      return 'country_required'.tr();
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Container(
                      width: 80,
                      padding: const EdgeInsets.only(
                        top: 12,
                        bottom: 12,
                        right: 8,
                      ),
                      child: Text(
                        _selectedCountry?['phone_code'] ?? '+261',
                        style: TextStyle(color: textColor, fontSize: 16),
                      ),
                    ),
                    Expanded(
                      child: TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          labelText: 'phone'.tr(),
                          labelStyle: TextStyle(
                            color: textColor.withOpacity(0.6),
                          ),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: textColor.withOpacity(0.2),
                            ),
                          ),
                          focusedBorder: const UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: Color(0xFF1DB954),
                              width: 2,
                            ),
                          ),
                          errorBorder: const UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.red),
                          ),
                          focusedErrorBorder: const UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.red, width: 2),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'phone_required'.tr();
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _handleContinue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'next'.tr(),
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
      ),
    );
  }
}
