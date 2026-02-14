import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../providers/subscription_offer_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/auth_provider.dart';
import '../services/auth_service.dart';
import '../config/api_config.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Rafraîchir le profil utilisateur pour avoir les dernières données
      final authProvider = context.read<AuthProvider>();
      await authProvider.refreshLoginStatus();

      // Charger les offres basées sur le pays de l'utilisateur
      final offerProvider = context.read<SubscriptionOfferProvider>();
      offerProvider.loadOffersByUserCountry(authProvider);

      // Charger l'abonnement actif si l'utilisateur est premium
      if (authProvider.hasActiveSubscription) {
        await offerProvider.loadActiveSubscription();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final authProvider = Provider.of<AuthProvider>(context);
    final offerProvider = Provider.of<SubscriptionOfferProvider>(context);
    final userCountryName = authProvider.isMadagascarUser
        ? 'Madagascar'
        : 'International';

    return Scaffold(
      appBar: AppBar(title: const Text('Mon abonnement')),
      body: Consumer<SubscriptionOfferProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          // Si l'utilisateur a un abonnement actif, afficher ses détails
          if (authProvider.hasActiveSubscription) {
            return _buildActiveSubscriptionView(
              context,
              authProvider,
              offerProvider,
              isDarkMode,
            );
          }

          // Sinon, afficher les offres disponibles
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

  // Widget pour afficher l'abonnement actif
  Widget _buildActiveSubscriptionView(
    BuildContext context,
    AuthProvider authProvider,
    SubscriptionOfferProvider offerProvider,
    bool isDarkMode,
  ) {
    final expiresAt = authProvider.subscriptionExpiresAt;
    final formattedDate = expiresAt != null
        ? '${expiresAt.day.toString().padLeft(2, '0')}/${expiresAt.month.toString().padLeft(2, '0')}/${expiresAt.year}'
        : 'N/A';

    final daysRemaining = expiresAt != null
        ? expiresAt.difference(DateTime.now()).inDays
        : 0;

    // Récupérer les détails de l'offre active
    final subscription = offerProvider.activeSubscription;
    final offerName = subscription?['offer_name'] ?? 'Premium';
    final offerDuration = subscription?['offer_duration'] ?? 1;
    final offerAmount = subscription?['amount'];
    final offerCurrency = subscription?['currency'] ?? 'MGA';
    final startedAt = subscription?['started_at'] != null
        ? DateTime.tryParse(subscription!['started_at'].toString())
        : null;
    final formattedStartDate = startedAt != null
        ? '${startedAt.day.toString().padLeft(2, '0')}/${startedAt.month.toString().padLeft(2, '0')}/${startedAt.year}'
        : 'N/A';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Badge Premium avec nom de l'offre
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFD700).withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.workspace_premium,
                  size: 80,
                  color: Colors.white,
                ),
                const SizedBox(height: 16),
                Text(
                  '✨ $offerName ✨',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$offerDuration mois',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.95),
                  ),
                ),
                if (offerAmount != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '$offerAmount $offerCurrency',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Détails de l'abonnement
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey[850] : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildInfoRow(
                  context,
                  icon: Icons.play_arrow,
                  label: 'Début',
                  value: formattedStartDate,
                  isDarkMode: isDarkMode,
                ),
                const Divider(height: 24),
                _buildInfoRow(
                  context,
                  icon: Icons.calendar_today,
                  label: 'Expire le',
                  value: formattedDate,
                  isDarkMode: isDarkMode,
                ),
                const Divider(height: 24),
                _buildInfoRow(
                  context,
                  icon: Icons.timer,
                  label: 'Jours restants',
                  value: '$daysRemaining jours',
                  isDarkMode: isDarkMode,
                  valueColor: daysRemaining <= 7 ? Colors.orange : Colors.green,
                ),
                const Divider(height: 24),
                _buildInfoRow(
                  context,
                  icon: Icons.check_circle,
                  label: 'Statut',
                  value: 'Actif',
                  isDarkMode: isDarkMode,
                  valueColor: Colors.green,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Note d'annulation
          Text(
            'Pour changer d\'offre, attendez l\'expiration de votre abonnement actuel.',
            style: TextStyle(
              fontSize: 14,
              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required bool isDarkMode,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 24, color: const Color(0xFFFFD700)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 16,
              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: valueColor ?? (isDarkMode ? Colors.white : Colors.black87),
          ),
        ),
      ],
    );
  }

  Widget _buildBenefitItem(String text, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          const Icon(Icons.check_circle, size: 20, color: Color(0xFFFFD700)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 15,
                color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
              ),
            ),
          ),
        ],
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
                          _showPaymentModeDialog(
                            context,
                            widget.offer.id,
                            offerName,
                            '${widget.offer.amount} ${widget.offer.currency}',
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

  void _showPaymentModeDialog(
    BuildContext context,
    int offerId,
    String planName,
    String price,
  ) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isMadagascar = authProvider.isMadagascarUser;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('payment_mode'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${'plan'.tr()}: $planName'),
            Text('${'price'.tr()}: $price'),
            const SizedBox(height: 24),
            // Madagascar: show only Mobile Money
            if (isMadagascar)
              ListTile(
                leading: const Icon(Icons.phone_android, color: Colors.green),
                title: Text('mobile_money'.tr()),
                subtitle: Text('mobile_money_providers'.tr()),
                onTap: () {
                  Navigator.pop(context);
                  _initiatePayment(context, offerId, 'mobile_money');
                },
              ),
            // International: show only Bank Card
            if (!isMadagascar)
              ListTile(
                leading: const Icon(Icons.credit_card, color: Colors.blue),
                title: Text('bank_card'.tr()),
                subtitle: Text('card_types'.tr()),
                onTap: () {
                  Navigator.pop(context);
                  _initiatePayment(context, offerId, 'international');
                },
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('cancel'.tr()),
          ),
        ],
      ),
    );
  }

  Future<void> _initiatePayment(
    BuildContext context,
    int offerId,
    String paymentMode,
  ) async {
    // Save references before async operations
    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final authService = AuthService();
      final token = await authService.getToken();

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/subscriptions/upgrade'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'offer_id': offerId, 'payment_mode': paymentMode}),
      );

      navigator.pop(); // Close loading dialog

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['payment_url'] != null) {
          // Open payment URL in WebView
          navigator.push(
            MaterialPageRoute(
              builder: (context) => PaymentWebView(
                paymentUrl: data['payment_url'],
                transactionId: data['transaction_id'],
              ),
            ),
          );
        } else {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(data['error'] ?? 'payment_init_error'.tr()),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('${'server_error'.tr()}: ${response.statusCode}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      navigator.pop(); // Close loading dialog
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('${'error'.tr()}: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

// WebView for Vanilla Pay payment
class PaymentWebView extends StatefulWidget {
  final String paymentUrl;
  final int transactionId;

  const PaymentWebView({
    super.key,
    required this.paymentUrl,
    required this.transactionId,
  });

  @override
  State<PaymentWebView> createState() => _PaymentWebViewState();
}

class _PaymentWebViewState extends State<PaymentWebView> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            setState(() => _isLoading = true);

            // Check immediately when redirect URL is detected
            if (url.contains('/payment-callback') ||
                url.contains('/payment/success') ||
                url.contains('transaction=')) {
              Future.delayed(const Duration(seconds: 2), () {
                _checkPaymentStatus();
              });
            }
          },
          onPageFinished: (url) {
            setState(() => _isLoading = false);

            // Check if payment completed - detect redirect URL from backend
            if (url.contains('/payment-callback') ||
                url.contains('/payment/success') ||
                url.contains('transaction=')) {
              _checkPaymentStatus();
            }
          },
          onWebResourceError: (error) {
            // Even on error, check payment status (404 on redirect is ok)
            _checkPaymentStatus();
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.paymentUrl));
  }

  Future<void> _checkPaymentStatus() async {
    try {
      final authService = AuthService();
      final token = await authService.getToken();

      final response = await http.get(
        Uri.parse(
          '${ApiConfig.baseUrl}/api/payments/transaction/${widget.transactionId}',
        ),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final transaction = data['transaction'];

        if (transaction['etat'] == 'SUCCESS') {
          _showSuccessAndGoBack();
        } else if (transaction['etat'] == 'FAILED') {
          _showError('payment_failed'.tr());
        }
      }
    } catch (e) {
    }
  }

  void _showSuccessAndGoBack() async {
    // Rafraîchir le profil utilisateur pour mettre à jour isPremium
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.refreshLoginStatus();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('payment_success'.tr()),
        content: Text('premium_activated'.tr()),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close WebView
              Navigator.pop(context); // Close offers screen
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('error'.tr()),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('payment'.tr()),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _controller.reload(),
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
