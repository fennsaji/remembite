// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dish_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$dishRepositoryHash() => r'e36a613511dbdab9e3cfbad80119e6dada964fee';

/// See also [dishRepository].
@ProviderFor(dishRepository)
final dishRepositoryProvider = AutoDisposeProvider<DishRepository>.internal(
  dishRepository,
  name: r'dishRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$dishRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef DishRepositoryRef = AutoDisposeProviderRef<DishRepository>;
String _$compatibilitySignalHash() =>
    r'afbee76e5a8dac3c1916d39185131fe5f773a4b3';

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

/// See also [compatibilitySignal].
@ProviderFor(compatibilitySignal)
const compatibilitySignalProvider = CompatibilitySignalFamily();

/// See also [compatibilitySignal].
class CompatibilitySignalFamily
    extends Family<AsyncValue<CompatibilitySignal?>> {
  /// See also [compatibilitySignal].
  const CompatibilitySignalFamily();

  /// See also [compatibilitySignal].
  CompatibilitySignalProvider call(String dishId) {
    return CompatibilitySignalProvider(dishId);
  }

  @override
  CompatibilitySignalProvider getProviderOverride(
    covariant CompatibilitySignalProvider provider,
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
  String? get name => r'compatibilitySignalProvider';
}

/// See also [compatibilitySignal].
class CompatibilitySignalProvider
    extends AutoDisposeFutureProvider<CompatibilitySignal?> {
  /// See also [compatibilitySignal].
  CompatibilitySignalProvider(String dishId)
    : this._internal(
        (ref) => compatibilitySignal(ref as CompatibilitySignalRef, dishId),
        from: compatibilitySignalProvider,
        name: r'compatibilitySignalProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$compatibilitySignalHash,
        dependencies: CompatibilitySignalFamily._dependencies,
        allTransitiveDependencies:
            CompatibilitySignalFamily._allTransitiveDependencies,
        dishId: dishId,
      );

  CompatibilitySignalProvider._internal(
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
    FutureOr<CompatibilitySignal?> Function(CompatibilitySignalRef provider)
    create,
  ) {
    return ProviderOverride(
      origin: this,
      override: CompatibilitySignalProvider._internal(
        (ref) => create(ref as CompatibilitySignalRef),
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
  AutoDisposeFutureProviderElement<CompatibilitySignal?> createElement() {
    return _CompatibilitySignalProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is CompatibilitySignalProvider && other.dishId == dishId;
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
mixin CompatibilitySignalRef
    on AutoDisposeFutureProviderRef<CompatibilitySignal?> {
  /// The parameter `dishId` of this provider.
  String get dishId;
}

class _CompatibilitySignalProviderElement
    extends AutoDisposeFutureProviderElement<CompatibilitySignal?>
    with CompatibilitySignalRef {
  _CompatibilitySignalProviderElement(super.provider);

  @override
  String get dishId => (origin as CompatibilitySignalProvider).dishId;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
