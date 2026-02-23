import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../providers/subscription_offer_provider.dart';
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
  bool _initialLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final authProvider = context.read<AuthProvider>();
    await authProvider.refreshLoginStatus();

    final offerProvider = context.read<SubscriptionOfferProvider>();

    // Load offers and active subscription in parallel
    final futures = <Future>[
      offerProvider.loadOffersByUserCountry(authProvider),
    ];
    if (authProvider.hasActiveSubscription) {
      futures.add(offerProvider.loadActiveSubscription());
    }
    await Future.wait(futures);

    if (mounted) setState(() => _initialLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authProvider = Provider.of<AuthProvider>(context);
    final offerProvider = Provider.of<SubscriptionOfferProvider>(context);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: Text(
          'my_subscription'.tr(),
          style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.4),
        ),
        backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: Consumer<SubscriptionOfferProvider>(
        builder: (context, provider, _) {
          // Active subscription → show details
          if (authProvider.hasActiveSubscription) {
            return _buildActiveSubscriptionView(
              context, authProvider, offerProvider, isDark,
            );
          }

          // No active sub → show offers list (with shimmer while loading)
          final displayOffers = authProvider.isMadagascarUser
              ? provider.madagascarOffers
              : provider.internationalOffers;
          final isLoading = _initialLoading || provider.isLoading;

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'choose_your_plan'.tr(),
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.6,
                      color: isDark ? Colors.white : const Color(0xFF1C1C1E),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    '${'plans_available_in'.tr()} ${authProvider.isMadagascarUser ? 'Madagascar' : 'International'}',
                    style: TextStyle(
                      fontSize: 15,
                      color: isDark ? const Color(0xFF98989D) : const Color(0xFF8E8E93),
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // Shimmer skeleton while loading
                if (isLoading)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: List.generate(3, (i) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _OfferShimmer(isDark: isDark),
                      )),
                    ),
                  )
                // Empty state
                else if (displayOffers.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.credit_card_off_rounded,
                            size: 56,
                            color: isDark ? const Color(0xFF48484A) : const Color(0xFFC7C7CC),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'no_offers_available'.tr(),
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF1C1C1E),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'try_again_later'.tr(),
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? const Color(0xFF98989D) : const Color(0xFF8E8E93),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                // Offers list – Apple Music cards
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: List.generate(displayOffers.length, (index) {
                        final offer = displayOffers[index];
                        final isPopular = index == (displayOffers.length ~/ 2);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: OfferCard(offer: offer, isPopular: isPopular),
                        );
                      }),
                    ),
                  ),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  // Widget pour afficher l'abonnement actif - Style Apple Music
  Widget _buildActiveSubscriptionView(
    BuildContext context,
    AuthProvider authProvider,
    SubscriptionOfferProvider offerProvider,
    bool isDark,
  ) {
    final subscription = offerProvider.activeSubscription;

    final expiresAt = subscription?['expires_at'] != null
        ? DateTime.tryParse(subscription!['expires_at'].toString())
        : null;
    final startedAt = subscription?['started_at'] != null
        ? DateTime.tryParse(subscription!['started_at'].toString())
        : null;

    final formattedDate = expiresAt != null
        ? '${expiresAt.day.toString().padLeft(2, '0')}/${expiresAt.month.toString().padLeft(2, '0')}/${expiresAt.year}'
        : 'N/A';
    final formattedStartDate = startedAt != null
        ? '${startedAt.day.toString().padLeft(2, '0')}/${startedAt.month.toString().padLeft(2, '0')}/${startedAt.year}'
        : 'N/A';
    final daysRemaining = expiresAt != null
        ? expiresAt.difference(DateTime.now()).inDays
        : 0;

    String offerName = 'Premium';
    if (subscription?['offer_name'] != null) {
      final nameData = subscription!['offer_name'];
      if (nameData is Map) {
        final languageCode = context.locale.languageCode;
        offerName = nameData[languageCode]?.toString() ??
            nameData['fr']?.toString() ??
            nameData.values.first?.toString() ??
            'Premium';
      } else if (nameData is String) {
        offerName = nameData;
      }
    }

    final offerDuration = subscription?['offer_duration'] ?? 1;
    final offerAmount = subscription?['amount'];
    final offerCurrency = subscription?['currency'] ?? 'MGA';

    // Avantages
    List<String> advantages = [];
    if (subscription?['offer_advantages'] != null) {
      final advantagesData = subscription!['offer_advantages'];
      if (advantagesData is List) {
        final languageCode = context.locale.languageCode;
        for (var item in advantagesData) {
          if (item is Map && item['lang'] == languageCode) {
            advantages = List<String>.from(item['advantages'] ?? []);
            break;
          }
        }
        if (advantages.isEmpty && advantagesData.isNotEmpty) {
          final firstItem = advantagesData[0];
          if (firstItem is Map && firstItem['advantages'] != null) {
            advantages = List<String>.from(firstItem['advantages']);
          }
        }
      }
    }
    if (advantages.isEmpty) {
      advantages = [
        'unlimited_access'.tr(),
        'offline_reading'.tr(),
        'no_ads'.tr(),
        'early_access'.tr(),
      ];
    }

    // Colors
    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final secondaryColor = isDark ? const Color(0xFF98989D) : const Color(0xFF8E8E93);
    final separatorColor = isDark ? const Color(0xFF38383A) : const Color(0xFFE5E5EA);
    final accentPink = isDark ? const Color(0xFFFF375F) : const Color(0xFFFF2D55);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            'your_subscription'.tr(),
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: titleColor,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 24),

          // ── Main card ──
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                  child: Row(
                    children: [
                      // Plan icon
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [accentPink, accentPink.withOpacity(0.7)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.workspace_premium_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              offerName,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: titleColor,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            if (offerAmount != null)
                              Text(
                                '$offerAmount $offerCurrency · $offerDuration ${'months'.tr()}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: secondaryColor,
                                  letterSpacing: -0.1,
                                ),
                              ),
                          ],
                        ),
                      ),
                      // Active badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF34C759).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'active'.tr(),
                          style: const TextStyle(
                            color: Color(0xFF34C759),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Separator
                Container(height: 0.5, color: separatorColor, margin: const EdgeInsets.symmetric(horizontal: 20)),

                // Details rows
                _buildAppleDetailRow('start_date'.tr(), formattedStartDate, titleColor, secondaryColor),
                Container(height: 0.5, color: separatorColor, margin: const EdgeInsets.symmetric(horizontal: 20)),
                _buildAppleDetailRow('expiration_date'.tr(), formattedDate, titleColor, secondaryColor),
                Container(height: 0.5, color: separatorColor, margin: const EdgeInsets.symmetric(horizontal: 20)),
                _buildAppleDetailRow(
                  'days_remaining'.tr(),
                  '$daysRemaining ${'days'.tr()}',
                  titleColor,
                  daysRemaining <= 7 ? Colors.orange : const Color(0xFF34C759),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Advantages card ──
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                  child: Text(
                    'included_benefits'.tr(),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: secondaryColor,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                ...advantages.asMap().entries.map((entry) {
                  final isLast = entry.key == advantages.length - 1;
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_rounded,
                              size: 18,
                              color: accentPink,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                entry.value,
                                style: TextStyle(
                                  fontSize: 15,
                                  color: titleColor,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!isLast)
                        Container(height: 0.5, color: separatorColor, margin: const EdgeInsets.only(left: 50, right: 20)),
                    ],
                  );
                }),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppleDetailRow(String label, String value, Color titleColor, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 15, color: titleColor, letterSpacing: -0.2),
          ),
          Text(
            value,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: valueColor, letterSpacing: -0.2),
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

class _OfferCardState extends State<OfferCard> {
  @override
  Widget build(BuildContext context) {
    final languageCode = context.locale.languageCode;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final offerName = widget.offer.getNameByLanguage(languageCode);
    final advantages = widget.offer.getAdvantagesByLanguage(languageCode);

    // Apple Music adaptive palette
    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final secondaryColor = isDark ? const Color(0xFF98989D) : const Color(0xFF8E8E93);
    final separatorColor = isDark ? const Color(0xFF38383A) : const Color(0xFFE5E5EA);
    final accentPink = isDark ? const Color(0xFFFF375F) : const Color(0xFFFF2D55);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: widget.isPopular
            ? Border.all(color: accentPink.withOpacity(0.4), width: 1.5)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Popular badge
                      if (widget.isPopular)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: accentPink,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'popular'.tr(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ),
                      Text(
                        offerName,
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          color: titleColor,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${widget.offer.duration} ${'months_access'.tr()}',
                        style: TextStyle(
                          fontSize: 14,
                          color: secondaryColor,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ],
                  ),
                ),
                // Price
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (widget.isPopular) const SizedBox(height: 20),
                    Text(
                      '${widget.offer.amount.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: titleColor,
                        letterSpacing: -0.8,
                      ),
                    ),
                    Text(
                      '${widget.offer.currency} / ${'per_month'.tr()}',
                      style: TextStyle(
                        fontSize: 13,
                        color: secondaryColor,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Advantages
          if (advantages.isNotEmpty) ...[
            Container(height: 0.5, color: separatorColor, margin: const EdgeInsets.symmetric(horizontal: 20)),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
              child: Column(
                children: advantages.map((advantage) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.check_rounded, size: 17, color: accentPink),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            advantage,
                            style: TextStyle(
                              fontSize: 14,
                              color: titleColor.withOpacity(0.85),
                              letterSpacing: -0.1,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],

          // CTA button
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.isPopular
                      ? accentPink
                      : (isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA)),
                  foregroundColor: widget.isPopular
                      ? Colors.white
                      : titleColor,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
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
                  'subscribe_now'.tr(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ),
          ),
        ],
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final sheetBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final secondaryColor = isDark ? const Color(0xFF98989D) : const Color(0xFF8E8E93);
    final separatorColor = isDark ? const Color(0xFF38383A) : const Color(0xFFE5E5EA);
    final accentPink = isDark ? const Color(0xFFFF375F) : const Color(0xFFFF2D55);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: sheetBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Container(
                  width: 36,
                  height: 5,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF48484A) : const Color(0xFFC7C7CC),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(height: 20),

                // Title
                Text(
                  'payment_mode'.tr(),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: titleColor,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 6),

                // Plan + price
                Text(
                  '$planName · $price',
                  style: TextStyle(
                    fontSize: 15,
                    color: secondaryColor,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 24),

                // Payment provider logos
                if (isMadagascar) ...[
                  // Mobile Money logos
                  Text(
                    'mobile_money'.tr(),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: secondaryColor,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _PaymentLogo(
                        svgAsset: 'assets/logo/logo Mvola.svg',
                        label: 'MVola',
                        isDark: isDark,
                      ),
                      const SizedBox(width: 20),
                      _PaymentLogo(
                        svgAsset: 'assets/logo/logo orange.svg',
                        label: 'Orange Money',
                        isDark: isDark,
                      ),
                      const SizedBox(width: 20),
                      _PaymentLogo(
                        svgAsset: 'assets/logo/logo airtel.svg',
                        label: 'Airtel Money',
                        isDark: isDark,
                      ),
                    ],
                  ),
                ] else ...[
                  // Bank card logos
                  Text(
                    'bank_card'.tr(),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: secondaryColor,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _PaymentLogo(
                        svgAsset: 'assets/logo/logo visa.svg',
                        label: 'Visa',
                        isDark: isDark,
                      ),
                      const SizedBox(width: 20),
                      _PaymentLogo(
                        svgAsset: 'assets/logo/logo master card.svg',
                        label: 'Mastercard',
                        isDark: isDark,
                      ),
                      const SizedBox(width: 20),
                      _PaymentLogo(
                        svgAsset: 'assets/logo/logo paypal.svg',
                        label: 'PayPal',
                        isDark: isDark,
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 28),

                // Separator
                Container(height: 0.5, color: separatorColor),
                const SizedBox(height: 20),

                // CTA – Proceed to payment
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _initiatePayment(
                        context,
                        offerId,
                        isMadagascar ? 'mobile_money' : 'international',
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentPink,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      'proceed_to_payment'.tr(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Cancel
                GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      'cancel'.tr(),
                      style: TextStyle(
                        color: isDark ? const Color(0xFF0A84FF) : const Color(0xFF007AFF),
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
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

// ── Payment provider logo widget ──
class _PaymentLogo extends StatelessWidget {
  final String svgAsset;
  final String label;
  final bool isDark;

  const _PaymentLogo({
    required this.svgAsset,
    required this.label,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7);
    final labelColor = isDark ? const Color(0xFF98989D) : const Color(0xFF8E8E93);

    return Column(
      children: [
        Container(
          width: 64,
          height: 44,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: SvgPicture.asset(
              svgAsset,
              width: 36,
              height: 36,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: labelColor,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.1,
          ),
        ),
      ],
    );
  }
}

// ── Shimmer skeleton for lazy loading ──
class _OfferShimmer extends StatefulWidget {
  final bool isDark;
  const _OfferShimmer({required this.isDark});

  @override
  State<_OfferShimmer> createState() => _OfferShimmerState();
}

class _OfferShimmerState extends State<_OfferShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cardBg = widget.isDark ? const Color(0xFF1C1C1E) : Colors.white;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final shimmerColor = widget.isDark
            ? Color.lerp(const Color(0xFF2C2C2E), const Color(0xFF3A3A3C), _controller.value)!
            : Color.lerp(const Color(0xFFE5E5EA), const Color(0xFFF2F2F7), _controller.value)!;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 120, height: 18,
                        decoration: BoxDecoration(color: shimmerColor, borderRadius: BorderRadius.circular(6)),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: 80, height: 14,
                        decoration: BoxDecoration(color: shimmerColor, borderRadius: BorderRadius.circular(6)),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        width: 60, height: 22,
                        decoration: BoxDecoration(color: shimmerColor, borderRadius: BorderRadius.circular(6)),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 50, height: 12,
                        decoration: BoxDecoration(color: shimmerColor, borderRadius: BorderRadius.circular(6)),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(height: 0.5, color: shimmerColor),
              const SizedBox(height: 14),
              ...List.generate(3, (_) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      width: 16, height: 16,
                      decoration: BoxDecoration(color: shimmerColor, borderRadius: BorderRadius.circular(4)),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 160, height: 14,
                      decoration: BoxDecoration(color: shimmerColor, borderRadius: BorderRadius.circular(6)),
                    ),
                  ],
                ),
              )),
              const SizedBox(height: 12),
              Container(
                width: double.infinity, height: 48,
                decoration: BoxDecoration(color: shimmerColor, borderRadius: BorderRadius.circular(14)),
              ),
            ],
          ),
        );
      },
    );
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
