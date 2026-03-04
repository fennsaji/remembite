import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/db/app_database.dart';
import '../../../core/db/daos/reaction_dao.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../../../core/network/auth_state.dart';
import '../../../core/theme/app_theme.dart';
import '../data/pending_edit_count_provider.dart';
import '../data/restaurant_repository.dart';
import '../../dish/data/dish_repository.dart';
import 'session_state.dart';

part 'restaurant_screen.g.dart';

@riverpod
Future<RestaurantDetail> restaurantDetail(Ref ref, String id) =>
    ref.watch(restaurantRepositoryProvider).getRestaurantDetail(id);

@riverpod
Future<List<DishItem>> restaurantDishes(Ref ref, String restaurantId) =>
    ref.watch(dishRepositoryProvider).getDishesByRestaurant(restaurantId);

@riverpod
Future<List<TopBiteRow>> yourTopBites(Ref ref, String restaurantId) async {
  final auth = ref.watch(authStateProvider).value;
  if (auth == null) return [];
  return ref
      .watch(appDatabaseProvider)
      .reactionDao
      .getTopBitesForRestaurant(auth.id, restaurantId);
}

@riverpod
Future<ReactionSummary> dishReactionSummary(Ref ref, String dishId) =>
    ref.watch(dishRepositoryProvider).getReactionSummary(dishId);

class RestaurantScreen extends ConsumerStatefulWidget {
  final String restaurantId;
  const RestaurantScreen({super.key, required this.restaurantId});

  @override
  ConsumerState<RestaurantScreen> createState() => _RestaurantScreenState();
}

class _RestaurantScreenState extends ConsumerState<RestaurantScreen> {
  bool _menuExpanded = false;

  String _reactionEmoji(String reaction) => switch (reaction) {
        'so_yummy' => '🔥',
        'tasty' => '😋',
        'pretty_good' => '🙂',
        'meh' => '😐',
        'never_again' => '🤢',
        _ => '❓',
      };

  void _showRatingSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.elevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) =>
          _RatingBottomSheet(restaurantId: widget.restaurantId),
    );
  }

  void _showSuggestEditSheet(BuildContext context, String restaurantName) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.elevated,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SuggestEditBottomSheet(
        restaurantId: widget.restaurantId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final restaurantAsync =
        ref.watch(restaurantDetailProvider(widget.restaurantId));
    final dishesAsync =
        ref.watch(restaurantDishesProvider(widget.restaurantId));

    ref.listen<RestaurantSessionRecord>(
      restaurantSessionStateProvider(widget.restaurantId),
      (prev, next) {
        if (next.reactionCount >= 2 && !next.ratingShown) {
          ref
              .read(restaurantSessionStateProvider(widget.restaurantId).notifier)
              .markRatingShown();
          Future.delayed(const Duration(milliseconds: 400), () {
            if (context.mounted) _showRatingSheet(context);
          });
        }
      },
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: restaurantAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
        error: (e, _) => Center(
          child: Text(apiErrorMessage(e),
              style: const TextStyle(color: AppColors.secondaryText)),
        ),
        data: (restaurant) => CustomScrollView(
          slivers: [
            // Header
            SliverAppBar(
              expandedHeight: 120,
              floating: false,
              pinned: true,
              backgroundColor: AppColors.background,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back,
                    color: AppColors.primaryText),
                onPressed: () => context.pop(),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined,
                      color: AppColors.mutedText),
                  onPressed: () =>
                      _showSuggestEditSheet(context, restaurant.name),
                  tooltip: 'Suggest Edit',
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                titlePadding:
                    const EdgeInsets.fromLTRB(56, 0, 56, 16),
                title: Text(
                  restaurant.name,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(
                        color: AppColors.primaryText,
                        fontWeight: FontWeight.w700,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),

            // Rating row
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Row(
                  children: [
                    if (restaurant.avgRating != null) ...[
                      const Icon(Icons.star_rounded,
                          color: AppColors.accent, size: 18),
                      const SizedBox(width: 4),
                      Text(
                        restaurant.avgRating!.toStringAsFixed(1),
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(
                              color: AppColors.primaryText,
                            ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '(${restaurant.ratingCount})',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                              color: AppColors.mutedText,
                            ),
                      ),
                      const SizedBox(width: 16),
                    ],
                    if (restaurant.cuisineType != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.elevated,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          restaurant.cuisineType!,
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(
                                color: AppColors.secondaryText,
                              ),
                        ),
                      ),
                    const Spacer(),
                    OutlinedButton.icon(
                      onPressed: () => _showRatingSheet(context),
                      icon: const Icon(Icons.star_outline, size: 16),
                      label: const Text('Rate'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.accent,
                        side: const BorderSide(color: AppColors.accent),
                        minimumSize: Size.zero,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Community updates pending indicator
            SliverToBoxAdapter(
              child: ref
                  .watch(pendingEditCountProvider(widget.restaurantId))
                  .when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (count) {
                  if (count == 0) return const SizedBox.shrink();
                  return GestureDetector(
                    onTap: () => context.push(
                        '/restaurant/${widget.restaurantId}/edits'),
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.accentMuted,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.accent),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.people_outline,
                              color: AppColors.accent, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            '$count community update${count == 1 ? '' : 's'} pending',
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(
                                  color: AppColors.accent,
                                  fontFamily: 'DM Sans',
                                ),
                          ),
                          const Spacer(),
                          const Icon(Icons.chevron_right,
                              color: AppColors.accent, size: 16),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // YOUR TOP BITES
            const SliverToBoxAdapter(
                child: _SectionHeader(label: 'YOUR TOP BITES')),
            SliverToBoxAdapter(
              child: ref
                  .watch(yourTopBitesProvider(widget.restaurantId))
                  .when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (bites) {
                  if (bites.isEmpty) {
                    return Padding(
                      padding:
                          const EdgeInsets.fromLTRB(20, 4, 20, 12),
                      child: Row(
                        children: [
                          const Icon(Icons.restaurant_menu_outlined,
                              color: AppColors.accent, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'React to dishes to see your top bites here.',
                              style: const TextStyle(
                                  color: AppColors.secondaryText,
                                  fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return SizedBox(
                    height: 80,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 4),
                      separatorBuilder: (_, __) =>
                          const SizedBox(width: 10),
                      itemCount: bites.length,
                      itemBuilder: (context, i) {
                        final b = bites[i];
                        return GestureDetector(
                          onTap: () =>
                              context.push('/dish/${b.dishId}'),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            constraints: const BoxConstraints(
                                minWidth: 100, maxWidth: 140),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border:
                                  Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: [
                                Text(
                                  _reactionEmoji(b.reaction),
                                  style: const TextStyle(fontSize: 18),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  b.dishName,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelMedium
                                      ?.copyWith(
                                          color: AppColors.primaryText),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),

            // Community Favorites
            const SliverToBoxAdapter(
                child: _SectionHeader(label: 'COMMUNITY FAVORITES')),
            dishesAsync.when(
              loading: () => const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child:
                      CircularProgressIndicator(color: AppColors.accent),
                ),
              ),
              error: (_, __) => const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('Could not load dishes.',
                      style: TextStyle(color: AppColors.mutedText)),
                ),
              ),
              data: (dishes) {
                final favorites =
                    (dishes.where((d) => d.voteCount >= 5).toList()
                      ..sort((a, b) => (b.communityScore ?? 0)
                          .compareTo(a.communityScore ?? 0)));
                final newDishes =
                    dishes.where((d) => d.voteCount < 5).toList();

                if (favorites.isEmpty && newDishes.isEmpty) {
                  return const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      child: Text('No dishes yet.',
                          style:
                              TextStyle(color: AppColors.mutedText)),
                    ),
                  );
                }
                return SliverList.builder(
                  itemCount: favorites.length + newDishes.length,
                  itemBuilder: (context, i) {
                    if (i < favorites.length) {
                      return _DishTile(dish: favorites[i]);
                    }
                    return _DishTile(
                        dish: newDishes[i - favorites.length],
                        badge: 'NEW');
                  },
                );
              },
            ),

            // Full Menu
            const SliverToBoxAdapter(
                child: _SectionHeader(label: 'FULL MENU')),
            dishesAsync.when(
              loading: () =>
                  const SliverToBoxAdapter(child: SizedBox()),
              error: (_, __) =>
                  const SliverToBoxAdapter(child: SizedBox()),
              data: (dishes) {
                final visible = _menuExpanded
                    ? dishes
                    : dishes.take(5).toList();
                return SliverList.builder(
                  itemCount:
                      visible.length + (dishes.length > 5 ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (i == visible.length) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 4),
                        child: TextButton(
                          onPressed: () => setState(
                              () => _menuExpanded = !_menuExpanded),
                          child: Text(
                            _menuExpanded
                                ? 'Show Less'
                                : 'View All (${dishes.length})',
                            style: const TextStyle(
                                color: AppColors.accent),
                          ),
                        ),
                      );
                    }
                    return _DishTile(dish: visible[i]);
                  },
                );
              },
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            context.push('/restaurant/${widget.restaurantId}/scan'),
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.background,
        icon: const Icon(Icons.document_scanner_outlined),
        label: const Text('Scan Menu'),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
      child: Row(
        children: [
          Container(width: 24, height: 2, color: AppColors.accent),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.secondaryText,
                  letterSpacing: 0.8,
                ),
          ),
        ],
      ),
    );
  }
}

// Maps reaction type key to its display emoji
const _reactionEmojis = {
  'so_yummy': '🔥',
  'tasty': '😋',
  'pretty_good': '🙂',
  'meh': '😐',
  'never_again': '🤢',
};

// Ordered reaction keys for display
const _reactionOrder = [
  'so_yummy',
  'tasty',
  'pretty_good',
  'meh',
  'never_again',
];

class _DishTile extends ConsumerWidget {
  final DishItem dish;
  final String? badge;
  const _DishTile({required this.dish, this.badge});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(dishReactionSummaryProvider(dish.id));

    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      onTap: () => context.push('/dish/${dish.id}'),
      title: Text(
        dish.name,
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(color: AppColors.primaryText),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dish.category != null)
            Text(
              dish.category!,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.mutedText),
            ),
          summaryAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (summary) {
              final pairs = _reactionOrder
                  .where((key) => (summary.breakdown[key] ?? 0) > 0)
                  .map((key) => (
                        _reactionEmojis[key]!,
                        summary.breakdown[key]!,
                      ))
                  .toList();

              if (pairs.isEmpty) return const SizedBox.shrink();

              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (int i = 0; i < pairs.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Text(
                        pairs[i].$1,
                        style: const TextStyle(fontSize: 11),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${pairs[i].$2}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.mutedText,
                          fontFamily: 'DM Sans',
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (badge != null) ...[
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                badge!,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.mutedText, fontSize: 9),
              ),
            ),
            const SizedBox(width: 4),
          ],
          if (dish.communityScore != null)
            Text(
              '${dish.communityScore!.toStringAsFixed(1)} ★',
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: AppColors.accent),
            ),
          if (dish.price != null) ...[
            const SizedBox(width: 8),
            Text(
              '₹${dish.price}',
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: AppColors.mutedText),
            ),
          ],
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right,
              color: AppColors.mutedText, size: 18),
        ],
      ),
    );
  }
}

class _RatingBottomSheet extends ConsumerStatefulWidget {
  final String restaurantId;
  const _RatingBottomSheet({required this.restaurantId});

  @override
  ConsumerState<_RatingBottomSheet> createState() =>
      _RatingBottomSheetState();
}

class _RatingBottomSheetState
    extends ConsumerState<_RatingBottomSheet> {
  int _stars = 0;
  bool _submitted = false;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'How was your visit?',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(color: AppColors.primaryText),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final filled = i < _stars;
                return GestureDetector(
                  onTap: () => setState(() => _stars = i + 1),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(
                      filled
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: filled
                          ? AppColors.accent
                          : AppColors.border,
                      size: 40,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _stars > 0 && !_submitted ? _submit : null,
              child: const Text('Submit Rating'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _submitted = true);
    try {
      await ref
          .read(restaurantRepositoryProvider)
          .upsertRating(widget.restaurantId, _stars);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => _submitted = false);
    }
  }
}

// ─────────────────────────────────────────────
// Suggest Edit Bottom Sheet
// ─────────────────────────────────────────────

class _SuggestEditBottomSheet extends ConsumerStatefulWidget {
  final String restaurantId;
  const _SuggestEditBottomSheet({required this.restaurantId});

  @override
  ConsumerState<_SuggestEditBottomSheet> createState() =>
      _SuggestEditBottomSheetState();
}

class _SuggestEditBottomSheetState
    extends ConsumerState<_SuggestEditBottomSheet> {
  static const _fields = [
    ('name', 'Name'),
    ('city', 'City'),
    ('cuisine_type', 'Cuisine Type'),
  ];

  String _selectedField = 'name';
  final _valueController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _valueController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final value = _valueController.text.trim();
    if (value.isEmpty) return;

    setState(() => _submitting = true);

    try {
      final dio = ref.read(apiClientProvider);
      await dio.post('/edit-suggestions', data: {
        'entity_type': 'restaurant',
        'entity_id': widget.restaurantId,
        'field': _selectedField,
        'proposed_value': value,
      });

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Edit submitted — thanks!',
              style: TextStyle(fontFamily: 'DM Sans'),
            ),
            backgroundColor: AppColors.accentPress,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              apiErrorMessage(e),
              style: const TextStyle(
                  fontFamily: 'DM Sans', color: AppColors.primaryText),
            ),
            backgroundColor: AppColors.elevated,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            'Suggest an Edit',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.primaryText,
                  fontFamily: 'Fraunces',
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Help keep restaurant info accurate for the community.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.mutedText,
                  fontFamily: 'DM Sans',
                ),
          ),
          const SizedBox(height: 24),

          // Field dropdown
          Text(
            'FIELD',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.secondaryText,
                  letterSpacing: 0.8,
                  fontFamily: 'DM Sans',
                ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedField,
                dropdownColor: AppColors.elevated,
                iconEnabledColor: AppColors.mutedText,
                isExpanded: true,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.primaryText,
                      fontFamily: 'DM Sans',
                    ),
                items: _fields
                    .map(
                      (f) => DropdownMenuItem(
                        value: f.$1,
                        child: Text(
                          f.$2,
                          style: const TextStyle(fontFamily: 'DM Sans'),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _selectedField = v);
                },
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Proposed value input
          Text(
            'PROPOSED VALUE',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.secondaryText,
                  letterSpacing: 0.8,
                  fontFamily: 'DM Sans',
                ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _valueController,
            style: const TextStyle(
              color: AppColors.primaryText,
              fontFamily: 'DM Sans',
            ),
            decoration: const InputDecoration(
              hintText: 'Enter corrected value…',
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submitting ? null : _submit(),
          ),
          const SizedBox(height: 24),

          // Submit button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.background,
                      ),
                    )
                  : const Text('Submit Edit'),
            ),
          ),
        ],
      ),
    );
  }
}
