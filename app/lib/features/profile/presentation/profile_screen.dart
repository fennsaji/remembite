import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/billing/pro_status_provider.dart';
import '../../../core/db/app_database.dart';
import '../../../core/network/auth_state.dart';
import '../../../core/theme/app_theme.dart';

part 'profile_screen.g.dart';

@riverpod
Future<ProfileStats> profileStats(Ref ref) async {
  final auth = ref.watch(authStateProvider).value;
  if (auth == null) return const ProfileStats();
  final db = ref.watch(appDatabaseProvider);
  final dao = db.reactionDao;
  final restaurants = await dao.getRestaurantCount(auth.id);
  final dishes = await dao.getDishCount(auth.id);
  final reactionCount = await dao.getTotalReactionCount(auth.id);
  final topReaction = await dao.getMostUsedReaction(auth.id);
  return ProfileStats(
    restaurantsVisited: restaurants,
    dishesTracked: dishes,
    reactionCount: reactionCount,
    mostUsedReaction: topReaction,
  );
}

class ProfileStats {
  final int restaurantsVisited;
  final int dishesTracked;
  final int reactionCount;
  final String? mostUsedReaction;

  const ProfileStats({
    this.restaurantsVisited = 0,
    this.dishesTracked = 0,
    this.reactionCount = 0,
    this.mostUsedReaction,
  });
}

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider).value;
    final isPro = ref.watch(proStatusProvider);
    final statsAsync = ref.watch(profileStatsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined,
                color: AppColors.secondaryText),
            onPressed: () => context.push('/settings'),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: AppColors.elevated,
                      child: auth?.avatarUrl != null
                          ? ClipOval(
                              child: CachedNetworkImage(
                                imageUrl: auth!.avatarUrl!,
                                width: 56,
                                height: 56,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => Text(
                                  auth.displayName[0].toUpperCase(),
                                  style: const TextStyle(
                                      color: AppColors.primaryText,
                                      fontSize: 20),
                                ),
                              ),
                            )
                          : Text(
                              (auth?.displayName ?? 'U')[0].toUpperCase(),
                              style: const TextStyle(
                                  color: AppColors.primaryText, fontSize: 20),
                            ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  auth?.displayName ?? '',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(color: AppColors.primaryText),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isPro) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.accent,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'PRO',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: AppColors.background,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 9,
                                        ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Text(
                            auth?.email ?? '',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: AppColors.mutedText),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: statsAsync.when(
                loading: () => const SizedBox(height: 80),
                error: (_, __) => const SizedBox.shrink(),
                data: (stats) => Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    children: [
                      _StatBox(value: '${stats.restaurantsVisited}', label: 'Restaurants'),
                      const SizedBox(width: 12),
                      _StatBox(value: '${stats.dishesTracked}', label: 'Dishes'),
                      const SizedBox(width: 12),
                      _StatBox(
                        value: _reactionEmoji(stats.mostUsedReaction),
                        label: 'Top Reaction',
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: statsAsync.maybeWhen(
                data: (stats) => _TasteProfileCard(
                  reactionCount: stats.reactionCount,
                  isPro: isPro,
                  onUpgrade: () => context.push('/upgrade'),
                ),
                orElse: SizedBox.shrink,
              ),
            ),
            if (isPro)
              SliverToBoxAdapter(
                child: const _ProInfoCard(),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                child: TextButton(
                  onPressed: () =>
                      ref.read(authStateProvider.notifier).signOut(),
                  child: const Text(
                    'Sign Out',
                    style: TextStyle(color: AppColors.error),
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
    );
  }

  static String _reactionEmoji(String? reaction) => switch (reaction) {
    'so_yummy'    => '🔥',
    'tasty'       => '😋',
    'pretty_good' => '🙂',
    'meh'         => '😐',
    'never_again' => '🤢',
    _             => '—',
  };
}

class _StatBox extends StatelessWidget {
  final String value;
  final String label;
  const _StatBox({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Text(value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.primaryText,
                      fontWeight: FontWeight.bold,
                    )),
            const SizedBox(height: 2),
            Text(label,
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: AppColors.mutedText)),
          ],
        ),
      ),
    );
  }
}

class _TasteProfileCard extends StatelessWidget {
  final int reactionCount;
  final bool isPro;
  final VoidCallback onUpgrade;
  const _TasteProfileCard(
      {required this.reactionCount, required this.isPro, required this.onUpgrade});

  @override
  Widget build(BuildContext context) {
    final progress = (reactionCount / 10).clamp(0.0, 1.0);
    final remaining = (10 - reactionCount).clamp(0, 10);
    final isComplete = reactionCount >= 10;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.surface, Color(0xFF2A2115)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 24, height: 2, color: AppColors.accent),
                const SizedBox(width: 8),
                Text(
                  'TASTE PROFILE',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.secondaryText,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: AppColors.border,
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isComplete
                  ? 'Taste profile complete!'
                  : 'React to $remaining more dishes to unlock predictions',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.secondaryText),
            ),
            if (!isPro && isComplete) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onUpgrade,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.background,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Unlock Predictions — Upgrade to Pro'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProInfoCard extends StatelessWidget {
  const _ProInfoCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.workspace_premium_outlined,
                color: AppColors.accent, size: 20),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Pro subscription active',
                style: TextStyle(color: AppColors.secondaryText, fontSize: 13),
              ),
            ),
            TextButton(
              onPressed: () async {
                final url = Uri.parse(
                    'https://play.google.com/store/account/subscriptions');
                if (await canLaunchUrl(url)) launchUrl(url);
              },
              child: const Text('Manage',
                  style: TextStyle(color: AppColors.accent)),
            ),
          ],
        ),
      ),
    );
  }
}
