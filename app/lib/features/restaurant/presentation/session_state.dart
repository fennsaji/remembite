import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'session_state.g.dart';

typedef RestaurantSessionRecord = ({int reactionCount, bool ratingShown});

@riverpod
class RestaurantSessionState extends _$RestaurantSessionState {
  @override
  RestaurantSessionRecord build(String restaurantId) =>
      (reactionCount: 0, ratingShown: false);

  void incrementReaction() {
    state = (reactionCount: state.reactionCount + 1, ratingShown: state.ratingShown);
  }

  void markRatingShown() {
    state = (reactionCount: state.reactionCount, ratingShown: true);
  }
}
