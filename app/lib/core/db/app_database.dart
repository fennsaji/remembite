import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'daos/dish_dao.dart';
import 'daos/reaction_dao.dart';
import 'daos/restaurant_dao.dart';
import 'tables/dishes_table.dart';
import 'tables/favorites_table.dart';
import 'tables/ratings_table.dart';
import 'tables/reactions_table.dart';
import 'tables/restaurants_table.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Restaurants,
    Dishes,
    Reactions,
    Ratings,
    Favorites,
  ],
  daos: [
    RestaurantDao,
    DishDao,
    ReactionDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(reactions, reactions.updatedAt);
        // Backfill: existing rows get created_at as their initial updated_at
        await m.database.customStatement(
          'UPDATE reactions SET updated_at = created_at WHERE updated_at IS NULL',
        );
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

@riverpod
AppDatabase appDatabase(Ref ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
}
