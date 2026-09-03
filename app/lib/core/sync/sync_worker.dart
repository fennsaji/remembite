import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../db/app_database.dart';
import '../network/api_client.dart';
import '../network/auth_state.dart';

part 'sync_worker.g.dart';

enum SyncStatus { idle, syncing, error }

/// Storage key for the incremental-download cursor, held as
/// `<rfc3339 updated_at>|<uuid>`. Stored in FlutterSecureStorage rather than a
/// new Drift table: it's one tiny scalar per user, the app already depends on
/// secure storage for auth (no new dependency, no migration), and losing it is
/// harmless — the next sync simply falls back to a full paged download.
const _syncCursorKeyPrefix = 'sync_cursor_';

/// Page size requested from GET /sync/full. The server clamps to 1..=2000.
const _syncPageLimit = 500;

/// Safety valve so a server that always reports has_more can't spin forever.
const _maxSyncPages = 200;

@riverpod
class SyncWorker extends _$SyncWorker {
  Timer? _pollTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _isSyncing = false;
  bool _disposed = false;
  bool _paused = false;

  @override
  SyncStatus build() {
    ref.onDispose(() {
      _disposed = true;
      _pollTimer?.cancel();
      _connectivitySub?.cancel();
    });
    _startPolling();
    _listenConnectivity();
    return SyncStatus.idle;
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _syncPending(),
    );
  }

  void _listenConnectivity() {
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      if (results.any((r) => r != ConnectivityResult.none)) {
        _syncPending();
      }
    });
  }

  /// Whether background sync is currently paused. The Settings toggle reads
  /// this so it reflects the worker's real state instead of defaulting to
  /// "on" every time the screen is rebuilt.
  bool get isPaused => _paused;

  void setPaused(bool paused) {
    _paused = paused;
  }

  /// Force an immediate sync cycle. Called after Pro upgrade.
  Future<void> syncNow() => _syncPending();

  Future<void> _syncPending() async {
    if (_paused) return;
    if (_isSyncing) return;
    _isSyncing = true;
    try {
      final auth = ref.read(authStateProvider).value;
      if (auth == null) return;

      final db = ref.read(appDatabaseProvider);
      final dio = ref.read(apiClientProvider);

      if (auth.isPro) {
        // Cross-device restore is a Pro feature. First sync on this device (no local rows and no saved cursor) does
        // a full paged download. Afterwards the saved cursor makes every
        // resync incremental instead of re-downloading a lifetime of history.
        final cursor = await _readCursor(auth.id);
        final localCount = await db.reactionDao.getTotalReactionCount(
          auth.id,
        );
        if (localCount == 0 || cursor != null) {
          await _pullFromCloud(db, dio, auth, cursor);
        }
      }

      // Retry uploading THIS device's own unsynced reactions for every user,
      // Pro or free. This isn't the cross-device "cloud sync" feature above
      // (still Pro-gated) — it's just making sure a reaction that failed to
      // reach the server (submitted while offline) eventually does. Without
      // this, a free user's offline reaction stayed correct locally forever
      // but never reached the server, permanently missing from community
      // counts and their own taste-profile progress (both server-computed).
      final pending = await db.reactionDao.getPendingSync(auth.id);
      if (pending.isEmpty) {
        if (state == SyncStatus.error && !_disposed) state = SyncStatus.idle;
        return;
      }

      if (!_disposed) state = SyncStatus.syncing;
      for (final r in pending) {
        try {
          await dio.post(
            '/dishes/${r.dishId}/reactions',
            data: {
              'reaction': r.reaction,
              if (r.notes != null) 'notes': r.notes,
            },
          );
          await db.reactionDao.markSynced(r.id);
        } catch (_) {
          // Individual failure — continue with others
        }
      }
      if (!_disposed) state = SyncStatus.idle;
    } catch (_) {
      if (!_disposed) state = SyncStatus.error;
    } finally {
      _isSyncing = false;
    }
  }

  static const _secureStorage = FlutterSecureStorage();

  /// Returns the saved `<updated_at>|<id>` cursor, or null on first sync.
  Future<String?> _readCursor(String userId) async {
    try {
      return await _secureStorage.read(key: '$_syncCursorKeyPrefix$userId');
    } catch (_) {
      return null; // unreadable cursor == first sync; safe, just re-downloads
    }
  }

  Future<void> _writeCursor(String userId, String cursor) async {
    try {
      await _secureStorage.write(
        key: '$_syncCursorKeyPrefix$userId',
        value: cursor,
      );
    } catch (_) {
      // Non-fatal: the next sync just starts from the previous cursor.
    }
  }

  /// Pages through GET /sync/full using the server's next_since/next_since_id
  /// cursor, persisting after each successful page so an interrupted sync
  /// resumes where it stopped rather than restarting from the beginning.
  Future<void> _pullFromCloud(
    AppDatabase db,
    Dio dio,
    AuthUser auth,
    String? startCursor,
  ) async {
    try {
      var cursor = startCursor;
      for (var page = 0; page < _maxSyncPages; page++) {
        final parts = cursor?.split('|');
        final resp = await dio.get(
          '/sync/full',
          queryParameters: {
            'limit': _syncPageLimit,
            if (parts != null && parts.isNotEmpty && parts.first.isNotEmpty)
              'since': parts.first,
            if (parts != null && parts.length > 1 && parts[1].isNotEmpty)
              'since_id': parts[1],
          },
        );

        final data = resp.data as Map<String, dynamic>;
        final reactions = (data['reactions'] as List? ?? const [])
            .cast<Map<String, dynamic>>();
        for (final r in reactions) {
          await db.reactionDao.upsert(
            ReactionsCompanion(
              id: Value(r['id'] as String),
              userId: Value(auth.id),
              dishId: Value(r['dish_id'] as String),
              reaction: Value(r['reaction'] as String),
              notes: Value(r['notes'] as String?),
              createdAt: Value(
                DateTime.tryParse(r['updated_at'] as String? ?? '') ??
                    DateTime.now(),
              ),
              updatedAt: Value(DateTime.now()),
              syncedAt: Value(DateTime.now()),
            ),
          );
        }

        // An older server (no cursor fields) returns everything in one shot:
        // nextSince is null and hasMore false, so we stop after one page and
        // behave exactly as before.
        final nextSince = data['next_since'] as String?;
        final nextSinceId = data['next_since_id'] as String?;
        final hasMore = data['has_more'] == true;

        if (nextSince != null) {
          cursor = '$nextSince|${nextSinceId ?? ''}';
          await _writeCursor(auth.id, cursor);
        }
        if (!hasMore || nextSince == null) break;
      }
    } catch (_) {
      // Cloud pull failed — not fatal, user still has local data. The cursor
      // stays at the last fully-applied page.
    }
  }
}
