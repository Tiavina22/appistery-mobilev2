import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  late AnimationController _animationController;

  final List<OnboardingData> _pages = [
    OnboardingData(
      imagePath: 'assets/onboarding/one.png',
      titleKey: 'onboarding_title_1',
      descriptionKey: 'onboarding_desc_1',
      color: const Color(0xFF1DB954),
    ),
    OnboardingData(
      imagePath: 'assets/onboarding/two.png',
      titleKey: 'onboarding_title_2',
      descriptionKey: 'onboarding_desc_2',
      color: const Color(0xFF1DB954),
    ),
    OnboardingData(
      imagePath: 'assets/onboarding/three.png',
      titleKey: 'onboarding_title_3',
      descriptionKey: 'onboarding_desc_3',
      color: const Color(0xFF1DB954),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
      _animationController.forward(from: 0);
    } else {
      _completeOnboarding();
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
    final topSafe = MediaQuery.of(context).padding.top;
    final logoTop = topSafe + 8 * verticalS;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // PageView with images
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
              _animationController.forward(from: 0);
            },
            itemCount: _pages.length,
            itemBuilder: (context, index) {
              return _OnboardingPage(data: _pages[index]);
            },
          ),
          
          // Top gradient overlay
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 120 * verticalS,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.6),
                    Colors.black.withOpacity(0.3),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          
          // Logo en haut
          Positioned(
            top: logoTop,
            left: 0,
            right: 0,
            child: Center(
              child: Hero(
                tag: 'app_logo',
                child: Image.asset(
                  'assets/logo/logo-appistery-no.png',
                  width: (40 * s).clamp(32.0, 56.0),
                  height: (40 * s).clamp(32.0, 56.0),
                ),
              ),
            ),
          ),
          
          // Skip button at top right
          if (_currentPage < _pages.length - 1)
            Positioned(
              top: logoTop,
              right: hPad,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _completeOnboarding,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: (16 * s).clamp(12.0, 24.0),
                      vertical: (8 * s).clamp(6.0, 12.0),
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      'skip'.tr(),
                      style: TextStyle(
                        fontSize: (13 * s).clamp(11.0, 16.0),
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          
          // Bottom section avec dots et bouton
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                padding: EdgeInsets.fromLTRB(hPad, 32 * verticalS, hPad, 24 * verticalS),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.7),
                      Colors.black.withOpacity(0.95),
                    ],
                    stops: const [0.0, 0.3, 1.0],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Page indicators
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _pages.length,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          margin: EdgeInsets.symmetric(horizontal: 4 * s),
                          width: _currentPage == index ? (28 * s).clamp(20.0, 36.0) : (7 * s).clamp(6.0, 10.0),
                          height: (7 * s).clamp(6.0, 10.0),
                          decoration: BoxDecoration(
                            gradient: _currentPage == index
                                ? const LinearGradient(
                                    colors: [
                                      Color(0xFF1DB954),
                                      Color(0xFF1AA34A),
                                    ],
                                  )
                                : null,
                            color: _currentPage != index
                                ? Colors.white.withOpacity(0.3)
                                : null,
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: _currentPage == index
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFF1DB954).withOpacity(0.5),
                                      blurRadius: 8,
                                      spreadRadius: -2,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 28 * verticalS),
                    
                    // Boutons
                    Row(
                      children: [
                        // Bouton Back
                        if (_currentPage > 0)
                          Expanded(
                            flex: 1,
                            child: OutlinedButton(
                              onPressed: () {
                                _pageController.previousPage(
                                  duration: const Duration(milliseconds: 400),
                                  curve: Curves.easeInOutCubic,
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: BorderSide(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 1.5,
                                ),
                                padding: EdgeInsets.symmetric(vertical: (12 * s).clamp(10.0, 16.0)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.arrow_back_rounded, size: (16 * s).clamp(14.0, 20.0)),
                                  SizedBox(width: 4 * s),
                                  Text(
                                    'previous'.tr(),
                                    style: TextStyle(
                                      fontSize: (13 * s).clamp(11.0, 16.0),
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (_currentPage > 0) SizedBox(width: 12 * s),
                        
                        // Bouton Next/Start
                        Expanded(
                          flex: _currentPage > 0 ? 2 : 1,
                          child: ElevatedButton(
                            onPressed: _currentPage == _pages.length - 1
                                ? _completeOnboarding
                                : _nextPage,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1DB954),
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: (12 * s).clamp(10.0, 16.0)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 6,
                              shadowColor: const Color(0xFF1DB954).withOpacity(0.4),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _currentPage == _pages.length - 1
                                      ? 'start'.tr()
                                      : 'next'.tr(),
                                  style: TextStyle(
                                    fontSize: (13 * s).clamp(11.0, 16.0),
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                SizedBox(width: 4 * s),
                                Icon(
                                  _currentPage == _pages.length - 1
                                      ? Icons.check_rounded
                                      : Icons.arrow_forward_rounded,
                                  size: (16 * s).clamp(14.0, 20.0),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }
}

class OnboardingData {
  final String imagePath;
  final String titleKey;
  final String descriptionKey;
  final Color color;

  OnboardingData({
    required this.imagePath,
    required this.titleKey,
    required this.descriptionKey,
    required this.color,
  });
}

class _OnboardingPage extends StatefulWidget {
  final OnboardingData data;

  const _OnboardingPage({required this.data});

  @override
  State<_OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<_OnboardingPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final w = size.width;
    final h = size.height;
    final s = (w / 375).clamp(0.75, 1.3);
    final verticalS = (h / 812).clamp(0.7, 1.3);
    final hPad = (w * 0.07).clamp(16.0, 40.0);
    // Bottom space adapts to screen height so text doesn't overlap controls
    final bottomSpace = (h * 0.22).clamp(100.0, 220.0);

    return Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage(widget.data.imagePath),
          fit: BoxFit.cover,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.1),
              Colors.black.withOpacity(0.3),
              Colors.black.withOpacity(0.85),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 24 * verticalS),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                
                // Contenu texte avec animations
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Column(
                      children: [
                        // Title avec background subtil
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: (20 * s).clamp(14.0, 28.0),
                            vertical: (12 * s).clamp(10.0, 20.0),
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(16 * s),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.1),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            widget.data.titleKey.tr(),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: (26 * s).clamp(20.0, 36.0),
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: -0.5,
                              height: 1.2,
                            ),
                          ),
                        ),
                        SizedBox(height: 18 * verticalS),
                        
                        // Description
                        Text(
                          widget.data.descriptionKey.tr(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: (15 * s).clamp(13.0, 20.0),
                            color: Colors.white.withOpacity(0.95),
                            height: 1.6,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                SizedBox(height: bottomSpace),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
