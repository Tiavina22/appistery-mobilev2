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
    with TickerProviderStateMixin {
  late AnimationController _floatController;
  late AnimationController _fadeController;
  late AnimationController _glowController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _floatAnimation;
  late Animation<double> _glowAnimation;
  double _progress = 0.0;
  Timer? _progressTimer;

  @override
  void initState() {
    super.initState();
    
    // Fade in animation
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );

    // Floating up/down animation (loop)
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _floatAnimation = Tween<double>(begin: -12.0, end: 12.0).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );
    _floatController.repeat(reverse: true);

    // Glow pulsing animation
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _glowAnimation = Tween<double>(begin: 0.3, end: 0.8).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
    _glowController.repeat(reverse: true);

    _fadeController.forward();
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
    _floatController.dispose();
    _fadeController.dispose();
    _glowController.dispose();
    _progressTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/loading/loading.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: AnimatedBuilder(
              animation: Listenable.merge([_floatController, _glowController]),
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, _floatAnimation.value),
                  child: _buildGhost(),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGhost() {
    final glowOpacity = _glowAnimation.value;
    return SizedBox(
      width: 160,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Glow effect behind ghost
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withOpacity(glowOpacity * 0.3),
                  blurRadius: 60,
                  spreadRadius: 20,
                ),
                BoxShadow(
                  color: const Color(0xFF1DB954).withOpacity(glowOpacity * 0.2),
                  blurRadius: 40,
                  spreadRadius: 10,
                ),
              ],
            ),
          ),
          // Ghost body
          CustomPaint(
            size: const Size(140, 180),
            painter: _GhostPainter(glowOpacity: glowOpacity),
          ),
          // Eyes
          Positioned(
            top: 55,
            left: 48,
            child: _buildEye(),
          ),
          Positioned(
            top: 55,
            right: 48,
            child: _buildEye(),
          ),
          // Mouth (small smile)
          Positioned(
            top: 85,
            child: Container(
              width: 20,
              height: 10,
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Colors.black.withOpacity(0.6),
                    width: 2.5,
                  ),
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(10),
                  bottomRight: Radius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEye() {
    return Container(
      width: 16,
      height: 20,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Align(
        alignment: const Alignment(0.3, 0.3),
        child: Container(
          width: 5,
          height: 5,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

class _GhostPainter extends CustomPainter {
  final double glowOpacity;

  _GhostPainter({required this.glowOpacity});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.92)
      ..style = PaintingStyle.fill;

    final path = Path();
    final w = size.width;
    final h = size.height;

    // Head (rounded top)
    path.moveTo(w * 0.5, 0);
    path.cubicTo(w * 0.15, 0, 0, h * 0.18, 0, h * 0.35);

    // Left side body
    path.lineTo(0, h * 0.82);

    // Wavy bottom (3 waves)
    final waveCount = 3;
    final waveWidth = w / waveCount;
    for (int i = 0; i < waveCount; i++) {
      final startX = i * waveWidth;
      final midX = startX + waveWidth / 2;
      final endX = startX + waveWidth;
      final isUp = i % 2 == 0;
      path.quadraticBezierTo(
        midX, isUp ? h : h * 0.75,
        endX, h * 0.82,
      );
    }

    // Right side body
    path.lineTo(w, h * 0.35);

    // Head (rounded top right)
    path.cubicTo(w, h * 0.18, w * 0.85, 0, w * 0.5, 0);

    path.close();
    canvas.drawPath(path, paint);

    // Subtle outline
    final outlinePaint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(path, outlinePaint);
  }

  @override
  bool shouldRepaint(covariant _GhostPainter oldDelegate) {
    return oldDelegate.glowOpacity != glowOpacity;
  }
}
