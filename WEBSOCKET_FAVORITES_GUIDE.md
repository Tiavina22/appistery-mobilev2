# Guide WebSocket pour les Favoris

## Implémentation Client (Flutter) ✅ FAIT

L'application Flutter a été mise à jour pour écouter les changements de favoris en temps réel via WebSocket.

### Événements écoutés:

1. **`favorite:added`** - Quand un utilisateur ajoute une histoire à ses favoris
   ```json
   {
     "story_id": 123,
     "title": "Nom de l'histoire",
     "description": "Description...",
     "author_id": 456,
     "author_name": "Nom de l'auteur",
     "genre": "Genre",
     "cover_image": "url_image"
   }
   ```

2. **`favorite:removed`** - Quand un utilisateur supprime une histoire de ses favoris
   ```json
   {
     "story_id": 123
   }
   ```

3. **`favorites:updated`** - Mise à jour globale de la liste des favoris (après un sync forcé)
   ```json
   {
     "user_id": 789,
     "timestamp": "2026-01-09T10:30:00Z"
   }
   ```

## Implémentation Backend (Node.js) 🔧 À FAIRE

### 1. Dans le contrôleur des favoris (`favoriteController.js`)

Émettez les événements WebSocket après les opérations sur les favoris:

```javascript
// Ajouter un favori
const addFavorite = async (req, res) => {
  try {
    // ... votre logique existante ...
    const favorite = await addFavoriteLogic(req.userId, req.body.storyId);

    // Émettre l'événement WebSocket
    const io = req.app.get('io');
    io.emit('favorite:added', {
      story_id: req.body.storyId,
      user_id: req.userId,
      title: favorite.story.title,
      description: favorite.story.description,
      author_id: favorite.story.author_id,
      author_name: favorite.story.author.pseudo,
      genre: favorite.story.genre,
      cover_image: favorite.story.cover_image
    });

    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

// Supprimer un favori
const removeFavorite = async (req, res) => {
  try {
    // ... votre logique existante ...
    await removeFavoriteLogic(req.userId, req.body.storyId);

    // Émettre l'événement WebSocket
    const io = req.app.get('io');
    io.emit('favorite:removed', {
      story_id: req.body.storyId,
      user_id: req.userId
    });

    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};
```

### 2. Optionnel: Ajouter une route pour forcer la synchronisation

```javascript
// GET /api/favorites/sync
const syncFavorites = async (req, res) => {
  try {
    const favorites = await getFavoritesLogic(req.userId);

    // Émettre l'événement de mise à jour globale
    const io = req.app.get('io');
    io.emit('favorites:updated', {
      user_id: req.userId,
      timestamp: new Date().toISOString()
    });

    res.json({ success: true, count: favorites.length });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};
```

## Comportement Attendu

### Scénario 1: Ajouter un favori
1. L'utilisateur A clique sur "Ajouter aux favoris" sur une histoire
2. L'API reçoit la requête et crée le lien en base de données
3. **L'événement `favorite:added` est émis via WebSocket**
4. L'écran des favoris de l'utilisateur A se met à jour automatiquement en temps réel
5. ✅ Pas besoin de recharger l'écran

### Scénario 2: Supprimer un favori
1. L'utilisateur A clique sur "Supprimer des favoris"
2. L'API reçoit la requête et supprime le lien en base de données
3. **L'événement `favorite:removed` est émis via WebSocket**
4. L'écran des favoris se met à jour automatiquement
5. ✅ La story disparaît de la liste en temps réel

## Logs à Vérifier

Ouvrez la console Flutter DevTools pour vérifier que les événements sont reçus:

```
✅ WebSocket: Connected to server
📝 WebSocket: Enregistrement callback favorite:added
📝 WebSocket: Enregistrement callback favorite:removed
📝 WebSocket: Enregistrement callback favorites:updated

# Quand un favori est ajouté:
🔥🔥🔥 WebSocket: EVENT favorite:added reçu!
❤️ StoryProvider: Favori ajouté via WebSocket
✅ Favori ajouté à la liste
```

## Résumé des Modifications

### Fichier: `websocket_service.dart`
- ✅ Ajout de 3 listes de callbacks pour les favoris
- ✅ Ajout de 3 listeners WebSocket (`favorite:added`, `favorite:removed`, `favorites:updated`)
- ✅ Ajout de 3 méthodes d'enregistrement

### Fichier: `story_provider.dart`
- ✅ Implémentation de listeners pour mettre à jour la liste des favoris en temps réel
- ✅ Gestion des cas où la story n'existe pas encore en local

## Tests Recommandés

1. **Test avec deux appareils/fenêtres**:
   - Ouvrir l'app sur deux appareils avec le même compte
   - Ajouter un favori sur le premier appareil
   - Vérifier que le deuxième appareil reçoit la mise à jour automatiquement

2. **Test du statut de connexion**:
   - Vérifier que le statut "En ligne/Hors ligne" s'affiche correctement
   - Simuler une perte de connexion
   - Vérifier la reconnexion automatique

3. **Test de performance**:
   - Ajouter/supprimer rapidement plusieurs favoris
   - Vérifier qu'il n'y a pas de lag ou de crash

## Questions/Problèmes?

Si les événements n'arrivent pas:
1. Vérifier que WebSocket est bien connecté (indicateur "En ligne" dans le header)
2. Vérifier les logs côté backend pour voir si `io.emit()` est appelé
3. Vérifier que l'événement est envoyé avec les bonnes données JSON
