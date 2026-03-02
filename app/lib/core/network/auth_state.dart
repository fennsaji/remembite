import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'displayName': displayName,
    'avatarUrl': avatarUrl,
    'isPro': isPro,
    'accessToken': accessToken,
  };

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
    id: json['id'] as String,
    email: json['email'] as String,
    displayName: json['displayName'] as String,
    avatarUrl: json['avatarUrl'] as String?,
    isPro: json['isPro'] as bool,
    accessToken: json['accessToken'] as String,
  );
}

const _storage = FlutterSecureStorage();
const _storageKey = 'auth_user';

@riverpod
class AuthState extends _$AuthState {
  @override
  Future<AuthUser?> build() async {
    final raw = await _storage.read(key: _storageKey);
    if (raw == null) return null;
    try {
      return AuthUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      await _storage.delete(key: _storageKey);
      return null;
    }
  }

  Future<void> signIn(AuthUser user) async {
    await _storage.write(key: _storageKey, value: jsonEncode(user.toJson()));
    state = AsyncData(user);
  }

  Future<void> signOut() async {
    await _storage.delete(key: _storageKey);
    state = const AsyncData(null);
  }
}
