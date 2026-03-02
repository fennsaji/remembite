import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../data/restaurant_repository.dart';

class AddRestaurantScreen extends ConsumerStatefulWidget {
  const AddRestaurantScreen({super.key});

  @override
  ConsumerState<AddRestaurantScreen> createState() =>
      _AddRestaurantScreenState();
}

class _AddRestaurantScreenState extends ConsumerState<AddRestaurantScreen> {
  final _nameController = TextEditingController();
  final _cityController = TextEditingController();
  String? _selectedCuisine;
  double? _latitude;
  double? _longitude;
  DuplicateCheckResult? _duplicateResult;
  bool _loadingLocation = false;
  bool _saving = false;
  bool _bypassDuplicateCheck = false;
  Timer? _debounce;

  static const _cuisines = [
    'Indian', 'Chinese', 'Italian', 'Mexican', 'Japanese',
    'Thai', 'Continental', 'Fast Food', 'Biryani', 'South Indian',
    'North Indian', 'Street Food', 'Café', 'Desserts',
  ];

  @override
  void initState() {
    super.initState();
    _detectLocation();
    _nameController.addListener(_onNameChanged);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cityController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onNameChanged() {
    _bypassDuplicateCheck = false;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), _checkDuplicates);
  }

  Future<void> _detectLocation() async {
    setState(() => _loadingLocation = true);
    try {
      final perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );
      setState(() {
        _latitude = pos.latitude;
        _longitude = pos.longitude;
      });
    } finally {
      setState(() => _loadingLocation = false);
    }
  }

  Future<void> _checkDuplicates() async {
    if (_nameController.text.trim().isEmpty ||
        _latitude == null ||
        _longitude == null) {
      setState(() => _duplicateResult = null);
      return;
    }
    try {
      final result = await ref
          .read(restaurantRepositoryProvider)
          .checkDuplicates(
            name: _nameController.text.trim(),
            lat: _latitude!,
            lng: _longitude!,
          );
      if (!mounted || _bypassDuplicateCheck) return;
      setState(() => _duplicateResult = result);
    } catch (_) {}
  }

  Future<void> _save({bool force = false}) async {
    if (_saving) return;
    if (_nameController.text.trim().isEmpty) return;
    if (_latitude == null || _longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location required')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final detail = await ref
          .read(restaurantRepositoryProvider)
          .createRestaurant(
            name: _nameController.text.trim(),
            city: _cityController.text.trim().isNotEmpty
                ? _cityController.text.trim()
                : 'Unknown',
            latitude: _latitude!,
            longitude: _longitude!,
            cuisineType: _selectedCuisine,
          );
      if (mounted) {
        if (force) setState(() => _duplicateResult = null);
        context.pushReplacement('/restaurant/${detail.id}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primaryText),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Add Restaurant',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(color: AppColors.primaryText),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Name field
          TextField(
            controller: _nameController,
            style: const TextStyle(color: AppColors.primaryText),
            decoration: InputDecoration(
              labelText: 'Restaurant Name *',
              labelStyle:
                  const TextStyle(color: AppColors.secondaryText),
              hintText: 'e.g. Sharma Dhaba',
            ),
          ),
          const SizedBox(height: 16),

          // Duplicate check banner
          if (_duplicateResult != null &&
              _duplicateResult!.hasDuplicate) ...[
            _DuplicateBanner(
              result: _duplicateResult!,
              onViewExisting: () => context
                  .push('/restaurant/${_duplicateResult!.candidates.first.id}'),
              onCreateAnyway: () {
                _bypassDuplicateCheck = true;
                _save(force: true);
              },
            ),
            const SizedBox(height: 16),
          ],

          // City field
          TextField(
            controller: _cityController,
            style: const TextStyle(color: AppColors.primaryText),
            decoration: const InputDecoration(
              labelText: 'City',
              labelStyle: TextStyle(color: AppColors.secondaryText),
            ),
          ),
          const SizedBox(height: 16),

          // Cuisine type
          DropdownButtonFormField<String>(
            value: _selectedCuisine,
            dropdownColor: AppColors.elevated,
            style: const TextStyle(color: AppColors.primaryText),
            decoration: InputDecoration(
              labelText: 'Cuisine Type (optional)',
              labelStyle:
                  const TextStyle(color: AppColors.secondaryText),
            ),
            hint: const Text('Select cuisine',
                style: TextStyle(color: AppColors.mutedText)),
            items: _cuisines
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (v) => setState(() => _selectedCuisine = v),
          ),
          const SizedBox(height: 16),

          // Location
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Icon(
                  _latitude != null
                      ? Icons.location_on
                      : Icons.location_off,
                  color: _latitude != null
                      ? AppColors.accent
                      : AppColors.mutedText,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _loadingLocation
                        ? 'Detecting location…'
                        : _latitude != null
                            ? 'Location detected (${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)})'
                            : 'Location not available',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.secondaryText,
                        ),
                  ),
                ),
                if (!_loadingLocation)
                  TextButton(
                    onPressed: _detectLocation,
                    child: const Text('Retry',
                        style: TextStyle(color: AppColors.accent)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          ElevatedButton(
            onPressed: _saving ? null : _save,
            child:
                _saving ? const Text('Saving…') : const Text('Save Restaurant'),
          ),
        ],
      ),
    );
  }
}

class _DuplicateBanner extends StatelessWidget {
  final DuplicateCheckResult result;
  final VoidCallback onViewExisting;
  final VoidCallback onCreateAnyway;

  const _DuplicateBanner({
    required this.result,
    required this.onViewExisting,
    required this.onCreateAnyway,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline,
                  color: AppColors.accent, size: 16),
              const SizedBox(width: 8),
              Text(
                'Similar restaurant found nearby',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.accent,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            result.candidates.first.name,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.secondaryText),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onViewExisting,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.accent,
                    side: const BorderSide(color: AppColors.accent),
                    minimumSize: const Size(0, 36),
                  ),
                  child: const Text('View Existing'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextButton(
                  onPressed: onCreateAnyway,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.secondaryText,
                    minimumSize: const Size(0, 36),
                  ),
                  child: const Text('Create Anyway'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
