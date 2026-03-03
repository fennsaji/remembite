import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/db/app_database.dart';
import '../../../core/db/daos/favorites_dao.dart';
import '../../../core/network/auth_state.dart';
import '../../../core/theme/app_theme.dart';

part 'favorites_screen.g.dart';

@riverpod
Stream<List<FavoritedDish>> favoritedDishes(Ref ref, String userId) {
  final db = ref.watch(appDatabaseProvider);
  return db.favoritesDao.getFavorites(userId);
}

// ─────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────

String _reactionEmoji(String? r) => switch (r) {
      'so_yummy' => '🔥',
      'tasty' => '😋',
      'pretty_good' => '🙂',
      'meh' => '😐',
      'never_again' => '🤢',
      _ => '',
    };

int _reactionWeight(String? r) => switch (r) {
      'so_yummy' => 5,
      'tasty' => 4,
      'pretty_good' => 3,
      'meh' => 2,
      'never_again' => 1,
      _ => 0,
    };

// ─────────────────────────────────────────────────────────
// FavoritesScreen
// ─────────────────────────────────────────────────────────

class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  String? _selectedReaction;
  String _sortMode = 'recent';
  String? _selectedRestaurantId;

  @override
  Widget build(BuildContext context) {
    final authAsync = ref.watch(authStateProvider);
    final userId = authAsync.value?.id;

    if (userId == null) {
      return _emptyScaffold(context);
    }

    final favoritesAsync = ref.watch(favoritedDishesProvider(userId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        automaticallyImplyLeading: false,
        title: Text(
          'Favorites',
          style: GoogleFonts.fraunces(
            color: AppColors.primaryText,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.sort, color: AppColors.secondaryText),
            onPressed: () => _showSortSheet(context),
          ),
        ],
      ),
      body: favoritesAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
        error: (e, _) {
          debugPrint('Favorites load error: $e');
          return const Center(
            child: Text('Failed to load favorites',
                style: TextStyle(color: AppColors.mutedText)),
          );
        },
        data: (all) => _buildBody(context, all),
      ),
    );
  }

  Widget _buildBody(BuildContext context, List<FavoritedDish> all) {
    // Distinct restaurants for the restaurant filter row
    final restaurantMap = <String, String>{};
    for (final d in all) {
      restaurantMap[d.restaurantId] = d.restaurantName;
    }
    final hasMultipleRestaurants = restaurantMap.length > 1;

    // Apply reaction filter
    var filtered = _selectedReaction == null
        ? all
        : all.where((d) => d.reaction == _selectedReaction).toList();

    // Apply restaurant filter
    if (_selectedRestaurantId != null) {
      filtered =
          filtered.where((d) => d.restaurantId == _selectedRestaurantId).toList();
    }

    // Apply sort
    if (_sortMode == 'weight') {
      filtered.sort((a, b) {
        final wCmp =
            _reactionWeight(b.reaction).compareTo(_reactionWeight(a.reaction));
        if (wCmp != 0) return wCmp;
        return b.favoritedAt.compareTo(a.favoritedAt);
      });
    } else {
      filtered.sort((a, b) => b.favoritedAt.compareTo(a.favoritedAt));
    }

    return Column(
      children: [
        // Reaction filter chips
        _ReactionFilterRow(
          selected: _selectedReaction,
          onChanged: (r) => setState(() => _selectedReaction = r),
        ),

        // Restaurant filter chips (only when >1 restaurant)
        if (hasMultipleRestaurants)
          _RestaurantFilterRow(
            restaurantMap: restaurantMap,
            selectedId: _selectedRestaurantId,
            onChanged: (id) => setState(() => _selectedRestaurantId = id),
          ),

        // List or empty state
        Expanded(
          child: filtered.isEmpty
              ? const _EmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 100),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final item = filtered[i];
                    final emoji = _reactionEmoji(item.reaction);
                    return ListTile(
                      leading: emoji.isNotEmpty
                          ? Text(
                              emoji,
                              style: const TextStyle(fontSize: 22),
                            )
                          : const Icon(
                              Icons.favorite,
                              color: AppColors.error,
                            ),
                      title: Text(
                        item.dishName,
                        style: const TextStyle(color: AppColors.primaryText),
                      ),
                      subtitle: Text(
                        item.restaurantName,
                        style: const TextStyle(color: AppColors.mutedText),
                      ),
                      onTap: () => context.push('/dish/${item.dishId}'),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showSortSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.elevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text(
                  'Most Recent',
                  style: TextStyle(color: AppColors.primaryText),
                ),
                trailing: _sortMode == 'recent'
                    ? const Icon(Icons.check, color: AppColors.accent)
                    : null,
                onTap: () {
                  setState(() => _sortMode = 'recent');
                  Navigator.of(ctx).pop();
                },
              ),
              ListTile(
                title: const Text(
                  'Highest Reaction',
                  style: TextStyle(color: AppColors.primaryText),
                ),
                trailing: _sortMode == 'weight'
                    ? const Icon(Icons.check, color: AppColors.accent)
                    : null,
                onTap: () {
                  setState(() => _sortMode = 'weight');
                  Navigator.of(ctx).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _emptyScaffold(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        automaticallyImplyLeading: false,
        title: Text(
          'Favorites',
          style: GoogleFonts.fraunces(
            color: AppColors.primaryText,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: const _EmptyState(),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Reaction filter chip row
// ─────────────────────────────────────────────────────────

class _ReactionFilterRow extends StatelessWidget {
  final String? selected;
  final ValueChanged<String?> onChanged;

  const _ReactionFilterRow({
    required this.selected,
    required this.onChanged,
  });

  static const _reactions = [
    (null, 'All'),
    ('so_yummy', '🔥'),
    ('tasty', '😋'),
    ('pretty_good', '🙂'),
    ('meh', '😐'),
    ('never_again', '🤢'),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: _reactions.map((entry) {
          final (value, label) = entry;
          final isSelected = selected == value;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(label),
              selected: isSelected,
              onSelected: (_) => onChanged(value),
              labelStyle: TextStyle(
                color: isSelected ? AppColors.background : AppColors.secondaryText,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              selectedColor: AppColors.accent,
              backgroundColor: AppColors.elevated,
              side: BorderSide.none,
              showCheckmark: false,
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Restaurant filter chip row
// ─────────────────────────────────────────────────────────

class _RestaurantFilterRow extends StatelessWidget {
  final Map<String, String> restaurantMap;
  final String? selectedId;
  final ValueChanged<String?> onChanged;

  const _RestaurantFilterRow({
    required this.restaurantMap,
    required this.selectedId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: [
          // "All Restaurants" chip
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: const Text('All Restaurants'),
              selected: selectedId == null,
              onSelected: (_) => onChanged(null),
              labelStyle: TextStyle(
                color: selectedId == null
                    ? AppColors.background
                    : AppColors.secondaryText,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              selectedColor: AppColors.accent,
              backgroundColor: AppColors.elevated,
              side: BorderSide.none,
              showCheckmark: false,
            ),
          ),
          // One chip per restaurant
          ...restaurantMap.entries.map((e) {
            final isSelected = selectedId == e.key;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(e.value),
                selected: isSelected,
                onSelected: (_) => onChanged(e.key),
                labelStyle: TextStyle(
                  color:
                      isSelected ? AppColors.background : AppColors.secondaryText,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                selectedColor: AppColors.accent,
                backgroundColor: AppColors.elevated,
                side: BorderSide.none,
                showCheckmark: false,
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Tap ♡ on any dish to save it here',
        style: TextStyle(color: AppColors.mutedText),
        textAlign: TextAlign.center,
      ),
    );
  }
}
