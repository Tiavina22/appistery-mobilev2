import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/language_selection_screen.dart';
import 'screens/theme_selection_screen.dart';
import 'screens/login_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/subscription_offers_screen.dart';
import 'providers/theme_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/story_provider.dart';
import 'providers/websocket_provider.dart';
import 'providers/version_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/subscription_offer_provider.dart';
import 'widgets/home_with_version_check.dart';
import 'widgets/netflix_splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  await dotenv.load(fileName: ".env");

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('fr'), Locale('mg')],
      path: 'assets/translations',
      fallbackLocale: const Locale('fr'),
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => StoryProvider()),
          ChangeNotifierProvider(create: (_) => WebSocketProvider()),
          ChangeNotifierProvider(create: (_) => VersionProvider()),
          ChangeNotifierProvider(create: (_) => NotificationProvider()),
          ChangeNotifierProvider(create: (_) => SubscriptionOfferProvider()),
        ],
        child: const MainApp(),
      ),
    ),
  );
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return Builder(
      builder: (context) {
        // Map 'mg' to 'fr' for Material localization since 'mg' is not supported by Flutter
        final currentLocale = context.locale;
        final materialLocale = currentLocale.languageCode == 'mg' 
            ? const Locale('fr') 
            : currentLocale;

        return MaterialApp(
          localizationsDelegates: [
            ...context.localizationDelegates,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('en'),
            Locale('fr'),
          ],
          locale: materialLocale,
          debugShowCheckedModeBanner: false,
          theme: themeProvider.lightTheme,
          darkTheme: themeProvider.darkTheme,
          themeMode: themeProvider.themeMode,
          routes: {
            '/notifications': (context) => const NotificationsScreen(),
            '/subscription-offers': (context) => const SubscriptionOffersScreen(),
          },
          home: const InitialScreenLoader(),
        );
      }
    );
  }
}

class InitialScreenLoader extends StatefulWidget {
  const InitialScreenLoader({super.key});

  @override
  State<InitialScreenLoader> createState() => _InitialScreenLoaderState();
}

class _InitialScreenLoaderState extends State<InitialScreenLoader> {
  Widget? _initialScreen;
  bool _isLoading = true;
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    _loadInitialScreen();
  }

  Future<void> _loadInitialScreen() async {
    final prefs = await SharedPreferences.getInstance();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final versionProvider = Provider.of<VersionProvider>(
      context,
      listen: false,
    );
    final storyProvider = Provider.of<StoryProvider>(
      context,
      listen: false,
    );

    // Check version immediately
    await versionProvider.checkVersionAtStartup();

    final languageSelected = prefs.getBool('language_selected') ?? false;
    final themeSelected = prefs.getBool('theme_selected') ?? false;
    final onboardingCompleted = prefs.getBool('onboarding_completed') ?? false;

    Widget screen;

    // Vérifier d'abord les étapes d'onboarding
    if (!languageSelected) {
      screen = const LanguageSelectionScreen();
      _showSplash = false; // Pas de splash pour l'onboarding
    } else if (!themeSelected) {
      screen = const ThemeSelectionScreen();
      _showSplash = false;
    } else if (!onboardingCompleted) {
      // Si onboarding non complété, aller au login
      screen = const LoginScreen();
      _showSplash = false;
    } else {
      // Onboarding complété, vérifier si l'utilisateur est connecté
      await authProvider.refreshLoginStatus();

      if (authProvider.isLoggedIn) {
        screen = const HomeWithVersionCheck();
        // Pré-charger les stories et notifications en parallèle pendant le splash
        Future.wait([
          storyProvider.loadStories(),
          storyProvider.loadGenres(),
          storyProvider.loadAuthors(),
          Provider.of<NotificationProvider>(
            context,
            listen: false,
          ).loadNotifications(),
        ]);
      } else {
        screen = const LoginScreen();
        _showSplash = false;
      }
    }

    if (mounted) {
      setState(() {
        _initialScreen = screen;
        _isLoading = false;
      });
    }
  }

  void _onSplashComplete() {
    setState(() {
      _showSplash = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Afficher le splash screen pendant le chargement initial ou si nécessaire
    if (_isLoading || _showSplash) {
      return NetflixSplashScreen(
        onComplete: _onSplashComplete,
      );
    }

    return _initialScreen ?? const LanguageSelectionScreen();
  }
}
