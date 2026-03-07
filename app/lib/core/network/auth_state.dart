import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'api_client.dart';

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
    _registerFcmToken(user); // fire-and-forget
  }

  Future<void> _registerFcmToken(AuthUser user) async {
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      final token = await messaging.getToken();
      if (token == null || token.isEmpty) return;

      final dio = ref.read(apiClientProvider);
      await dio.patch('/users/me/fcm-token', data: {'token': token});

      // Subscribe to token rotations so the backend always has the current token
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        try {
          final refreshDio = ref.read(apiClientProvider);
          await refreshDio.patch(
            '/users/me/fcm-token',
            data: {'token': newToken},
          );
        } catch (e) {
          debugPrint('FCM token refresh update failed: $e');
        }
      });
    } catch (_) {
      // FCM token registration is non-critical — ignore failures
    }
  }

  Future<void> signOut() async {
    await _storage.delete(key: _storageKey);
    state = const AsyncData(null);
  }
}
