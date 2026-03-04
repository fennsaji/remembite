import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/db/app_database.dart';
import '../../../core/network/api_error.dart';
import '../../../core/network/auth_state.dart';
import '../../../core/theme/app_theme.dart';
import '../../restaurant/data/restaurant_repository.dart';

part 'map_screen.g.dart';

// ─────────────────────────────────────────────
// Record type for map restaurant pins
// ─────────────────────────────────────────────

typedef MapRestaurant = ({
  String id,
  String name,
  double lat,
  double lng,
});

// ─────────────────────────────────────────────
// Google Places nearby result model
// ─────────────────────────────────────────────

class _NearbyPlace {
  final String placeId;
  final String name;
  final String vicinity;
  final double lat;
  final double lng;
  final String? cuisineType;
  final double? rating;
  final int? ratingCount;
  final int? priceLevel;
  final bool? isOpen;
  final String businessStatus;

  const _NearbyPlace({
    required this.placeId,
    required this.name,
    required this.vicinity,
    required this.lat,
    required this.lng,
    this.cuisineType,
    this.rating,
    this.ratingCount,
    this.priceLevel,
    this.isOpen,
    this.businessStatus = 'OPERATIONAL',
  });

  factory _NearbyPlace.fromJson(Map<String, dynamic> json) {
    final loc = (json['geometry'] as Map)['location'] as Map<String, dynamic>;
    final types = (json['types'] as List<dynamic>? ?? []).cast<String>();
    return _NearbyPlace(
      placeId: json['place_id'] as String,
      name: json['name'] as String,
      vicinity: json['vicinity'] as String? ?? '',
      lat: (loc['lat'] as num).toDouble(),
      lng: (loc['lng'] as num).toDouble(),
      cuisineType: _mapCuisine(types),
      rating: (json['rating'] as num?)?.toDouble(),
      ratingCount: json['user_ratings_total'] as int?,
      priceLevel: json['price_level'] as int?,
      isOpen: (json['opening_hours'] as Map<String, dynamic>?)?['open_now'] as bool?,
      businessStatus: json['business_status'] as String? ?? 'OPERATIONAL',
    );
  }

  static String? _mapCuisine(List<String> types) {
    if (types.contains('indian_restaurant')) return 'Indian';
    if (types.contains('chinese_restaurant')) return 'Chinese';
    if (types.contains('italian_restaurant')) return 'Italian';
    if (types.contains('japanese_restaurant')) return 'Japanese';
    if (types.contains('mexican_restaurant')) return 'Mexican';
    if (types.contains('thai_restaurant')) return 'Thai';
    if (types.contains('cafe')) return 'Café';
    if (types.contains('bakery')) return 'Desserts';
    if (types.contains('fast_food_restaurant')) return 'Fast Food';
    return null;
  }
}

// ─────────────────────────────────────────────
// Place Detail model (phone, website, hours)
// ─────────────────────────────────────────────

class _PlaceDetail {
  final String? phoneNumber;
  final String? website;
  final List<String> weekdayText;
  final bool? isOpenNow;

  const _PlaceDetail({
    this.phoneNumber,
    this.website,
    this.weekdayText = const [],
    this.isOpenNow,
  });
}

// ─────────────────────────────────────────────
// Autocomplete prediction model
// ─────────────────────────────────────────────

class _PlacePrediction {
  final String placeId;
  final String mainText;
  final String secondaryText;

  const _PlacePrediction({
    required this.placeId,
    required this.mainText,
    required this.secondaryText,
  });

  factory _PlacePrediction.fromJson(Map<String, dynamic> json) {
    final sf = json['structured_formatting'] as Map<String, dynamic>? ?? {};
    return _PlacePrediction(
      placeId: json['place_id'] as String,
      mainText: sf['main_text'] as String? ?? json['description'] as String? ?? '',
      secondaryText: sf['secondary_text'] as String? ?? '',
    );
  }
}

// ─────────────────────────────────────────────
// Provider: map search params (center + radius)
// Updated on GPS fix and when user taps "Search this area"
// ─────────────────────────────────────────────

final _mapSearchParamsProvider =
    StateProvider<({LatLng center, int radius})?>((ref) => null);

// ─────────────────────────────────────────────
// Provider: DB restaurants for current map area
// ─────────────────────────────────────────────

@riverpod
Future<List<RestaurantSummary>> mapNearbyRestaurants(Ref ref) async {
  final params = ref.watch(_mapSearchParamsProvider);
  final repo = ref.watch(restaurantRepositoryProvider);
  if (params == null) return [];
  return repo
      .getNearbyRestaurants(
        params.center.latitude,
        params.center.longitude,
        radius: params.radius.toDouble(),
      )
      .timeout(const Duration(minutes: 1));
}

// ─────────────────────────────────────────────
// Provider: reacted restaurants from local DB
// ─────────────────────────────────────────────

@riverpod
Future<List<MapRestaurant>> reactedRestaurantsOnMap(Ref ref) async {
  final auth = ref.watch(authStateProvider).value;
  if (auth == null) return [];

  final db = ref.watch(appDatabaseProvider);

  final rows = await db.restaurantDao.getRecentlyVisited(auth.id, limit: 1000);

  return rows
      .map((r) => (id: r.id, name: r.name, lat: r.latitude, lng: r.longitude))
      .toList();
}

// ─────────────────────────────────────────────
// MapScreen
// ─────────────────────────────────────────────

class MapScreen extends ConsumerStatefulWidget {
  final bool addMode;
  final String? initialQuery;
  const MapScreen({super.key, this.addMode = false, this.initialQuery});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  GoogleMapController? _mapController;
  LatLng? _currentPosition;
  LatLng? _cameraCenter;
  double _currentZoom = 14.0;
  bool _fetchingLocation = false;

  static const String _mapsApiKey = String.fromEnvironment('MAPS_API_KEY');

  static const LatLng _fallback = LatLng(19.0760, 72.8777);

  static const String _mapStyle = '''
[
  {"featureType":"poi.business","stylers":[{"visibility":"off"}]},
  {"featureType":"poi.attraction","elementType":"labels","stylers":[{"visibility":"off"}]}
]
''';

  // Device pixel ratio — set on first build, used for crisp marker bitmaps
  double _pixelRatio = 1.0;

  // Place selected from search dropdown — shown as a pin on the map
  _NearbyPlace? _selectedPlace;

  // Places fetch
  bool _fetchingPlaces = false;
  List<_NearbyPlace> _nearbyPlaces = [];
  bool _addingPlace = false;
  final Map<String, BitmapDescriptor> _markerIcons = {};
  // Tracks in-progress async icon builds to avoid duplicate work
  final Set<String> _buildingIcons = {};

  // Search
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  List<_PlacePrediction> _predictions = [];
  bool _loadingPredictions = false;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _fetchLocation();
    _searchController.addListener(_onSearchChanged);
    // Pre-fill search bar if launched from another screen with a query
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _searchController.text = widget.initialQuery!;
        _searchQuery = widget.initialQuery!;
        _fetchPredictions(widget.initialQuery!);
      });
    }
    if (widget.addMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Tap any restaurant pin to add it to Remembite',
              style: TextStyle(color: AppColors.primaryText),
            ),
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.elevated,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.border),
            ),
          ),
        );
      });
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  // ── Location ───────────────────────────────────────────────────────────

  Future<void> _fetchLocation() async {
    if (_fetchingLocation) return;
    if (!mounted) return;
    setState(() => _fetchingLocation = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() => _currentPosition = _fallback);
          ref.read(_mapSearchParamsProvider.notifier).state =
              (center: _fallback, radius: _fetchRadiusForZoom(_currentZoom));
        }
        return;
      }

      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() => _currentPosition = _fallback);
          ref.read(_mapSearchParamsProvider.notifier).state =
              (center: _fallback, radius: _fetchRadiusForZoom(_currentZoom));
        }
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.medium),
      ).timeout(const Duration(seconds: 10));

      if (mounted) {
        final latlng = LatLng(pos.latitude, pos.longitude);
        setState(() { _currentPosition = latlng; });
        ref.read(_mapSearchParamsProvider.notifier).state =
            (center: latlng, radius: _fetchRadiusForZoom(_currentZoom));
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(latlng, 14),
        );
      }
    } catch (_) {
      if (mounted) {
          setState(() => _currentPosition = _fallback);
          ref.read(_mapSearchParamsProvider.notifier).state =
              (center: _fallback, radius: _fetchRadiusForZoom(_currentZoom));
        }
    } finally {
      if (mounted) {
        setState(() => _fetchingLocation = false);
      } else {
        _fetchingLocation = false;
      }
    }
  }

  // ── Search / Autocomplete ──────────────────────────────────────────────

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query == _searchQuery) return;
    setState(() => _searchQuery = query);

    _searchDebounce?.cancel();
    if (query.isEmpty) {
      setState(() => _predictions = []);
      return;
    }
    _searchDebounce = Timer(
      const Duration(milliseconds: 350),
      () => _fetchPredictions(query),
    );
  }

  Future<void> _fetchPredictions(String query) async {
    if (_mapsApiKey.isEmpty || query.isEmpty) return;
    if (!mounted) return;
    setState(() => _loadingPredictions = true);
    try {
      final pos = _cameraCenter ?? _currentPosition;
      final locationBias = pos != null
          ? '&location=${pos.latitude},${pos.longitude}&radius=5000'
          : '';
      final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json'
        '?input=${Uri.encodeComponent(query)}'
        '&types=establishment'
        '$locationBias'
        '&key=$_mapsApiKey',
      );
      final response = await http.get(uri);
      if (!mounted) return;
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final status = body['status'] as String? ?? '';
        if (status == 'OK' || status == 'ZERO_RESULTS') {
          final predictions = (body['predictions'] as List<dynamic>? ?? [])
              .map((e) => _PlacePrediction.fromJson(e as Map<String, dynamic>))
              .toList();
          if (mounted) setState(() => _predictions = predictions);
        }
      }
    } catch (e) {
      debugPrint('[MapScreen] autocomplete error: $e');
    } finally {
      if (mounted) setState(() => _loadingPredictions = false);
    }
  }

  Future<void> _selectPrediction(_PlacePrediction prediction) async {
    if (_mapsApiKey.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _predictions = [];
    });
    try {
      final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/details/json'
        '?place_id=${prediction.placeId}'
        '&fields=geometry,name,vicinity,formatted_address,types,'
            'rating,user_ratings_total,opening_hours,business_status,price_level'
        '&key=$_mapsApiKey',
      );
      final response = await http.get(uri);
      if (!mounted) return;
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        if (body['status'] == 'OK') {
          final result = body['result'] as Map<String, dynamic>;
          final loc = (result['geometry'] as Map)['location'] as Map<String, dynamic>;
          final lat = (loc['lat'] as num).toDouble();
          final lng = (loc['lng'] as num).toDouble();
          final types = (result['types'] as List<dynamic>? ?? []).cast<String>();
          final hours = result['opening_hours'] as Map<String, dynamic>?;
          final place = _NearbyPlace(
            placeId: prediction.placeId,
            name: result['name'] as String? ?? prediction.mainText,
            vicinity: result['vicinity'] as String? ??
                result['formatted_address'] as String? ??
                prediction.secondaryText,
            lat: lat,
            lng: lng,
            cuisineType: _NearbyPlace._mapCuisine(types),
            rating: (result['rating'] as num?)?.toDouble(),
            ratingCount: result['user_ratings_total'] as int?,
            priceLevel: result['price_level'] as int?,
            isOpen: hours?['open_now'] as bool?,
            businessStatus: result['business_status'] as String? ?? 'OPERATIONAL',
          );
          _mapController?.animateCamera(
            CameraUpdate.newLatLngZoom(LatLng(lat, lng), 16),
          );
          if (!mounted) return;
          final reacted = ref.read(reactedRestaurantsOnMapProvider).valueOrNull ?? [];
          // Use a direct API call with a 200 m radius so we get fresh DB data
          // regardless of whether mapNearbyRestaurantsProvider is currently loading
          // (valueOrNull returns [] during re-fetches triggered by camera-idle).
          List<RestaurantSummary> nearbyCheck;
          try {
            nearbyCheck = await ref
                .read(restaurantRepositoryProvider)
                .getNearbyRestaurants(lat, lng, radius: 200);
          } catch (_) {
            nearbyCheck = ref.read(mapNearbyRestaurantsProvider).valueOrNull ?? [];
          }
          if (!mounted) return;
          final existingId = _findInDb(place, reacted, nearbyCheck);
          if (existingId != null) {
            // Already in DB — go straight to the restaurant page
            context.push('/restaurant/$existingId');
            return;
          }
          // Not in DB — show Add sheet with pre-built custom pin
          final icon = await _buildMarkerIcon(place.name, fillColor: _placesMarkerColor);
          _markerIcons['_search_selected'] = icon;
          if (mounted) {
            setState(() => _selectedPlace = place);
            await _showAddPlaceSheet(place);
            if (mounted) {
              _markerIcons.remove('_search_selected');
              setState(() => _selectedPlace = null);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[MapScreen] place details error: $e');
    }
  }

  // ── Custom marker icon ─────────────────────────────────────────────────

  // Blue used for Google Places pins not yet added to Remembite
  static const Color _placesMarkerColor = Color(0xFF5B8DD9);

  Future<BitmapDescriptor> _buildMarkerIcon(
    String name, {
    Color fillColor = const Color(0xFFE6A830),
  }) async {
    final s = _pixelRatio; // scale all logical px → physical px
    const double circleRadius = 16.0;
    const double circleD = circleRadius * 2;
    const double iconFontSize = 15.0;
    const double labelFontSize = 9.0;
    const double labelPadH = 6.0;
    const double labelPadV = 2.0;
    const double gap = 2.0;

    final label = name.length > 22 ? '${name.substring(0, 20)}…' : name;

    // Layout text at scaled font sizes so measurements are in physical px
    final labelPainter = TextPainter(textDirection: TextDirection.ltr)
      ..text = TextSpan(
        text: label,
        style: TextStyle(
          fontSize: labelFontSize * s,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF1C1410),
        ),
      )
      ..layout();

    final labelW = labelPainter.width + labelPadH * 2 * s;
    final labelH = labelPainter.height + labelPadV * 2 * s;
    final totalW = math.max(circleD * s, labelW);
    final totalH = circleD * s + gap * s + labelH;
    final cx = totalW / 2;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, totalW, totalH));

    canvas.drawCircle(
      Offset(cx, circleRadius * s),
      circleRadius * s,
      Paint()
        ..color = Colors.black38
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4 * s),
    );

    canvas.drawCircle(
      Offset(cx, circleRadius * s),
      (circleRadius - 1) * s,
      Paint()..color = fillColor,
    );

    canvas.drawCircle(
      Offset(cx, circleRadius * s),
      (circleRadius - 2) * s,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 * s,
    );

    final iconPainter = TextPainter(textDirection: TextDirection.ltr)
      ..text = TextSpan(
        text: String.fromCharCode(Icons.restaurant.codePoint),
        style: TextStyle(
          fontSize: iconFontSize * s,
          fontFamily: Icons.restaurant.fontFamily,
          package: Icons.restaurant.fontPackage,
          color: Colors.white,
        ),
      )
      ..layout();
    iconPainter.paint(
      canvas,
      Offset(cx - iconPainter.width / 2,
          circleRadius * s - iconPainter.height / 2),
    );

    final labelTop = circleD * s + gap * s;
    final labelLeft = cx - labelW / 2;
    final labelRect = RRect.fromLTRBR(
      labelLeft, labelTop, labelLeft + labelW, labelTop + labelH,
      Radius.circular(6 * s),
    );
    canvas.drawRRect(
      labelRect,
      Paint()
        ..color = Colors.white
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2 * s),
    );
    canvas.drawRRect(labelRect, Paint()..color = Colors.white);
    canvas.drawRRect(
      labelRect,
      Paint()
        ..color = fillColor.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1 * s,
    );

    labelPainter.paint(
      canvas,
      Offset(cx - labelPainter.width / 2, labelTop + labelPadV * s),
    );

    final picture = recorder.endRecording();
    final img = await picture.toImage(totalW.ceil(), totalH.ceil());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    // imagePixelRatio tells the Maps SDK the bitmap is drawn at `s` physical
    // pixels per logical pixel, so it renders at the correct logical size.
    return BitmapDescriptor.bytes(
      bytes!.buffer.asUint8List(),
      imagePixelRatio: s,
    );
  }

  // ── DB marker icon builder ──────────────────────────────────────────────

  /// Builds and caches a custom marker icon for a DB restaurant.
  /// Fire-and-forget: returns immediately; calls setState when done.
  void _ensureDbMarkerIcon(String id, String name) {
    final key = 'db_$id';
    if (_markerIcons.containsKey(key)) return;
    if (_buildingIcons.contains(key)) return;
    _buildingIcons.add(key);
    _buildMarkerIcon(name).then((icon) {
      _markerIcons[key] = icon;
      _buildingIcons.remove(key);
      if (mounted) setState(() {});
    }).catchError((Object _) {
      // Unblock the key so it can be retried on the next build pass
      _buildingIcons.remove(key);
    });
  }

  /// Returns the DB restaurant ID if [place] matches an existing DB entry,
  /// null otherwise. Matched by proximity (~55 m) or exact name.
  String? _findInDb(
    _NearbyPlace place,
    List<MapRestaurant> reacted,
    List<RestaurantSummary> nearby,
  ) {
    const d = 0.0005; // ≈ 55 metres in degrees
    final placeName = place.name.toLowerCase().trim();
    // Coordinate match
    final byCoordReacted = reacted.where(
        (r) => (r.lat - place.lat).abs() < d && (r.lng - place.lng).abs() < d);
    if (byCoordReacted.isNotEmpty) return byCoordReacted.first.id;
    final byCoordNearby = nearby.where((r) =>
        (r.latitude - place.lat).abs() < d &&
        (r.longitude - place.lng).abs() < d);
    if (byCoordNearby.isNotEmpty) return byCoordNearby.first.id;
    // Name match — catches GPS-drifted duplicates
    final byNameReacted =
        reacted.where((r) => r.name.toLowerCase().trim() == placeName);
    if (byNameReacted.isNotEmpty) return byNameReacted.first.id;
    final byNameNearby =
        nearby.where((r) => r.name.toLowerCase().trim() == placeName);
    if (byNameNearby.isNotEmpty) return byNameNearby.first.id;
    return null;
  }

  /// Returns true if [place] already exists in our DB.
  bool _isAlreadyInDb(
    _NearbyPlace place,
    List<MapRestaurant> reacted,
    List<RestaurantSummary> nearby,
  ) =>
      _findInDb(place, reacted, nearby) != null;

  // ── Places fetch ───────────────────────────────────────────────────────

  int _fetchRadiusForZoom(double zoom) {
    if (zoom < 12) return 5000;
    if (zoom < 13) return 3000;
    if (zoom < 14) return 1500;
    if (zoom < 15) return 800;
    return 400;
  }

  Future<void> _fetchPlaces({bool fromButton = false}) async {
    if (_fetchingPlaces) return;
    if (_mapsApiKey.isEmpty) return;
    final pos = _cameraCenter ?? _currentPosition;
    if (pos == null) return;
    if (!mounted) return;

    setState(() => _fetchingPlaces = true);

    final radius = _fetchRadiusForZoom(_currentZoom);
    final allPlaces = <_NearbyPlace>[];

    try {
      String? pageToken;
      // Fetch up to 3 pages (60 results max from Places API).
      for (int page = 0; page < 3; page++) {
        if (!mounted) break;
        final base =
            'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
            '?location=${pos.latitude},${pos.longitude}'
            '&radius=$radius&type=restaurant&key=$_mapsApiKey';
        final uri = Uri.parse(
            pageToken != null ? '$base&pagetoken=$pageToken' : base);
        final response = await http.get(uri).timeout(const Duration(minutes: 1));
        if (!mounted) break;
        if (response.statusCode != 200) break;

        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final status = body['status'] as String? ?? 'UNKNOWN';
        if (status != 'OK' && status != 'ZERO_RESULTS') {
          debugPrint('[MapScreen] Places API: $status — ${body['error_message']}');
          break;
        }

        final results = body['results'] as List<dynamic>? ?? [];
        allPlaces.addAll(
            results.map((e) => _NearbyPlace.fromJson(e as Map<String, dynamic>)));

        pageToken = body['next_page_token'] as String?;
        if (pageToken == null) break;
        // Google requires a short delay before the next-page token becomes valid.
        await Future.delayed(const Duration(milliseconds: 2000));
      }

      await Future.wait(
        allPlaces.map((p) async {
          if (_markerIcons.containsKey(p.placeId)) return;
          final icon = await _buildMarkerIcon(p.name, fillColor: _placesMarkerColor);
          _markerIcons[p.placeId] = icon;
        }),
      );

      if (mounted) setState(() => _nearbyPlaces = allPlaces);
    } catch (e) {
      debugPrint('[MapScreen] _fetchPlaces: $e');
    } finally {
      if (mounted) {
        setState(() => _fetchingPlaces = false);
      } else {
        _fetchingPlaces = false;
      }
    }
  }

  // ── Place Detail fetch ──────────────────────────────────────────────────

  Future<_PlaceDetail> _fetchPlaceDetail(String placeId) async {
    final uri = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/details/json'
      '?place_id=$placeId'
      '&fields=formatted_phone_number,website,opening_hours'
      '&key=$_mapsApiKey',
    );
    try {
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        if (body['status'] == 'OK') {
          final result = body['result'] as Map<String, dynamic>;
          final hours = result['opening_hours'] as Map<String, dynamic>?;
          return _PlaceDetail(
            phoneNumber: result['formatted_phone_number'] as String?,
            website: result['website'] as String?,
            weekdayText: (hours?['weekday_text'] as List<dynamic>?)
                    ?.cast<String>() ??
                [],
            isOpenNow: hours?['open_now'] as bool?,
          );
        }
      }
    } catch (e) {
      debugPrint('[MapScreen] _fetchPlaceDetail: $e');
    }
    return const _PlaceDetail();
  }

  // ── Format helpers ──────────────────────────────────────────────────────

  String _formatCount(int count) {
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return count.toString();
  }

  // ── Pin density helpers ────────────────────────────────────────────────

  double _placeScore(_NearbyPlace p) {
    final rating = ((p.rating ?? 3.0) / 5.0) * 40;
    final popularity = (math.log(math.max(1.0, (p.ratingCount ?? 0).toDouble() + 1)) /
            math.log(1000))
        .clamp(0.0, 1.0) *
        30;
    final openBonus = (p.isOpen == true) ? 20.0 : 0.0;
    final opStatus = (p.businessStatus == 'OPERATIONAL') ? 10.0 : 0.0;
    return rating + popularity + openBonus + opStatus;
  }

  int _maxPlacePins(double zoom) {
    if (zoom < 12) return 8;
    if (zoom < 13) return 15;
    if (zoom < 14) return 30;
    if (zoom < 15) return 60;
    return _nearbyPlaces.length;
  }

  // Minimum metres between two visible Google Places pins at a given zoom.
  // Returns 0 at zoom ≥ 15 — show everything when fully zoomed in.
  double _minPinSpacingMeters(double zoom) {
    if (zoom < 12) return 800;
    if (zoom < 13) return 400;
    if (zoom < 14) return 200;
    if (zoom < 15) return 100;
    if (zoom < 16) return 50;
    return 0;
  }

  // Fast flat-earth distance in metres (accurate enough for <5 km).
  double _distanceMeters(double lat1, double lng1, double lat2, double lng2) {
    const k = 111000.0;
    final dlat = (lat2 - lat1) * k;
    final dlng = (lng2 - lng1) * k * math.cos(lat1 * math.pi / 180);
    return math.sqrt(dlat * dlat + dlng * dlng);
  }

  // ── Markers ────────────────────────────────────────────────────────────

  Set<Marker> _buildMarkers(
    AsyncValue<List<MapRestaurant>> reactedAsync,
    AsyncValue<List<RestaurantSummary>> nearbyAsync,
  ) {
    final markers = <Marker>{};
    final reacted = reactedAsync.valueOrNull ?? [];
    final nearby = nearbyAsync.valueOrNull ?? [];

    // ── Search-selected place pin (always visible, even while DB loads) ──
    final sel = _selectedPlace;
    if (sel != null && _markerIcons.containsKey('_search_selected')) {
      markers.add(Marker(
        markerId: const MarkerId('_search_selected'),
        position: LatLng(sel.lat, sel.lng),
        icon: _markerIcons['_search_selected']!,
        zIndexInt: 2,
        onTap: () => _showAddPlaceSheet(sel),
      ));
    }

    // ── DB: nearby restaurants in Remembite ───────────────────────────
    for (final r in nearby) {
      _ensureDbMarkerIcon(r.id, r.name);
      markers.add(Marker(
        markerId: MarkerId('nearby_${r.id}'),
        position: LatLng(r.latitude, r.longitude),
        icon: _markerIcons['db_${r.id}'] ??
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        onTap: () => context.push('/restaurant/${r.id}'),
      ));
    }

    // ── DB: restaurants user has reacted to (not already in nearby) ───
    for (final r in reacted) {
      if (nearby.any((n) => n.id == r.id)) continue; // already added above
      _ensureDbMarkerIcon(r.id, r.name);
      markers.add(Marker(
        markerId: MarkerId('reacted_${r.id}'),
        position: LatLng(r.lat, r.lng),
        icon: _markerIcons['db_${r.id}'] ??
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        onTap: () => context.push('/restaurant/${r.id}'),
      ));
    }

    // ── Google Places pins — only rendered after DB fetch completes ──
    // Giving DB restaurants precedence: Places pins are suppressed while
    // nearbyAsync is still loading so deduplication runs on fresh DB data.
    if (nearbyAsync.isLoading) return markers;

    final sortedPlaces = [..._nearbyPlaces]
      ..sort((a, b) => _placeScore(b).compareTo(_placeScore(a)));
    final minSpacing = _minPinSpacingMeters(_currentZoom);
    final placedLatLngs = <(double, double)>[];
    int placedCount = 0;
    final maxPins = _maxPlacePins(_currentZoom);
    for (final place in sortedPlaces) {
      if (placedCount >= maxPins) break;
      // Skip if too close to an already-placed pin (disabled at zoom ≥ 15).
      if (minSpacing > 0) {
        final tooClose = placedLatLngs.any((p) =>
            _distanceMeters(p.$1, p.$2, place.lat, place.lng) < minSpacing);
        if (tooClose) continue;
      }
      if (_isAlreadyInDb(place, reacted, nearby)) continue;
      placedLatLngs.add((place.lat, place.lng));
      placedCount++;
      markers.add(Marker(
        markerId: MarkerId('places_${place.placeId}'),
        position: LatLng(place.lat, place.lng),
        icon: _markerIcons[place.placeId] ??
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        onTap: () => _showAddPlaceSheet(place),
      ));
    }

    return markers;
  }

  // ── Add Place Sheet ────────────────────────────────────────────────────

  Future<void> _showAddPlaceSheet(_NearbyPlace place) async {
    // Local helper: price symbols
    String priceSymbols(int? level) {
      if (level == null || level == 0) return '';
      return '₹' * level;
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.elevated,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isDismissible: true,
      enableDrag: true,
      builder: (sheetContext) {
        _PlaceDetail? placeDetail;
        bool loadingDetail = true;
        bool fetchStarted = false;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            // Trigger Place Details fetch exactly once using fetchStarted sentinel
            // to prevent duplicate calls if setSheetState fires during in-flight request.
            if (!fetchStarted) {
              fetchStarted = true;
              _fetchPlaceDetail(place.placeId).then((detail) {
                if (sheetContext.mounted) {
                  setSheetState(() {
                    placeDetail = detail;
                    loadingDetail = false;
                  });
                }
              });
            }

            final isPermanentlyClosed =
                place.businessStatus == 'PERMANENTLY_CLOSED';
            final symbols = priceSymbols(place.priceLevel);

            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Drag handle ──
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(2)),
                    ),
                  ),

                  // ── Name ──
                  Text(place.name,
                      style: GoogleFonts.fraunces(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryText)),
                  const SizedBox(height: 6),

                  // ── Vicinity / address ──
                  Row(children: [
                    const Icon(Icons.location_on_outlined,
                        size: 14, color: AppColors.mutedText),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(place.vicinity,
                          style: GoogleFonts.dmSans(
                              fontSize: 13, color: AppColors.secondaryText),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    ),
                  ]),
                  const SizedBox(height: 8),

                  // ── Permanently closed warning ──
                  if (isPermanentlyClosed) ...[
                    Row(children: [
                      const Icon(Icons.warning_amber_rounded,
                          size: 16, color: AppColors.error),
                      const SizedBox(width: 6),
                      Text('Permanently closed',
                          style: GoogleFonts.dmSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.error)),
                    ]),
                    const SizedBox(height: 8),
                  ],

                  // ── Detail rows: shimmer or data ──
                  if (loadingDetail) ...[
                    Shimmer.fromColors(
                      baseColor: AppColors.border,
                      highlightColor: AppColors.elevated,
                      child: Container(
                        height: 14,
                        width: 180,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ] else ...[
                    // Rating row
                    Row(children: [
                      const Icon(Icons.star_rounded,
                          size: 14, color: AppColors.accent),
                      const SizedBox(width: 4),
                      Text(
                        '${place.rating?.toStringAsFixed(1) ?? '–'}  '
                        '(${_formatCount(place.ratingCount ?? 0)} ratings)',
                        style: GoogleFonts.dmSans(
                            fontSize: 13, color: AppColors.secondaryText),
                      ),
                    ]),
                    const SizedBox(height: 8),

                    // Open / Closed badge + price level row
                    Row(children: [
                      if ((place.isOpen ?? placeDetail?.isOpenNow) == true) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4CAF50).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: const Color(0xFF4CAF50)
                                    .withValues(alpha: 0.4)),
                          ),
                          child: Text('Open now',
                              style: GoogleFonts.dmSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF4CAF50))),
                        ),
                        const SizedBox(width: 8),
                      ] else if ((place.isOpen ?? placeDetail?.isOpenNow) == false) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: AppColors.error.withValues(alpha: 0.3)),
                          ),
                          child: Text('Closed',
                              style: GoogleFonts.dmSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.error)),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (symbols.isNotEmpty)
                        Text(symbols,
                            style: GoogleFonts.dmSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.accent)),
                    ]),
                    const SizedBox(height: 8),
                  ],

                  // ── Cuisine badge ──
                  if (place.cuisineType != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: AppColors.accent.withValues(alpha: 0.3)),
                      ),
                      child: Text(place.cuisineType!,
                          style: GoogleFonts.dmSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.accent)),
                    ),
                    const SizedBox(height: 8),
                  ],

                  const SizedBox(height: 16),

                  // ── Add to Remembite button ──
                  SizedBox(
                    width: double.infinity, height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: AppColors.background,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28)),
                        disabledBackgroundColor:
                            AppColors.accent.withValues(alpha: 0.4),
                      ),
                      onPressed: (_addingPlace || isPermanentlyClosed)
                          ? null
                          : () async {
                              setState(() => _addingPlace = true);
                              setSheetState(() {});
                              final nav = Navigator.of(sheetContext);
                              final router = GoRouter.of(context);
                              final messenger = ScaffoldMessenger.of(context);
                              try {
                                final repo =
                                    ref.read(restaurantRepositoryProvider);
                                final detail = await repo.createRestaurant(
                                  name: place.name,
                                  city: place.vicinity,
                                  latitude: place.lat,
                                  longitude: place.lng,
                                  cuisineType: place.cuisineType,
                                  googlePlaceId: place.placeId,
                                  googleRating: place.rating,
                                  googleRatingCount: place.ratingCount,
                                  priceLevel: place.priceLevel,
                                  businessStatus: place.businessStatus,
                                  phoneNumber: placeDetail?.phoneNumber,
                                  websiteUrl: placeDetail?.website,
                                  openingHoursJson:
                                      placeDetail?.weekdayText.isNotEmpty == true
                                          ? jsonEncode({
                                              'weekday_text':
                                                  placeDetail!.weekdayText,
                                              'open_now': place.isOpen,
                                            })
                                          : null,
                                );
                                if (!mounted) return;
                                // Refresh DB providers so the new restaurant
                                // appears as a DB pin and deduplication removes
                                // its Places pin automatically.
                                ref.invalidate(mapNearbyRestaurantsProvider);
                                ref.invalidate(reactedRestaurantsOnMapProvider);
                                nav.pop();
                                router.push('/restaurant/${detail.id}');
                              } catch (e) {
                                if (!mounted) return;
                                messenger.showSnackBar(SnackBar(
                                    content: Text(apiErrorMessage(e),
                                        style: const TextStyle(
                                            color: AppColors.primaryText)),
                                    backgroundColor: AppColors.elevated));
                              } finally {
                                if (mounted) {
                                  setState(() => _addingPlace = false);
                                  setSheetState(() {});
                                } else {
                                  _addingPlace = false;
                                }
                              }
                            },
                      child: _addingPlace
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.background))
                          : Text('Add to Remembite',
                              style: GoogleFonts.dmSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    if (mounted && _addingPlace) setState(() => _addingPlace = false);
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    _pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final reactedAsync = ref.watch(reactedRestaurantsOnMapProvider);
    final nearbyAsync = ref.watch(mapNearbyRestaurantsProvider);
    // GPS not yet resolved → params null → treat as initial loading
    final paramsReady = ref.watch(_mapSearchParamsProvider) != null;
    final isSearchingArea = !paramsReady || _fetchingPlaces || nearbyAsync.isLoading;
    final pos = _currentPosition;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.elevated,
        automaticallyImplyLeading: false,
        elevation: 0,
        title: Text('Map',
            style: GoogleFonts.dmSans(
                color: AppColors.primaryText,
                fontSize: 17,
                fontWeight: FontWeight.w600)),
      ),
      body: pos == null
          ? Center(
              child: CircularProgressIndicator(
                  color: AppColors.accent, strokeWidth: 2))
          : Stack(
              fit: StackFit.expand,
              children: [
                // ── Map ──────────────────────────────────────────────
                GoogleMap(
                  style: _mapStyle,
                  onMapCreated: (controller) {
                    setState(() => _mapController = controller);
                    _fetchPlaces();
                  },
                  initialCameraPosition:
                      CameraPosition(target: pos, zoom: 14.0),
                  mapType: MapType.normal,
                  myLocationEnabled: false,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  // ScaleGestureRecognizer: wins arena on drag/pinch so
                  // MOVE events are forwarded LIVE to the native map for
                  // panning/zooming; rejects simple taps so marker onTap
                  // and overlay buttons still fire normally.
                  gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                    Factory<ScaleGestureRecognizer>(
                        () => ScaleGestureRecognizer()),
                  },
                  onCameraMove: (position) {
                    _cameraCenter = position.target;
                    final newZoom = position.zoom;
                    if ((_currentZoom - newZoom).abs() >= 0.5) {
                      setState(() { _currentZoom = newZoom; });
                    } else {
                      _currentZoom = newZoom;
                    }
                  },
                  onCameraIdle: () {
                    // Auto-refresh both APIs when camera settles.
                    final center = _cameraCenter;
                    if (center != null) {
                      ref.read(_mapSearchParamsProvider.notifier).state =
                          (center: center, radius: _fetchRadiusForZoom(_currentZoom));
                    }
                    _fetchPlaces();
                  },
                  markers: _buildMarkers(reactedAsync, nearbyAsync),
                ),

                // ── Search bar + dropdown ─────────────────────────────
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Material(
                        color: AppColors.elevated,
                        borderRadius: BorderRadius.circular(12),
                        elevation: 6,
                        shadowColor: Colors.black54,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              const SizedBox(width: 12),
                              Icon(
                                _loadingPredictions
                                    ? Icons.hourglass_empty
                                    : Icons.search,
                                size: 18,
                                color: AppColors.mutedText,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  focusNode: _searchFocusNode,
                                  style: GoogleFonts.dmSans(
                                      fontSize: 14,
                                      color: AppColors.primaryText),
                                  decoration: InputDecoration(
                                    hintText: 'Search restaurants & places…',
                                    hintStyle: GoogleFonts.dmSans(
                                        fontSize: 14,
                                        color: AppColors.mutedText),
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 14),
                                  ),
                                  textInputAction: TextInputAction.search,
                                  onSubmitted: (_) {
                                    if (_predictions.isNotEmpty) {
                                      _selectPrediction(_predictions.first);
                                    }
                                  },
                                ),
                              ),
                              if (_searchQuery.isNotEmpty)
                                GestureDetector(
                                  onTap: () {
                                    _searchController.clear();
                                    _searchFocusNode.unfocus();
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10),
                                    child: Icon(Icons.close,
                                        size: 18, color: AppColors.mutedText),
                                  ),
                                )
                              else
                                const SizedBox(width: 12),
                            ],
                          ),
                        ),
                      ),
                      if (_predictions.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          decoration: BoxDecoration(
                            color: AppColors.elevated,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black38,
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 280),
                              child: ListView.separated(
                                padding: EdgeInsets.zero,
                                shrinkWrap: true,
                                itemCount: _predictions.length,
                                separatorBuilder: (_, __) =>
                                    Divider(height: 1, color: AppColors.border, indent: 48),
                                itemBuilder: (_, i) {
                                  final p = _predictions[i];
                                  return InkWell(
                                    onTap: () => _selectPrediction(p),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 12),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 28,
                                            height: 28,
                                            decoration: BoxDecoration(
                                              color: AppColors.accent
                                                  .withValues(alpha: 0.12),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: const Icon(Icons.restaurant,
                                                size: 15, color: AppColors.accent),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  p.mainText,
                                                  style: GoogleFonts.dmSans(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                    color: AppColors.primaryText,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                if (p.secondaryText.isNotEmpty)
                                                  Text(
                                                    p.secondaryText,
                                                    style: GoogleFonts.dmSans(
                                                      fontSize: 11,
                                                      color: AppColors.secondaryText,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // ── "Search this area" button (bottom-left) ──────────
                // Use Material+InkWell instead of ElevatedButton to avoid
                // _InputPadding's invisible extra hit area, which intercepts
                // map gestures in TLHC mode and breaks panning.
                Positioned(
                  bottom: 24,
                  left: 16,
                  child: Material(
                    color: AppColors.elevated,
                    borderRadius: BorderRadius.circular(24),
                    elevation: 6,
                    shadowColor: Colors.black54,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: isSearchingArea
                          ? null
                          : () {
                              final center = _cameraCenter;
                              if (center != null) {
                                ref.read(_mapSearchParamsProvider.notifier).state =
                                    (center: center, radius: _fetchRadiusForZoom(_currentZoom));
                              }
                              _fetchPlaces(fromButton: true);
                            },
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: AppColors.border),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            isSearchingArea
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.accent),
                                  )
                                : const Icon(Icons.search,
                                    size: 16, color: AppColors.accent),
                            const SizedBox(width: 8),
                            Text('Search this area',
                                style: GoogleFonts.dmSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primaryText)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // ── GPS button (bottom-right) ─────────────────────────
                Positioned(
                  bottom: 24,
                  right: 16,
                  child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.elevated,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.border),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black38,
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: _fetchingLocation
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.accent,
                                ),
                              )
                            : const Icon(Icons.my_location,
                                size: 20, color: AppColors.accent),
                        onPressed:
                            _fetchingLocation ? null : _fetchLocation,
                        tooltip: 'My location',
                      ),
                    ),
                ),
              ],
            ),
    );
  }
}
