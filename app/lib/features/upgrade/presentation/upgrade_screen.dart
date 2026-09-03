import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/billing/billing_service.dart';
import '../../../core/theme/app_theme.dart';

class UpgradeScreen extends ConsumerWidget {
  const UpgradeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final billingState = ref.watch(billingServiceProvider);
    final billing = ref.read(billingServiceProvider.notifier);
    // Real store prices, so a Play Console price change or a region's local
    // currency is what the user actually reads on the paywall.
    final products = ref.watch(proProductsProvider).valueOrNull;
    // A pending purchase (UPI, bank transfer) can take hours to clear, so
    // both cards stay disabled and the screen says so instead of showing an
    // indefinite "Processing…" that reads like a freeze.
    final busy =
        billingState == BillingState.purchasing ||
        billingState == BillingState.pending;

    // `purchasing -> idle` only happens once a purchase completes
    // successfully (idle is also the initial pre-purchase state, but that
    // transition can only be reached by way of `purchasing`). Previously a
    // successful purchase gave no feedback at all — the screen just sat
    // there with both buttons back to "Subscribe" and no confirmation or
    // navigation away from the paywall.
    ref.listen<BillingState>(billingServiceProvider, (previous, next) {
      if ((previous == BillingState.purchasing ||
              previous == BillingState.pending) &&
          next == BillingState.idle) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("You're Pro! Welcome aboard.")),
        );
        if (context.canPop()) context.pop();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.primaryText),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Unlock Pro',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: AppColors.primaryText),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'UNLOCK PRO',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              fontFamily: AppFonts.fraunces,
              color: AppColors.accent,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Intelligence behind every bite.',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: AppColors.secondaryText),
          ),
          const SizedBox(height: 32),
          ..._features.map(
            (f) => _FeatureRow(icon: f.$1, title: f.$2, description: f.$3),
          ),
          const SizedBox(height: 32),
          _PlanCard(
            title: 'Annual',
            price: products?['remembite_pro_annual']?.price ?? '₹399',
            period: '/year',
            badge: 'Save 32%',
            recommended: true,
            // Keyed to the specific product being purchased — previously
            // this was `billingState == purchasing` on BOTH cards, so
            // tapping Monthly showed "Processing…" on the Annual card
            // instead of the one the user actually tapped.
            loading: billing.purchasingProductId == 'remembite_pro_annual',
            pending:
                billingState == BillingState.pending &&
                billing.purchasingProductId == 'remembite_pro_annual',
            onSubscribe: busy
                ? null
                : () => billing.purchase('remembite_pro_annual'),
          ),
          const SizedBox(height: 12),
          _PlanCard(
            title: 'Monthly',
            price: products?['remembite_pro_monthly']?.price ?? '₹49',
            period: '/month',
            recommended: false,
            loading: billing.purchasingProductId == 'remembite_pro_monthly',
            pending:
                billingState == BillingState.pending &&
                billing.purchasingProductId == 'remembite_pro_monthly',
            onSubscribe: busy
                ? null
                : () => billing.purchase('remembite_pro_monthly'),
          ),
          const SizedBox(height: 16),
          if (billingState == BillingState.pending)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Your payment is being confirmed. This can take a while — '
                'Pro unlocks automatically once it clears.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.secondaryText),
              ),
            ),
          if (billingState == BillingState.error)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Purchase failed. Please try again.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.error),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            'Subscriptions renew automatically. Cancel anytime in the Play Store.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.mutedText),
          ),
        ],
      ),
    );
  }

  static const _features = [
    (
      Icons.psychology_outlined,
      'AI Taste Compatibility',
      'Personalized dish predictions based on your reactions',
    ),
    (
      Icons.insights_outlined,
      'Advanced Taste Insights',
      'Deep analysis of your flavor preferences',
    ),
    (Icons.sync_outlined, 'Cloud Sync', 'Access your data across all devices'),
    (Icons.download_outlined, 'Data Export', 'Export your full dining history'),
  ];
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.surface, AppColors.proSurface],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.accent, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.primaryText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.secondaryText,
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

class _PlanCard extends StatelessWidget {
  final String title;
  final String price;
  final String period;
  final String? badge;
  final bool recommended;
  final bool loading;
  final bool pending;
  final VoidCallback? onSubscribe;

  const _PlanCard({
    required this.title,
    required this.price,
    required this.period,
    this.badge,
    required this.recommended,
    required this.loading,
    this.pending = false,
    this.onSubscribe,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: recommended
            ? const LinearGradient(
                colors: [AppColors.surface, AppColors.proSurface],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: recommended ? null : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: recommended ? AppColors.accent : AppColors.border,
          width: recommended ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: AppColors.primaryText),
              ),
              if (badge != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badge!,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.background,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              if (recommended) ...[
                const Spacer(),
                Text(
                  'RECOMMENDED',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.accent,
                    fontSize: 9,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                price,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppColors.primaryText,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  period,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.secondaryText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onSubscribe,
              style: ElevatedButton.styleFrom(
                backgroundColor: recommended
                    ? AppColors.accent
                    : AppColors.elevated,
                foregroundColor: recommended
                    ? AppColors.background
                    : AppColors.primaryText,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                pending
                    ? 'Payment pending…'
                    : (loading ? 'Processing…' : 'Subscribe'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
