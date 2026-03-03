import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

import '../../../core/billing/pro_status_provider.dart';
import '../../../core/db/app_database.dart';
import '../../../core/network/api_client.dart';

part 'dish_repository.g.dart';

// ─────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────

class DishDetail {
  final String id;
  final String restaurantId;
  final String name;
  final String? category;
  final int? price;
  final String attributeState;
  final double? communityScore;
  final int voteCount;
  final AttributePriors? attributePriors;

  const DishDetail({
    required this.id,
    required this.restaurantId,
    required this.name,
    this.category,
    this.price,
    required this.attributeState,
    this.communityScore,
    required this.voteCount,
    this.attributePriors,
  });

  factory DishDetail.fromJson(Map<String, dynamic> json) => DishDetail(
    id: json['id'] as String,
    restaurantId: json['restaurant_id'] as String,
    name: json['name'] as String,
    category: json['category'] as String?,
    price: json['price'] as int?,
    attributeState: json['attribute_state'] as String,
    communityScore: (json['community_score'] as num?)?.toDouble(),
    voteCount: json['vote_count'] as int,
    attributePriors: json['attribute_priors'] != null
        ? AttributePriors.fromJson(
            json['attribute_priors'] as Map<String, dynamic>)
        : null,
  );
}

class AttributePriors {
  final double spiceScore;
  final double sweetnessScore;
  final String dishType;
  final String cuisine;
  final double? finalSpiceScore;
  final double? finalSweetnessScore;
  final int communityVoteCount;
  final double? confidenceScore;

  const AttributePriors({
    required this.spiceScore,
    required this.sweetnessScore,
    required this.dishType,
    required this.cuisine,
    this.finalSpiceScore,
    this.finalSweetnessScore,
    required this.communityVoteCount,
    this.confidenceScore,
  });

  factory AttributePriors.fromJson(Map<String, dynamic> json) =>
      AttributePriors(
        spiceScore: (json['spice_score'] as num).toDouble(),
        sweetnessScore: (json['sweetness_score'] as num).toDouble(),
        dishType: json['dish_type'] as String,
        cuisine: json['cuisine'] as String,
        finalSpiceScore: (json['final_spice_score'] as num?)?.toDouble(),
        finalSweetnessScore:
            (json['final_sweetness_score'] as num?)?.toDouble(),
        communityVoteCount: json['community_vote_count'] as int,
        confidenceScore: (json['confidence_score'] as num?)?.toDouble(),
      );
}

class CompatibilitySignal {
  final String? signal;
  final double? score;
  final String? reason;

  const CompatibilitySignal({this.signal, this.score, this.reason});

  factory CompatibilitySignal.fromJson(Map<String, dynamic> json) =>
      CompatibilitySignal(
        signal: json['signal'] as String?,
        score: (json['score'] as num?)?.toDouble(),
        reason: json['reason'] as String?,
      );
}

class DishItem {
  final String id;
  final String restaurantId;
  final String name;
  final String? category;
  final int? price;
  final String attributeState;
  final double? communityScore;
  final int voteCount;

  const DishItem({
    required this.id,
    required this.restaurantId,
    required this.name,
    this.category,
    this.price,
    required this.attributeState,
    this.communityScore,
    required this.voteCount,
  });

  factory DishItem.fromJson(Map<String, dynamic> json) => DishItem(
    id: json['id'] as String,
    restaurantId: json['restaurant_id'] as String,
    name: json['name'] as String,
    category: json['category'] as String?,
    price: json['price'] as int?,
    attributeState: json['attribute_state'] as String,
    communityScore: (json['community_score'] as num?)?.toDouble(),
    voteCount: json['vote_count'] as int,
  );
}

class ReactionSummary {
  final int total;
  final Map<String, int> breakdown;
  final double weightedScore;

  const ReactionSummary({
    required this.total,
    required this.breakdown,
    required this.weightedScore,
  });

  factory ReactionSummary.fromJson(Map<String, dynamic> json) =>
      ReactionSummary(
        total: (json['total'] as num).toInt(),
        breakdown: (json['breakdown'] as Map<String, dynamic>)
            .map((k, v) => MapEntry(k, (v as num).toInt())),
        weightedScore: (json['weighted_score'] as num).toDouble(),
      );
}

// ─────────────────────────────────────────────
// Repository
// ─────────────────────────────────────────────

class DishRepository {
  DishRepository(this._dio, this._db);

  final Dio _dio;
  final AppDatabase _db;

  Future<List<DishItem>> getDishesByRestaurant(String restaurantId) async {
    final response = await _dio.get('/restaurants/$restaurantId/dishes');
    final items = (response.data as List<dynamic>)
        .map((d) => DishItem.fromJson(d as Map<String, dynamic>))
        .toList();

    // Cache locally
    await _db.dishDao.upsertAll(items
        .map((d) => DishesCompanion(
              id: Value(d.id),
              restaurantId: Value(d.restaurantId),
              name: Value(d.name),
              category: Value(d.category),
              price: Value(d.price),
              attributeState: Value(d.attributeState),
              communityScore: Value(d.communityScore),
              voteCount: Value(d.voteCount),
              syncedAt: Value(DateTime.now()),
            ))
        .toList());

    return items;
  }

  Future<DishDetail> getDishDetail(String id) async {
    final response = await _dio.get('/dishes/$id');
    return DishDetail.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<DishItem>> batchCreateDishes(
    String restaurantId,
    List<Map<String, dynamic>> dishes,
  ) async {
    final response = await _dio.post(
      '/restaurants/$restaurantId/dishes',
      data: {'dishes': dishes},
    );
    return (response.data as List<dynamic>)
        .map((d) => DishItem.fromJson(d as Map<String, dynamic>))
        .toList();
  }

  /// Write reaction locally first (optimistic), then sync to server.
  Future<void> upsertReaction({
    required String userId,
    required String dishId,
    required String reaction,
  }) async {
    const uuid = Uuid();
    // Optimistic local write (unsynced)
    await _db.reactionDao.upsert(
      ReactionsCompanion(
        id: Value(uuid.v4()),
        userId: Value(userId),
        dishId: Value(dishId),
        reaction: Value(reaction),
        createdAt: Value(DateTime.now()),
        syncedAt: const Value(null),
      ),
    );

    // Fire-and-forget sync
    try {
      await _dio.post('/dishes/$dishId/reactions', data: {'reaction': reaction});
      final local = await _db.reactionDao.getByUserAndDish(userId, dishId);
      if (local != null) {
        await _db.reactionDao.markSynced(local.id);
      }
    } catch (_) {
      // Will sync later via background job
    }
  }

  Future<ReactionSummary> getReactionSummary(String dishId) async {
    final response = await _dio.get('/dishes/$dishId/reactions/summary');
    return ReactionSummary.fromJson(response.data as Map<String, dynamic>);
  }

  Future<bool> toggleFavorite(String dishId) async {
    final response = await _dio.post('/dishes/$dishId/favorites');
    return (response.data as Map<String, dynamic>)['favorited'] as bool;
  }

  Future<void> upsertAttributeVote({
    required String dishId,
    required String attribute,
    required double value,
  }) async {
    await _dio.post(
      '/dishes/$dishId/attribute_votes',
      data: {'attribute': attribute, 'value': value},
    );
  }

  Future<List<DishRow>> getFavorites(String userId) async {
    throw UnimplementedError('Favorites screen is not yet implemented');
  }

  Future<CompatibilitySignal> getCompatibility(String dishId) async {
    final response = await _dio.get('/dishes/$dishId/compatibility');
    return CompatibilitySignal.fromJson(response.data as Map<String, dynamic>);
  }
}

@riverpod
DishRepository dishRepository(Ref ref) {
  return DishRepository(
    ref.watch(apiClientProvider),
    ref.watch(appDatabaseProvider),
  );
}

@riverpod
Future<CompatibilitySignal?> compatibilitySignal(
    Ref ref, String dishId) async {
  final isPro = ref.watch(proStatusProvider);
  if (!isPro) return null;
  try {
    return await ref.read(dishRepositoryProvider).getCompatibility(dishId);
  } catch (_) {
    return null;
  }
}
