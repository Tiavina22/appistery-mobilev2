import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/language_selection_screen.dart';
import 'screens/theme_selection_screen.dart';
import 'screens/home_screen.dart';
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
import 'widgets/force_update_dialog.dart';
import 'widgets/home_with_version_check.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  await dotenv.load(fileName: ".env");

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('fr')],
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

  Future<Widget> _getInitialScreen(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final versionProvider = Provider.of<VersionProvider>(
      context,
      listen: false,
    );

    // Check version immediately
    await versionProvider.checkVersionAtStartup();

    final languageSelected = prefs.getBool('language_selected') ?? false;
    final themeSelected = prefs.getBool('theme_selected') ?? false;
    final onboardingCompleted = prefs.getBool('onboarding_completed') ?? false;

    // Vérifier d'abord les étapes d'onboarding
    if (!languageSelected) {
      return const LanguageSelectionScreen();
    } else if (!themeSelected) {
      return const ThemeSelectionScreen();
    }

    // Si onboarding non complété, aller au login
    if (!onboardingCompleted) {
      return const LoginScreen();
    }

    // Onboarding complété, vérifier si l'utilisateur est connecté
    // Rafraîchir le statut de connexion au démarrage
    await authProvider.refreshLoginStatus();

    if (authProvider.isLoggedIn) {
      return const HomeWithVersionCheck();
    } else {
      return const LoginScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    if (!themeProvider.isInitialized) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return MaterialApp(
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      debugShowCheckedModeBanner: false,
      theme: themeProvider.lightTheme,
      darkTheme: themeProvider.darkTheme,
      themeMode: themeProvider.themeMode,
      routes: {
        '/notifications': (context) => const NotificationsScreen(),
        '/subscription-offers': (context) => const SubscriptionOffersScreen(),
      },
      home: FutureBuilder<Widget>(
        future: _getInitialScreen(context),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return snapshot.data ?? const LanguageSelectionScreen();
        },
      ),
    );
  }
}
