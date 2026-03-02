import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/dishes_table.dart';

part 'dish_dao.g.dart';

@DriftAccessor(tables: [Dishes])
class DishDao extends DatabaseAccessor<AppDatabase> with _$DishDaoMixin {
  DishDao(super.db);

  Future<DishRow?> getById(String id) =>
      (select(dishes)..where((d) => d.id.equals(id))).getSingleOrNull();

  Future<List<DishRow>> getByRestaurant(String restaurantId) =>
      (select(dishes)..where((d) => d.restaurantId.equals(restaurantId))
        ..orderBy([(d) => OrderingTerm.desc(d.communityScore)]))
          .get();

  Future<void> upsert(DishesCompanion row) =>
      into(dishes).insertOnConflictUpdate(row);

  Future<void> upsertAll(List<DishesCompanion> rows) async {
    await batch((b) => b.insertAllOnConflictUpdate(dishes, rows));
  }
}
