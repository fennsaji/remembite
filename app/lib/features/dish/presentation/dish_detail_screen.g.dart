// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dish_detail_screen.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$dishDetailHash() => r'7917c8d78c74d208e741436d0571ab6a9130b00d';

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

/// See also [dishDetail].
@ProviderFor(dishDetail)
const dishDetailProvider = DishDetailFamily();

/// See also [dishDetail].
class DishDetailFamily extends Family<AsyncValue<DishDetail>> {
  /// See also [dishDetail].
  const DishDetailFamily();

  /// See also [dishDetail].
  DishDetailProvider call(String id) {
    return DishDetailProvider(id);
  }

  @override
  DishDetailProvider getProviderOverride(
    covariant DishDetailProvider provider,
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
  String? get name => r'dishDetailProvider';
}

/// See also [dishDetail].
class DishDetailProvider extends AutoDisposeFutureProvider<DishDetail> {
  /// See also [dishDetail].
  DishDetailProvider(String id)
    : this._internal(
        (ref) => dishDetail(ref as DishDetailRef, id),
        from: dishDetailProvider,
        name: r'dishDetailProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$dishDetailHash,
        dependencies: DishDetailFamily._dependencies,
        allTransitiveDependencies: DishDetailFamily._allTransitiveDependencies,
        id: id,
      );

  DishDetailProvider._internal(
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
    FutureOr<DishDetail> Function(DishDetailRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: DishDetailProvider._internal(
        (ref) => create(ref as DishDetailRef),
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
  AutoDisposeFutureProviderElement<DishDetail> createElement() {
    return _DishDetailProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is DishDetailProvider && other.id == id;
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
mixin DishDetailRef on AutoDisposeFutureProviderRef<DishDetail> {
  /// The parameter `id` of this provider.
  String get id;
}

class _DishDetailProviderElement
    extends AutoDisposeFutureProviderElement<DishDetail>
    with DishDetailRef {
  _DishDetailProviderElement(super.provider);

  @override
  String get id => (origin as DishDetailProvider).id;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
