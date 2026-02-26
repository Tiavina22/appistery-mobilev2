/// Utilitaires pour la gestion des locales dans l'application
/// 
/// Certains packages Flutter (comme intl pour DateFormat) ne supportent pas
/// toutes les locales personnalisées utilisées dans l'app. Ce fichier fournit
/// des fonctions pour mapper ces locales vers des locales supportées.

/// Obtient un code de locale valide pour DateFormat
/// 
/// Le package intl utilisé par DateFormat ne supporte pas toutes les locales.
/// Cette fonction mappe les codes de langue non supportés vers des alternatives valides.
/// 
/// Mappings actuels:
/// - 'mg' (Malgache) -> 'fr' (Français, langue commune à Madagascar)
/// - 'gasy' (Alias pour Malgache) -> 'fr'
/// 
/// Paramètres:
/// - [languageCode]: Le code de langue à valider (ex: 'mg', 'fr', 'en')
/// 
/// Retourne:
/// Un code de locale supporté par le package intl
String getValidDateFormatLocale(String languageCode) {
  switch (languageCode) {
    case 'mg': // Malgache
      return 'fr'; // Utiliser Français comme fallback
    case 'gasy': // Alias pour Malgache
      return 'fr';
    default:
      return languageCode;
  }
}

/// Obtient un nom de mois localisé
/// 
/// Utile pour afficher des dates dans des formats personnalisés
Map<String, List<String>> monthNames = {
  'fr': [
    'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
    'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'
  ],
  'en': [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ],
  'mg': [
    'Janoary', 'Febroary', 'Martsa', 'Aprily', 'Mey', 'Jona',
    'Jolay', 'Aogositra', 'Septambra', 'Oktobra', 'Novambra', 'Desambra'
  ],
};

/// Noms abrégés des mois
Map<String, List<String>> monthNamesShort = {
  'fr': [
    'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
    'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'
  ],
  'en': [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ],
  'mg': [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mey', 'Jon',
    'Jol', 'Aog', 'Sep', 'Okt', 'Nov', 'Des'
  ],
};

/// Noms des jours de la semaine
Map<String, List<String>> dayNames = {
  'fr': ['lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'],
  'en': ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'],
  'mg': ['Alatsinainy', 'Talata', 'Alarobia', 'Alakamisy', 'Zoma', 'Sabotsy', 'Alahady'],
};

/// Noms abrégés des jours
Map<String, List<String>> dayNamesShort = {
  'fr': ['lun', 'mar', 'mer', 'jeu', 'ven', 'sam', 'dim'],
  'en': ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
  'mg': ['Alats', 'Tal', 'Alar', 'Alak', 'Zom', 'Sab', 'Alah'],
};
