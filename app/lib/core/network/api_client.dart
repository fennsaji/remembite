import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'auth_state.dart';

part 'api_client.g.dart';

const _baseUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'http://10.0.2.2:8080',
);

// keepAlive: read via `ref.read` from one-off call sites (sync worker,
// billing service, FCM token registration) that don't hold a watching
// subscription — under autoDispose those reads could race a teardown
// triggered by unrelated UI rebuilds elsewhere in the tree.
@Riverpod(keepAlive: true)
Dio apiClient(Ref ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  // JWT interceptor — attach access token to every request
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final auth = ref.read(authStateProvider).value;
        if (auth != null) {
          options.headers['Authorization'] = 'Bearer ${auth.accessToken}';
        }
        handler.next(options);
      },
    ),
  );

  // Single-flight guard: concurrent requests that all 401 around the same
  // moment (e.g. a screen that fires several calls at once) share one
  // refresh call instead of each racing their own.
  Future<bool>? refreshInFlight;

  // 401 handling — try a token refresh before giving up. Previously any 401
  // (including a routine access-token expiry, which happens on every
  // session past jwt_access_expiry_hours) signed the user out immediately,
  // dumping them to the sign-in screen mid-task with unsaved state lost.
  dio.interceptors.add(
    InterceptorsWrapper(
      onError: (error, handler) async {
        if (error.response?.statusCode != 401 ||
            error.requestOptions.path.contains('/auth/refresh')) {
          handler.next(error);
          return;
        }

        final alreadyRetried =
            error.requestOptions.extra['retried_after_refresh'] == true;
        if (alreadyRetried) {
          // The retried request also 401'd — the refreshed token was
          // rejected too, so the session is genuinely dead.
          await ref.read(authStateProvider.notifier).signOut();
          handler.next(error);
          return;
        }

        refreshInFlight ??= ref
            .read(authStateProvider.notifier)
            .tryRefreshAccessToken();
        final refreshed = await refreshInFlight!;
        refreshInFlight = null;

        if (!refreshed) {
          await ref.read(authStateProvider.notifier).signOut();
          handler.next(error);
          return;
        }

        final auth = ref.read(authStateProvider).value;
        final opts = error.requestOptions
          ..headers['Authorization'] = 'Bearer ${auth!.accessToken}'
          ..extra['retried_after_refresh'] = true;
        try {
          final response = await dio.fetch(opts);
          handler.resolve(response);
        } on DioException catch (e) {
          handler.next(e);
        }
      },
    ),
  );

  // Retry interceptor — retry once on network timeouts, GET only. The old
  // version retried every method including POST: a `receiveTimeout` on a
  // write the server had already processed (slow response, not a failed
  // request) meant the replay created a second reaction/restaurant/etc.
  // GET requests are safe to replay unconditionally.
  dio.interceptors.add(
    InterceptorsWrapper(
      onError: (error, handler) async {
        final isTimeout =
            error.type == DioExceptionType.connectionTimeout ||
            error.type == DioExceptionType.receiveTimeout;
        final isGet = error.requestOptions.method.toUpperCase() == 'GET';
        final alreadyRetried =
            error.requestOptions.extra['retried_after_timeout'] == true;

        if (isTimeout && isGet && !alreadyRetried) {
          error.requestOptions.extra['retried_after_timeout'] = true;
          try {
            final response = await dio.fetch(error.requestOptions);
            return handler.resolve(response);
          } catch (_) {}
        }
        handler.next(error);
      },
    ),
  );

  return dio;
}
