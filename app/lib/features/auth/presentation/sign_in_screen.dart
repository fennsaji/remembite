import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/auth_state.dart';
import '../../../core/theme/app_theme.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  bool _loading = false;

  Future<void> _signInWithGoogle() async {
    setState(() => _loading = true);
    try {
      final googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);
      final account = await googleSignIn.signIn();
      if (account == null) return; // user cancelled

      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null) throw Exception('No ID token from Google');

      // Exchange Google ID token for Remembite JWT
      final dio = ref.read(apiClientProvider);
      final response = await dio.post('/auth/google', data: {'id_token': idToken});

      final data = response.data as Map<String, dynamic>;
      final userJson = data['user'] as Map<String, dynamic>;

      await ref.read(authStateProvider.notifier).signIn(AuthUser(
        id: userJson['id'] as String,
        email: userJson['email'] as String,
        displayName: userJson['display_name'] as String,
        avatarUrl: userJson['avatar_url'] as String?,
        isPro: userJson['pro_status'] as bool,
        accessToken: data['access_token'] as String,
      ));

      if (mounted) context.go('/onboarding');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sign in failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Text(
                'Remembite',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryText,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Remember What You Loved.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.secondaryText,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _signInWithGoogle,
                  icon: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.g_mobiledata, size: 24),
                  label: Text(_loading ? 'Signing in…' : 'Continue with Google'),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
