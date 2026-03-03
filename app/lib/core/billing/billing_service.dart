import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../network/api_client.dart';
import '../network/auth_state.dart';
import '../sync/sync_worker.dart';

part 'billing_service.g.dart';

const _kProductIds = {
  'remembite_pro_monthly',
  'remembite_pro_annual',
};

enum BillingState { idle, loading, purchasing, error }

@riverpod
class BillingService extends _$BillingService {
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;
  List<ProductDetails> _products = [];

  @override
  BillingState build() {
    ref.onDispose(() => _purchaseSub?.cancel());
    _init();
    return BillingState.idle;
  }

  List<ProductDetails> get products => _products;

  Future<void> _init() async {
    final available = await InAppPurchase.instance.isAvailable();
    if (!available) return;

    _purchaseSub = InAppPurchase.instance.purchaseStream
        .listen(_handlePurchaseUpdate);

    await _loadProducts();
    await InAppPurchase.instance.restorePurchases();
  }

  Future<void> _loadProducts() async {
    final response =
        await InAppPurchase.instance.queryProductDetails(_kProductIds);
    _products = response.productDetails;
  }

  Future<void> purchase(String productId) async {
    final product = _products.firstWhere(
      (p) => p.id == productId,
      orElse: () => throw Exception('Product not found: $productId'),
    );
    state = BillingState.purchasing;
    await InAppPurchase.instance.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: product),
    );
  }

  Future<void> _handlePurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _verifyAndActivate(purchase);
        case PurchaseStatus.error:
          state = BillingState.error;
          await InAppPurchase.instance.completePurchase(purchase);
        case PurchaseStatus.canceled:
          state = BillingState.idle;
        case PurchaseStatus.pending:
          state = BillingState.purchasing;
      }
    }
  }

  Future<void> _verifyAndActivate(PurchaseDetails purchase) async {
    try {
      final dio = ref.read(apiClientProvider);
      final response = await dio.post(
        '/payments/verify',
        data: {
          'purchase_token': purchase.verificationData.serverVerificationData,
          'product_id': purchase.productID,
        },
      );

      final currentAuth = ref.read(authStateProvider).value;
      if (currentAuth != null) {
        final updatedUser = AuthUser(
          id: currentAuth.id,
          email: currentAuth.email,
          displayName: currentAuth.displayName,
          avatarUrl: currentAuth.avatarUrl,
          isPro: true,
          accessToken: response.data['access_token'] as String,
        );
        await ref.read(authStateProvider.notifier).signIn(updatedUser);
      }

      await InAppPurchase.instance.completePurchase(purchase);
      state = BillingState.idle;

      // Trigger immediate cloud sync now that user is Pro
      ref.read(syncWorkerProvider.notifier).syncNow();
    } catch (e) {
      state = BillingState.error;
      await InAppPurchase.instance.completePurchase(purchase);
    }
  }
}
