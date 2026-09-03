import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'daos/dish_dao.dart';
import 'daos/dish_intents_dao.dart';
import 'daos/favorites_dao.dart';
import 'daos/reaction_dao.dart';
import 'daos/restaurant_dao.dart';
import 'tables/dish_intents_table.dart';
import 'tables/dishes_table.dart';
import 'tables/favorites_table.dart';
import 'tables/ratings_table.dart';
import 'tables/reactions_table.dart';
import 'tables/restaurants_table.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [Restaurants, Dishes, Reactions, Ratings, Favorites, DishIntents],
  daos: [RestaurantDao, DishDao, ReactionDao, FavoritesDao, DishIntentsDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        // reactions.updatedAt is declared with withDefault(currentDateAndTime)
        // — m.addColumn() would emit the full column definition including
        // that DEFAULT clause, and SQLite rejects a non-constant expression
        // (CURRENT_TIMESTAMP) as an ALTER TABLE ADD COLUMN default. That
        // throw would fail onUpgrade entirely, so the database would never
        // open again for any v1 install. Add the column bare (no default,
        // nullable at the SQL level) via raw SQL instead — Drift's
        // generated Dart API still treats the field as required and always
        // supplies a value on writes going forward, so the relaxed SQL-level
        // nullability never surfaces in the app.
        await m.database.customStatement(
          'ALTER TABLE reactions ADD COLUMN updated_at INTEGER',
        );
        // Backfill: existing rows get created_at as their initial updated_at
        await m.database.customStatement(
          'UPDATE reactions SET updated_at = created_at WHERE updated_at IS NULL',
        );
      }
      if (from < 3) {
        await m.addColumn(restaurants, restaurants.googlePlaceId);
        await m.addColumn(restaurants, restaurants.googleRating);
        await m.addColumn(restaurants, restaurants.googleRatingCount);
        await m.addColumn(restaurants, restaurants.priceLevel);
        await m.addColumn(restaurants, restaurants.businessStatus);
        await m.addColumn(restaurants, restaurants.phoneNumber);
        await m.addColumn(restaurants, restaurants.websiteUrl);
        await m.addColumn(restaurants, restaurants.openingHours);
      }
      if (from < 4) {
        await m.createTable(dishIntents);
      }
      if (from < 5 && from >= 4) {
        // dish_intents had no userId column — every "want to try" bookmark
        // was global to the device, not the signed-in account. On a shared
        // device or a second account signing in, that meant user B saw (and
        // could clear) user A's bookmarks. This is a purely local cache
        // (never synced as history), introduced only one version ago at
        // schema v4, so there's no safe way to retroactively attribute
        // existing rows to a user — drop and recreate with the new column
        // rather than guess. (A fresh install jumping straight from <4 to 5
        // already gets the current — userId-having — schema from the
        // `from < 4` branch above, so this only needs to run for from == 4.)
        await m.deleteTable('dish_intents');
        await m.createTable(dishIntents);
      }
      if (from < 6) {
        // Private notes were POSTed to the server but never stored locally,
        // so an offline (or failed) write lost the note for good and the
        // background sync had nothing to retry. Nullable, no default —
        // plain addColumn is safe here.
        await m.addColumn(reactions, reactions.notes);
      }
    },
  );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'remembite.db'));
    return NativeDatabase(file);
  });
}

// keepAlive: this is read via `ref.read` (not `ref.watch`) from several
// one-off call sites (sync_worker, auth_state's FCM registration, billing
// service) that establish no subscription — under autoDispose those reads
// could see the provider torn down (db.close()) mid-cycle by an unrelated
// rebuild elsewhere, throwing "database is closed" from whichever call
// happened to lose the race.
@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
}
