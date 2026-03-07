import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/dishes_table.dart';
import '../tables/favorites_table.dart';
import '../tables/reactions_table.dart';
import '../tables/restaurants_table.dart';

part 'favorites_dao.g.dart';

class FavoritedDish {
  final String dishId;
  final String dishName;
  final String restaurantId;
  final String restaurantName;
  final String? reaction;
  final DateTime favoritedAt;

  const FavoritedDish({
    required this.dishId,
    required this.dishName,
    required this.restaurantId,
    required this.restaurantName,
    this.reaction,
    required this.favoritedAt,
  });
}

@DriftAccessor(tables: [Favorites, Dishes, Restaurants, Reactions])
class FavoritesDao extends DatabaseAccessor<AppDatabase>
    with _$FavoritesDaoMixin {
  FavoritesDao(super.db);

  Stream<List<FavoritedDish>> getFavorites(String userId) {
    return customSelect(
      '''
      SELECT
        f.dish_id,
        d.name           AS dish_name,
        d.restaurant_id,
        r.name           AS restaurant_name,
        rx.reaction,
        f.created_at     AS favorited_at
      FROM favorites f
      JOIN dishes d ON d.id = f.dish_id
      JOIN restaurants r ON r.id = d.restaurant_id
      LEFT JOIN reactions rx ON rx.id = (
        SELECT id FROM reactions
        WHERE dish_id = f.dish_id AND user_id = f.user_id
        ORDER BY updated_at DESC
        LIMIT 1
      )
      WHERE f.user_id = ?
      ORDER BY f.created_at DESC
      ''',
      variables: [Variable.withString(userId)],
      readsFrom: {favorites, dishes, restaurants, reactions},
    ).watch().map(
      (rows) => rows
          .map(
            (row) => FavoritedDish(
              dishId: row.read<String>('dish_id'),
              dishName: row.read<String>('dish_name'),
              restaurantId: row.read<String>('restaurant_id'),
              restaurantName: row.read<String>('restaurant_name'),
              reaction: row.readNullable<String>('reaction'),
              favoritedAt: row.read<DateTime>('favorited_at'),
            ),
          )
          .toList(),
    );
  }

  /// Toggles the favorite state for [dishId] by [userId].
  /// Returns `true` if the dish is now favorited, `false` if unfavorited.
  Future<bool> toggleFavorite(String userId, String dishId) async {
    final existing =
        await (select(favorites)
              ..where((f) => f.userId.equals(userId) & f.dishId.equals(dishId)))
            .getSingleOrNull();

    if (existing != null) {
      await (delete(
        favorites,
      )..where((f) => f.userId.equals(userId) & f.dishId.equals(dishId))).go();
      return false;
    } else {
      await into(favorites).insert(
        FavoritesCompanion.insert(
          userId: userId,
          dishId: dishId,
          createdAt: DateTime.now(),
        ),
      );
      return true;
    }
  }
}
