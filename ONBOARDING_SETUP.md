# Configuration de l'Onboarding APPISTERY

## ✅ Modifications effectuées

### 1. **Écran de sélection de langue** (language_selection_screen.dart)
- ✅ Thème Spotify (fond noir #000000)
- ✅ Logo APPISTERY remplace l'icône
- ✅ Cards avec fond #181818 et bordure verte #1DB954
- ✅ Navigation vers l'onboarding après sélection

### 2. **Écrans d'onboarding** (onboarding_screen.dart)
- ✅ 3 écrans avec PageView
- ✅ Icônes adaptées: book, headphones, auto_stories
- ✅ Couleur verte Spotify #1DB954 partout
- ✅ Fond noir avec texte blanc
- ✅ Indicateurs de page (dots) verts
- ✅ Boutons stylisés Spotify
- ✅ Navigation vers HomeScreen après "Commencer"

### 3. **Traductions** (fr.json & en.json)
- ✅ Français:
  - "Histoires Authentiques" - Découvrez des histoires vraies...
  - "Écoutez Partout" - Profitez de vos histoires en audio...
  - "Créez et Partagez" - Devenez auteur...

- ✅ Anglais:
  - "Authentic Stories" - Discover true stories...
  - "Listen Anywhere" - Enjoy your favorite stories...
  - "Create and Share" - Become an author...

### 4. **Configuration**
- ✅ pubspec.yaml mis à jour pour inclure assets/logo/
- ✅ Dossier assets/logo/ créé

## 📋 Prochaines étapes

### 1. **Copier le logo**
Copiez le fichier `logo-appistery-no.png` depuis le projet web vers :
```
appisterylunch/assets/logo/logo-appistery-no.png
```

### 2. **Tester l'application**
```bash
cd appisterylunch
flutter pub get
flutter run
```

### 3. **Réinitialiser l'onboarding pour tester**
Pour voir l'onboarding à nouveau (car il s'affiche uniquement au premier lancement):

Dans le terminal de debug Flutter:
```dart
// Exécuter ce code dans la console
SharedPreferences.getInstance().then((prefs) {
  prefs.remove('language_selected');
  prefs.remove('onboarding_completed');
});
```

Ou désinstaller/réinstaller l'app:
```bash
flutter clean
flutter run
```

## 🎨 Flux utilisateur

1. **Premier lancement** → Écran sélection langue (noir + logo)
2. **Sélection langue** → 3 écrans onboarding (slides verts)
3. **"Commencer"** → HomeScreen (login/register)
4. **Lancements suivants** → Directement vers HomeScreen

## 🎯 Thème Spotify appliqué

- **Fond principal**: `#000000` (noir pur)
- **Cards/Conteneurs**: `#181818` (gris très foncé)
- **Accent principal**: `#1DB954` (vert Spotify)
- **Texte principal**: `#FFFFFF` (blanc)
- **Texte secondaire**: `#B3B3B3` (gris)
- **Bordures**: `rgba(255,255,255,0.1)` (blanc 10%)

## 📱 Responsive

Tous les écrans sont responsive et s'adaptent aux différentes tailles d'écran Android.
