import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../services/auth_service.dart';
// author_service removed: no posts/followers in UI

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  Map<String, String> _countries = {};

  @override
  void initState() {
    super.initState();
    // Load extras after first frame to access providers safely
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadExtras());
  }

  Future<void> _loadExtras() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.user;

      // Load countries
      final authService = AuthService();
      final countriesRes = await authService.getCountries();
      if (countriesRes['success'] == true) {
        final List data = countriesRes['data'] as List? ?? [];
        setState(() {
          _countries = {
            for (var c in data) (c['id'].toString()): (c['name'] as String)
          };
        });
      }
      // No posts/followers loading (not used)
    } catch (e) {
      // ignore errors silently for now
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'profile'.tr(),
          style:
              Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ) ??
              const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
      ),
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          if (authProvider.user == null) {
            return Center(child: Text('error'.tr()));
          }

          final user = authProvider.user!;
          final email = user['email'] ?? 'N/A';
          final username = user['username'] ?? 'N/A';
          final pseudo = user['pseudo'] ?? username;
          final avatar = user['avatar'];
          final bool isDark = Theme.of(context).brightness == Brightness.dark;

          // Debug: Print avatar info
          print(
            'DEBUG: Avatar value: ${avatar?.substring(0, avatar.length > 50 ? 50 : avatar.length)}',
          );
          print('DEBUG: Avatar is null: ${avatar == null}');
          print('DEBUG: Avatar is empty: ${avatar?.isEmpty}');

            // Human-friendly values
            // Prefer an embedded country object if provided by the backend
            String countryName = '—';
            if (user['country'] != null && user['country'] is Map && user['country']['name'] != null) {
              countryName = user['country']['name'].toString();
            } else if (user['country_id'] != null) {
              countryName = _countries[user['country_id'].toString()] ?? '—';
            }
            final languageLabel = (user['language'] != null)
              ? (user['language'].toString().toUpperCase() == 'FR'
                ? 'Français'
                : (user['language'].toString().toUpperCase() == 'EN' ? 'English' : user['language'].toString()))
              : '—';
            final etatRaw = (user['etat'] ?? '').toString();
            final etatLabel = etatRaw.isEmpty
              ? '—'
              : (etatRaw.toLowerCase() == 'active' ? 'Actif' : (etatRaw.toLowerCase() == 'inactive' ? 'Inactif' : etatRaw));

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Instagram-like header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // Avatar
                          Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.grey.shade200,
                              image: avatar != null && avatar.isNotEmpty
                                  ? DecorationImage(
                                      image: MemoryImage(base64Decode(avatar)),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: avatar == null || avatar.isEmpty
                                ? Icon(Icons.person, size: 48, color: isDark ? Colors.white : Colors.black)
                                : null,
                          ),
                          const SizedBox(width: 16),
                          const Spacer(),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Header info: pseudo, bio and edit button
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  pseudo,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  user['bio'] ?? '',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              // TODO: navigate to edit profile
                            },
                            child: const Text('Editer'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Username Card
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white.withOpacity(0.08)
                                      : Colors.black.withOpacity(0.04),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.person_outline,
                                  color: isDark ? Colors.white : Colors.black,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'username'.tr(),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      username,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Full Profile Details
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'profile_details'.tr(),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _buildDetailRow('ID', user['id']?.toString() ?? '—', isDark),
                              _buildDetailRow('Téléphone', user['telephone'] ?? '—', isDark),
                              _buildDetailRow('Pays', countryName, isDark),
                              _buildDetailRow('Langue', languageLabel, isDark),
                              _buildDetailRow('Premium', (user['premium'] == true) ? 'Oui' : 'Non', isDark),
                              _buildDetailRow('État', etatLabel, isDark),
                              _buildDetailRow('CGU acceptées', (user['cgu_accepted'] == true) ? 'Oui' : 'Non', isDark),
                              _buildDetailRow('Date début', _formatDate(user['date_debut']), isDark),
                              _buildDetailRow('Date fin', _formatDate(user['date_fin']), isDark),
                              _buildDetailRow('Créé le', _formatDate(user['date_creation'] ?? user['created_at']), isDark),
                              _buildDetailRow('Mis à jour', _formatDate(user['updated_at']), isDark),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

Widget _buildDetailRow(String label, String value, bool isDark) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6.0),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
        ),
      ],
    ),
  );
}

String _formatDate(dynamic raw) {
  if (raw == null) return '—';
  try {
    final dt = DateTime.parse(raw.toString());
    return dt.toLocal().toString().split('.').first;
  } catch (e) {
    return raw.toString();
  }
}

// counts removed: no posts/followers/following in profile UI
