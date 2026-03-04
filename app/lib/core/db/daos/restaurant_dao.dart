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
    // Returns restaurants that have reactions from this user, ordered by most recent.
    // Uses GROUP BY + MAX(updated_at) to avoid the SQLite DISTINCT + ORDER BY non-selected
    // column pitfall, and lists all three read tables so Drift invalidates the query correctly.
    final query = customSelect(
      '''
      SELECT r.id, r.name, r.city, r.latitude, r.longitude,
             r.cuisine_type, r.google_place_id, r.google_rating, r.google_rating_count,
             r.price_level, r.business_status, r.phone_number, r.website_url,
             r.opening_hours, r.avg_rating, r.rating_count, r.synced_at
      FROM restaurants r
      JOIN dishes d ON d.restaurant_id = r.id
      JOIN reactions rx ON rx.dish_id = d.id
      WHERE rx.user_id = ?
      GROUP BY r.id
      ORDER BY MAX(rx.updated_at) DESC
      LIMIT ?
      ''',
      variables: [Variable.withString(userId), Variable.withInt(limit)],
      readsFrom: {restaurants, attachedDatabase.dishes, attachedDatabase.reactions},
    );

    return query.map((row) => RestaurantRow(
      id: row.read<String>('id'),
      name: row.read<String>('name'),
      city: row.read<String>('city'),
      latitude: row.read<double>('latitude'),
      longitude: row.read<double>('longitude'),
      cuisineType: row.readNullable<String>('cuisine_type'),
      googlePlaceId: row.readNullable<String>('google_place_id'),
      googleRating: row.readNullable<double>('google_rating'),
      googleRatingCount: row.readNullable<int>('google_rating_count'),
      priceLevel: row.readNullable<int>('price_level'),
      businessStatus: row.readNullable<String>('business_status'),
      phoneNumber: row.readNullable<String>('phone_number'),
      websiteUrl: row.readNullable<String>('website_url'),
      openingHours: row.readNullable<String>('opening_hours'),
      avgRating: row.readNullable<double>('avg_rating'),
      ratingCount: row.read<int>('rating_count'),
      syncedAt: row.readNullable<DateTime>('synced_at'),
    )).get();
  }
}
