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

import '../../../core/db/app_database.dart';
import '../../../core/network/api_error.dart';
import '../../../core/network/auth_state.dart';
import '../../../core/theme/app_theme.dart';
import '../../home/presentation/home_screen.dart';
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

  const _NearbyPlace({
    required this.placeId,
    required this.name,
    required this.vicinity,
    required this.lat,
    required this.lng,
    this.cuisineType,
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
  const MapScreen({super.key, this.addMode = false});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  GoogleMapController? _mapController;
  LatLng? _currentPosition;
  LatLng? _cameraCenter;
  bool _fetchingLocation = false;

  static const String _mapsApiKey = String.fromEnvironment('MAPS_API_KEY');

  static const LatLng _fallback = LatLng(19.0760, 72.8777);

  static const String _mapStyle = '''
[
  {"featureType":"poi.business","stylers":[{"visibility":"off"}]},
  {"featureType":"poi.attraction","elementType":"labels","stylers":[{"visibility":"off"}]}
]
''';

  // Places fetch
  bool _fetchingPlaces = false;
  bool _searchingArea = false;
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
        if (mounted) setState(() => _currentPosition = _fallback);
        return;
      }

      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        if (mounted) setState(() => _currentPosition = _fallback);
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.medium),
      ).timeout(const Duration(seconds: 10));

      if (mounted) {
        setState(() {
          _currentPosition = LatLng(pos.latitude, pos.longitude);
        });
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(LatLng(pos.latitude, pos.longitude), 14),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _currentPosition = _fallback);
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
        '&fields=geometry,name,vicinity,formatted_address,types'
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
          final place = _NearbyPlace(
            placeId: prediction.placeId,
            name: result['name'] as String? ?? prediction.mainText,
            vicinity: result['vicinity'] as String? ??
                result['formatted_address'] as String? ??
                prediction.secondaryText,
            lat: lat,
            lng: lng,
            cuisineType: _NearbyPlace._mapCuisine(types),
          );
          _mapController?.animateCamera(
            CameraUpdate.newLatLngZoom(LatLng(lat, lng), 16),
          );
          if (mounted) _showAddPlaceSheet(place);
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
    const double circleRadius = 16.0;
    const double circleD = circleRadius * 2;
    const double iconFontSize = 15.0;
    const double labelFontSize = 9.0;
    const double labelPadH = 6.0;
    const double labelPadV = 2.0;
    const double gap = 2.0;

    final label = name.length > 22 ? '${name.substring(0, 20)}…' : name;

    final labelPainter = TextPainter(textDirection: TextDirection.ltr)
      ..text = TextSpan(
        text: label,
        style: const TextStyle(
          fontSize: labelFontSize,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1C1410),
        ),
      )
      ..layout();

    final labelW = labelPainter.width + labelPadH * 2;
    final labelH = labelPainter.height + labelPadV * 2;
    final totalW = math.max(circleD, labelW);
    final totalH = circleD + gap + labelH;
    final cx = totalW / 2;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, totalW, totalH));

    canvas.drawCircle(
      Offset(cx, circleRadius),
      circleRadius,
      Paint()
        ..color = Colors.black38
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    canvas.drawCircle(
      Offset(cx, circleRadius),
      circleRadius - 1,
      Paint()..color = fillColor,
    );

    canvas.drawCircle(
      Offset(cx, circleRadius),
      circleRadius - 2,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    final iconPainter = TextPainter(textDirection: TextDirection.ltr)
      ..text = TextSpan(
        text: String.fromCharCode(Icons.restaurant.codePoint),
        style: TextStyle(
          fontSize: iconFontSize,
          fontFamily: Icons.restaurant.fontFamily,
          package: Icons.restaurant.fontPackage,
          color: Colors.white,
        ),
      )
      ..layout();
    iconPainter.paint(
      canvas,
      Offset(cx - iconPainter.width / 2,
          circleRadius - iconPainter.height / 2),
    );

    final labelTop = circleD + gap;
    final labelLeft = cx - labelW / 2;
    final labelRect = RRect.fromLTRBR(
      labelLeft, labelTop, labelLeft + labelW, labelTop + labelH,
      const Radius.circular(6),
    );
    canvas.drawRRect(
      labelRect,
      Paint()
        ..color = Colors.white
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.drawRRect(labelRect, Paint()..color = Colors.white);
    canvas.drawRRect(
      labelRect,
      Paint()
        ..color = fillColor.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    labelPainter.paint(
      canvas,
      Offset(cx - labelPainter.width / 2, labelTop + labelPadV),
    );

    final picture = recorder.endRecording();
    final img = await picture.toImage(totalW.ceil(), totalH.ceil());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
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
    });
  }

  /// Returns true if [place] from Google Places already exists in our DB
  /// (reacted or nearby) — matched by proximity (~55 m threshold).
  bool _isAlreadyInDb(
    _NearbyPlace place,
    List<MapRestaurant> reacted,
    List<RestaurantSummary> nearby,
  ) {
    const d = 0.0005; // ≈ 55 metres in degrees
    return reacted.any(
          (r) => (r.lat - place.lat).abs() < d && (r.lng - place.lng).abs() < d,
        ) ||
        nearby.any(
          (r) =>
              (r.latitude - place.lat).abs() < d &&
              (r.longitude - place.lng).abs() < d,
        );
  }

  // ── Places fetch ───────────────────────────────────────────────────────

  Future<void> _fetchPlaces({bool fromButton = false}) async {
    if (_fetchingPlaces) return;
    if (_mapsApiKey.isEmpty) return;
    final pos = _cameraCenter ?? _currentPosition;
    if (pos == null) return;
    if (!mounted) return;

    _fetchingPlaces = true;
    if (fromButton) setState(() => _searchingArea = true);

    try {
      final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
        '?location=${pos.latitude},${pos.longitude}'
        '&radius=1500&type=restaurant&key=$_mapsApiKey',
      );
      final response = await http.get(uri);
      if (!mounted) return;

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final status = body['status'] as String? ?? 'UNKNOWN';

        if (status == 'OK' || status == 'ZERO_RESULTS') {
          final results = body['results'] as List<dynamic>? ?? [];
          final places = results
              .map((e) => _NearbyPlace.fromJson(e as Map<String, dynamic>))
              .toList();

          await Future.wait(
            places.map((p) async {
              final icon = await _buildMarkerIcon(
                p.name,
                fillColor: _placesMarkerColor,
              );
              _markerIcons[p.placeId] = icon;
            }),
          );

          if (mounted) {
            setState(() => _nearbyPlaces = places);
          }
        } else {
          debugPrint('[MapScreen] Places API: $status — ${body['error_message']}');
        }
      }
    } catch (e) {
      debugPrint('[MapScreen] _fetchPlaces: $e');
    } finally {
      _fetchingPlaces = false;
      if (mounted) setState(() => _searchingArea = false);
    }
  }

  // ── Markers ────────────────────────────────────────────────────────────

  Set<Marker> _buildMarkers(
    AsyncValue<List<MapRestaurant>> reactedAsync,
    AsyncValue<List<RestaurantSummary>> nearbyAsync,
  ) {
    final markers = <Marker>{};
    final reacted = reactedAsync.value ?? [];
    final nearby = nearbyAsync.value ?? [];

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

    // ── Google Places pins — skip any that overlap a DB restaurant ────
    for (final place in _nearbyPlaces) {
      if (_isAlreadyInDb(place, reacted, nearby)) continue;
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
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.elevated,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isDismissible: true,
      enableDrag: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Text(place.name,
                  style: GoogleFonts.fraunces(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryText)),
              const SizedBox(height: 6),
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
              if (place.cuisineType != null) ...[
                const SizedBox(height: 10),
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
              ],
              const SizedBox(height: 24),
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
                  onPressed: _addingPlace
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
                            );
                            if (!mounted) return;
                            // Refresh DB providers so the new restaurant
                            // appears as a DB pin and deduplication removes
                            // its Places pin automatically.
                            ref.invalidate(nearbyRestaurantsProvider);
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
        ),
      ),
    );
    if (mounted && _addingPlace) setState(() => _addingPlace = false);
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final reactedAsync = ref.watch(reactedRestaurantsOnMapProvider);
    final nearbyAsync = ref.watch(nearbyRestaurantsProvider);
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
                    // Only track center — no setState here to avoid
                    // rebuilding the widget tree at 60fps during pan.
                    _cameraCenter = position.target;
                  },
                  onCameraIdle: () {
                    // Camera settled — no-op; button visibility driven by
                    // _mapController != null so it shows as soon as map loads.
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
                                    contentPadding:
                                        const EdgeInsets.symmetric(vertical: 14),
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
                      onTap: _searchingArea
                          ? null
                          : () => _fetchPlaces(fromButton: true),
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
                            _searchingArea
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
