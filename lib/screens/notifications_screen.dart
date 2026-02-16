import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../providers/notification_provider.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    // Rafraîchir les notifications en arrière-plan (déjà chargées au démarrage)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<NotificationProvider>();
      if (provider.notifications.isEmpty) {
        provider.loadNotifications();
      }
    });
  }

  String _getNotificationIcon(String type) {
    switch (type) {
      case 'story_created':
        return '📖';
      case 'reaction_added':
        return '❤️';
      case 'comment_added':
        return '💬';
      case 'follow':
        return '👤';
      default:
        return '🔔';
    }
  }

  String _getNotificationTitle(String type) {
    switch (type) {
      case 'story_created':
        return 'Nouvelle histoire';
      case 'reaction_added':
        return 'Nouvelle réaction';
      case 'comment_added':
        return 'Nouveau commentaire';
      case 'follow':
        return 'Nouvel abonné';
      default:
        return 'Notification';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        elevation: 0,
        backgroundColor:
            theme.appBarTheme.backgroundColor ?? theme.scaffoldBackgroundColor,
        foregroundColor:
            theme.appBarTheme.foregroundColor ?? theme.colorScheme.onSurface,
        actions: [
          Consumer<NotificationProvider>(
            builder: (context, provider, _) {
              return provider.unreadCount > 0
                  ? TextButton(
                      onPressed: () {
                        provider.markAllAsRead();
                      },
                      child: const Text('Marquer tout comme lu'),
                    )
                  : const SizedBox();
            },
          ),
        ],
      ),
      body: Consumer<NotificationProvider>(
        builder: (context, provider, _) {
          if (provider.notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('🔔', style: TextStyle(fontSize: 64)),
                  const SizedBox(height: 16),
                  const Text(
                    'Aucune notification',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Vous n\'avez pas de notification pour l\'instant',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: provider.notifications.length,
            itemBuilder: (context, index) {
              final notification = provider.notifications[index];

              return NotificationTile(
                notification: notification,
                onMarkAsRead: () {
                  if (!notification.is_read) {
                    provider.markAsRead(notification.id);
                  }
                },
                onDelete: () {
                  provider.deleteNotification(notification.id);
                },
              );
            },
          );
        },
      ),
    );
  }
}

class NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onMarkAsRead;
  final VoidCallback onDelete;

  const NotificationTile({
    Key? key,
    required this.notification,
    required this.onMarkAsRead,
    required this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Dismissible(
      key: Key(notification.id.toString()),
      direction: DismissDirection.endToStart,
      onDismissed: (direction) {
        onDelete();
      },
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: Container(
        color: notification.is_read
            ? Colors.transparent
            : (isDarkMode 
                ? Colors.blue.withOpacity(0.1)
                : Colors.blue.withOpacity(0.05)),
        child: ListTile(
          leading: _buildAvatar(notification, isDarkMode),
          title: Text(
            notification.title,
            style: TextStyle(
              fontWeight: notification.is_read
                  ? FontWeight.normal
                  : FontWeight.bold,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                notification.message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                _getTimeAgo(notification.created_at),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          trailing: !notification.is_read
              ? Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(6),
                  ),
                )
              : null,
          onTap: () {
            onMarkAsRead();
            // Naviguer vers le détail si c'est lié à une histoire
            if (notification.related_story_id != null) {
              Navigator.of(
                context,
              ).pushNamed('/story', arguments: notification.related_story_id);
            }
          },
        ),
      ),
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'À l\'instant';
    } else if (difference.inMinutes < 60) {
      return 'Il y a ${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''}';
    } else if (difference.inHours < 24) {
      return 'Il y a ${difference.inHours} heure${difference.inHours > 1 ? 's' : ''}';
    } else if (difference.inDays < 7) {
      return 'Il y a ${difference.inDays} jour${difference.inDays > 1 ? 's' : ''}';
    } else {
      return 'Il y a ${(difference.inDays / 7).floor()} semaine${(difference.inDays / 7).floor() > 1 ? 's' : ''}';
    }
  }

  Widget _buildAvatar(AppNotification notification, bool isDarkMode) {
    // Si l'acteur a un avatar, l'afficher
    if (notification.actor != null && notification.actor!['avatar'] != null) {
      final avatar = notification.actor!['avatar'];
      
      // Vérifier si c'est une URL ou base64
      if (avatar.startsWith('/uploads/')) {
        final apiUrl = 'https://mistery.pro';
        return CircleAvatar(
          backgroundImage: NetworkImage('$apiUrl$avatar'),
          backgroundColor: isDarkMode 
              ? Colors.blue.withOpacity(0.3)
              : Colors.blue.withOpacity(0.2),
        );
      } else if (avatar.startsWith('data:image')) {
        try {
          final base64String = avatar.split(',')[1];
          final bytes = base64Decode(base64String);
          return CircleAvatar(
            backgroundImage: MemoryImage(bytes),
            backgroundColor: isDarkMode 
                ? Colors.blue.withOpacity(0.3)
                : Colors.blue.withOpacity(0.2),
          );
        } catch (e) {
          // Fallback to emoji
        }
      }
    }
    
    // Sinon, afficher l'emoji par défaut
    return CircleAvatar(
      backgroundColor: isDarkMode 
          ? Colors.blue.withOpacity(0.3)
          : Colors.blue.withOpacity(0.2),
      child: Text(
        notification.type == 'story_created'
            ? '📖'
            : notification.type == 'reaction_added'
            ? '❤️'
            : notification.type == 'comment_added'
            ? '💬'
            : '👤',
        style: const TextStyle(fontSize: 20),
      ),
    );
  }
}
