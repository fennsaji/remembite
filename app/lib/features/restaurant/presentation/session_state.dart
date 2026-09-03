import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'session_state.g.dart';

typedef RestaurantSessionRecord = ({
  Set<String> reactedDishIds,
  bool ratingShown,
});

extension RestaurantSessionRecordX on RestaurantSessionRecord {
  /// Number of *distinct* dishes reacted to this session. Re-reacting to
  /// the same dish (e.g. changing 🔥 → 😐) does not count twice, so the
  /// passive rating prompt can't fire after a single dish.
  int get reactionCount => reactedDishIds.length;
}

@riverpod
class RestaurantSessionState extends _$RestaurantSessionState {
  @override
  RestaurantSessionRecord build(String restaurantId) =>
      (reactedDishIds: const {}, ratingShown: false);

  void recordReaction(String dishId) {
    if (state.reactedDishIds.contains(dishId)) return;
    state = (
      reactedDishIds: {...state.reactedDishIds, dishId},
      ratingShown: state.ratingShown,
    );
  }

  void markRatingShown() {
    state = (reactedDishIds: state.reactedDishIds, ratingShown: true);
  }
}
