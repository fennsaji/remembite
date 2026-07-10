import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
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
      final googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
        serverClientId: const String.fromEnvironment('GOOGLE_WEB_CLIENT_ID'),
      );
      final account = await googleSignIn.signIn();
      if (account == null) return; // user cancelled

      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null) throw Exception('No ID token from Google');

      // Exchange Google ID token for Remembite JWT
      final dio = ref.read(apiClientProvider);
      final response = await dio.post(
        '/auth/google',
        data: {'id_token': idToken},
      );

      final data = response.data as Map<String, dynamic>;
      final userJson = data['user'] as Map<String, dynamic>;
      final userId = userJson['id'] as String;

      await ref
          .read(authStateProvider.notifier)
          .signIn(
            AuthUser(
              id: userId,
              email: userJson['email'] as String,
              displayName: userJson['display_name'] as String,
              avatarUrl: userJson['avatar_url'] as String?,
              isPro: userJson['pro_status'] as bool,
              accessToken: data['access_token'] as String,
              refreshToken: data['refresh_token'] as String,
            ),
          );

      if (mounted) {
        const storage = FlutterSecureStorage();
        // Keyed per-user — a global 'has_bootstrapped' key meant a second
        // account signing in on the same device skipped taste-calibration
        // onboarding entirely, starting with an empty taste profile.
        final bootstrapped = await storage.read(
          key: 'has_bootstrapped_$userId',
        );
        if (mounted) {
          context.go(bootstrapped == 'true' ? '/home' : '/onboarding');
        }
      }
    } catch (e, st) {
      debugPrint('SIGN_IN_ERROR: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
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
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: AppColors.secondaryText),
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
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.g_mobiledata, size: 24),
                  label: Text(
                    _loading ? 'Signing in…' : 'Continue with Google',
                  ),
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
