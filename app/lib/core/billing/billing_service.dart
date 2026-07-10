import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../network/api_client.dart';
import '../network/auth_state.dart';
import '../sync/sync_worker.dart';

part 'billing_service.g.dart';

const _kProductIds = {'remembite_pro_monthly', 'remembite_pro_annual'};

enum BillingState { idle, loading, purchasing, error }

@riverpod
class BillingService extends _$BillingService {
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;
  List<ProductDetails> _products = [];
  String? _purchasingProductId;

  @override
  BillingState build() {
    ref.onDispose(() => _purchaseSub?.cancel());
    _init();
    return BillingState.idle;
  }

  List<ProductDetails> get products => _products;

  /// Which product is mid-purchase, if any — lets the UI show "Processing…"
  /// on the specific card the user tapped instead of every card sharing one
  /// boolean (previously Monthly's loading state was hardcoded `false`, so
  /// tapping Monthly showed "Processing…" on the Annual card instead).
  String? get purchasingProductId => _purchasingProductId;

  Future<void> _init() async {
    final available = await InAppPurchase.instance.isAvailable();
    if (!available) return;

    _purchaseSub = InAppPurchase.instance.purchaseStream.listen(
      _handlePurchaseUpdate,
    );

    await _loadProducts();
    await InAppPurchase.instance.restorePurchases();
  }

  Future<void> _loadProducts() async {
    final response = await InAppPurchase.instance.queryProductDetails(
      _kProductIds,
    );
    _products = response.productDetails;
  }

  Future<void> purchase(String productId) async {
    ProductDetails product;
    try {
      // firstWhere throws (not returns null) on no match — this fires if
      // products haven't finished loading yet (e.g. offline at app start)
      // or the Play Store product ID is wrong. Previously uncaught, so
      // tapping Subscribe did nothing: state never left `idle`, no error
      // shown, no button ever went into "Processing…".
      product = _products.firstWhere((p) => p.id == productId);
    } catch (_) {
      state = BillingState.error;
      return;
    }

    _purchasingProductId = productId;
    state = BillingState.purchasing;
    try {
      final launched = await InAppPurchase.instance.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
      if (!launched) {
        // Store dialog failed to launch (e.g. itemAlreadyOwned, pending
        // purchase) — purchaseStream never fires for this attempt, so
        // without this check `state` stayed `purchasing` forever and both
        // Subscribe buttons stayed disabled until app restart.
        _purchasingProductId = null;
        state = BillingState.error;
      }
    } catch (_) {
      _purchasingProductId = null;
      state = BillingState.error;
    }
  }

  Future<void> _handlePurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _verifyAndActivate(purchase);
        case PurchaseStatus.error:
          _purchasingProductId = null;
          state = BillingState.error;
          await InAppPurchase.instance.completePurchase(purchase);
        case PurchaseStatus.canceled:
          _purchasingProductId = null;
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
          refreshToken: response.data['refresh_token'] as String,
        );
        await ref.read(authStateProvider.notifier).signIn(updatedUser);
      }

      await InAppPurchase.instance.completePurchase(purchase);
      _purchasingProductId = null;
      state = BillingState.idle;

      // Trigger immediate cloud sync now that user is Pro
      ref.read(syncWorkerProvider.notifier).syncNow();
    } catch (e) {
      _purchasingProductId = null;
      state = BillingState.error;
      // Do NOT call completePurchase here — the transaction stays pending
      // so the store re-delivers it on the next app launch for retry.
    }
  }
}
