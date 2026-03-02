import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/restaurants_table.dart';

part 'restaurant_dao.g.dart';

@DriftAccessor(tables: [Restaurants])
class RestaurantDao extends DatabaseAccessor<AppDatabase>
    with _$RestaurantDaoMixin {
  RestaurantDao(super.db);

  Future<RestaurantRow?> getById(String id) =>
      (select(restaurants)..where((r) => r.id.equals(id))).getSingleOrNull();

  Future<List<RestaurantRow>> getAll() => select(restaurants).get();

  Future<void> upsert(RestaurantsCompanion row) =>
      into(restaurants).insertOnConflictUpdate(row);

  Future<List<RestaurantRow>> getRecentlyVisited(String userId, {int limit = 5}) {
    // Returns restaurants that have reactions from this user, ordered by most recent
    final query = customSelect(
      '''
      SELECT DISTINCT r.* FROM restaurants r
      JOIN dishes d ON d.restaurant_id = r.id
      JOIN reactions rx ON rx.dish_id = d.id
      WHERE rx.user_id = ?
      ORDER BY rx.created_at DESC
      LIMIT ?
      ''',
      variables: [Variable.withString(userId), Variable.withInt(limit)],
      readsFrom: {restaurants},
    );

    return query.map((row) => RestaurantRow(
      id: row.read<String>('id'),
      name: row.read<String>('name'),
      city: row.read<String>('city'),
      latitude: row.read<double>('latitude'),
      longitude: row.read<double>('longitude'),
      cuisineType: row.readNullable<String>('cuisine_type'),
      avgRating: row.readNullable<double>('avg_rating'),
      ratingCount: row.read<int>('rating_count'),
      syncedAt: row.readNullable<DateTime>('synced_at'),
    )).get();
  }
}
