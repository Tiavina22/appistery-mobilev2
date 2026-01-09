import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../services/cgu_service.dart';

class CguScreen extends StatefulWidget {
  const CguScreen({super.key});

  @override
  State<CguScreen> createState() => _CguScreenState();
}

class _CguScreenState extends State<CguScreen> {
  late Future<Map<String, dynamic>> _cguFuture;
  final CguService _cguService = CguService();

  @override
  void initState() {
    super.initState();
    _cguFuture = _cguService.getCgu();
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
          'Conditions d\'Utilisation',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _cguFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 60,
                    color: Colors.grey.shade500,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Erreur lors du chargement des CGU',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _cguFuture = _cguService.getCgu();
                      });
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Réessayer'),
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData) {
            return Center(child: Text('Aucune donnée disponible'));
          }

          final cgu = snapshot.data!;
          final content = cgu['content'] as String? ?? '';
          final lastUpdated = cgu['lastUpdated'] as String? ?? '';

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Dernière mise à jour
                  if (lastUpdated.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Text(
                        'Dernière mise à jour: $lastUpdated',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                      ),
                    ),

                  // Contenu des CGU
                  _buildCguContent(content, context),

                  const SizedBox(height: 24),

                  // Message d'acceptation
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'En utilisant Appistery, vous acceptez ces conditions.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCguContent(String content, BuildContext context) {
    // Parse le contenu Markdown basique
    final lines = content.split('\n');
    final widgets = <Widget>[];

    for (final line in lines) {
      if (line.startsWith('# ')) {
        // Titre principal
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
            child: Text(
              line.replaceFirst('# ', ''),
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
        );
      } else if (line.startsWith('## ')) {
        // Sous-titre
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 14.0, bottom: 6.0),
            child: Text(
              line.replaceFirst('## ', ''),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
        );
      } else if (line.startsWith('- ')) {
        // Bullet point
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(left: 8.0, bottom: 4.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• ', style: TextStyle(fontSize: 16)),
                Expanded(
                  child: Text(
                    line.replaceFirst('- ', ''),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        );
      } else if (line.startsWith('---')) {
        // Séparateur
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: Divider(color: Colors.grey.withOpacity(0.3)),
          ),
        );
      } else if (line.trim().isEmpty) {
        // Espace vide
        widgets.add(const SizedBox(height: 4));
      } else {
        // Texte normal
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(line, style: Theme.of(context).textTheme.bodyMedium),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }
}
