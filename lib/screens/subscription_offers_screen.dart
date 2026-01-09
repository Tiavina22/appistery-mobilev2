import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../providers/subscription_offer_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/auth_provider.dart';

class SubscriptionOffersScreen extends StatefulWidget {
  const SubscriptionOffersScreen({Key? key}) : super(key: key);

  @override
  State<SubscriptionOffersScreen> createState() =>
      _SubscriptionOffersScreenState();
}

class _SubscriptionOffersScreenState extends State<SubscriptionOffersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Charger les offres basées sur le pays de l'utilisateur
      final authProvider = context.read<AuthProvider>();

      // Afficher le pays détecté
      print(
        '📍 Utilisateur détecté: ${authProvider.isMadagascarUser ? "Madagascar" : "International"}',
      );
      print('📍 Country data: ${authProvider.userCountry}');

      final offerProvider = context.read<SubscriptionOfferProvider>();
      offerProvider.loadOffersByUserCountry(authProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final authProvider = Provider.of<AuthProvider>(context);
    final userCountryName = authProvider.isMadagascarUser
        ? 'Madagascar'
        : 'International';

    return Scaffold(
      appBar: AppBar(title: const Text('Plans d\'abonnement')),
      body: Consumer<SubscriptionOfferProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          // Sélectionner les offres : par défaut du pays de l'utilisateur
          final displayOffers = authProvider.isMadagascarUser
              ? provider.madagascarOffers
              : provider.internationalOffers;

          return SingleChildScrollView(
            child: Column(
              children: [
                // Description/Header
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 24,
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Choisissez votre plan',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Plans disponibles en $userCountryName',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: isDarkMode
                              ? Colors.grey[400]
                              : Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                // Liste des offres
                if (displayOffers.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('💳', style: TextStyle(fontSize: 64)),
                        const SizedBox(height: 16),
                        const Text(
                          'Aucune offre disponible',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Réessayez plus tard',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: List.generate(displayOffers.length, (index) {
                        final offer = displayOffers[index];
                        // Le plan intermédiaire est mis en avant
                        final isPopular = index == (displayOffers.length ~/ 2);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: OfferCard(offer: offer, isPopular: isPopular),
                        );
                      }),
                    ),
                  ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }
}

class OfferCard extends StatefulWidget {
  final SubscriptionOffer offer;
  final bool isPopular;

  const OfferCard({Key? key, required this.offer, this.isPopular = false})
    : super(key: key);

  @override
  State<OfferCard> createState() => _OfferCardState();
}

class _OfferCardState extends State<OfferCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.02,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final languageCode = context.locale.languageCode;
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final offerName = widget.offer.getNameByLanguage(languageCode);
    final advantages = widget.offer.getAdvantagesByLanguage(languageCode);
    final primary = Theme.of(context).colorScheme.primary;

    return MouseRegion(
      onEnter: (_) => _controller.forward(),
      onExit: (_) => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: widget.isPopular
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      primary.withOpacity(0.15),
                      primary.withOpacity(0.05),
                    ],
                  )
                : null,
            color: !widget.isPopular
                ? (isDarkMode ? Colors.grey[900] : Colors.white)
                : null,
            border: Border.all(
              color: widget.isPopular
                  ? primary.withOpacity(0.3)
                  : (isDarkMode ? Colors.grey[700]! : Colors.grey[200]!),
              width: widget.isPopular ? 2 : 1,
            ),
            boxShadow: [
              if (widget.isPopular)
                BoxShadow(
                  color: primary.withOpacity(0.2),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                )
              else
                BoxShadow(
                  color: Colors.black.withOpacity(isDarkMode ? 0.2 : 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: Stack(
            children: [
              // Badge "Populaire"
              if (widget.isPopular)
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('⭐', style: TextStyle(fontSize: 12)),
                        const SizedBox(width: 6),
                        Text(
                          'Populaire',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              // Contenu
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Entête avec nom et prix
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          offerName,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '${widget.offer.amount.toStringAsFixed(0)}',
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: primary,
                                  ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${widget.offer.currency}',
                              style: Theme.of(
                                context,
                              ).textTheme.bodyMedium?.copyWith(color: primary),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '/ mois',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: isDarkMode
                                        ? Colors.grey[400]
                                        : Colors.grey[600],
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.offer.duration} mois d\'accès',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: isDarkMode
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                              ),
                        ),
                      ],
                    ),
                  ),
                  // Divider
                  Divider(
                    height: 1,
                    color: isDarkMode ? Colors.grey[700] : Colors.grey[200],
                  ),
                  // Avantages
                  if (advantages.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ...advantages.map((advantage) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        color: primary.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(50),
                                      ),
                                      child: Center(
                                        child: Text(
                                          '✓',
                                          style: TextStyle(
                                            color: primary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      advantage,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  // Bouton d'action
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.isPopular ? primary : null,
                          foregroundColor: widget.isPopular
                              ? Colors.white
                              : (isDarkMode ? Colors.white : Colors.black),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(50),
                            side: widget.isPopular
                                ? BorderSide.none
                                : BorderSide(
                                    color: isDarkMode
                                        ? Colors.grey[600]!
                                        : Colors.grey[300]!,
                                  ),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('S\'abonner à $offerName'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        child: Text(
                          'S\'abonner maintenant',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
