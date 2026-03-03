// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'restaurant_screen.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$restaurantDetailHash() => r'9a9ab4cfcec3d8b25888391cb046d6d11f48f1d6';

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

/// See also [restaurantDetail].
@ProviderFor(restaurantDetail)
const restaurantDetailProvider = RestaurantDetailFamily();

/// See also [restaurantDetail].
class RestaurantDetailFamily extends Family<AsyncValue<RestaurantDetail>> {
  /// See also [restaurantDetail].
  const RestaurantDetailFamily();

  /// See also [restaurantDetail].
  RestaurantDetailProvider call(String id) {
    return RestaurantDetailProvider(id);
  }

  @override
  RestaurantDetailProvider getProviderOverride(
    covariant RestaurantDetailProvider provider,
  ) {
    return call(provider.id);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'restaurantDetailProvider';
}

/// See also [restaurantDetail].
class RestaurantDetailProvider
    extends AutoDisposeFutureProvider<RestaurantDetail> {
  /// See also [restaurantDetail].
  RestaurantDetailProvider(String id)
    : this._internal(
        (ref) => restaurantDetail(ref as RestaurantDetailRef, id),
        from: restaurantDetailProvider,
        name: r'restaurantDetailProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$restaurantDetailHash,
        dependencies: RestaurantDetailFamily._dependencies,
        allTransitiveDependencies:
            RestaurantDetailFamily._allTransitiveDependencies,
        id: id,
      );

  RestaurantDetailProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.id,
  }) : super.internal();

  final String id;

  @override
  Override overrideWith(
    FutureOr<RestaurantDetail> Function(RestaurantDetailRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: RestaurantDetailProvider._internal(
        (ref) => create(ref as RestaurantDetailRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        id: id,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<RestaurantDetail> createElement() {
    return _RestaurantDetailProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is RestaurantDetailProvider && other.id == id;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, id.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin RestaurantDetailRef on AutoDisposeFutureProviderRef<RestaurantDetail> {
  /// The parameter `id` of this provider.
  String get id;
}

class _RestaurantDetailProviderElement
    extends AutoDisposeFutureProviderElement<RestaurantDetail>
    with RestaurantDetailRef {
  _RestaurantDetailProviderElement(super.provider);

  @override
  String get id => (origin as RestaurantDetailProvider).id;
}

String _$restaurantDishesHash() => r'cd587d0e3b9156d8fc872182d53bdb5005c004d0';

/// See also [restaurantDishes].
@ProviderFor(restaurantDishes)
const restaurantDishesProvider = RestaurantDishesFamily();

/// See also [restaurantDishes].
class RestaurantDishesFamily extends Family<AsyncValue<List<DishItem>>> {
  /// See also [restaurantDishes].
  const RestaurantDishesFamily();

  /// See also [restaurantDishes].
  RestaurantDishesProvider call(String restaurantId) {
    return RestaurantDishesProvider(restaurantId);
  }

  @override
  RestaurantDishesProvider getProviderOverride(
    covariant RestaurantDishesProvider provider,
  ) {
    return call(provider.restaurantId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'restaurantDishesProvider';
}

/// See also [restaurantDishes].
class RestaurantDishesProvider
    extends AutoDisposeFutureProvider<List<DishItem>> {
  /// See also [restaurantDishes].
  RestaurantDishesProvider(String restaurantId)
    : this._internal(
        (ref) => restaurantDishes(ref as RestaurantDishesRef, restaurantId),
        from: restaurantDishesProvider,
        name: r'restaurantDishesProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$restaurantDishesHash,
        dependencies: RestaurantDishesFamily._dependencies,
        allTransitiveDependencies:
            RestaurantDishesFamily._allTransitiveDependencies,
        restaurantId: restaurantId,
      );

  RestaurantDishesProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.restaurantId,
  }) : super.internal();

  final String restaurantId;

  @override
  Override overrideWith(
    FutureOr<List<DishItem>> Function(RestaurantDishesRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: RestaurantDishesProvider._internal(
        (ref) => create(ref as RestaurantDishesRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        restaurantId: restaurantId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<DishItem>> createElement() {
    return _RestaurantDishesProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is RestaurantDishesProvider &&
        other.restaurantId == restaurantId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, restaurantId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin RestaurantDishesRef on AutoDisposeFutureProviderRef<List<DishItem>> {
  /// The parameter `restaurantId` of this provider.
  String get restaurantId;
}

class _RestaurantDishesProviderElement
    extends AutoDisposeFutureProviderElement<List<DishItem>>
    with RestaurantDishesRef {
  _RestaurantDishesProviderElement(super.provider);

  @override
  String get restaurantId => (origin as RestaurantDishesProvider).restaurantId;
}

String _$yourTopBitesHash() => r'473586fa3e44c06bf150c0e2f7a21b0c669789c2';

/// See also [yourTopBites].
@ProviderFor(yourTopBites)
const yourTopBitesProvider = YourTopBitesFamily();

/// See also [yourTopBites].
class YourTopBitesFamily extends Family<AsyncValue<List<TopBiteRow>>> {
  /// See also [yourTopBites].
  const YourTopBitesFamily();

  /// See also [yourTopBites].
  YourTopBitesProvider call(String restaurantId) {
    return YourTopBitesProvider(restaurantId);
  }

  @override
  YourTopBitesProvider getProviderOverride(
    covariant YourTopBitesProvider provider,
  ) {
    return call(provider.restaurantId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'yourTopBitesProvider';
}

/// See also [yourTopBites].
class YourTopBitesProvider extends AutoDisposeFutureProvider<List<TopBiteRow>> {
  /// See also [yourTopBites].
  YourTopBitesProvider(String restaurantId)
    : this._internal(
        (ref) => yourTopBites(ref as YourTopBitesRef, restaurantId),
        from: yourTopBitesProvider,
        name: r'yourTopBitesProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$yourTopBitesHash,
        dependencies: YourTopBitesFamily._dependencies,
        allTransitiveDependencies:
            YourTopBitesFamily._allTransitiveDependencies,
        restaurantId: restaurantId,
      );

  YourTopBitesProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.restaurantId,
  }) : super.internal();

  final String restaurantId;

  @override
  Override overrideWith(
    FutureOr<List<TopBiteRow>> Function(YourTopBitesRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: YourTopBitesProvider._internal(
        (ref) => create(ref as YourTopBitesRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        restaurantId: restaurantId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<TopBiteRow>> createElement() {
    return _YourTopBitesProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is YourTopBitesProvider && other.restaurantId == restaurantId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, restaurantId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin YourTopBitesRef on AutoDisposeFutureProviderRef<List<TopBiteRow>> {
  /// The parameter `restaurantId` of this provider.
  String get restaurantId;
}

class _YourTopBitesProviderElement
    extends AutoDisposeFutureProviderElement<List<TopBiteRow>>
    with YourTopBitesRef {
  _YourTopBitesProviderElement(super.provider);

  @override
  String get restaurantId => (origin as YourTopBitesProvider).restaurantId;
}

String _$dishReactionSummaryHash() =>
    r'4ed4d4d5f7510b707e6a13072ba73c4b0a655d5a';

/// See also [dishReactionSummary].
@ProviderFor(dishReactionSummary)
const dishReactionSummaryProvider = DishReactionSummaryFamily();

/// See also [dishReactionSummary].
class DishReactionSummaryFamily extends Family<AsyncValue<ReactionSummary>> {
  /// See also [dishReactionSummary].
  const DishReactionSummaryFamily();

  /// See also [dishReactionSummary].
  DishReactionSummaryProvider call(String dishId) {
    return DishReactionSummaryProvider(dishId);
  }

  @override
  DishReactionSummaryProvider getProviderOverride(
    covariant DishReactionSummaryProvider provider,
  ) {
    return call(provider.dishId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'dishReactionSummaryProvider';
}

/// See also [dishReactionSummary].
class DishReactionSummaryProvider
    extends AutoDisposeFutureProvider<ReactionSummary> {
  /// See also [dishReactionSummary].
  DishReactionSummaryProvider(String dishId)
    : this._internal(
        (ref) => dishReactionSummary(ref as DishReactionSummaryRef, dishId),
        from: dishReactionSummaryProvider,
        name: r'dishReactionSummaryProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$dishReactionSummaryHash,
        dependencies: DishReactionSummaryFamily._dependencies,
        allTransitiveDependencies:
            DishReactionSummaryFamily._allTransitiveDependencies,
        dishId: dishId,
      );

  DishReactionSummaryProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.dishId,
  }) : super.internal();

  final String dishId;

  @override
  Override overrideWith(
    FutureOr<ReactionSummary> Function(DishReactionSummaryRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: DishReactionSummaryProvider._internal(
        (ref) => create(ref as DishReactionSummaryRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        dishId: dishId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<ReactionSummary> createElement() {
    return _DishReactionSummaryProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is DishReactionSummaryProvider && other.dishId == dishId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, dishId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin DishReactionSummaryRef on AutoDisposeFutureProviderRef<ReactionSummary> {
  /// The parameter `dishId` of this provider.
  String get dishId;
}

class _DishReactionSummaryProviderElement
    extends AutoDisposeFutureProviderElement<ReactionSummary>
    with DishReactionSummaryRef {
  _DishReactionSummaryProviderElement(super.provider);

  @override
  String get dishId => (origin as DishReactionSummaryProvider).dishId;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
