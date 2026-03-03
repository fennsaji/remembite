import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/auth_state.dart';
import '../../../core/theme/app_theme.dart';
import '../../restaurant/data/restaurant_repository.dart';

part 'home_screen.g.dart';

@riverpod
Future<List<RestaurantSummary>> nearbyRestaurants(Ref ref) async {
  final repo = ref.watch(restaurantRepositoryProvider);
  try {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return [];

    final permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return [];
    }

    // Try last known position first (instant, works on emulator with mock location)
    Position? pos = await Geolocator.getLastKnownPosition();

    // Fall back to fresh fix with a hard 10s timeout via Future.timeout()
    pos ??= await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
      ),
    ).timeout(const Duration(seconds: 10));

    return repo.getNearbyRestaurants(pos.latitude, pos.longitude);
  } catch (_) {
    return [];
  }
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider).value;
    final nearbyAsync = ref.watch(nearbyRestaurantsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // App bar with search
            SliverAppBar(
              floating: true,
              backgroundColor: AppColors.background,
              automaticallyImplyLeading: false,
              titleSpacing: 16,
              title: _SearchBar(onTap: () => context.push('/search')),
            ),

            // Greeting
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.fromLTRB(20, 20, 20, 4),
                child: Text(
                  _greeting(auth?.displayName),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: AppColors.primaryText,
                      ),
                ),
              ),
            ),

            // Recently Visited
            const SliverToBoxAdapter(child: _SectionLabel(label: 'RECENTLY VISITED')),
            const SliverToBoxAdapter(child: _RecentlyVisitedSection()),

            // Nearby Restaurants
            const SliverToBoxAdapter(child: _SectionLabel(label: 'NEARBY')),
            nearbyAsync.when(
              loading: () => SliverToBoxAdapter(
                child: SizedBox(
                  height: 120,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.accent,
                      strokeWidth: 2,
                    ),
                  ),
                ),
              ),
              error: (_, __) => const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'Could not load nearby restaurants.',
                    style: TextStyle(color: AppColors.secondaryText),
                  ),
                ),
              ),
              data: (restaurants) => restaurants.isEmpty
                  ? SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                        child: Row(
                          children: [
                            const Icon(Icons.storefront_outlined,
                                color: AppColors.accent, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              'No restaurants found nearby. Try adding one!',
                              style: TextStyle(color: AppColors.secondaryText),
                            ),
                          ],
                        ),
                      ),
                    )
                  : SliverList.separated(
                      separatorBuilder: (_, __) =>
                          const Divider(color: AppColors.border, height: 1),
                      itemCount: restaurants.length,
                      itemBuilder: (context, i) =>
                          _RestaurantTile(restaurant: restaurants[i]),
                    ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/search'),
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.background,
        icon: const Icon(Icons.search),
        label: const Text('Search Restaurant'),
      ),
    );
  }

  String _greeting(String? name) {
    final hour = DateTime.now().hour;
    final timeOfDay = hour < 12
        ? 'morning'
        : hour < 17
            ? 'afternoon'
            : 'evening';
    final first = name?.split(' ').first ?? '';
    return 'Good $timeOfDay${first.isNotEmpty ? ', $first' : ''} 👋';
  }

}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

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
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final VoidCallback onTap;
  const _SearchBar({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.search, color: AppColors.mutedText, size: 18),
            const SizedBox(width: 8),
            Text(
              'Search restaurants or dishes…',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.mutedText,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentlyVisitedSection extends ConsumerWidget {
  const _RecentlyVisitedSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider).value;
    if (auth == null) return const SizedBox.shrink();

    return FutureBuilder(
      future: ref
          .read(restaurantRepositoryProvider)
          .getRecentlyVisited(auth.id),
      builder: (context, snapshot) {
        final rows = snapshot.data ?? [];
        if (rows.isEmpty) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Row(
              children: [
                const Icon(Icons.add_location_alt_outlined,
                    color: AppColors.accent, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Add a restaurant and react to dishes to see your history here.',
                    style: TextStyle(
                      color: AppColors.secondaryText,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        return SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemCount: rows.length,
            itemBuilder: (context, i) {
              final r = rows[i];
              return GestureDetector(
                onTap: () => context.push('/restaurant/${r.id}'),
                child: Container(
                  width: 130,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        r.name,
                        style: Theme.of(context)
                            .textTheme
                            .labelLarge
                            ?.copyWith(color: AppColors.primaryText),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        r.cuisineType ?? r.city,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.mutedText),
                        maxLines: 1,
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
    );
  }
}

class _RestaurantTile extends StatelessWidget {
  final RestaurantSummary restaurant;
  const _RestaurantTile({required this.restaurant});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      onTap: () => context.push('/restaurant/${restaurant.id}'),
      title: Text(
        restaurant.name,
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(color: AppColors.primaryText),
      ),
      subtitle: Text(
        restaurant.cuisineType ?? restaurant.city,
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: AppColors.mutedText),
      ),
      trailing: restaurant.avgRating != null
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star_rounded,
                    color: AppColors.accent, size: 16),
                const SizedBox(width: 4),
                Text(
                  restaurant.avgRating!.toStringAsFixed(1),
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(color: AppColors.secondaryText),
                ),
              ],
            )
          : null,
    );
  }
}

