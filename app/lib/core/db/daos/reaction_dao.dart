import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/reactions_table.dart';

part 'reaction_dao.g.dart';

class TopBiteRow {
  final String dishId;
  final String dishName;
  final String? category;
  final String reaction;

  const TopBiteRow({
    required this.dishId,
    required this.dishName,
    this.category,
    required this.reaction,
  });
}

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

  Future<List<TopBiteRow>> getTopBitesForRestaurant(
      String userId, String restaurantId) {
    final query = customSelect(
      '''
      SELECT d.id, d.name, d.category, rx.reaction
      FROM reactions rx
      JOIN dishes d ON d.id = rx.dish_id
      WHERE rx.user_id = ? AND d.restaurant_id = ?
      ORDER BY
        CASE rx.reaction
          WHEN 'so_yummy'    THEN 5
          WHEN 'tasty'       THEN 4
          WHEN 'pretty_good' THEN 3
          WHEN 'meh'         THEN 2
          WHEN 'never_again' THEN 1
          ELSE 0
        END DESC,
        rx.updated_at DESC
      LIMIT 10
      ''',
      variables: [
        Variable.withString(userId),
        Variable.withString(restaurantId),
      ],
      readsFrom: {reactions, attachedDatabase.dishes},
    );
    return query
        .map((row) => TopBiteRow(
              dishId: row.read<String>('id'),
              dishName: row.read<String>('name'),
              category: row.readNullable<String>('category'),
              reaction: row.read<String>('reaction'),
            ))
        .get();
  }

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
          updatedAt: Value(DateTime.now()),
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
        .write(ReactionsCompanion(
          syncedAt: Value(DateTime.now()),
          updatedAt: Value(DateTime.now()),
        ));
  }
}
