# WebSocket - Communication Temps Réel

## 🚀 Implémentation

### Backend (Node.js + Socket.IO)
✅ Socket.IO configuré dans `src/app.js`
✅ Authentification JWT automatique
✅ Événements en temps réel configurés

### Mobile (Flutter + socket_io_client)
✅ Service WebSocket créé
✅ Provider WebSocket intégré
✅ Indicateur de connexion dans le home screen

## 📡 Événements disponibles

### Événements serveur → client

**Notifications**
- `notification:received` - Recevoir une notification
- `user:online` - Un utilisateur est en ligne
- `user:offline` - Un utilisateur s'est déconnecté

**Histoires**
- `story:new` - Nouvelle histoire publiée
- `story:updated` - Histoire mise à jour
- `chapter:new` - Nouveau chapitre publié

**Chat/Typing (préparé pour futur)**
- `user:typing` - Un utilisateur tape
- `user:stopped_typing` - Un utilisateur a arrêté de taper

### Événements client → serveur

**Test**
- `ping` - Envoyer un ping (retourne `pong`)

**Notifications**
- `send:notification` - Envoyer une notification à un utilisateur

**Typing**
- `typing:start` - Commencer à taper
- `typing:stop` - Arrêter de taper

**Broadcast**
- `story:published` - Broadcaster une nouvelle histoire
- `chapter:published` - Broadcaster un nouveau chapitre
- `profile:updated` - Notifier mise à jour profil

## 💡 Utilisation dans Flutter

### 1. Accéder au service WebSocket

```dart
import 'package:provider/provider.dart';
import '../providers/websocket_provider.dart';

// Dans un widget
final wsProvider = Provider.of<WebSocketProvider>(context, listen: false);
```

### 2. Écouter les événements

```dart
// Dans initState ou didChangeDependencies
@override
void initState() {
  super.init State();
  
  final wsProvider = Provider.of<WebSocketProvider>(context, listen: false);
  
  // Écouter les nouvelles histoires
  wsProvider.wsService.onNewStory((data) {
    print('Nouvelle histoire reçue: $data');
    // Recharger les histoires, afficher notification, etc.
  });
  
  // Écouter les notifications
  wsProvider.wsService.onNotification((data) {
    print('Notification reçue: $data');
    // Afficher une snackbar, popup, etc.
  });
}
```

### 3. Envoyer des événements

```dart
final wsProvider = Provider.of<WebSocketProvider>(context, listen: false);

// Envoyer un ping
wsProvider.wsService.sendPing();

// Envoyer une notification
wsProvider.wsService.sendNotificationToUser(
  123, // userId
  {
    'title': 'Nouveau message',
    'message': 'Vous avez reçu un message',
  },
);

// Broadcaster une histoire
wsProvider.wsService.broadcastStoryPublished({
  'id': 1,
  'title': 'Mon histoire',
  'author': 'Auteur',
});
```

### 4. Vérifier l'état de connexion

```dart
Consumer<WebSocketProvider>(
  builder: (context, wsProvider, _) {
    return Text(
      wsProvider.isConnected ? 'Connecté' : 'Déconnecté',
      style: TextStyle(
        color: wsProvider.isConnected ? Colors.green : Colors.red,
      ),
    );
  },
)
```

### 5. Gérer les notifications

```dart
Consumer<WebSocketProvider>(
  builder: (context, wsProvider, _) {
    return ListView.builder(
      itemCount: wsProvider.notifications.length,
      itemBuilder: (context, index) {
        final notif = wsProvider.notifications[index];
        return ListTile(
          title: Text(notif['title'] ?? ''),
          subtitle: Text(notif['message'] ?? ''),
          onTap: () {
            wsProvider.markNotificationAsRead(index);
          },
        );
      },
    );
  },
)
```

## 🔧 Utilisation côté Backend

### Dans un contrôleur

```javascript
const { broadcastNewStory } = require('../utils/socket');

exports.createStory = async (req, res) => {
  try {
    // Créer l'histoire
    const story = await Story.create(req.body);
    
    // Broadcaster en temps réel
    broadcastNewStory({
      id: story.id,
      title: story.title,
      author: story.author,
    });
    
    res.json({ success: true, story });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};
```

### Envoyer une notification à un utilisateur

```javascript
const { sendNotificationToUser } = require('../utils/socket');

sendNotificationToUser(userId, {
  title: 'Nouveau follower',
  message: 'Quelqu\'un vous suit maintenant',
  type: 'follower',
  data: { followerId: 123 }
});
```

## 🎯 Cas d'usage

1. **Notifications en temps réel** - Nouveaux likes, commentaires, followers
2. **Nouvelles histoires** - Alerter quand un auteur suivi publie
3. **Nouveaux chapitres** - Notifier les lecteurs
4. **Chat (futur)** - Messagerie instantanée
5. **Typing indicators** - Voir quand quelqu'un tape
6. **Présence** - Voir qui est en ligne
7. **Mises à jour live** - Synchronisation automatique des données

## 🔒 Sécurité

- ✅ Authentification JWT obligatoire
- ✅ Token vérifié à chaque connexion
- ✅ Rooms personnelles par utilisateur (`user:${userId}`)
- ✅ Broadcast contrôlé

## 📝 Notes

- Le WebSocket se connecte automatiquement au démarrage de l'app
- La reconnexion est automatique en cas de déconnexion
- Les notifications sont stockées en mémoire (max 50)
- Le service persiste durant toute la session

## 🚀 Pour démarrer

1. **Backend**: Le serveur WebSocket démarre automatiquement avec `npm run dev`
2. **Mobile**: Exécutez `flutter pub get` puis lancez l'app
3. L'indicateur "En ligne/Hors ligne" apparaît dans le topbar
4. Testez avec `wsProvider.wsService.sendPing()` !
