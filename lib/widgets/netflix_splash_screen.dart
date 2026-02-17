import 'package:flutter/material.dart';
import 'dart:async';

class NetflixSplashScreen extends StatefulWidget {
  final VoidCallback onComplete;
  
  const NetflixSplashScreen({
    super.key,
    required this.onComplete,
  });

  @override
  State<NetflixSplashScreen> createState() => _NetflixSplashScreenState();
}

class _NetflixSplashScreenState extends State<NetflixSplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  double _progress = 0.0;
  Timer? _progressTimer;

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _controller.forward();

    // Simuler un chargement progressif
    _startProgressAnimation();
  }

  void _startProgressAnimation() {
    const duration = Duration(milliseconds: 50);
    _progressTimer = Timer.periodic(duration, (timer) {
      setState(() {
        _progress += 0.02;
        if (_progress >= 1.0) {
          _progress = 1.0;
          timer.cancel();
          // Attendre un peu avant de terminer
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) {
              widget.onComplete();
            }
          });
        }
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _progressTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : Colors.white,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Image.asset(
              'assets/logo/logo-appistery-no.png',
              width: 180,
              height: 180,
            ),
          ),
        ),
      ),
    );
  }
}
