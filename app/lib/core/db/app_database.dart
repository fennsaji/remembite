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
  int get schemaVersion => 1;
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
