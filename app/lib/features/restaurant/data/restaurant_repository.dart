import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/db/app_database.dart';
import '../../../core/network/api_client.dart';

part 'restaurant_repository.g.dart';

// ─────────────────────────────────────────────
// Models (mirrors backend DTOs)
// ─────────────────────────────────────────────

class RestaurantDetail {
  final String id;
  final String name;
  final String city;
  final double latitude;
  final double longitude;
  final String? cuisineType;
  final double? avgRating;
  final int ratingCount;
  final List<DishSummary> topDishes;
  // Enrichment fields (populated when restaurant was added via Google Places)
  final String? businessStatus;
  final String? phoneNumber;
  final String? websiteUrl;
  final Map<String, dynamic>? openingHours;

  const RestaurantDetail({
    required this.id,
    required this.name,
    required this.city,
    required this.latitude,
    required this.longitude,
    this.cuisineType,
    this.avgRating,
    required this.ratingCount,
    required this.topDishes,
    this.businessStatus,
    this.phoneNumber,
    this.websiteUrl,
    this.openingHours,
  });

  /// Whether the place is permanently closed.
  bool get isPermanentlyClosed => businessStatus == 'PERMANENTLY_CLOSED';

  /// Whether the place is open right now (from the stored opening_hours snapshot).
  bool? get isOpenNow {
    final oh = openingHours;
    if (oh == null) return null;
    return oh['open_now'] as bool?;
  }

  /// Weekday text lines, e.g. ["Monday: 9:00 AM – 10:00 PM", …]
  List<String> get weekdayText {
    final oh = openingHours;
    if (oh == null) return [];
    return (oh['weekday_text'] as List<dynamic>? ?? []).cast<String>();
  }

  factory RestaurantDetail.fromJson(Map<String, dynamic> json) =>
      RestaurantDetail(
        id: json['id'] as String,
        name: json['name'] as String,
        city: json['city'] as String,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        cuisineType: json['cuisine_type'] as String?,
        avgRating: (json['avg_rating'] as num?)?.toDouble(),
        ratingCount: json['rating_count'] as int,
        topDishes: (json['top_dishes'] as List<dynamic>)
            .map((d) => DishSummary.fromJson(d as Map<String, dynamic>))
            .toList(),
        businessStatus: json['business_status'] as String?,
        phoneNumber: json['phone_number'] as String?,
        websiteUrl: json['website'] as String?,
        openingHours: json['opening_hours'] as Map<String, dynamic>?,
      );
}

class DishSummary {
  final String id;
  final String name;
  final String? category;
  final double? communityScore;

  const DishSummary({
    required this.id,
    required this.name,
    this.category,
    this.communityScore,
  });

  factory DishSummary.fromJson(Map<String, dynamic> json) => DishSummary(
    id: json['id'] as String,
    name: json['name'] as String,
    category: json['category'] as String?,
    communityScore: (json['community_score'] as num?)?.toDouble(),
  );
}

class RestaurantSummary {
  final String id;
  final String name;
  final String city;
  final String? cuisineType;
  final double? avgRating;
  final int ratingCount;
  final double latitude;
  final double longitude;

  const RestaurantSummary({
    required this.id,
    required this.name,
    required this.city,
    this.cuisineType,
    this.avgRating,
    required this.ratingCount,
    required this.latitude,
    required this.longitude,
  });

  factory RestaurantSummary.fromJson(Map<String, dynamic> json) =>
      RestaurantSummary(
        id: json['id'] as String,
        name: json['name'] as String,
        city: json['city'] as String,
        cuisineType: json['cuisine_type'] as String?,
        avgRating: (json['avg_rating'] as num?)?.toDouble(),
        ratingCount: json['rating_count'] as int,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
      );
}

class DuplicateCheckResult {
  final bool hasDuplicate;
  final List<RestaurantSummary> candidates;

  const DuplicateCheckResult({
    required this.hasDuplicate,
    required this.candidates,
  });
}

class ParsedDishItem {
  final String name;
  final int? priceRupees;
  final String? category;

  const ParsedDishItem({required this.name, this.priceRupees, this.category});

  factory ParsedDishItem.fromJson(Map<String, dynamic> json) => ParsedDishItem(
    name: json['name'] as String,
    priceRupees: json['price_rupees'] as int?,
    category: json['category'] as String?,
  );
}

// ─────────────────────────────────────────────
// Repository
// ─────────────────────────────────────────────

class RestaurantRepository {
  RestaurantRepository(this._dio, this._db);

  final Dio _dio;
  final AppDatabase _db;

  Future<RestaurantDetail> getRestaurantDetail(String id) async {
    final response = await _dio.get('/restaurants/$id');
    final detail = RestaurantDetail.fromJson(
      response.data as Map<String, dynamic>,
    );

    // Cache to local DB
    await _db.restaurantDao.upsert(
      RestaurantsCompanion(
        id: Value(detail.id),
        name: Value(detail.name),
        city: Value(detail.city),
        latitude: Value(detail.latitude),
        longitude: Value(detail.longitude),
        cuisineType: Value(detail.cuisineType),
        avgRating: Value(detail.avgRating),
        ratingCount: Value(detail.ratingCount),
        syncedAt: Value(DateTime.now()),
      ),
    );

    return detail;
  }

  Future<List<RestaurantSummary>> getNearbyRestaurants(
    double lat,
    double lng, {
    double radius = 2000,
  }) async {
    final response = await _dio.get(
      '/restaurants/nearby',
      queryParameters: {'lat': lat, 'lng': lng, 'radius': radius},
    );
    return (response.data as List<dynamic>)
        .map((r) => RestaurantSummary.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<RestaurantDetail> createRestaurant({
    required String name,
    required String city,
    required double latitude,
    required double longitude,
    String? cuisineType,
    String? googlePlaceId,
    double? googleRating,
    int? googleRatingCount,
    int? priceLevel,
    String? businessStatus,
    String? phoneNumber,
    String? websiteUrl,
    String? openingHoursJson,
  }) async {
    final response = await _dio.post(
      '/restaurants',
      data: {
        'name': name,
        'city': city,
        'latitude': latitude,
        'longitude': longitude,
        if (cuisineType != null) 'cuisine_type': cuisineType,
        if (googlePlaceId != null) 'google_place_id': googlePlaceId,
        if (googleRating != null) 'google_rating': googleRating,
        if (googleRatingCount != null) 'google_rating_count': googleRatingCount,
        if (priceLevel != null) 'price_level': priceLevel,
        if (businessStatus != null) 'business_status': businessStatus,
        if (phoneNumber != null) 'phone_number': phoneNumber,
        if (websiteUrl != null) 'website': websiteUrl,
        if (openingHoursJson != null)
          'opening_hours': jsonDecode(openingHoursJson),
      },
    );
    return RestaurantDetail.fromJson(response.data as Map<String, dynamic>);
  }

  Future<DuplicateCheckResult> checkDuplicates({
    required String name,
    required double lat,
    required double lng,
  }) async {
    final response = await _dio.get(
      '/restaurants/duplicate-check',
      queryParameters: {'name': name, 'lat': lat, 'lng': lng},
    );
    final data = response.data as Map<String, dynamic>;
    return DuplicateCheckResult(
      hasDuplicate: data['has_duplicate'] as bool,
      candidates: (data['candidates'] as List<dynamic>)
          .map((c) => RestaurantSummary.fromJson(c as Map<String, dynamic>))
          .toList(),
    );
  }

  Future<void> updateRestaurant(
    String id, {
    String? name,
    String? city,
    String? cuisineType,
  }) async {
    await _dio.patch(
      '/restaurants/$id',
      data: {
        if (name != null) 'name': name,
        if (city != null) 'city': city,
        if (cuisineType != null) 'cuisine_type': cuisineType,
      },
    );
  }

  Future<void> upsertRating(String restaurantId, int stars) async {
    await _dio.post(
      '/restaurants/$restaurantId/ratings',
      data: {'stars': stars},
    );
  }

  Future<List<RestaurantRow>> getRecentlyVisited(String userId) =>
      _db.restaurantDao.getRecentlyVisited(userId);

  Future<List<ParsedDishItem>> parseOcr({
    required String rawText,
    required String restaurantId,
  }) async {
    final response = await _dio.post(
      '/ocr/parse',
      data: {'raw_text': rawText, 'restaurant_id': restaurantId},
    );
    final raw = response.data as Map<String, dynamic>;
    final dishes = (raw['dishes'] as List<dynamic>? ?? [])
        .map((d) => ParsedDishItem.fromJson(d as Map<String, dynamic>))
        .toList();
    return dishes;
  }
}

@riverpod
RestaurantRepository restaurantRepository(Ref ref) {
  return RestaurantRepository(
    ref.watch(apiClientProvider),
    ref.watch(appDatabaseProvider),
  );
}
