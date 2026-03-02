// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_state.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$restaurantSessionStateHash() =>
    r'1bc5ee8f9de085c07850be71663e3ea052dd44f7';

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

abstract class _$RestaurantSessionState
    extends BuildlessAutoDisposeNotifier<RestaurantSessionRecord> {
  late final String restaurantId;

  RestaurantSessionRecord build(String restaurantId);
}

/// See also [RestaurantSessionState].
@ProviderFor(RestaurantSessionState)
const restaurantSessionStateProvider = RestaurantSessionStateFamily();

/// See also [RestaurantSessionState].
class RestaurantSessionStateFamily extends Family<RestaurantSessionRecord> {
  /// See also [RestaurantSessionState].
  const RestaurantSessionStateFamily();

  /// See also [RestaurantSessionState].
  RestaurantSessionStateProvider call(String restaurantId) {
    return RestaurantSessionStateProvider(restaurantId);
  }

  @override
  RestaurantSessionStateProvider getProviderOverride(
    covariant RestaurantSessionStateProvider provider,
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
  String? get name => r'restaurantSessionStateProvider';
}

/// See also [RestaurantSessionState].
class RestaurantSessionStateProvider
    extends
        AutoDisposeNotifierProviderImpl<
          RestaurantSessionState,
          RestaurantSessionRecord
        > {
  /// See also [RestaurantSessionState].
  RestaurantSessionStateProvider(String restaurantId)
    : this._internal(
        () => RestaurantSessionState()..restaurantId = restaurantId,
        from: restaurantSessionStateProvider,
        name: r'restaurantSessionStateProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$restaurantSessionStateHash,
        dependencies: RestaurantSessionStateFamily._dependencies,
        allTransitiveDependencies:
            RestaurantSessionStateFamily._allTransitiveDependencies,
        restaurantId: restaurantId,
      );

  RestaurantSessionStateProvider._internal(
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
  RestaurantSessionRecord runNotifierBuild(
    covariant RestaurantSessionState notifier,
  ) {
    return notifier.build(restaurantId);
  }

  @override
  Override overrideWith(RestaurantSessionState Function() create) {
    return ProviderOverride(
      origin: this,
      override: RestaurantSessionStateProvider._internal(
        () => create()..restaurantId = restaurantId,
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
  AutoDisposeNotifierProviderElement<
    RestaurantSessionState,
    RestaurantSessionRecord
  >
  createElement() {
    return _RestaurantSessionStateProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is RestaurantSessionStateProvider &&
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
mixin RestaurantSessionStateRef
    on AutoDisposeNotifierProviderRef<RestaurantSessionRecord> {
  /// The parameter `restaurantId` of this provider.
  String get restaurantId;
}

class _RestaurantSessionStateProviderElement
    extends
        AutoDisposeNotifierProviderElement<
          RestaurantSessionState,
          RestaurantSessionRecord
        >
    with RestaurantSessionStateRef {
  _RestaurantSessionStateProviderElement(super.provider);

  @override
  String get restaurantId =>
      (origin as RestaurantSessionStateProvider).restaurantId;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
