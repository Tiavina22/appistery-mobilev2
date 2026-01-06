# Version Management System - Documentation

## Overview
Ce système permet de gérer les versions d'application avec des mises à jour obligatoires ou facultatives, avec une date d'expiration.

---

## 🔧 Backend Configuration

### 1. Table Version
Créée via migration: `20260106000001-create-appistery-version.js`

**Colonnes:**
- `version_name` (VARCHAR): Nom de la version (ex: "1.0.0", "1.0.1")
- `version_code` (INT): Code numérique unique pour comparaison (ex: 1, 2, 3)
- `description` (TEXT): Changelog/description des changements
- `start_date` (DATE): Date d'activation de la version
- `end_date` (DATE): Date d'expiration (force update)
- `download_url` (VARCHAR): Lien de téléchargement
- `is_active` (BOOLEAN): Version active ou non
- `is_required` (BOOLEAN): Mise à jour obligatoire
- `platform` (ENUM): 'ios', 'android', ou 'both'

### 2. API Endpoints

#### Vérifier la version (Public)
```
POST /api/version/check
Body:
{
  "versionCode": 1,
  "platform": "android"
}

Response:
{
  "success": true,
  "data": {
    "currentVersion": 2,
    "versionName": "1.0.1",
    "downloadUrl": "https://...",
    "isUpdateRequired": false,
    "isVersionExpired": false,
    "updateAvailable": true,
    "userVersionCode": 1
  }
}
```

#### Admin Endpoints
- `GET /api/version` - Lister toutes les versions
- `GET /api/version/:id` - Détails d'une version
- `POST /api/version` - Créer une version
- `PUT /api/version/:id` - Modifier une version
- `DELETE /api/version/:id` - Supprimer une version

---

## 📱 Mobile Configuration

### 1. Variables d'Environnement (.env)
```env
# Version Configuration
APP_VERSION_CODE=1
APP_VERSION_NAME=1.0.0

# Backend API
API_URL=http://192.168.1.206:5500

# Platform
APP_PLATFORM=android
```

### 2. Classes Principales

#### VersionService
- `checkVersion()` - Vérifie la version auprès du backend
- `getAppVersionCode()` - Récupère le code de version depuis .env
- `getAppVersionName()` - Récupère le nom de version depuis .env
- `getAppPlatform()` - Récupère la plateforme depuis .env

#### VersionProvider (State Management)
Gère l'état de la vérification de version:
- `isUpdateRequired` - Si une mise à jour est requise
- `isVersionExpired` - Si la version a expiré
- `downloadUrl` - URL de téléchargement
- `checkVersionAtStartup()` - Lance la vérification au démarrage

#### ForceUpdateDialog
Widget pour afficher le dialog de mise à jour forcée avec:
- Titre et description
- Bouton de téléchargement
- Option pour ignorer (selon si version expirée ou non)

### 3. Flux d'Exécution

```
main.dart
  ↓
_getInitialScreen()
  ↓
VersionProvider.checkVersionAtStartup()
  ↓
appelle: /api/version/check
  ↓
compare versionCode local vs backend
  ↓
Si update requise:
  → HomeWithVersionCheck() affiche le dialog
Sinon:
  → HomeScreen() normal
```

---

## 📋 Exemple d'Utilisation

### Créer une nouvelle version dans l'admin
```javascript
POST /api/version
{
  "version_name": "1.0.1",
  "version_code": 2,
  "description": "Bug fixes et améliorations de performance",
  "start_date": "2024-01-06T00:00:00Z",
  "end_date": "2024-02-06T00:00:00Z",  // Optionnel
  "download_url": "https://play.google.com/store/apps/details?id=...",
  "platform": "android",
  "is_required": true,
  "is_active": true
}
```

### Mise à jour de l'app mobile
1. Mettre à jour `APP_VERSION_CODE` et `APP_VERSION_NAME` dans `.env`
2. L'app au démarrage appelle `/api/version/check`
3. Si le code de version est inférieur au server:
   - S'il y a `end_date` passée → affiche dialog non-dismissible
   - S'il y a `is_required=true` → affiche dialog
   - Sinon → affiche juste notification

---

## 🎯 Comportements

### Update disponible (code < server)
- Dialog s'affiche avec description
- Bouton "Télécharger" ouvre le lien

### Version expirée (end_date < aujourd'hui)
- Dialog NON-dismissible
- Empêche l'accès à l'app
- Utilisateur DOIT télécharger

### Update non-requis
- App continue normalement
- Aucun dialog

---

## 🔐 Security Notes
- Endpoint `/api/version/check` est public (pas d'authentification requise)
- Admin endpoints nécessitent authentification admin
- Version code est entier croissant pour éviter les contrefaçons

---

## 📲 Test

Utiliser Postman ou curl:
```bash
curl -X POST http://localhost:3000/api/version/check \
  -H "Content-Type: application/json" \
  -d '{"versionCode": 1, "platform": "android"}'
```
