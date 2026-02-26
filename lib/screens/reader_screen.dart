import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';
import 'dart:async';
import '../services/reading_service.dart';
import '../services/story_service.dart';
import '../providers/theme_provider.dart';

// Énumération pour les thèmes de lecture
enum ReaderTheme { light, dark, sepia }

class ReaderScreen extends StatefulWidget {
  final Story story;
  final int initialChapterIndex;
  final String? selectedLang;

  const ReaderScreen({
    super.key,
    required this.story,
    this.initialChapterIndex = 0,
    this.selectedLang,
  });

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  final ReadingService _readingService = ReadingService();
  final ScrollController _scrollController = ScrollController();
  late final PageController _pageController;

  late int _currentChapterIndex;
  Map<String, dynamic>? _currentChapter;
  bool _isLoading = true;
  bool _showControls = true;

  // Reader settings
  late ReaderTheme _theme;
  double _fontSize = 18.0;
  String _fontFamily = 'Merriweather';

  // Tracking variables
  DateTime? _readingStartTime;
  Timer? _progressTimer;
  double _scrollPosition = 0.0;

  @override
  void initState() {
    super.initState();
    // Synchroniser avec le thème global de l'app
    final themeProvider = context.read<ThemeProvider>();
    _theme = themeProvider.isDarkMode ? ReaderTheme.dark : ReaderTheme.light;

    _currentChapterIndex = widget.initialChapterIndex;
    _pageController = PageController(initialPage: _currentChapterIndex);
    _loadReaderPreferences(); // Charger les préférences sauvegardées
    _loadChapterAndProgress();
    _recordView();
    _setupScrollListener();
    _startReadingTimer();
  }

  // Charger les préférences de lecture depuis SharedPreferences
  Future<void> _loadReaderPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _fontSize = prefs.getDouble('reader_font_size') ?? 18.0;
      _fontFamily = prefs.getString('reader_font_family') ?? 'Merriweather';
    });
  }

  // Sauvegarder les préférences de lecture
  Future<void> _saveReaderPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('reader_font_size', _fontSize);
    await prefs.setString('reader_font_family', _fontFamily);
  }

  @override
  void dispose() {
    _saveProgress();
    _progressTimer?.cancel();
    _scrollController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (_scrollController.hasClients) {
        final maxScroll = _scrollController.position.maxScrollExtent;
        final currentScroll = _scrollController.position.pixels;

        if (maxScroll > 0) {
          setState(() {
            _scrollPosition = (currentScroll / maxScroll * 100).clamp(
              0.0,
              100.0,
            );
          });
        }
      }
    });
  }

  void _startReadingTimer() {
    _readingStartTime = DateTime.now();

    // Auto-save progress every 30 seconds
    _progressTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _saveProgress();
    });
  }

  Future<void> _recordView() async {
    await _readingService.recordView(widget.story.id);
  }

  Future<void> _loadChapterAndProgress() async {
    setState(() => _isLoading = true);

    try {
      // Vérifier si les chapitres sont chargés
      late Map<String, dynamic> chapter;

      if (widget.story.chaptersList.isEmpty) {
        // Si les chapitres ne sont pas chargés, récupérer l'histoire complète
        final storyService = StoryService();
        final fullStory = await storyService.getStoryById(widget.story.id);

        if (fullStory.chaptersList.isEmpty) {
          throw Exception('Aucun chapitre disponible pour cette histoire');
        }

        chapter = fullStory.chaptersList[_currentChapterIndex];
      } else {
        chapter = widget.story.chaptersList[_currentChapterIndex];
      }

      // Load chapter content
      final chapterData = await _readingService.getChapter(
        chapter['id'] as int,
      );

      setState(() {
        _currentChapter = chapterData;
      });

      // Load last reading position for this chapter
      final progress = await _readingService.getProgress(widget.story.id);
      if (progress != null &&
          progress['chapter_id'] == chapter['id'] &&
          _scrollController.hasClients) {
        final savedPosition = progress['scroll_position'] ?? 0.0;
        final maxScroll = _scrollController.position.maxScrollExtent;
        final targetScroll = maxScroll * (savedPosition / 100);

        await Future.delayed(const Duration(milliseconds: 300));
        _scrollController.animateTo(
          targetScroll,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProgress() async {
    if (_currentChapter == null || _readingStartTime == null) return;

    final readingTime = DateTime.now().difference(_readingStartTime!).inSeconds;
    final isCompleted = _scrollPosition >= 95.0;

    await _readingService.saveProgress(
      storyId: widget.story.id,
      chapterId: _currentChapter!['id'],
      scrollPosition: _scrollPosition,
      isCompleted: isCompleted,
      readingTimeSeconds: readingTime,
    );

    // Si c'est le dernier chapitre et qu'il est complété, marquer l'histoire comme complète
    if (isCompleted &&
        _currentChapterIndex == widget.story.chaptersList.length - 1) {
      await _readingService.markStoryCompleted(widget.story.id);
    }
  }

  void _goToPreviousChapter() {
    if (_currentChapterIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _goToNextChapter() {
    if (_currentChapterIndex < widget.story.chaptersList.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // Si c'est le dernier chapitre et qu'il est complété, marquer l'histoire comme complète
      _checkAndMarkStoryCompletion();
    }
  }

  Future<void> _checkAndMarkStoryCompletion() async {
    if (_scrollPosition >= 95.0 &&
        _currentChapterIndex == widget.story.chaptersList.length - 1) {
      final success = await _readingService.markStoryCompleted(widget.story.id);
      if (success && mounted) {
        _showCompletionDialog();
      }
    }
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _getBackgroundColor(),
        title: Text(
          'reader_congratulations'.tr(),
          style: TextStyle(color: _getTextColor(), fontSize: 24),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'reader_finished_story'.tr(),
              style: TextStyle(color: _getTextColor(), fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (_readingStartTime != null)
              Text(
                '${'reader_reading_time'.tr()} ${_formatReadingTime(DateTime.now().difference(_readingStartTime!).inSeconds)}',
                style: TextStyle(
                  color: _getTextColor().withOpacity(0.7),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('reader_back'.tr()),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: Text('reader_see_other_stories'.tr()),
          ),
        ],
      ),
    );
  }

  String _formatReadingTime(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;

    if (hours > 0) {
      return '$hours h $minutes min';
    } else {
      return '$minutes min';
    }
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });

    if (!_showControls) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  void _showSettingsBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: BoxDecoration(
            color: _getBackgroundColor(),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'reader_settings'.tr(),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _getTextColor(),
                ),
              ),
              const SizedBox(height: 24),

              // Thème synchronisé avec l'app
              Text(
                'reader_theme'.tr(),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _getTextColor(),
                ),
              ),
              const SizedBox(height: 12),
              Consumer<ThemeProvider>(
                builder: (context, themeProvider, _) => Row(
                  children: [
                    Expanded(
                      child: _buildThemeOption(
                        'reader_theme_light'.tr(),
                        ReaderTheme.light,
                        Colors.white,
                        Colors.black,
                        setModalState,
                        themeProvider.isDarkMode == false,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildThemeOption(
                        'reader_theme_dark'.tr(),
                        ReaderTheme.dark,
                        const Color(0xFF1a1a1a),
                        Colors.white,
                        setModalState,
                        themeProvider.isDarkMode == true,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Taille de police
              Text(
                'reader_text_size'.tr(),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _getTextColor(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  IconButton(
                    onPressed: () {
                      if (_fontSize > 14) {
                        setState(() => _fontSize -= 2);
                        setModalState(() {});
                        _saveReaderPreferences();
                      }
                    },
                    icon: const Icon(Icons.remove_circle_outline),
                    color: _getTextColor(),
                  ),
                  Expanded(
                    child: Slider(
                      value: _fontSize,
                      min: 14,
                      max: 28,
                      divisions: 7,
                      label: _fontSize.round().toString(),
                      onChanged: (value) {
                        setState(() => _fontSize = value);
                        setModalState(() {});
                        _saveReaderPreferences();
                      },
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      if (_fontSize < 28) {
                        setState(() => _fontSize += 2);
                        setModalState(() {});
                        _saveReaderPreferences();
                      }
                    },
                    icon: const Icon(Icons.add_circle_outline),
                    color: _getTextColor(),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Police
              Text(
                'reader_font'.tr(),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _getTextColor(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildFontOption(
                      'Serif',
                      'Merriweather',
                      setModalState,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildFontOption('Sans', 'Roboto', setModalState),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemeOption(
    String label,
    ReaderTheme theme,
    Color bg,
    Color text,
    StateSetter setModalState,
    bool isGlobalTheme,
  ) {
    final isSelected = _theme == theme;
    return GestureDetector(
      onTap: () {
        setState(() => _theme = theme);

        // Synchroniser avec le ThemeProvider global
        final themeProvider = context.read<ThemeProvider>();
        if (theme == ReaderTheme.light) {
          themeProvider.setTheme(ThemeMode.light);
        } else if (theme == ReaderTheme.dark) {
          themeProvider.setTheme(ThemeMode.dark);
        }

        setModalState(() {});
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: text,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFontOption(
    String label,
    String font,
    StateSetter setModalState,
  ) {
    final isSelected = _fontFamily == font;
    return GestureDetector(
      onTap: () {
        setState(() => _fontFamily = font);
        setModalState(() {});
        _saveReaderPreferences();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.withOpacity(0.1) : Colors.transparent,
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontFamily: font,
              color: _getTextColor(),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Color _getBackgroundColor() {
    switch (_theme) {
      case ReaderTheme.light:
        return Colors.white;
      case ReaderTheme.dark:
        return const Color(0xFF1a1a1a);
      case ReaderTheme.sepia:
        return const Color(0xFFFFF8E1);
    }
  }

  Color _getTextColor() {
    switch (_theme) {
      case ReaderTheme.light:
        return Colors.black87;
      case ReaderTheme.dark:
        return Colors.white;
      case ReaderTheme.sepia:
        return Colors.black87;
    }
  }

  /// Mapper le code locale vers la clé backend
  String _localeToKey(String localeCode) {
    switch (localeCode) {
      case 'mg':
        return 'gasy';
      case 'fr':
        return 'fr';
      case 'en':
        return 'en';
      default:
        return 'gasy';
    }
  }

  String _getContent(dynamic content, String language) {
    if (content is Map) {
      final key = _localeToKey(language);
      // Essayer d'abord la langue mappée, puis les fallbacks (gasy d'abord)
      return content[key]?.toString() ?? 
             content['gasy']?.toString() ?? 
             content['fr']?.toString() ?? 
             content['en']?.toString() ?? 
             content.values.firstOrNull?.toString() ?? '';
    }
    return content?.toString() ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _getBackgroundColor(),
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          children: [
            // Page view pour swipe entre chapitres (horizontal, style livre)
            PageView.builder(
              controller: _pageController,
              itemCount: widget.story.chaptersList.length,
              onPageChanged: (index) {
                _saveProgress();
                setState(() {
                  _currentChapterIndex = index;
                  _scrollPosition = 0.0;
                  _readingStartTime = DateTime.now();
                });
                // Réinitialiser le scroll au début du nouveau chapitre
                if (_scrollController.hasClients) {
                  _scrollController.jumpTo(0);
                }
                _loadChapterAndProgress();
              },
              itemBuilder: (context, index) {
                if (index != _currentChapterIndex || _isLoading) {
                  return _buildChapterLoadingSkeleton();
                }

                // Contenu du chapitre avec scroll vertical
                final currentLang = widget.selectedLang != null 
                    ? (widget.selectedLang == 'gasy' ? 'mg' : widget.selectedLang!)
                    : context.locale.languageCode;
                final content = _getContent(_currentChapter?['content'], currentLang);
                final title = _getContent(_currentChapter?['title'], currentLang);
                final chapterNum = _currentChapter?['chapter_number'] ?? '';

                return SingleChildScrollView(
                  controller: _scrollController,
                  padding: EdgeInsets.only(
                    left: 24,
                    right: 24,
                    top: _showControls ? 120 : 60,
                    bottom: _showControls ? 120 : 80,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Titre du chapitre
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: _fontSize + 10,
                          fontWeight: FontWeight.bold,
                          fontFamily: _fontFamily,
                          color: _getTextColor(),
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${'chapter_title'.tr()} $chapterNum',
                        style: TextStyle(
                          fontSize: _fontSize - 4,
                          color: _getTextColor().withOpacity(0.6),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      Divider(
                        height: 40,
                        thickness: 1,
                        color: _getTextColor().withOpacity(0.2),
                      ),

                      // Contenu du chapitre (scroll vertical)
                      Text(
                        content,
                        style: TextStyle(
                          fontSize: _fontSize,
                          height: 1.8,
                          fontFamily: _fontFamily,
                          color: _getTextColor(),
                          letterSpacing: 0.3,
                        ),
                        textAlign: TextAlign.justify,
                      ),
                      
                      // Espace et indication de fin de chapitre
                      const SizedBox(height: 40),
                      Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.more_horiz,
                              color: _getTextColor().withOpacity(0.3),
                              size: 32,
                            ),
                            const SizedBox(height: 16),
                            if (_currentChapterIndex < widget.story.chaptersList.length - 1)
                              Text(
                                'reader_swipe_next'.tr(),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _getTextColor().withOpacity(0.4),
                                  fontStyle: FontStyle.italic,
                                ),
                              )
                            else
                              Text(
                                'reader_end_of_story'.tr(),
                                style: TextStyle(
                                  fontSize: 14,
                                  // ignore: deprecated_member_use
                                  color: _getTextColor().withOpacity(0.5),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                );
              },
            ),

            // Top bar avec progression
            if (_showControls)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: _getBackgroundColor(),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top,
                    left: 8,
                    right: 8,
                    bottom: 8,
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.arrow_back,
                              color: _getTextColor(),
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  widget.story.getTitle(widget.selectedLang ?? 'gasy'),
                                  style: TextStyle(
                                    color: _getTextColor(),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '${'chapter_title'.tr()} ${_currentChapter?['chapter_number'] ?? _currentChapterIndex + 1}/${widget.story.chaptersList.length}',
                                  style: TextStyle(
                                    color: _getTextColor().withOpacity(0.6),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.settings, color: _getTextColor()),
                            onPressed: _showSettingsBottomSheet,
                          ),
                        ],
                      ),
                      // Barre de progression
                      if (!_isLoading)
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 2,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 6,
                            ),
                            overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 12,
                            ),
                          ),
                          child: Slider(
                            value: _scrollPosition,
                            min: 0,
                            max: 100,
                            activeColor: const Color(0xFFFC3C44),
                            inactiveColor: _getTextColor().withOpacity(0.2),
                            onChanged: (value) {
                              if (_scrollController.hasClients) {
                                final maxScroll =
                                    _scrollController.position.maxScrollExtent;
                                final targetScroll = maxScroll * (value / 100);
                                _scrollController.jumpTo(targetScroll);
                              }
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),

            // Bottom navigation
            if (_showControls)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: _getBackgroundColor(),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    bottom: MediaQuery.of(context).padding.bottom + 12,
                    top: 12,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Previous chapter
                      ElevatedButton.icon(
                        onPressed: _currentChapterIndex > 0
                            ? _goToPreviousChapter
                            : null,
                        icon: const Icon(Icons.chevron_left, size: 20),
                        label: Text('reader_previous'.tr()),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _getTextColor(),
                          foregroundColor: _getBackgroundColor(),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),

                      // Progress indicator
                      Text(
                        '${_scrollPosition.toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _getTextColor().withOpacity(0.7),
                        ),
                      ),

                      // Next chapter
                      ElevatedButton.icon(
                        onPressed:
                            _currentChapterIndex <
                                widget.story.chaptersList.length - 1
                            ? _goToNextChapter
                            : null,
                        icon: const Icon(Icons.chevron_right, size: 20),
                        label: Text('reader_next'.tr()),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _getTextColor(),
                          foregroundColor: _getBackgroundColor(),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Build lazy loading skeleton for chapter loading
  Widget _buildChapterLoadingSkeleton() {
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: _showControls ? 120 : 60,
        bottom: _showControls ? 120 : 80,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title skeleton
          Container(
            width: double.infinity,
            height: 32,
            decoration: BoxDecoration(
              color: _getTextColor().withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 12),
          // Subtitle skeleton
          Container(
            width: 150,
            height: 16,
            decoration: BoxDecoration(
              color: _getTextColor().withOpacity(0.08),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 32),
          // Content skeleton lines
          ...List.generate(15, (index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                width: index % 4 == 0 ? double.infinity * 0.85 : double.infinity,
                height: 20,
                decoration: BoxDecoration(
                  color: _getTextColor().withOpacity(0.06),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}