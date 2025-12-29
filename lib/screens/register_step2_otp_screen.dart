import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import 'register_step3_avatar_screen.dart';
import '../services/auth_service.dart';
import 'dart:async';

class RegisterStep2OTPScreen extends StatefulWidget {
  final String email;
  final String username;

  const RegisterStep2OTPScreen({
    super.key,
    required this.email,
    required this.username,
  });

  @override
  State<RegisterStep2OTPScreen> createState() => _RegisterStep2OTPScreenState();
}

class _RegisterStep2OTPScreenState extends State<RegisterStep2OTPScreen> {
  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _isLoading = false;
  bool _isResending = false;
  int _remainingSeconds = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _startTimer() {
    _remainingSeconds = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _handleResendOTP() async {
    setState(() {
      _isResending = true;
    });

    final authService = AuthService();
    final result = await authService.sendOTP(
      email: widget.email,
      username: widget.username,
    );

    setState(() {
      _isResending = false;
    });

    if (result['success'] == true && mounted) {
      _startTimer();
      for (var controller in _otpControllers) {
        controller.clear();
      }
      _focusNodes[0].requestFocus();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('otp_resent'.tr()),
          backgroundColor: const Color(0xFF1DB954),
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'otp_resend_error'.tr()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleVerifyOTP() async {
    final code = _otpControllers.map((c) => c.text).join();

    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('otp_incomplete'.tr()),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final authService = AuthService();
    final result = await authService.verifyOTP(email: widget.email, code: code);

    setState(() {
      _isLoading = false;
    });

    if (result['success'] == true && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => RegisterStep3AvatarScreen(
            email: widget.email,
            username: widget.username,
          ),
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'otp_invalid'.tr()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final bgColor = isDark ? const Color(0xFF000000) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final accentColor = const Color(0xFF1DB954);
    final cardColor = isDark
        ? const Color(0xFF181818)
        : const Color(0xFFF5F5F5);

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
                  Expanded(
                    child: Container(
                      height: 3,
                      color: textColor.withOpacity(0.2),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'register_step2_title'.tr(),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'register_step2_subtitle'.tr(args: [widget.email]),
                style: TextStyle(
                  fontSize: 14,
                  color: textColor.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(
                  6,
                  (index) => SizedBox(
                    width: 48,
                    height: 56,
                    child: TextFormField(
                      controller: _otpControllers[index],
                      focusNode: _focusNodes[index],
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      maxLength: 1,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        filled: true,
                        fillColor: cardColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: accentColor, width: 2),
                        ),
                      ),
                      onChanged: (value) {
                        if (value.isNotEmpty && index < 5) {
                          _focusNodes[index + 1].requestFocus();
                        } else if (value.isEmpty && index > 0) {
                          _focusNodes[index - 1].requestFocus();
                        }
                        if (index == 5 && value.isNotEmpty) {
                          _handleVerifyOTP();
                        }
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Center(
                child: _remainingSeconds > 0
                    ? Text(
                        'otp_resend_in'.tr(
                          args: [_remainingSeconds.toString()],
                        ),
                        style: TextStyle(
                          color: textColor.withOpacity(0.6),
                          fontSize: 14,
                        ),
                      )
                    : TextButton(
                        onPressed: _isResending ? null : _handleResendOTP,
                        child: Text(
                          'otp_resend'.tr(),
                          style: TextStyle(
                            color: accentColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
              ),
              SizedBox(height: MediaQuery.of(context).size.height * 0.2),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleVerifyOTP,
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
                          'verify'.tr(),
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
