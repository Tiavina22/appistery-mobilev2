import 'dart:math';

/// Service d'Intelligence Artificielle maison pour générer des titres
/// de catégories intelligents et personnalisés comme Netflix
/// Supporte le français, l'anglais et le malgache de manière dynamique
class CategoryIntelligenceService {
  final Random _random = Random();

  /// Templates de titres par genre avec variations multiples
  /// Structure: {langue: {genre: [titres]}}
  static const Map<String, Map<String, List<String>>> _genreTemplates = {
    // ==================== FRANÇAIS ====================
    'fr': {
      // Romance
      'Romance': [
        'Pour vous les amoureux',
        'Quand l\'amour frappe',
        'Histoires de cœur',
        'Tombez amoureux',
        'Passion et romance',
        'L\'amour est dans l\'air',
        'Émotions à fleur de peau',
      ],
      'Romantic': [
        'Pour vous les amoureux',
        'Quand l\'amour frappe',
        'Histoires de cœur',
        'Tombez amoureux',
        'Passion et romance',
      ],
      
      // Horreur
      'Horror': [
        'Vous êtes horrifié',
        'Frissons garantis',
        'Osez avoir peur',
        'Nuits blanches assurées',
        'Terreur nocturne',
        'Préparez-vous à trembler',
        'L\'horreur vous attend',
      ],
      'Horreur': [
        'Vous êtes horrifié',
        'Frissons garantis',
        'Osez avoir peur',
        'Nuits blanches assurées',
        'Terreur nocturne',
      ],
      
      // Thriller / Suspense
      'Thriller': [
        'Suspense haletant',
        'Tension maximale',
        'Accrochez-vous',
        'L\'adrénaline monte',
        'Mystères à résoudre',
        'Impossible de décrocher',
        'Au bord du siège',
      ],
      'Suspense': [
        'Suspense haletant',
        'Tension maximale',
        'Mystères à résoudre',
        'Impossible de décrocher',
      ],
      
      // Fantaisie / Fantasy
      'Fantasy': [
        'Mondes imaginaires',
        'Magie et aventures',
        'Évadez-vous ailleurs',
        'Univers fantastiques',
        'Quand la magie opère',
        'Au-delà du réel',
        'Royaumes enchantés',
      ],
      'Fantaisie': [
        'Mondes imaginaires',
        'Magie et aventures',
        'Évadez-vous ailleurs',
        'Univers fantastiques',
      ],
      
      // Science-Fiction
      'Science Fiction': [
        'Futurs possibles',
        'Voyages spatio-temporels',
        'Technologie et humanité',
        'Au-delà des étoiles',
        'Demain commence aujourd\'hui',
        'Univers parallèles',
        'L\'avenir est maintenant',
      ],
      'Sci-Fi': [
        'Futurs possibles',
        'Voyages spatio-temporels',
        'Au-delà des étoiles',
      ],
      
      // Drame
      'Drame': [
        'Émotions profondes',
        'Histoires bouleversantes',
        'La vie en face',
        'Drames humains',
        'Quand la vie bascule',
        'Récits poignants',
        'Émotions brutes',
      ],
      'Drama': [
        'Émotions profondes',
        'Histoires bouleversantes',
        'Drames humains',
        'Récits poignants',
      ],
      
      // Comédie
      'Comédie': [
        'Rires garantis',
        'Bonne humeur assurée',
        'Détente et sourires',
        'Pour vous faire rire',
        'Légèreté bienvenue',
        'Moments hilarants',
        'Sourire aux lèvres',
      ],
      'Comedy': [
        'Rires garantis',
        'Bonne humeur assurée',
        'Pour vous faire rire',
        'Moments hilarants',
      ],
      
      // Aventure
      'Aventure': [
        'Explorations épiques',
        'L\'aventure vous appelle',
        'Quêtes extraordinaires',
        'Périples mémorables',
        'Partez à l\'aventure',
        'Voyages incroyables',
        'Découvertes fascinantes',
      ],
      'Adventure': [
        'Explorations épiques',
        'L\'aventure vous appelle',
        'Quêtes extraordinaires',
        'Partez à l\'aventure',
      ],
      
      // Action
      'Action': [
        'Action explosive',
        'Adrénaline pure',
        'Rythme effréné',
        'Cascades spectaculaires',
        'Intensité maximale',
        'Battements de cœur',
        'Non-stop action',
      ],
      
      // Mystère
      'Mystère': [
        'Énigmes captivantes',
        'Mystères à élucider',
        'Indices cachés',
        'Enquêtes palpitantes',
        'Secrets révélés',
        'Résolvez l\'énigme',
      ],
      'Mystery': [
        'Énigmes captivantes',
        'Mystères à élucider',
        'Enquêtes palpitantes',
        'Secrets révélés',
      ],
      
      // Historique
      'Historique': [
        'Plongée dans le passé',
        'Histoire vivante',
        'Époques révolues',
        'Témoins de l\'histoire',
        'Récits d\'autrefois',
        'Mémoires du temps',
      ],
      'Historical': [
        'Plongée dans le passé',
        'Histoire vivante',
        'Témoins de l\'histoire',
        'Récits d\'autrefois',
      ],
    },

    // ==================== ENGLISH ====================
    'en': {
      // Romance
      'Romance': [
        'For the romantics',
        'When love strikes',
        'Tales of the heart',
        'Fall in love',
        'Passion and romance',
        'Love is in the air',
        'Heartfelt emotions',
      ],
      'Romantic': [
        'For the romantics',
        'When love strikes',
        'Tales of the heart',
        'Fall in love',
        'Passion and romance',
      ],
      
      // Horror
      'Horror': [
        'You\'re terrified',
        'Guaranteed chills',
        'Dare to be scared',
        'Sleepless nights ahead',
        'Nighttime terror',
        'Prepare to shiver',
        'Horror awaits',
      ],
      'Horreur': [
        'You\'re terrified',
        'Guaranteed chills',
        'Dare to be scared',
        'Sleepless nights ahead',
        'Nighttime terror',
      ],
      
      // Thriller / Suspense
      'Thriller': [
        'Heart-pounding suspense',
        'Maximum tension',
        'Hold on tight',
        'Adrenaline rising',
        'Mysteries to solve',
        'Can\'t put it down',
        'Edge of your seat',
      ],
      'Suspense': [
        'Heart-pounding suspense',
        'Maximum tension',
        'Mysteries to solve',
        'Can\'t put it down',
      ],
      
      // Fantasy
      'Fantasy': [
        'Imaginary worlds',
        'Magic and adventures',
        'Escape elsewhere',
        'Fantastic universes',
        'When magic happens',
        'Beyond reality',
        'Enchanted realms',
      ],
      'Fantaisie': [
        'Imaginary worlds',
        'Magic and adventures',
        'Escape elsewhere',
        'Fantastic universes',
      ],
      
      // Science-Fiction
      'Science Fiction': [
        'Possible futures',
        'Space-time travels',
        'Technology and humanity',
        'Beyond the stars',
        'Tomorrow starts today',
        'Parallel universes',
        'The future is now',
      ],
      'Sci-Fi': [
        'Possible futures',
        'Space-time travels',
        'Beyond the stars',
      ],
      
      // Drama
      'Drame': [
        'Deep emotions',
        'Moving stories',
        'Facing life',
        'Human dramas',
        'When life changes',
        'Powerful tales',
        'Raw emotions',
      ],
      'Drama': [
        'Deep emotions',
        'Moving stories',
        'Human dramas',
        'Powerful tales',
      ],
      
      // Comedy
      'Comédie': [
        'Guaranteed laughs',
        'Good vibes assured',
        'Relax and smile',
        'Make you laugh',
        'Welcome lightness',
        'Hilarious moments',
        'Smile on your face',
      ],
      'Comedy': [
        'Guaranteed laughs',
        'Good vibes assured',
        'Make you laugh',
        'Hilarious moments',
      ],
      
      // Adventure
      'Aventure': [
        'Epic explorations',
        'Adventure calls',
        'Extraordinary quests',
        'Memorable journeys',
        'Go on an adventure',
        'Incredible voyages',
        'Fascinating discoveries',
      ],
      'Adventure': [
        'Epic explorations',
        'Adventure calls',
        'Extraordinary quests',
        'Go on an adventure',
      ],
      
      // Action
      'Action': [
        'Explosive action',
        'Pure adrenaline',
        'Frantic pace',
        'Spectacular stunts',
        'Maximum intensity',
        'Heart racing',
        'Non-stop action',
      ],
      
      // Mystery
      'Mystère': [
        'Captivating puzzles',
        'Mysteries to solve',
        'Hidden clues',
        'Thrilling investigations',
        'Secrets revealed',
        'Solve the enigma',
      ],
      'Mystery': [
        'Captivating puzzles',
        'Mysteries to solve',
        'Thrilling investigations',
        'Secrets revealed',
      ],
      
      // Historical
      'Historique': [
        'Dive into the past',
        'Living history',
        'Bygone eras',
        'Witnesses of history',
        'Tales of old',
        'Memories of time',
      ],
      'Historical': [
        'Dive into the past',
        'Living history',
        'Witnesses of history',
        'Tales of old',
      ],
    },

    // ==================== MALAGASY ====================
    'mg': {
      // Romance
      'Romance': [
        'Ho anareo tia',
        'Rehefa mitempo ny fo',
        'Tantaran\'ny fo',
        'Tiavo izao',
        'Fitiavana sy hafanam-po',
        'Eny amin\'ny rivotra ny fitiavana',
        'Fihetseham-po lalina',
      ],
      'Romantic': [
        'Ho anareo tia',
        'Rehefa mitempo ny fo',
        'Tantaran\'ny fo',
        'Tiavo izao',
        'Fitiavana sy hafanam-po',
      ],
      
      // Horror
      'Horror': [
        'Mampatahotra anao',
        'Horohoro azo antoka',
        'Sahia matahotra',
        'Alina tsy mahatery torimaso',
        'Tahotra amin\'ny alina',
        'Miomàna hangovitra',
        'Miandry anao ny horohoro',
      ],
      'Horreur': [
        'Mampatahotra anao',
        'Horohoro azo antoka',
        'Sahia matahotra',
        'Alina tsy mahatery torimaso',
        'Tahotra amin\'ny alina',
      ],
      
      // Thriller / Suspense
      'Thriller': [
        'Suspense mampientanentana',
        'Fahaketrahana lehibe',
        'Mihazona mafy',
        'Miakatra ny adrenalina',
        'Mistery ho vavahana',
        'Tsy afaka miala',
        'Eo an-tsisin\'ny seza',
      ],
      'Suspense': [
        'Suspense mampientanentana',
        'Fahaketrahana lehibe',
        'Mistery ho vavahana',
        'Tsy afaka miala',
      ],
      
      // Fantasy
      'Fantasy': [
        'Tontolo noforonina',
        'Majika sy aventure',
        'Mandosira any hafa',
        'Univers mahagaga',
        'Rehefa miasa ny majika',
        'Mihoatra ny tena izy',
        'Fanjakana voavoady',
      ],
      'Fantaisie': [
        'Tontolo noforonina',
        'Majika sy aventure',
        'Mandosira any hafa',
        'Univers mahagaga',
      ],
      
      // Science-Fiction
      'Science Fiction': [
        'Ho avy mety',
        'Dia amin\'ny fotoana',
        'Teknolojia sy olombelona',
        'Mihoatra ny kintana',
        'Rahampitso manomboka androany',
        'Univers mifanila',
        'Efa izao ny ho avy',
      ],
      'Sci-Fi': [
        'Ho avy mety',
        'Dia amin\'ny fotoana',
        'Mihoatra ny kintana',
      ],
      
      // Drama
      'Drame': [
        'Fihetseham-po lalina',
        'Tantara mampihontsina',
        'Miatrika ny fiainana',
        'Draman\'olombelona',
        'Rehefa miova ny fiainana',
        'Tantara mahery',
        'Fihetseham-po mivantana',
      ],
      'Drama': [
        'Fihetseham-po lalina',
        'Tantara mampihontsina',
        'Draman\'olombelona',
        'Tantara mahery',
      ],
      
      // Comedy
      'Comédie': [
        'Hehy azo antoka',
        'Fihetseham-po tsara',
        'Mialà sasatra ary mitsiky',
        'Hampihomehy anao',
        'Maivana',
        'Fotoana mahafinaritra',
        'Tsiky eo am-bava',
      ],
      'Comedy': [
        'Hehy azo antoka',
        'Fihetseham-po tsara',
        'Hampihomehy anao',
        'Fotoana mahafinaritra',
      ],
      
      // Adventure
      'Aventure': [
        'Fitsidihana lehibe',
        'Miantso ny aventure',
        'Fikatsahana tsy mahazatra',
        'Dia tsy hay hadinoina',
        'Mandehana hikarokaroka',
        'Dia tsy mampino',
        'Fahitana mahafinaritra',
      ],
      'Adventure': [
        'Fitsidihana lehibe',
        'Miantso ny aventure',
        'Fikatsahana tsy mahazatra',
        'Mandehana hikarokaroka',
      ],
      
      // Action
      'Action': [
        'Action mamirapiratra',
        'Adrenalina madio',
        'Haingana be',
        'Cascades mahatalanjona',
        'Fahaketrahana lehibe',
        'Fo mivezivezy',
        'Action tsy miato',
      ],
      
      // Mystery
      'Mystère': [
        'Enigma mahavariana',
        'Mistery ho vavahana',
        'Soso-kevitra miafina',
        'Famotorana mampientanentana',
        'Tsiambaratelo voaseho',
        'Vahy ny enigma',
      ],
      'Mystery': [
        'Enigma mahavariana',
        'Mistery ho vavahana',
        'Famotorana mampientanentana',
        'Tsiambaratelo voaseho',
      ],
      
      // Historical
      'Historique': [
        'Milentika any amin\'ny lasa',
        'Tantara velona',
        'Vanim-potoana taloha',
        'Vavolombelon\'ny tantara',
        'Tantara fahiny',
        'Fahatsiarovana taloha',
      ],
      'Historical': [
        'Milentika any amin\'ny lasa',
        'Tantara velona',
        'Vavolombelon\'ny tantara',
        'Tantara fahiny',
      ],
    },
  };

  /// Templates contextuels basés sur l'heure de la journée
  static const Map<String, Map<String, Map<String, List<String>>>> _timeBasedTemplates = {
    'fr': {
      'morning': {
        'Romance': ['Commencez la journée avec amour', 'Douceur matinale'],
        'Horror': ['Frissons dès le matin', 'Réveillez-vous terrifié'],
        'Fantasy': ['Magie du matin', 'Rêvez éveillé'],
      },
      'afternoon': {
        'Romance': ['Après-midi romantique', 'Pause tendresse'],
        'Thriller': ['Suspense de l\'après-midi', 'Tension croissante'],
      },
      'evening': {
        'Horror': ['Soirée terrifiante', 'Quand la nuit tombe'],
        'Thriller': ['Mystères du soir', 'Soirée à suspense'],
        'Romance': ['Romance nocturne', 'Soirée intime'],
      },
      'night': {
        'Horror': ['Terreur nocturne', 'Cauchemars éveillés'],
        'Thriller': ['Nuit mystérieuse', 'Insomnie garantie'],
        'Fantasy': ['Rêves fantastiques', 'Magie de minuit'],
      },
    },
    'en': {
      'morning': {
        'Romance': ['Start your day with love', 'Morning sweetness'],
        'Horror': ['Morning chills', 'Wake up terrified'],
        'Fantasy': ['Morning magic', 'Daydream away'],
      },
      'afternoon': {
        'Romance': ['Romantic afternoon', 'Tenderness break'],
        'Thriller': ['Afternoon suspense', 'Rising tension'],
      },
      'evening': {
        'Horror': ['Terrifying evening', 'When night falls'],
        'Thriller': ['Evening mysteries', 'Suspenseful night'],
        'Romance': ['Evening romance', 'Intimate night'],
      },
      'night': {
        'Horror': ['Night terror', 'Waking nightmares'],
        'Thriller': ['Mysterious night', 'Guaranteed insomnia'],
        'Fantasy': ['Fantastic dreams', 'Midnight magic'],
      },
    },
    'mg': {
      'morning': {
        'Romance': ['Atombohy ny andro amin\'ny fitiavana', 'Hafaliana maraina'],
        'Horror': ['Horohoro maraina', 'Mifohaza matahotra'],
        'Fantasy': ['Majika maraina', 'Manoroninofy'],
      },
      'afternoon': {
        'Romance': ['Tolakandro romantika', 'Fialan-tsasatra fitiavana'],
        'Thriller': ['Suspense tolakandro', 'Fahaketrahana miakatra'],
      },
      'evening': {
        'Horror': ['Hariva mampatahotra', 'Rehefa milentika ny masoandro'],
        'Thriller': ['Mistery hariva', 'Hariva suspense'],
        'Romance': ['Romance alina', 'Hariva manokana'],
      },
      'night': {
        'Horror': ['Tahotra alina', 'Nofy ratsy'],
        'Thriller': ['Alina mistery', 'Tsy mahatery torimaso'],
        'Fantasy': ['Nofy mahagaga', 'Majika misasak\'alina'],
      },
    },
  };

  /// Mots-clés pour identifier les genres alternatifs
  static const Map<String, List<String>> _genreKeywords = {
    'romance': ['Romance', 'Romantic', 'Love', 'Amour'],
    'horror': ['Horror', 'Horreur', 'Terror', 'Terreur'],
    'thriller': ['Thriller', 'Suspense'],
    'fantasy': ['Fantasy', 'Fantaisie', 'Magic', 'Magie'],
    'scifi': ['Science Fiction', 'Sci-Fi', 'SF'],
    'drama': ['Drame', 'Drama'],
    'comedy': ['Comédie', 'Comedy'],
    'adventure': ['Aventure', 'Adventure'],
    'action': ['Action'],
    'mystery': ['Mystère', 'Mystery'],
    'historical': ['Historique', 'Historical', 'Histoire'],
  };

  /// Génère un titre intelligent pour une catégorie
  /// 
  /// Utilise un algorithme maison basé sur :
  /// - Le genre de l'histoire
  /// - La langue de l'application (fr/en)
  /// - L'heure de la journée (contexte temporel)
  /// - Une rotation aléatoire des templates pour éviter la répétition
  /// - L'historique de lecture (optionnel)
  String generateCategoryTitle(
    String originalGenre, {
    String language = 'fr',
    DateTime? currentTime,
    int? userReadCount,
    List<String>? userPreferences,
  }) {
    // Nettoyer et normaliser le genre
    final cleanGenre = originalGenre.trim();
    final lang = _genreTemplates.containsKey(language) ? language : 'fr';
    
    // Si le genre est vide ou inconnu, retourner un titre par défaut
    if (cleanGenre.isEmpty) {
      if (lang == 'mg') {
        return 'Mahita ny tantaranay';
      } else if (lang == 'fr') {
        return 'Découvrez nos histoires';
      } else {
        return 'Discover our stories';
      }
    }

    // 1. Essayer de trouver des templates directs
    if (_genreTemplates[lang]!.containsKey(cleanGenre)) {
      return _selectTemplate(cleanGenre, currentTime, lang);
    }

    // 2. Chercher dans les mots-clés pour trouver une correspondance
    final normalizedGenre = cleanGenre.toLowerCase();
    for (final entry in _genreKeywords.entries) {
      for (final keyword in entry.value) {
        if (normalizedGenre.contains(keyword.toLowerCase())) {
          // Utiliser le premier template disponible de cette catégorie
          if (_genreTemplates[lang]!.containsKey(keyword)) {
            return _selectTemplate(keyword, currentTime, lang);
          }
        }
      }
    }

    // 3. Générer un titre générique intelligent basé sur le contexte
    return _generateGenericTitle(cleanGenre, currentTime, userReadCount, lang);
  }

  /// Sélectionne un template en fonction du genre, du contexte temporel et de la langue
  String _selectTemplate(String genre, DateTime? currentTime, String language) {
    final now = currentTime ?? DateTime.now();
    final timeOfDay = _getTimeOfDay(now);

    // Essayer d'abord les templates temporels
    if (_timeBasedTemplates[language] != null &&
        _timeBasedTemplates[language]![timeOfDay] != null) {
      final timeTemplates = _timeBasedTemplates[language]![timeOfDay]!;
      if (timeTemplates.containsKey(genre) && timeTemplates[genre]!.isNotEmpty) {
        // 30% de chance d'utiliser un titre temporel
        if (_random.nextDouble() < 0.3) {
          final templates = timeTemplates[genre]!;
          return templates[_random.nextInt(templates.length)];
        }
      }
    }

    // Utiliser les templates standards
    final templates = _genreTemplates[language]![genre];
    if (templates != null && templates.isNotEmpty) {
      // Rotation basée sur le jour pour éviter trop de répétition
      final dayIndex = now.day % templates.length;
      
      // Ajouter un peu de randomisation (50% chance de prendre le dayIndex, 50% random)
      if (_random.nextDouble() < 0.5) {
        return templates[dayIndex];
      } else {
        return templates[_random.nextInt(templates.length)];
      }
    }

    return genre;
  }

  /// Détermine la période de la journée
  String _getTimeOfDay(DateTime time) {
    final hour = time.hour;
    
    if (hour >= 5 && hour < 12) {
      return 'morning';
    } else if (hour >= 12 && hour < 17) {
      return 'afternoon';
    } else if (hour >= 17 && hour < 22) {
      return 'evening';
    } else {
      return 'night';
    }
  }

  /// Génère un titre générique intelligent
  String _generateGenericTitle(
    String genre,
    DateTime? currentTime,
    int? userReadCount,
    String language,
  ) {
    // Templates génériques par défaut
    List<String> genericTemplates;
    
    if (language == 'mg') {
      genericTemplates = [
        'Mahita $genre',
        'Milentika ao amin\'ny $genre',
        'Tsidiho $genre',
        '$genre ho anao',
        'Safidy $genre',
        'Tontolo $genre',
        'Rakitra $genre',
      ];
    } else if (language == 'fr') {
      genericTemplates = [
        'Découvrez $genre',
        'Plongez dans $genre',
        'Explorez $genre',
        '$genre pour vous',
        'Sélection $genre',
        'L\'univers $genre',
        'Collection $genre',
      ];
    } else {
      genericTemplates = [
        'Discover $genre',
        'Dive into $genre',
        'Explore $genre',
        '$genre for you',
        '$genre selection',
        'The $genre universe',
        '$genre collection',
      ];
    }

    // Si l'utilisateur a beaucoup lu, personnaliser
    if (userReadCount != null && userReadCount > 10) {
      if (language == 'mg') {
        genericTemplates.addAll([
          'Bebe kokoa $genre ho anao',
          'Tohizo amin\'ny $genre',
          'Mbola betsaka $genre',
        ]);
      } else if (language == 'fr') {
        genericTemplates.addAll([
          'Plus de $genre pour vous',
          'Continuez avec $genre',
          'Encore plus de $genre',
        ]);
      } else {
        genericTemplates.addAll([
          'More $genre for you',
          'Continue with $genre',
          'Even more $genre',
        ]);
      }
    }

    return genericTemplates[_random.nextInt(genericTemplates.length)];
  }

  /// Génère un sous-titre optionnel pour enrichir la catégorie
  String? generateCategorySubtitle(
    String genre,
    int storyCount, {
    String language = 'fr',
    DateTime? currentTime,
  }) {
    if (storyCount == 0) return null;

    List<String> subtitles;
    
    if (language == 'mg') {
      subtitles = [
        '$storyCount tantara ho hitanao',
        'Safidy tantara $storyCount',
        '$storyCount tantara mahasarika',
      ];
    } else if (language == 'fr') {
      subtitles = [
        '$storyCount histoire${storyCount > 1 ? 's' : ''} à découvrir',
        'Sélection de $storyCount titre${storyCount > 1 ? 's' : ''}',
        '$storyCount histoire${storyCount > 1 ? 's' : ''} captivante${storyCount > 1 ? 's' : ''}',
      ];
    } else {
      subtitles = [
        '$storyCount stor${storyCount > 1 ? 'ies' : 'y'} to discover',
        'Selection of $storyCount title${storyCount > 1 ? 's' : ''}',
        '$storyCount captivating stor${storyCount > 1 ? 'ies' : 'y'}',
      ];
    }

    return subtitles[_random.nextInt(subtitles.length)];
  }

  /// Analyse les préférences utilisateur pour générer des recommandations
  /// (Pour usage futur avec historique de lecture)
  Map<String, double> analyzeUserPreferences(List<String> readGenres) {
    final preferences = <String, double>{};
    
    for (final genre in readGenres) {
      preferences[genre] = (preferences[genre] ?? 0) + 1;
    }

    // Normaliser les scores
    final total = preferences.values.fold(0.0, (a, b) => a + b);
    if (total > 0) {
      preferences.updateAll((key, value) => value / total);
    }

    return preferences;
  }

  /// Génère un titre "Pour vous" personnalisé basé sur l'historique
  String generatePersonalizedTitle(
    Map<String, double> preferences, {
    String language = 'fr',
  }) {
    if (preferences.isEmpty) {
      if (language == 'mg') {
        return 'Soso-kevitra ho anao';
      } else if (language == 'fr') {
        return 'Recommandé pour vous';
      } else {
        return 'Recommended for you';
      }
    }

    // Trouver le genre préféré
    final topGenre = preferences.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;

    List<String> personalizedTitles;
    
    if (language == 'mg') {
      personalizedTitles = [
        'Voafidy ho anao',
        'Ny tantaranao tiana',
        'Soso-kevitra ho anao',
        'Tohizo ny famakiana',
        'Satria tianao $topGenre',
        'Mifototra amin\'ny fitiavanao',
        'Natao ho anao',
      ];
    } else if (language == 'fr') {
      personalizedTitles = [
        'Sélectionné pour vous',
        'Vos histoires préférées',
        'Recommandé pour vous',
        'Continuer votre lecture',
        'Parce que vous aimez $topGenre',
        'Basé sur vos goûts',
        'Fait pour vous',
      ];
    } else {
      personalizedTitles = [
        'Selected for you',
        'Your favorite stories',
        'Recommended for you',
        'Continue reading',
        'Because you love $topGenre',
        'Based on your taste',
        'Made for you',
      ];
    }

    return personalizedTitles[_random.nextInt(personalizedTitles.length)];
  }
}
