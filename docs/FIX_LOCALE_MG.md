# 🌍 Gestion des Locales - Fix "Invalid locale 'mg'"

## Problème résolu

### Symptôme
Lorsque la langue de l'application est définie sur **"Mg" (Malgache)**, cliquer sur une histoire affichait l'erreur :
```
invalid arguments(s): invalid locale "mg"
```

### Cause
Le package `intl` utilisé par `DateFormat` ne supporte pas toutes les locales personnalisées. La locale "mg" (Malgache) n'est pas reconnue par ce package, ce qui causait un crash lors du formatage de dates.

### Solution ✅

1. **Fichier utilitaire créé** : [`lib/utils/locale_utils.dart`](../lib/utils/locale_utils.dart)
   - Fonction `getValidDateFormatLocale()` qui mappe les locales non supportées vers des alternatives valides
   - Mapping : `mg` → `fr` (Français, langue commune à Madagascar)

2. **Story Detail Screen mis à jour** : [`lib/screens/story_detail_screen.dart`](../lib/screens/story_detail_screen.dart)
   - Import de `locale_utils.dart`
   - Utilisation de `getValidDateFormatLocale()` au lieu de `context.locale.languageCode` directement

## Code modifié

### Avant (❌ Causait l'erreur)
```dart
DateFormat(
  'dd MMM yyyy',
  context.locale.languageCode, // "mg" non supporté !
).format(widget.story.createdAt!)
```

### Après (✅ Fonctionne)
```dart
import '../utils/locale_utils.dart';

// ...

DateFormat(
  'dd MMM yyyy',
  getValidDateFormatLocale(context.locale.languageCode), // "mg" → "fr"
).format(widget.story.createdAt!)
```

## Bonnes pratiques

### ⚠️ À FAIRE lors de l'utilisation de DateFormat

Toujours utiliser `getValidDateFormatLocale()` au lieu de `context.locale.languageCode` :

```dart
// ❌ ÉVITER - Peut causer des erreurs avec des locales non supportées
DateFormat('dd/MM/yyyy', context.locale.languageCode)

// ✅ RECOMMANDÉ - Gère automatiquement les locales non supportées
import 'package:appistery/utils/locale_utils.dart';
DateFormat('dd/MM/yyyy', getValidDateFormatLocale(context.locale.languageCode))
```

### 📋 Locales supportées par intl

Le package `intl` supporte officiellement :
- ✅ `en` - English
- ✅ `fr` - Français
- ✅ `es` - Español
- ✅ `de` - Deutsch
- ✅ `it` - Italiano
- ✅ `pt` - Português
- ✅ `ru` - Русский
- ✅ `zh` - 中文
- ✅ `ja` - 日本語
- ✅ `ar` - العربية
- Et quelques autres...

❌ **Non supportées** (mappées par notre utilitaire) :
- `mg` - Malgache → mappé vers `fr`
- `gasy` - Alias pour Malgache → mappé vers `fr`

## Extension du mapping

Pour ajouter de nouvelles locales non supportées, modifiez [`lib/utils/locale_utils.dart`](../lib/utils/locale_utils.dart) :

```dart
String getValidDateFormatLocale(String languageCode) {
  switch (languageCode) {
    case 'mg':
    case 'gasy':
      return 'fr';
    
    // Ajouter de nouveaux mappings ici
    case 'mon_code_custom':
      return 'en'; // Fallback vers English par exemple
    
    default:
      return languageCode;
  }
}
```

## Ressources utiles

### Noms de mois et jours en Malgache

Le fichier `locale_utils.dart` fournit également des mappings pour :
- Noms de mois complets et abrégés
- Noms de jours complets et abrégés

Pour un formatage personnalisé en Malgache :

```dart
import 'package:appistery/utils/locale_utils.dart';

// Utiliser les noms de mois malgaches
final monthIndex = DateTime.now().month - 1;
final monthNameMg = monthNames['mg']![monthIndex]; // "Janoary", "Febroary", etc.

// Utiliser les noms de jours malgaches
final dayIndex = DateTime.now().weekday - 1;
final dayNameMg = dayNames['mg']![dayIndex]; // "Alatsinainy", "Talata", etc.
```

## Testing

Pour vérifier que le fix fonctionne :

1. Changer la langue de l'app en **Malgache (Mg)**
2. Naviguer vers une liste d'histoires
3. Cliquer sur une histoire pour voir les détails
4. Vérifier que la date s'affiche correctement (en français comme fallback)
5. ✅ Aucune erreur "invalid locale" ne devrait apparaître

## Impact

- ✅ **Story Detail Screen** : Affiche correctement les dates en Malgache
- ✅ **Performance** : Aucun impact (simple mapping de string)
- ✅ **UX** : Les dates sont affichées en français (compréhensible à Madagascar)
- ✅ **Maintenabilité** : Utilitaire centralisé et réutilisable

## Notes

- La locale "mg" continue de fonctionner normalement pour **toutes les autres fonctionnalités** (traductions `easy_localization`, textes de l'UI, etc.)
- Seul le `DateFormat` utilise le mapping vers "fr"
- Le texte de l'interface reste en Malgache, seuls les formats de date système utilisent le français

## Prochaines étapes (optionnel)

Pour un support complet du Malgache dans DateFormat, on pourrait :

1. **Formater manuellement** les dates sans utiliser DateFormat
2. **Créer des formats personnalisés** en utilisant les mappings de `locale_utils.dart`
3. **Contribuer au package intl** pour ajouter le support officiel du Malgache

Exemple de formatage personnalisé :
```dart
String formatDateMalagasy(DateTime date) {
  final day = date.day;
  final month = monthNames['mg']![date.month - 1];
  final year = date.year;
  return '$day $month $year'; // "26 Febroary 2026"
}
```
