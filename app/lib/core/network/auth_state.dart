import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_state.g.dart';

class AuthUser {
  final String id;
  final String email;
  final String displayName;
  final String? avatarUrl;
  final bool isPro;
  final String accessToken;

  const AuthUser({
    required this.id,
    required this.email,
    required this.displayName,
    this.avatarUrl,
    required this.isPro,
    required this.accessToken,
  });
}

@riverpod
class AuthState extends _$AuthState {
  @override
  Future<AuthUser?> build() async {
    // TODO: load persisted auth from secure storage
    return null;
  }

  Future<void> signIn(AuthUser user) async {
    state = AsyncData(user);
    // TODO: persist to secure storage
  }

  Future<void> signOut() async {
    state = const AsyncData(null);
    // TODO: clear secure storage, local DB session data
  }
}
