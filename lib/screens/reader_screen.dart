import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../services/reading_service.dart';
import '../services/story_service.dart';
import '../providers/theme_provider.dart';

// Énumération pour les thèmes de lecture
enum ReaderTheme { light, dark, sepia }

class ReaderScreen extends StatefulWidget {
  final Story story;
  final int initialChapterIndex;

  const ReaderScreen({
    super.key,
    required this.story,
    this.initialChapterIndex = 0,
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
    _loadChapterAndProgress();
    _recordView();
    _setupScrollListener();
    _startReadingTimer();
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
      // Load chapter content
      final chapter = widget.story.chaptersList[_currentChapterIndex];
      final chapterData = await _readingService.getChapter(chapter['id']);

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
                'Paramètres de lecture',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _getTextColor(),
                ),
              ),
              const SizedBox(height: 24),

              // Thème synchronisé avec l'app
              Text(
                'Thème',
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
                        'Clair',
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
                        'Sombre',
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
                'Taille du texte',
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
                      },
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      if (_fontSize < 28) {
                        setState(() => _fontSize += 2);
                        setModalState(() {});
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
                'Police',
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

  String _getContent(dynamic content, String language) {
    if (content is Map) {
      return content[language] ?? content['fr'] ?? content['gasy'] ?? '';
    }
    return content.toString();
  }

  // Calculer les caractères par page en fonction de la hauteur réelle disponible
  int _calculateCharsPerPage(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    // Espace réservé aux contrôles et marges
    final topPadding = _showControls ? 120.0 : 60.0;
    final bottomPadding = _showControls
        ? 200.0
        : 160.0; // Plus d'espace pour le numéro de page + buffer
    final availableHeight = screenHeight - topPadding - bottomPadding;

    // Calculer le nombre de lignes qui peuvent tenir avec buffer de sécurité
    final lineHeight = _fontSize * 1.8; // height: 1.8
    // Réduire à 80% pour buffer supplémentaire
    final linesPerPage = ((availableHeight * 0.80) / lineHeight)
        .floor(); // 80% pour buffer maximum

    // Calcul des caractères par ligne (réduit pour plus de sécurité)
    final availableWidth = screenWidth - 48; // padding 24 + 24
    final charsPerLine = (availableWidth / (_fontSize * 0.65)).floor();
    final charsPerPage = (linesPerPage * charsPerLine).round();

    return charsPerPage > 150
        ? charsPerPage
        : 150; // Minimum 150 chars seulement
  }

  // Calculer le nombre de pages en fonction de la taille du texte ET de l'espace dispo
  int _getPageCount(String content, BuildContext context) {
    if (content.isEmpty) return 1;

    final charsPerPage = _calculateCharsPerPage(context);
    int totalPages = 0;
    int currentIndex = 0;

    while (currentIndex < content.length) {
      int endIndex = (currentIndex + charsPerPage).clamp(0, content.length);

      // Chercher le dernier espace si on n'est pas à la fin
      if (endIndex < content.length) {
        int lastSpace = content.lastIndexOf(' ', endIndex);
        if (lastSpace > currentIndex + (charsPerPage * 0.7)) {
          // 70% minimum
          endIndex = lastSpace + 1;
        }
      }

      currentIndex = endIndex;
      totalPages++;
    }

    return totalPages > 0 ? totalPages : 1;
  }

  // Récupérer le contenu d'une page spécifique
  String _getPageContent(
    String fullContent,
    int pageIndex,
    BuildContext context,
  ) {
    if (fullContent.isEmpty) return '';

    final charsPerPage = _calculateCharsPerPage(context);

    // Calculer la position de départ réelle pour cette page
    int currentIndex = 0;
    int currentPage = 0;

    // Parcourir jusqu'à la page demandée
    while (currentPage < pageIndex && currentIndex < fullContent.length) {
      int endIndex = (currentIndex + charsPerPage).clamp(0, fullContent.length);

      if (endIndex < fullContent.length) {
        int lastSpace = fullContent.lastIndexOf(' ', endIndex);
        if (lastSpace > currentIndex + (charsPerPage * 0.7)) {
          endIndex = lastSpace + 1;
        }
      }

      currentIndex = endIndex;
      currentPage++;
    }

    if (currentIndex >= fullContent.length) {
      return '';
    }

    // Extraire le contenu de cette page
    int endIndex = (currentIndex + charsPerPage).clamp(0, fullContent.length);

    // Si ce n'est pas la dernière page, couper au dernier espace
    if (endIndex < fullContent.length) {
      int lastSpace = fullContent.lastIndexOf(' ', endIndex);
      if (lastSpace > currentIndex + (charsPerPage * 0.7)) {
        endIndex = lastSpace;
      }
    }

    return fullContent.substring(currentIndex, endIndex).trim();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _getBackgroundColor(),
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          children: [
            // Page view pour swipe entre chapitres
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
                _loadChapterAndProgress();
              },
              itemBuilder: (context, index) {
                if (index != _currentChapterIndex || _isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                // Pagination style livre - diviser le texte en pages
                final content = _getContent(_currentChapter?['content'], 'fr');
                final title = _getContent(_currentChapter?['title'], 'fr');
                final chapterNum = _currentChapter?['chapter_number'] ?? '';
                final pageCount = _getPageCount(content, context);

                return PageView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: pageCount,
                  onPageChanged: (pageIndex) {
                    setState(() {
                      _scrollPosition = ((pageIndex + 1) / pageCount * 100)
                          .clamp(0.0, 100.0);
                    });
                  },
                  itemBuilder: (context, pageIndex) {
                    return Padding(
                      padding: EdgeInsets.only(
                        left: 24,
                        right: 24,
                        top: _showControls ? 120 : 60,
                        bottom: _showControls ? 200 : 160,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Titre du chapitre (seulement sur la première page)
                          if (pageIndex == 0) ...[
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
                              'Chapitre $chapterNum',
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
                          ],

                          // Contenu de la page
                          Expanded(
                            child: Text(
                              _getPageContent(content, pageIndex, context),
                              style: TextStyle(
                                fontSize: _fontSize,
                                height: 1.8,
                                fontFamily: _fontFamily,
                                color: _getTextColor(),
                                letterSpacing: 0.3,
                              ),
                              textAlign: TextAlign.justify,
                            ),
                          ),

                          // Numéro de page en bas
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: Text(
                                '${pageIndex + 1} / $pageCount',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _getTextColor().withOpacity(0.5),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
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
                                  widget.story.title,
                                  style: TextStyle(
                                    color: _getTextColor(),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  'Chapitre ${_currentChapterIndex + 1}/${widget.story.chaptersList.length}',
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
                            activeColor: Colors.blue,
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
                        label: const Text('Précédent'),
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
                        label: const Text('Suivant'),
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
}
