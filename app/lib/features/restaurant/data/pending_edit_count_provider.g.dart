// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pending_edit_count_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$pendingEditCountHash() => r'9622d2a6e0bd48baad5634c7d4bbb7b65eea6087';

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

/// See also [pendingEditCount].
@ProviderFor(pendingEditCount)
const pendingEditCountProvider = PendingEditCountFamily();

/// See also [pendingEditCount].
class PendingEditCountFamily extends Family<AsyncValue<int>> {
  /// See also [pendingEditCount].
  const PendingEditCountFamily();

  /// See also [pendingEditCount].
  PendingEditCountProvider call(String restaurantId) {
    return PendingEditCountProvider(restaurantId);
  }

  @override
  PendingEditCountProvider getProviderOverride(
    covariant PendingEditCountProvider provider,
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
  String? get name => r'pendingEditCountProvider';
}

/// See also [pendingEditCount].
class PendingEditCountProvider extends AutoDisposeFutureProvider<int> {
  /// See also [pendingEditCount].
  PendingEditCountProvider(String restaurantId)
    : this._internal(
        (ref) => pendingEditCount(ref as PendingEditCountRef, restaurantId),
        from: pendingEditCountProvider,
        name: r'pendingEditCountProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$pendingEditCountHash,
        dependencies: PendingEditCountFamily._dependencies,
        allTransitiveDependencies:
            PendingEditCountFamily._allTransitiveDependencies,
        restaurantId: restaurantId,
      );

  PendingEditCountProvider._internal(
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
    FutureOr<int> Function(PendingEditCountRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: PendingEditCountProvider._internal(
        (ref) => create(ref as PendingEditCountRef),
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
  AutoDisposeFutureProviderElement<int> createElement() {
    return _PendingEditCountProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is PendingEditCountProvider &&
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
mixin PendingEditCountRef on AutoDisposeFutureProviderRef<int> {
  /// The parameter `restaurantId` of this provider.
  String get restaurantId;
}

class _PendingEditCountProviderElement
    extends AutoDisposeFutureProviderElement<int>
    with PendingEditCountRef {
  _PendingEditCountProviderElement(super.provider);

  @override
  String get restaurantId => (origin as PendingEditCountProvider).restaurantId;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
