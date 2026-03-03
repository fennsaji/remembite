import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../db/app_database.dart';
import '../network/api_client.dart';
import '../network/auth_state.dart';

part 'sync_worker.g.dart';

enum SyncStatus { idle, syncing, error }

@riverpod
class SyncWorker extends _$SyncWorker {
  Timer? _pollTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _isSyncing = false;
  bool _disposed = false;

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
    _connectivitySub = Connectivity()
        .onConnectivityChanged
        .listen((results) {
      if (results.any((r) => r != ConnectivityResult.none)) {
        _syncPending();
      }
    });
  }

  /// Force an immediate sync cycle. Called after Pro upgrade.
  Future<void> syncNow() => _syncPending();

  Future<void> _syncPending() async {
    if (_isSyncing) return;
    _isSyncing = true;
    try {
      final auth = ref.read(authStateProvider).value;
      if (auth == null) return;
      if (!auth.isPro) return; // free users: local only

      final db = ref.read(appDatabaseProvider);
      final dio = ref.read(apiClientProvider);

      // Cross-device pull: if no local reactions, fetch from cloud
      final localCount = await db.reactionDao.getTotalReactionCount(auth.id);
      if (localCount == 0) {
        await _pullFromCloud(db, dio, auth);
      }

      final pending = await db.reactionDao.getPendingSync();
      if (pending.isEmpty) {
        if (state == SyncStatus.error && !_disposed) state = SyncStatus.idle;
        return;
      }

      if (!_disposed) state = SyncStatus.syncing;
      for (final r in pending) {
        try {
          await dio.post(
            '/dishes/${r.dishId}/reactions',
            data: {'reaction': r.reaction},
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

  Future<void> _pullFromCloud(AppDatabase db, Dio dio, AuthUser auth) async {
    try {
      final resp = await dio.get('/sync/full');
      final reactions =
          (resp.data['reactions'] as List).cast<Map<String, dynamic>>();
      for (final r in reactions) {
        await db.reactionDao.upsert(ReactionsCompanion(
          id: Value(r['id'] as String),
          userId: Value(auth.id),
          dishId: Value(r['dish_id'] as String),
          reaction: Value(r['reaction'] as String),
          createdAt: Value(
              DateTime.tryParse(r['updated_at'] as String? ?? '') ??
                  DateTime.now()),
          updatedAt: Value(DateTime.now()),
          syncedAt: Value(DateTime.now()),
        ));
      }
    } catch (_) {
      // Cloud pull failed — not fatal, user still has local data
    }
  }
}
