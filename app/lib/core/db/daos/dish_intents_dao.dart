import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../app_database.dart';
import '../tables/dish_intents_table.dart';

part 'dish_intents_dao.g.dart';

@DriftAccessor(tables: [DishIntents])
class DishIntentsDao extends DatabaseAccessor<AppDatabase>
    with _$DishIntentsDaoMixin {
  DishIntentsDao(super.db);

  Future<bool> isWantToTry(String dishId) async {
    final row = await (select(
      dishIntents,
    )..where((t) => t.dishId.equals(dishId))).getSingleOrNull();
    return row != null;
  }

  Future<void> setWantToTry(String dishId, bool active) async {
    if (active) {
      final exists = await isWantToTry(dishId);
      if (!exists) {
        await into(dishIntents).insert(
          DishIntentsCompanion.insert(id: const Uuid().v4(), dishId: dishId),
        );
      }
    } else {
      await (delete(dishIntents)..where((t) => t.dishId.equals(dishId))).go();
    }
  }

  Future<void> removeOnReaction(String dishId) async {
    await (delete(dishIntents)..where((t) => t.dishId.equals(dishId))).go();
  }

  Stream<List<String>> watchAllDishIds() =>
      select(dishIntents).map((r) => r.dishId).watch();
}
