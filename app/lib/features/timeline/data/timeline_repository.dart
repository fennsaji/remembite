import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/api_client.dart';

part 'timeline_repository.g.dart';

// ─────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────

class DishReactionItem {
  final String dishId;
  final String dishName;
  final String reaction;
  final DateTime reactedAt;

  const DishReactionItem({
    required this.dishId,
    required this.dishName,
    required this.reaction,
    required this.reactedAt,
  });

  factory DishReactionItem.fromJson(Map<String, dynamic> json) =>
      DishReactionItem(
        dishId: json['dish_id'] as String,
        dishName: json['dish_name'] as String,
        reaction: json['reaction'] as String,
        reactedAt: DateTime.parse(json['reacted_at'] as String),
      );
}

class TimelineEntry {
  final String restaurantId;
  final String restaurantName;
  final String date; // YYYY-MM-DD
  final List<DishReactionItem> reactions;

  const TimelineEntry({
    required this.restaurantId,
    required this.restaurantName,
    required this.date,
    required this.reactions,
  });

  factory TimelineEntry.fromJson(Map<String, dynamic> json) => TimelineEntry(
    restaurantId: json['restaurant_id'] as String,
    restaurantName: json['restaurant_name'] as String,
    date: json['date'] as String,
    reactions: (json['reactions'] as List<dynamic>)
        .map((r) => DishReactionItem.fromJson(r as Map<String, dynamic>))
        .toList(),
  );
}

// ─────────────────────────────────────────────
// Repository
// ─────────────────────────────────────────────

class TimelineRepository {
  TimelineRepository(this._dio);
  final Dio _dio;

  Future<List<TimelineEntry>> getTimeline() async {
    final response = await _dio.get('/users/me/timeline');
    final data = response.data as Map<String, dynamic>;
    return (data['entries'] as List<dynamic>)
        .map((e) => TimelineEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

@riverpod
TimelineRepository timelineRepository(Ref ref) {
  return TimelineRepository(ref.watch(apiClientProvider));
}
