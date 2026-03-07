// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pro_status_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$proStatusHash() => r'367a3b5dcdfd2af65a492ab0dcd64d51051664d9';

/// True when the current user has an active Pro subscription.
/// Single source of truth for Pro gating in the UI.
///
/// Copied from [proStatus].
@ProviderFor(proStatus)
final proStatusProvider = AutoDisposeProvider<bool>.internal(
  proStatus,
  name: r'proStatusProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$proStatusHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ProStatusRef = AutoDisposeProviderRef<bool>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
