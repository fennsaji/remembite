// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'home_screen.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$nearbyRestaurantsHash() => r'cf1f83e6a08723e76c6fa690c2676587da11f2e3';

/// See also [nearbyRestaurants].
@ProviderFor(nearbyRestaurants)
final nearbyRestaurantsProvider =
    AutoDisposeFutureProvider<List<RestaurantSummary>>.internal(
      nearbyRestaurants,
      name: r'nearbyRestaurantsProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$nearbyRestaurantsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef NearbyRestaurantsRef =
    AutoDisposeFutureProviderRef<List<RestaurantSummary>>;
String _$recentlyVisitedHash() => r'1dc3c79fe7a60330935c6af6fa13cd86851b6ef1';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// See also [recentlyVisited].
@ProviderFor(recentlyVisited)
const recentlyVisitedProvider = RecentlyVisitedFamily();

/// See also [recentlyVisited].
class RecentlyVisitedFamily extends Family<AsyncValue<List<RestaurantRow>>> {
  /// See also [recentlyVisited].
  const RecentlyVisitedFamily();

  /// See also [recentlyVisited].
  RecentlyVisitedProvider call(String userId) {
    return RecentlyVisitedProvider(userId);
  }

  @override
  RecentlyVisitedProvider getProviderOverride(
    covariant RecentlyVisitedProvider provider,
  ) {
    return call(provider.userId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'recentlyVisitedProvider';
}

/// See also [recentlyVisited].
class RecentlyVisitedProvider
    extends AutoDisposeFutureProvider<List<RestaurantRow>> {
  /// See also [recentlyVisited].
  RecentlyVisitedProvider(String userId)
    : this._internal(
        (ref) => recentlyVisited(ref as RecentlyVisitedRef, userId),
        from: recentlyVisitedProvider,
        name: r'recentlyVisitedProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$recentlyVisitedHash,
        dependencies: RecentlyVisitedFamily._dependencies,
        allTransitiveDependencies:
            RecentlyVisitedFamily._allTransitiveDependencies,
        userId: userId,
      );

  RecentlyVisitedProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.userId,
  }) : super.internal();

  final String userId;

  @override
  Override overrideWith(
    FutureOr<List<RestaurantRow>> Function(RecentlyVisitedRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: RecentlyVisitedProvider._internal(
        (ref) => create(ref as RecentlyVisitedRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        userId: userId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<RestaurantRow>> createElement() {
    return _RecentlyVisitedProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is RecentlyVisitedProvider && other.userId == userId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, userId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin RecentlyVisitedRef on AutoDisposeFutureProviderRef<List<RestaurantRow>> {
  /// The parameter `userId` of this provider.
  String get userId;
}

class _RecentlyVisitedProviderElement
    extends AutoDisposeFutureProviderElement<List<RestaurantRow>>
    with RecentlyVisitedRef {
  _RecentlyVisitedProviderElement(super.provider);

  @override
  String get userId => (origin as RecentlyVisitedProvider).userId;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
