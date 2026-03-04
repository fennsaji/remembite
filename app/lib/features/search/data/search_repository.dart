import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/api_client.dart';

part 'search_repository.g.dart';

// ─────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────

class SearchRestaurant {
  final String id;
  final String name;
  final String city;
  final String? cuisineType;
  final double? avgRating;
  final int ratingCount;

  const SearchRestaurant({
    required this.id,
    required this.name,
    required this.city,
    this.cuisineType,
    this.avgRating,
    required this.ratingCount,
  });

  factory SearchRestaurant.fromJson(Map<String, dynamic> json) =>
      SearchRestaurant(
        id: json['id'] as String,
        name: json['name'] as String,
        city: json['city'] as String,
        cuisineType: json['cuisine_type'] as String?,
        avgRating: (json['avg_rating'] as num?)?.toDouble(),
        ratingCount: json['rating_count'] as int,
      );
}

class SearchDish {
  final String name;
  final int restaurantCount;
  final List<String> restaurantIds;
  final List<String> restaurantNames;
  final String? category;
  final double? avgCommunityScore;

  const SearchDish({
    required this.name,
    required this.restaurantCount,
    required this.restaurantIds,
    required this.restaurantNames,
    this.category,
    this.avgCommunityScore,
  });

  factory SearchDish.fromJson(Map<String, dynamic> json) => SearchDish(
    name: json['name'] as String,
    restaurantCount: json['restaurant_count'] as int,
    restaurantIds: (json['restaurant_ids'] as List<dynamic>).cast<String>(),
    restaurantNames: (json['restaurant_names'] as List<dynamic>).cast<String>(),
    category: json['category'] as String?,
    avgCommunityScore: (json['avg_community_score'] as num?)?.toDouble(),
  );
}

class SearchResults {
  final List<SearchRestaurant> restaurants;
  final List<SearchDish> dishes;

  const SearchResults({required this.restaurants, required this.dishes});

  bool get isEmpty => restaurants.isEmpty && dishes.isEmpty;

  factory SearchResults.fromJson(Map<String, dynamic> json) => SearchResults(
    restaurants: (json['restaurants'] as List<dynamic>)
        .map((r) => SearchRestaurant.fromJson(r as Map<String, dynamic>))
        .toList(),
    dishes: (json['dishes'] as List<dynamic>)
        .map((d) => SearchDish.fromJson(d as Map<String, dynamic>))
        .toList(),
  );
}

// ─────────────────────────────────────────────
// Repository
// ─────────────────────────────────────────────

class SearchRepository {
  SearchRepository(this._dio);
  final Dio _dio;

  Future<SearchResults> search(
    String query, {
    double? lat,
    double? lng,
  }) async {
    if (query.trim().isEmpty) {
      return const SearchResults(restaurants: [], dishes: []);
    }
    final response = await _dio.get('/search', queryParameters: {
      'q': query,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
    });
    return SearchResults.fromJson(response.data as Map<String, dynamic>);
  }
}

@riverpod
SearchRepository searchRepository(Ref ref) {
  return SearchRepository(ref.watch(apiClientProvider));
}
