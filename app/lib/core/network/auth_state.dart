import 'dart:async';
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
  final String refreshToken;

  const AuthUser({
    required this.id,
    required this.email,
    required this.displayName,
    this.avatarUrl,
    required this.isPro,
    required this.accessToken,
    required this.refreshToken,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'displayName': displayName,
    'avatarUrl': avatarUrl,
    'isPro': isPro,
    'accessToken': accessToken,
    'refreshToken': refreshToken,
  };

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
    id: json['id'] as String,
    email: json['email'] as String,
    displayName: json['displayName'] as String,
    avatarUrl: json['avatarUrl'] as String?,
    isPro: json['isPro'] as bool,
    accessToken: json['accessToken'] as String,
    // Installs that signed in before refresh tokens were stored locally
    // fall back to '' — tryRefreshAccessToken() treats that as "can't
    // refresh, sign out" rather than crashing on a missing field.
    refreshToken: json['refreshToken'] as String? ?? '',
  );
}

const _storage = FlutterSecureStorage();
const _storageKey = 'auth_user';

// keepAlive: this is the app-wide session source of truth, read via
// `ref.read` from many one-off call sites (Dio interceptors, sync worker,
// billing service) that don't hold a watching subscription. It happens to
// stay alive today because appRouterProvider's _AuthNotifier holds a
// `ref.listen`, but that's an incidental side effect of router wiring, not
// a guarantee — pin it explicitly instead of depending on that.
@Riverpod(keepAlive: true)
class AuthState extends _$AuthState {
  StreamSubscription<String>? _tokenRefreshSub;

  @override
  Future<AuthUser?> build() async {
    ref.onDispose(() => _tokenRefreshSub?.cancel());
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

  /// Exchange the stored refresh token for a new access+refresh pair via
  /// POST /auth/refresh. Returns false if there's no refresh token or the
  /// server rejects it — the caller (api_client's 401 handler) treats that
  /// as "session is truly dead" and signs out.
  Future<bool> tryRefreshAccessToken() async {
    final current = state.value;
    if (current == null || current.refreshToken.isEmpty) return false;
    try {
      final dio = ref.read(apiClientProvider);
      final resp = await dio.post(
        '/auth/refresh',
        data: {'refresh_token': current.refreshToken},
      );
      final data = resp.data as Map<String, dynamic>;
      final updated = AuthUser(
        id: current.id,
        email: current.email,
        displayName: current.displayName,
        avatarUrl: current.avatarUrl,
        isPro: data['pro_status'] as bool,
        accessToken: data['access_token'] as String,
        refreshToken: data['refresh_token'] as String,
      );
      await _storage.write(
        key: _storageKey,
        value: jsonEncode(updated.toJson()),
      );
      state = AsyncData(updated);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _registerFcmToken(AuthUser user) async {
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      final token = await messaging.getToken();
      if (token == null || token.isEmpty) return;

      final dio = ref.read(apiClientProvider);
      await dio.patch('/users/me/fcm-token', data: {'token': token});

      // Subscribe to token rotations so the backend always has the current
      // token. signIn() is called on every sign-in AND every Pro purchase
      // (billing_service re-signs-in to refresh isPro) — without cancelling
      // the prior subscription first, each call leaked another listener,
      // so a user who upgraded to Pro three times had three duplicate PATCH
      // calls firing per token rotation, one of which would keep firing
      // (unauthenticated, 401 → forced signOut) even after the user signed
      // out on this device.
      await _tokenRefreshSub?.cancel();
      _tokenRefreshSub = FirebaseMessaging.instance.onTokenRefresh.listen((
        newToken,
      ) async {
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
    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;
    await _storage.delete(key: _storageKey);
    state = const AsyncData(null);
  }
}
