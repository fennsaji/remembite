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
    String userId,
    String restaurantId,
  ) {
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
        .map(
          (row) => TopBiteRow(
            dishId: row.read<String>('id'),
            dishName: row.read<String>('name'),
            category: row.readNullable<String>('category'),
            reaction: row.read<String>('reaction'),
          ),
        )
        .get();
  }

  Stream<List<TopBiteRow>> watchTopBitesForRestaurant(
    String userId,
    String restaurantId,
  ) {
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
        .map(
          (row) => TopBiteRow(
            dishId: row.read<String>('id'),
            dishName: row.read<String>('name'),
            category: row.readNullable<String>('category'),
            reaction: row.read<String>('reaction'),
          ),
        )
        .watch();
  }

  /// Unfiltered by user, this returned every device-local pending row
  /// regardless of who wrote it — on a shared device, signing in as a
  /// second (Pro) account would then upload the FIRST account's unsynced
  /// reactions to the server authenticated as the second account,
  /// permanently misattributing them.
  Future<List<ReactionRow>> getPendingSync(String userId) => (select(
    reactions,
  )..where((r) => r.userId.equals(userId) & r.syncedAt.isNull())).get();

  /// On conflict (same user + dish) `notes` is only overwritten when the
  /// caller actually supplied one — a reaction-only update must not clobber
  /// an existing note. Mirrors the server's
  /// `notes = COALESCE(EXCLUDED.notes, dish_reactions.notes)`.
  Future<void> upsert(ReactionsCompanion row) async {
    await (update(reactions)..where(
          (r) =>
              r.userId.equals(row.userId.value) &
              r.dishId.equals(row.dishId.value),
        ))
        .write(
          ReactionsCompanion(
            reaction: row.reaction,
            notes: (row.notes.present && row.notes.value != null)
                ? row.notes
                : const Value.absent(),
            syncedAt: row.syncedAt,
            updatedAt: Value(DateTime.now()),
          ),
        );

    final existing =
        await (select(reactions)..where(
              (r) =>
                  r.userId.equals(row.userId.value) &
                  r.dishId.equals(row.dishId.value),
            ))
            .getSingleOrNull();

    if (existing == null) {
      await into(reactions).insert(row);
    }
  }

  Future<void> markSynced(String id) async {
    await (update(reactions)..where((r) => r.id.equals(id))).write(
      ReactionsCompanion(
        syncedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Total distinct restaurants the user has reacted at.
  Future<int> getRestaurantCount(String userId) async {
    final query = customSelect(
      '''
      SELECT COUNT(DISTINCT d.restaurant_id) as cnt
      FROM reactions rx
      JOIN dishes d ON d.id = rx.dish_id
      WHERE rx.user_id = ?
      ''',
      variables: [Variable.withString(userId)],
      readsFrom: {reactions, attachedDatabase.dishes},
    );
    final rows = await query.get();
    return rows.first.read<int>('cnt');
  }

  /// Total distinct dishes the user has reacted to.
  Future<int> getDishCount(String userId) async {
    final result =
        await (selectOnly(reactions)
              ..addColumns([reactions.dishId.count(distinct: true)])
              ..where(reactions.userId.equals(userId)))
            .getSingleOrNull();
    return result?.read(reactions.dishId.count(distinct: true)) ?? 0;
  }

  /// Total reactions (for taste profile progress: count / 10).
  Future<int> getTotalReactionCount(String userId) async {
    final result =
        await (selectOnly(reactions)
              ..addColumns([reactions.id.count()])
              ..where(reactions.userId.equals(userId)))
            .getSingleOrNull();
    return result?.read(reactions.id.count()) ?? 0;
  }

  /// Most used reaction (e.g. "so_yummy").
  Future<String?> getMostUsedReaction(String userId) async {
    final query = customSelect(
      '''
      SELECT reaction, COUNT(*) as cnt
      FROM reactions
      WHERE user_id = ?
      GROUP BY reaction
      ORDER BY cnt DESC
      LIMIT 1
      ''',
      variables: [Variable.withString(userId)],
      readsFrom: {reactions},
    );
    final rows = await query.get();
    if (rows.isEmpty) return null;
    return rows.first.read<String>('reaction');
  }
}
