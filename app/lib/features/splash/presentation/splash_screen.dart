import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/auth_state.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    // Minimum display time so the splash is actually visible
    Future.delayed(const Duration(milliseconds: 1500), _maybeNavigate);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _maybeNavigate() {
    if (!mounted || _navigated) return;
    final auth = ref.read(authStateProvider);
    // If auth is still loading, wait for it (listener in didChangeDependencies)
    if (auth.isLoading) return;
    _navigate(auth.value != null);
  }

  void _navigate(bool isSignedIn) {
    if (_navigated || !mounted) return;
    _navigated = true;
    context.go(isSignedIn ? '/home' : '/auth/sign-in');
  }

  @override
  Widget build(BuildContext context) {
    // Also react when auth resolves after the delay
    ref.listen(authStateProvider, (_, next) {
      if (!next.isLoading) _maybeNavigate();
    });

    return Scaffold(
      backgroundColor: Colors.black,
      body: SizedBox.expand(
        child: Image.asset(
          'assets/images/splash_screen.png',
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
