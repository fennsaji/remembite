// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'favorites_screen.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$favoritedDishesHash() => r'fdf27048d6d66a325c3bc89b5aa73bf4e16be30a';

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

/// See also [favoritedDishes].
@ProviderFor(favoritedDishes)
const favoritedDishesProvider = FavoritedDishesFamily();

/// See also [favoritedDishes].
class FavoritedDishesFamily extends Family<AsyncValue<List<FavoritedDish>>> {
  /// See also [favoritedDishes].
  const FavoritedDishesFamily();

  /// See also [favoritedDishes].
  FavoritedDishesProvider call(String userId) {
    return FavoritedDishesProvider(userId);
  }

  @override
  FavoritedDishesProvider getProviderOverride(
    covariant FavoritedDishesProvider provider,
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
  String? get name => r'favoritedDishesProvider';
}

/// See also [favoritedDishes].
class FavoritedDishesProvider
    extends AutoDisposeStreamProvider<List<FavoritedDish>> {
  /// See also [favoritedDishes].
  FavoritedDishesProvider(String userId)
    : this._internal(
        (ref) => favoritedDishes(ref as FavoritedDishesRef, userId),
        from: favoritedDishesProvider,
        name: r'favoritedDishesProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$favoritedDishesHash,
        dependencies: FavoritedDishesFamily._dependencies,
        allTransitiveDependencies:
            FavoritedDishesFamily._allTransitiveDependencies,
        userId: userId,
      );

  FavoritedDishesProvider._internal(
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
    Stream<List<FavoritedDish>> Function(FavoritedDishesRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: FavoritedDishesProvider._internal(
        (ref) => create(ref as FavoritedDishesRef),
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
  AutoDisposeStreamProviderElement<List<FavoritedDish>> createElement() {
    return _FavoritedDishesProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is FavoritedDishesProvider && other.userId == userId;
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
mixin FavoritedDishesRef on AutoDisposeStreamProviderRef<List<FavoritedDish>> {
  /// The parameter `userId` of this provider.
  String get userId;
}

class _FavoritedDishesProviderElement
    extends AutoDisposeStreamProviderElement<List<FavoritedDish>>
    with FavoritedDishesRef {
  _FavoritedDishesProviderElement(super.provider);

  @override
  String get userId => (origin as FavoritedDishesProvider).userId;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
