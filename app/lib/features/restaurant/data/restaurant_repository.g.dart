// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'restaurant_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$restaurantRepositoryHash() =>
    r'b0c3c20d3d9d41072b8801e97be6418103caf457';

/// See also [restaurantRepository].
@ProviderFor(restaurantRepository)
final restaurantRepositoryProvider =
    AutoDisposeProvider<RestaurantRepository>.internal(
      restaurantRepository,
      name: r'restaurantRepositoryProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$restaurantRepositoryHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef RestaurantRepositoryRef = AutoDisposeProviderRef<RestaurantRepository>;
String _$restaurantReactionSummariesHash() =>
    r'b80b9fc3a9115cc1d6844ddcc888db3a2f9a0964';

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

/// Reaction summaries for a whole restaurant menu, keyed by dish id.
/// Replaces the per-dish `dishReactionSummaryProvider` on the menu list.
///
/// Copied from [restaurantReactionSummaries].
@ProviderFor(restaurantReactionSummaries)
const restaurantReactionSummariesProvider = RestaurantReactionSummariesFamily();

/// Reaction summaries for a whole restaurant menu, keyed by dish id.
/// Replaces the per-dish `dishReactionSummaryProvider` on the menu list.
///
/// Copied from [restaurantReactionSummaries].
class RestaurantReactionSummariesFamily
    extends Family<AsyncValue<Map<String, ReactionSummary>>> {
  /// Reaction summaries for a whole restaurant menu, keyed by dish id.
  /// Replaces the per-dish `dishReactionSummaryProvider` on the menu list.
  ///
  /// Copied from [restaurantReactionSummaries].
  const RestaurantReactionSummariesFamily();

  /// Reaction summaries for a whole restaurant menu, keyed by dish id.
  /// Replaces the per-dish `dishReactionSummaryProvider` on the menu list.
  ///
  /// Copied from [restaurantReactionSummaries].
  RestaurantReactionSummariesProvider call(String restaurantId) {
    return RestaurantReactionSummariesProvider(restaurantId);
  }

  @override
  RestaurantReactionSummariesProvider getProviderOverride(
    covariant RestaurantReactionSummariesProvider provider,
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
  String? get name => r'restaurantReactionSummariesProvider';
}

/// Reaction summaries for a whole restaurant menu, keyed by dish id.
/// Replaces the per-dish `dishReactionSummaryProvider` on the menu list.
///
/// Copied from [restaurantReactionSummaries].
class RestaurantReactionSummariesProvider
    extends AutoDisposeFutureProvider<Map<String, ReactionSummary>> {
  /// Reaction summaries for a whole restaurant menu, keyed by dish id.
  /// Replaces the per-dish `dishReactionSummaryProvider` on the menu list.
  ///
  /// Copied from [restaurantReactionSummaries].
  RestaurantReactionSummariesProvider(String restaurantId)
    : this._internal(
        (ref) => restaurantReactionSummaries(
          ref as RestaurantReactionSummariesRef,
          restaurantId,
        ),
        from: restaurantReactionSummariesProvider,
        name: r'restaurantReactionSummariesProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$restaurantReactionSummariesHash,
        dependencies: RestaurantReactionSummariesFamily._dependencies,
        allTransitiveDependencies:
            RestaurantReactionSummariesFamily._allTransitiveDependencies,
        restaurantId: restaurantId,
      );

  RestaurantReactionSummariesProvider._internal(
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
    FutureOr<Map<String, ReactionSummary>> Function(
      RestaurantReactionSummariesRef provider,
    )
    create,
  ) {
    return ProviderOverride(
      origin: this,
      override: RestaurantReactionSummariesProvider._internal(
        (ref) => create(ref as RestaurantReactionSummariesRef),
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
  AutoDisposeFutureProviderElement<Map<String, ReactionSummary>>
  createElement() {
    return _RestaurantReactionSummariesProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is RestaurantReactionSummariesProvider &&
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
mixin RestaurantReactionSummariesRef
    on AutoDisposeFutureProviderRef<Map<String, ReactionSummary>> {
  /// The parameter `restaurantId` of this provider.
  String get restaurantId;
}

class _RestaurantReactionSummariesProviderElement
    extends AutoDisposeFutureProviderElement<Map<String, ReactionSummary>>
    with RestaurantReactionSummariesRef {
  _RestaurantReactionSummariesProviderElement(super.provider);

  @override
  String get restaurantId =>
      (origin as RestaurantReactionSummariesProvider).restaurantId;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
