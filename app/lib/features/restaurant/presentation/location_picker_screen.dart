import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../../../core/theme/app_theme.dart';

// ─────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────

const _kFallback = LatLng(19.0760, 72.8777); // Mumbai fallback
const String _mapsApiKey = String.fromEnvironment('MAPS_API_KEY');

// ─────────────────────────────────────────────
// _PlaceResult
// ─────────────────────────────────────────────

class _PlaceResult {
  final String placeId;
  final String mainText;
  final String secondaryText;

  const _PlaceResult({
    required this.placeId,
    required this.mainText,
    required this.secondaryText,
  });

  factory _PlaceResult.fromJson(Map<String, dynamic> json) {
    final sf = json['structured_formatting'] as Map<String, dynamic>? ?? {};
    return _PlaceResult(
      placeId: json['place_id'] as String? ?? '',
      mainText: sf['main_text'] as String? ?? '',
      secondaryText: sf['secondary_text'] as String? ?? '',
    );
  }
}

// ─────────────────────────────────────────────
// LocationPickerScreen
// ─────────────────────────────────────────────

class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({super.key, this.initial});

  final LatLng? initial;

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  GoogleMapController? _mapController;
  LatLng? _currentPosition;
  LatLng _cameraCenter = _kFallback;
  bool _fetchingGps = false;
  bool _placeSelectedFromSearch = false;

  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  List<_PlaceResult> _searchResults = [];
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) {
      _currentPosition = widget.initial;
      _cameraCenter = widget.initial!;
    } else {
      _fetchGps();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _fetchGps() async {
    if (_fetchingGps) return;
    if (!mounted) return;
    setState(() => _fetchingGps = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            _currentPosition = _kFallback;
            _cameraCenter = _kFallback;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location services are disabled')),
          );
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
          setState(() {
            _currentPosition = _kFallback;
            _cameraCenter = _kFallback;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permission denied — using Mumbai as default'),
            ),
          );
        }
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.medium),
      ).timeout(const Duration(seconds: 10), onTimeout: () {
        throw TimeoutException('Location timed out');
      });

      if (mounted) {
        final latLng = LatLng(pos.latitude, pos.longitude);
        setState(() {
          _currentPosition = latLng;
          _cameraCenter = latLng;
        });
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(latLng, 15),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _currentPosition = _kFallback;
          _cameraCenter = _kFallback;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not determine location')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _fetchingGps = false);
      } else {
        _fetchingGps = false;
      }
    }
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    _searchDebounce = Timer(
      const Duration(milliseconds: 600),
      () => _runSearch(query.trim()),
    );
  }

  Future<void> _runSearch(String query) async {
    setState(() => _searching = true);
    try {
      final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json'
        '?input=${Uri.encodeComponent(query)}'
        '&key=$_mapsApiKey'
        '&language=en'
        '&components=country:in'
        '&types=establishment',
      );
      final response = await http.get(uri);
      if (!mounted) return;
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final predictions = body['predictions'] as List<dynamic>? ?? [];
        setState(() {
          _searchResults = predictions
              .map((e) => _PlaceResult.fromJson(e as Map<String, dynamic>))
              .where((r) => r.placeId.isNotEmpty)
              .toList();
        });
      } else {
        setState(() => _searchResults = []);
      }
    } catch (_) {
      if (mounted) setState(() => _searchResults = []);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _selectResult(_PlaceResult result) async {
    _searchController.text = result.mainText;
    setState(() {
      _searchResults = [];
      _placeSelectedFromSearch = true;
    });

    try {
      final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/details/json'
        '?place_id=${result.placeId}'
        '&fields=geometry'
        '&key=$_mapsApiKey',
      );
      final response = await http.get(uri);
      if (!mounted) return;
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final loc = (body['result'] as Map<String, dynamic>?)?['geometry']
            ?['location'] as Map<String, dynamic>?;
        if (loc != null) {
          final lat = (loc['lat'] as num).toDouble();
          final lng = (loc['lng'] as num).toDouble();
          final latLng = LatLng(lat, lng);
          _cameraCenter = latLng;
          _mapController?.animateCamera(
            CameraUpdate.newLatLngZoom(latLng, 16),
          );
        }
      }
    } catch (_) {
      // silently ignore — map stays where it is
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primaryText),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Pick Location',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(color: AppColors.primaryText),
        ),
      ),
      body: _currentPosition == null
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            )
          : Column(
              children: [
                // ── Search field ──────────────────────────────────
                Container(
                  color: AppColors.background,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    style: const TextStyle(color: AppColors.primaryText),
                    decoration: InputDecoration(
                      hintText: 'Search for a place…',
                      hintStyle:
                          const TextStyle(color: AppColors.mutedText),
                      prefixIcon: const Icon(Icons.search,
                          color: AppColors.mutedText),
                      suffixIcon: _searching
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.accent,
                                ),
                              ),
                            )
                          : null,
                      filled: true,
                      fillColor: AppColors.elevated,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: AppColors.accent),
                      ),
                    ),
                  ),
                ),

                // ── Search results dropdown ───────────────────────
                if (_searchResults.isNotEmpty)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 220),
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                      decoration: BoxDecoration(
                        color: AppColors.elevated,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        itemCount: _searchResults.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, color: AppColors.border),
                        itemBuilder: (context, i) {
                          final r = _searchResults[i];
                          return ListTile(
                            dense: true,
                            title: Text(
                              r.mainText,
                              style: const TextStyle(
                                color: AppColors.primaryText,
                                fontSize: 13,
                              ),
                            ),
                            subtitle: Text(
                              r.secondaryText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.mutedText,
                                fontSize: 11,
                              ),
                            ),
                            onTap: () => _selectResult(r),
                          );
                        },
                      ),
                    ),
                  ),

                // ── Map + crosshair + bottom buttons ─────────────
                Expanded(
                  child: Stack(
                    children: [
                      GoogleMap(
                        onMapCreated: (c) =>
                            setState(() => _mapController = c),
                        initialCameraPosition: CameraPosition(
                          target: _currentPosition!,
                          zoom: 15.0,
                        ),
                        onCameraMove: (pos) {
                          _cameraCenter = pos.target;
                          if (_placeSelectedFromSearch) {
                            setState(() => _placeSelectedFromSearch = false);
                          }
                        },
                        mapType: MapType.normal,
                        myLocationEnabled: false,
                        zoomControlsEnabled: false,
                        markers: const {},
                      ),
                      const Center(child: _Crosshair()),
                      Positioned(
                        left: 16,
                        right: 16,
                        bottom: 32,
                        child: Row(
                          children: [
                            // GPS button — Material+InkWell avoids
                            // ElevatedButton._InputPadding hitting map gestures
                            Material(
                              color: AppColors.elevated,
                              borderRadius: BorderRadius.circular(24),
                              elevation: 4,
                              shadowColor: Colors.black54,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(24),
                                onTap: _fetchingGps ? null : _fetchGps,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 10),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(24),
                                    border:
                                        Border.all(color: AppColors.accent),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _fetchingGps
                                          ? const SizedBox(
                                              width: 14,
                                              height: 14,
                                              child:
                                                  CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: AppColors.accent,
                                              ))
                                          : const Icon(Icons.my_location,
                                              size: 16,
                                              color: AppColors.accent),
                                      const SizedBox(width: 6),
                                      const Text(
                                        'Use GPS',
                                        style: TextStyle(
                                            color: AppColors.accent,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const Spacer(),
                            // Confirm button — same pattern, no _InputPadding
                            Material(
                              color: AppColors.accent,
                              borderRadius: BorderRadius.circular(24),
                              elevation: 4,
                              shadowColor: Colors.black54,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(24),
                                onTap: () => context.pop(_cameraCenter),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 10),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.check,
                                          size: 16,
                                          color: AppColors.background),
                                      const SizedBox(width: 6),
                                      Text(
                                        _placeSelectedFromSearch
                                            ? 'Confirm'
                                            : 'Use this location',
                                        style: const TextStyle(
                                            color: AppColors.background,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

// ─────────────────────────────────────────────
// _Crosshair
// ─────────────────────────────────────────────

class _Crosshair extends StatelessWidget {
  const _Crosshair();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 32,
      child: CustomPaint(painter: _CrosshairPainter()),
    );
  }
}

class _CrosshairPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.accent
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    final cx = size.width / 2;
    final cy = size.height / 2;
    canvas.drawLine(Offset(0, cy), Offset(size.width, cy), paint);
    canvas.drawLine(Offset(cx, 0), Offset(cx, size.height), paint);
    final fillPaint = Paint()
      ..color = AppColors.accent
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), 4, fillPaint);
  }

  @override
  bool shouldRepaint(_CrosshairPainter oldDelegate) => false;
}
