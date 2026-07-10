import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../app_database.dart';
import '../tables/dish_intents_table.dart';

part 'dish_intents_dao.g.dart';

@DriftAccessor(tables: [DishIntents])
class DishIntentsDao extends DatabaseAccessor<AppDatabase>
    with _$DishIntentsDaoMixin {
  DishIntentsDao(super.db);

  Future<bool> isWantToTry(String userId, String dishId) async {
    final row = await (select(dishIntents)..where(
          (t) => t.userId.equals(userId) & t.dishId.equals(dishId),
        ))
        .getSingleOrNull();
    return row != null;
  }

  Future<void> setWantToTry(String userId, String dishId, bool active) async {
    if (active) {
      final exists = await isWantToTry(userId, dishId);
      if (!exists) {
        await into(dishIntents).insert(
          DishIntentsCompanion.insert(
            id: const Uuid().v4(),
            userId: userId,
            dishId: dishId,
          ),
        );
      }
    } else {
      await (delete(dishIntents)..where(
            (t) => t.userId.equals(userId) & t.dishId.equals(dishId),
          ))
          .go();
    }
  }

  Future<void> removeOnReaction(String userId, String dishId) async {
    await (delete(dishIntents)..where(
          (t) => t.userId.equals(userId) & t.dishId.equals(dishId),
        ))
        .go();
  }

  Stream<List<String>> watchAllDishIds(String userId) =>
      (select(
        dishIntents,
      )..where((t) => t.userId.equals(userId))).map((r) => r.dishId).watch();
}
