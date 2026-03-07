// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'image_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$imageRepositoryHash() => r'583b6cc1c9d9cda443a27a19f96c59f523cef455';

/// See also [imageRepository].
@ProviderFor(imageRepository)
final imageRepositoryProvider = AutoDisposeProvider<ImageRepository>.internal(
  imageRepository,
  name: r'imageRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$imageRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ImageRepositoryRef = AutoDisposeProviderRef<ImageRepository>;
String _$dishImagesHash() => r'4badefbd482ec52cee8fd077dd8f979a9a1801b9';

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

/// See also [dishImages].
@ProviderFor(dishImages)
const dishImagesProvider = DishImagesFamily();

/// See also [dishImages].
class DishImagesFamily extends Family<AsyncValue<List<ImageModel>>> {
  /// See also [dishImages].
  const DishImagesFamily();

  /// See also [dishImages].
  DishImagesProvider call(String dishId) {
    return DishImagesProvider(dishId);
  }

  @override
  DishImagesProvider getProviderOverride(
    covariant DishImagesProvider provider,
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
  String? get name => r'dishImagesProvider';
}

/// See also [dishImages].
class DishImagesProvider extends AutoDisposeFutureProvider<List<ImageModel>> {
  /// See also [dishImages].
  DishImagesProvider(String dishId)
    : this._internal(
        (ref) => dishImages(ref as DishImagesRef, dishId),
        from: dishImagesProvider,
        name: r'dishImagesProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$dishImagesHash,
        dependencies: DishImagesFamily._dependencies,
        allTransitiveDependencies: DishImagesFamily._allTransitiveDependencies,
        dishId: dishId,
      );

  DishImagesProvider._internal(
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
    FutureOr<List<ImageModel>> Function(DishImagesRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: DishImagesProvider._internal(
        (ref) => create(ref as DishImagesRef),
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
  AutoDisposeFutureProviderElement<List<ImageModel>> createElement() {
    return _DishImagesProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is DishImagesProvider && other.dishId == dishId;
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
mixin DishImagesRef on AutoDisposeFutureProviderRef<List<ImageModel>> {
  /// The parameter `dishId` of this provider.
  String get dishId;
}

class _DishImagesProviderElement
    extends AutoDisposeFutureProviderElement<List<ImageModel>>
    with DishImagesRef {
  _DishImagesProviderElement(super.provider);

  @override
  String get dishId => (origin as DishImagesProvider).dishId;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
