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
  final String id;
  final String name;
  final String restaurantId;
  final String restaurantName;
  final String? category;
  final double? communityScore;

  const SearchDish({
    required this.id,
    required this.name,
    required this.restaurantId,
    required this.restaurantName,
    this.category,
    this.communityScore,
  });

  factory SearchDish.fromJson(Map<String, dynamic> json) => SearchDish(
    id: json['id'] as String,
    name: json['name'] as String,
    restaurantId: json['restaurant_id'] as String,
    restaurantName: json['restaurant_name'] as String,
    category: json['category'] as String?,
    communityScore: (json['community_score'] as num?)?.toDouble(),
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

  Future<SearchResults> search(String query) async {
    if (query.trim().isEmpty) {
      return const SearchResults(restaurants: [], dishes: []);
    }
    final response = await _dio.get('/search', queryParameters: {'q': query});
    return SearchResults.fromJson(response.data as Map<String, dynamic>);
  }
}

@riverpod
SearchRepository searchRepository(Ref ref) {
  return SearchRepository(ref.watch(apiClientProvider));
}
