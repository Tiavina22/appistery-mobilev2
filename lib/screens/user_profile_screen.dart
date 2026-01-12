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
            for (var c in data) (c['id'].toString()): (c['name'] as String),
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'profile'.tr(),
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
          final telephone = user['telephone'] ?? '—';

          // Human-friendly values
          String countryName = '—';
          if (user['country'] != null &&
              user['country'] is Map &&
              user['country']['name'] != null) {
            countryName = user['country']['name'].toString();
          } else if (user['country_id'] != null) {
            countryName = _countries[user['country_id'].toString()] ?? '—';
          }

          final isPremium = authProvider.isPremium;

          return SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 24),
                // Avatar
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isPremium ? Colors.amber : Colors.grey.shade300,
                      width: 3,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 70,
                    backgroundColor: Colors.grey.shade300,
                    backgroundImage: avatar != null && avatar.isNotEmpty
                        ? MemoryImage(base64Decode(avatar))
                        : null,
                    child: avatar == null || avatar.isEmpty
                        ? Icon(
                            Icons.person,
                            size: 60,
                            color: Colors.grey.shade600,
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 16),
                // Name
                Text(
                  pseudo,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                // Username
                Text(
                  '@$username',
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                ),
                if (isPremium) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Colors.amber, Colors.orange],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.star, color: Colors.white, size: 16),
                        SizedBox(width: 4),
                        Text(
                          'Premium',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                // Info sections
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Contact section
                      _buildSectionCard(
                        'Coordonnées',
                        Icons.contact_mail,
                        isDark,
                        [
                          _buildInfoTile(Icons.email, 'Email', email, isDark),
                          if (telephone != '—')
                            _buildInfoTile(
                              Icons.phone,
                              'Téléphone',
                              telephone,
                              isDark,
                            ),
                          if (countryName != '—')
                            _buildInfoTile(
                              Icons.location_on,
                              'Pays',
                              countryName,
                              isDark,
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
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

  Widget _buildSectionCard(
    String title,
    IconData icon,
    bool isDark,
    List<Widget> children,
  ) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(
    IconData icon,
    String label,
    String value,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
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
              icon,
              size: 20,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ],
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
