// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'billing_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$proProductsHash() => r'26572874f825e43b26de5a72d6c5ddfbb7f30210';

/// Live store product details keyed by product id.
///
/// The prices shown on the paywall must come from the store, not from
/// hardcoded strings — Play prices vary by region, can be changed in the
/// console, and may carry a promotional price. `BillingService.products` is
/// filled asynchronously inside `_init()` and setting `state` to the same
/// `BillingState` wouldn't notify listeners, so the UI reads prices through
/// this provider instead.
///
/// Copied from [proProducts].
@ProviderFor(proProducts)
final proProductsProvider =
    AutoDisposeFutureProvider<Map<String, ProductDetails>>.internal(
      proProducts,
      name: r'proProductsProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$proProductsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ProProductsRef =
    AutoDisposeFutureProviderRef<Map<String, ProductDetails>>;
String _$billingServiceHash() => r'85ff6f303256fe6bc6586dfbff85935690096d94';

/// See also [BillingService].
@ProviderFor(BillingService)
final billingServiceProvider =
    AutoDisposeNotifierProvider<BillingService, BillingState>.internal(
      BillingService.new,
      name: r'billingServiceProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$billingServiceHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$BillingService = AutoDisposeNotifier<BillingState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
