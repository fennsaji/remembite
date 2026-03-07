import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/auth/presentation/sign_in_screen.dart';
import '../../features/dish/presentation/dish_detail_screen.dart';
import '../../features/favorites/presentation/favorites_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/restaurant/data/restaurant_repository.dart';
import '../../features/restaurant/presentation/location_picker_screen.dart';
import '../../features/restaurant/presentation/menu_scan_screen.dart';
import '../../features/restaurant/presentation/ocr_results_screen.dart';
import '../../features/restaurant/presentation/pending_edits_screen.dart';
import '../../features/restaurant/presentation/restaurant_screen.dart';
import '../../features/search/presentation/search_screen.dart';
import '../../features/map/presentation/map_screen.dart';
import '../../features/timeline/presentation/timeline_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/upgrade/presentation/upgrade_screen.dart';
import '../network/auth_state.dart';
import '../theme/app_theme.dart';

part 'app_router.g.dart';

// Notifier that pings GoRouter to re-evaluate its redirect when auth changes.
// Only fires when sign-in state *actually* flips (null→user or user→null),
// not on every re-emission, to avoid duplicate-page-key crashes during navigation.
class _AuthNotifier extends ChangeNotifier {
  bool? _lastSignedIn;

  _AuthNotifier(Ref ref) {
    ref.listen(authStateProvider, (_, next) {
      final isSignedIn = next.value != null;
      if (_lastSignedIn != isSignedIn) {
        _lastSignedIn = isSignedIn;
        notifyListeners();
      }
    });
  }
}

@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref, {String? initialLocation}) {
  final notifier = _AuthNotifier(ref);
  ref.onDispose(notifier.dispose);

  return GoRouter(
    initialLocation: initialLocation ?? '/home',
    refreshListenable: notifier,
    redirect: (context, state) {
      final isSignedIn = ref.read(authStateProvider).value != null;
      final isAuthRoute = state.matchedLocation.startsWith('/auth');

      if (!isSignedIn && !isAuthRoute) return '/auth/sign-in';
      if (isSignedIn && isAuthRoute) return '/home';
      return null;
    },
    routes: [
      // Auth
      GoRoute(
        path: '/auth/sign-in',
        builder: (context, state) => const SignInScreen(),
      ),

      // Onboarding (outside shell — no bottom nav)
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),

      // Scan route (outside shell — full screen camera)
      // Always requires restaurantId — use /restaurant/:id/scan
      GoRoute(
        path: '/restaurant/:restaurantId/scan',
        builder: (context, state) =>
            MenuScanScreen(restaurantId: state.pathParameters['restaurantId']),
      ),
      GoRoute(
        path: '/scan/results',
        builder: (context, state) {
          final extra =
              (state.extra is Map<String, dynamic>
                  ? state.extra as Map<String, dynamic>
                  : null) ??
              {};
          return OcrResultsScreen(
            rawText: extra['rawText'] as String? ?? '',
            restaurantId: extra['restaurantId'] as String?,
            parsedDishes: extra['parsedDishes'] as List<ParsedDishItem>?,
          );
        },
      ),

      // Upgrade / Pro paywall (full-screen modal, no bottom nav)
      GoRoute(
        path: '/upgrade',
        builder: (context, state) => const UpgradeScreen(),
      ),

      // Pending edits (full-screen, has its own AppBar — outside shell)
      GoRoute(
        path: '/restaurant/:id/edits',
        builder: (context, state) =>
            PendingEditsScreen(restaurantId: state.pathParameters['id']!),
      ),

      // Location picker (full-screen map, no bottom nav)
      GoRoute(
        path: '/location-picker',
        builder: (context, state) => LocationPickerScreen(
          initial: state.extra is LatLng ? state.extra as LatLng : null,
        ),
      ),

      // Main shell with floating bottom nav
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/restaurant/add',
            redirect: (context, state) => '/map?mode=add',
          ),
          GoRoute(
            path: '/restaurant/:id',
            builder: (context, state) =>
                RestaurantScreen(restaurantId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/dish/:id',
            builder: (context, state) =>
                DishDetailScreen(dishId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/search',
            builder: (context, state) => const SearchScreen(),
          ),
          GoRoute(
            path: '/timeline',
            builder: (context, state) => const TimelineScreen(),
          ),
          GoRoute(
            path: '/favorites',
            builder: (context, state) => const FavoritesScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
          GoRoute(
            path: '/map',
            builder: (context, state) => MapScreen(
              addMode: state.uri.queryParameters['mode'] == 'add',
              initialQuery: state.uri.queryParameters['query'],
            ),
          ),
        ],
      ),
    ],
  );
}

// ─────────────────────────────────────────────
// Main Shell — Floating Pill Bottom Nav
// ─────────────────────────────────────────────

class MainShell extends StatelessWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    int index = 0;
    if (location.startsWith('/map')) index = 1;
    if (location.startsWith('/timeline')) index = 2;
    if (location.startsWith('/profile')) index = 3;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: child,
      bottomNavigationBar: _FloatingPillNav(
        currentIndex: index,
        onTap: (i) {
          switch (i) {
            case 0:
              GoRouter.of(context).go('/home');
            case 1:
              GoRouter.of(context).go('/map');
            case 2:
              GoRouter.of(context).go('/timeline');
            case 3:
              GoRouter.of(context).go('/profile');
          }
        },
      ),
    );
  }
}

class _FloatingPillNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _FloatingPillNav({required this.currentIndex, required this.onTap});

  static const _items = [
    (Icons.home_outlined, Icons.home, 'Home'),
    (Icons.map_outlined, Icons.map, 'Map'),
    (Icons.access_time_outlined, Icons.access_time, 'Timeline'),
    (Icons.person_outline, Icons.person, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: Container(
          height: 60,
          decoration: BoxDecoration(
            color: AppColors.elevated, // #241E18
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(_items.length, (i) {
              final (outlinedIcon, filledIcon, label) = _items[i];
              final isActive = i == currentIndex;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isActive ? filledIcon : outlinedIcon,
                        color: isActive
                            ? AppColors
                                  .accent // #E6A830
                            : AppColors.secondaryText,
                        size: 22,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        label,
                        style: TextStyle(
                          color: isActive
                              ? AppColors.accent
                              : AppColors.secondaryText,
                          fontSize: 10,
                          fontWeight: isActive
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
