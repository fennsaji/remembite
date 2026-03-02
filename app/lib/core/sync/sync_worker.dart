import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
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

  Future<void> _syncPending() async {
    if (_isSyncing) return;
    _isSyncing = true;
    try {
      final auth = ref.read(authStateProvider).value;
      if (auth == null) return;
      if (!auth.isPro) return; // free users: local only

      final db = ref.read(appDatabaseProvider);
      final dio = ref.read(apiClientProvider);

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
}
