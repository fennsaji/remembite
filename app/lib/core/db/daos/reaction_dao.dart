import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/reactions_table.dart';

part 'reaction_dao.g.dart';

@DriftAccessor(tables: [Reactions])
class ReactionDao extends DatabaseAccessor<AppDatabase>
    with _$ReactionDaoMixin {
  ReactionDao(super.db);

  Future<ReactionRow?> getByUserAndDish(String userId, String dishId) =>
      (select(reactions)
            ..where((r) => r.userId.equals(userId) & r.dishId.equals(dishId)))
          .getSingleOrNull();

  Future<List<ReactionRow>> getByUser(String userId) =>
      (select(reactions)..where((r) => r.userId.equals(userId))).get();

  Future<List<ReactionRow>> getPendingSync() =>
      (select(reactions)..where((r) => r.syncedAt.isNull())).get();

  Future<void> upsert(ReactionsCompanion row) async {
    await (update(reactions)
          ..where((r) =>
              r.userId.equals(row.userId.value) &
              r.dishId.equals(row.dishId.value)))
        .write(ReactionsCompanion(
          reaction: row.reaction,
          syncedAt: row.syncedAt,
        ));

    final existing = await (select(reactions)
          ..where((r) =>
              r.userId.equals(row.userId.value) &
              r.dishId.equals(row.dishId.value)))
        .getSingleOrNull();

    if (existing == null) {
      await into(reactions).insert(row);
    }
  }

  Future<void> markSynced(String id) async {
    await (update(reactions)..where((r) => r.id.equals(id)))
        .write(ReactionsCompanion(syncedAt: Value(DateTime.now())));
  }
}
