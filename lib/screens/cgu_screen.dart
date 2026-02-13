import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:easy_localization/easy_localization.dart';
import '../services/cgu_service.dart';

class CguScreen extends StatefulWidget {
  const CguScreen({super.key});

  @override
  State<CguScreen> createState() => _CguScreenState();
}

class _CguScreenState extends State<CguScreen> {
  late Future<Map<String, dynamic>> _cguFuture;
  final CguService _cguService = CguService();
  String? _currentLocale;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Get current language from context
    final locale = context.locale.languageCode;

    // Only reload if locale changed or first time
    if (_currentLocale != locale) {
      _currentLocale = locale;
      _cguFuture = _cguService.getCgu(language: locale);
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = MediaQuery.of(context).platformBrightness;
    final isDark = brightness == Brightness.dark;

    return CupertinoPageScaffold(
      backgroundColor: isDark
          ? CupertinoColors.black
          : CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: isDark
            ? CupertinoColors.black
            : CupertinoColors.systemGroupedBackground,
        border: null,
        leading: CupertinoNavigationBarBackButton(
          color: CupertinoColors.activeBlue,
          onPressed: () => Navigator.pop(context),
        ),
        middle: Text(
          'terms_of_service'.tr(),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      child: SafeArea(
        child: FutureBuilder<Map<String, dynamic>>(
          future: _cguFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CupertinoActivityIndicator(radius: 16),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        CupertinoIcons.exclamationmark_circle,
                        size: 64,
                        color: CupertinoColors.systemGrey,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'error_loading_cgu'.tr(),
                        style: CupertinoTheme.of(
                          context,
                        ).textTheme.navTitleTextStyle,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        snapshot.error.toString(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: CupertinoColors.systemGrey,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 32),
                      CupertinoButton.filled(
                        onPressed: () {
                          setState(() {
                            final locale = context.locale.languageCode;
                            _cguFuture = _cguService.getCgu(language: locale);
                          });
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(CupertinoIcons.refresh, size: 20),
                            const SizedBox(width: 8),
                            Text('retry'.tr()),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (!snapshot.hasData) {
              return Center(
                child: Text(
                  'no_data_available'.tr(),
                  style: TextStyle(
                    color: CupertinoColors.systemGrey,
                    fontSize: 16,
                  ),
                ),
              );
            }

            final cgu = snapshot.data!;
            final content = cgu['content'] as String? ?? '';
            final lastUpdated = cgu['lastUpdated'] as String? ?? '';

            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Dernière mise à jour
                    if (lastUpdated.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 20.0),
                        child: Text(
                          '${'last_updated'.tr()}: $lastUpdated',
                          style: TextStyle(
                            color: CupertinoColors.systemGrey,
                            fontSize: 13,
                          ),
                        ),
                      ),

                    // Contenu des CGU
                    _buildCguContent(content, context, isDark),

                    const SizedBox(height: 24),

                    // Message d'acceptation (style iOS)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark
                            ? CupertinoColors.systemGreen.darkColor.withOpacity(
                                0.15,
                              )
                            : CupertinoColors.systemGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            CupertinoIcons.check_mark_circled_solid,
                            color: CupertinoColors.systemGreen,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'cgu_acceptance_message'.tr(),
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark
                                    ? CupertinoColors.white
                                    : CupertinoColors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCguContent(String content, BuildContext context, bool isDark) {
    // Parse le contenu Markdown basique avec style iOS
    final lines = content.split('\n');
    final widgets = <Widget>[];

    for (final line in lines) {
      if (line.startsWith('# ')) {
        // Titre principal (iOS style - large title)
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 20.0, bottom: 12.0),
            child: Text(
              line.replaceFirst('# ', ''),
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.35,
                color: isDark ? CupertinoColors.white : CupertinoColors.black,
              ),
            ),
          ),
        );
      } else if (line.startsWith('## ')) {
        // Sous-titre (iOS style - headline)
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 20.0, bottom: 8.0),
            child: Text(
              line.replaceFirst('## ', ''),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.38,
                color: isDark ? CupertinoColors.white : CupertinoColors.black,
              ),
            ),
          ),
        );
      } else if (line.startsWith('- ')) {
        // Bullet point (iOS style)
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(left: 4.0, bottom: 6.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2.0, right: 8.0),
                  child: Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemGrey,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    line.replaceFirst('- ', ''),
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.5,
                      color: isDark
                          ? CupertinoColors.systemGrey6
                          : CupertinoColors.black,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      } else if (line.startsWith('---')) {
        // Séparateur (iOS style)
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Container(
              height: 0.5,
              color: isDark
                  ? CupertinoColors.systemGrey4
                  : CupertinoColors.systemGrey5,
            ),
          ),
        );
      } else if (line.trim().isEmpty) {
        // Espace vide
        widgets.add(const SizedBox(height: 8));
      } else {
        // Texte normal (iOS style - body)
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              line,
              style: TextStyle(
                fontSize: 16,
                height: 1.5,
                letterSpacing: -0.32,
                color: isDark
                    ? CupertinoColors.systemGrey6
                    : CupertinoColors.black,
              ),
            ),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }
}
