import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/auth/presentation/sign_in_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../network/auth_state.dart';

part 'app_router.g.dart';

@riverpod
GoRouter appRouter(Ref ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/home',
    redirect: (context, state) {
      final isSignedIn = authState.value != null;
      final isAuthRoute = state.matchedLocation.startsWith('/auth');

      if (!isSignedIn && !isAuthRoute) return '/auth/sign-in';
      if (isSignedIn && isAuthRoute) return '/home';
      return null;
    },
    routes: [
      GoRoute(
        path: '/auth/sign-in',
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/restaurant/:id',
            builder: (context, state) =>
                RestaurantPlaceholder(id: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/dish/:id',
            builder: (context, state) =>
                DishPlaceholder(id: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfilePlaceholder(),
          ),
          GoRoute(
            path: '/favorites',
            builder: (context, state) => const FavoritesPlaceholder(),
          ),
          GoRoute(
            path: '/map',
            builder: (context, state) => const MapPlaceholder(),
          ),
        ],
      ),
    ],
  );
}

// Bottom navigation shell
class MainShell extends StatelessWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    int index = 0;
    if (location.startsWith('/map')) index = 1;
    if (location.startsWith('/favorites')) index = 2;
    if (location.startsWith('/profile')) index = 3;

    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: index,
        type: BottomNavigationBarType.fixed,
        onTap: (i) {
          switch (i) {
            case 0: context.go('/home');
            case 1: context.go('/map');
            case 2: context.go('/favorites');
            case 3: context.go('/profile');
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.map_outlined), activeIcon: Icon(Icons.map), label: 'Map'),
          BottomNavigationBarItem(icon: Icon(Icons.favorite_outline), activeIcon: Icon(Icons.favorite), label: 'Favorites'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

// Placeholder screens — replaced in later phases
class RestaurantPlaceholder extends StatelessWidget {
  final String id;
  const RestaurantPlaceholder({super.key, required this.id});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text('Restaurant $id')));
}
class DishPlaceholder extends StatelessWidget {
  final String id;
  const DishPlaceholder({super.key, required this.id});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text('Dish $id')));
}
class ProfilePlaceholder extends StatelessWidget {
  const ProfilePlaceholder({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Profile')));
}
class FavoritesPlaceholder extends StatelessWidget {
  const FavoritesPlaceholder({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Favorites')));
}
class MapPlaceholder extends StatelessWidget {
  const MapPlaceholder({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Map')));
}
