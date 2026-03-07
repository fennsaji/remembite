import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter_android/google_maps_flutter_android.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';

import 'core/billing/billing_service.dart';
import 'core/router/app_router.dart';
import 'core/sync/sync_worker.dart';
import 'core/theme/app_theme.dart';

/// Top-level background message handler — required to be a top-level function,
/// not a closure or class method. Called by Flutter's background isolate when
/// a FCM message arrives while the app is in the background or terminated.
@pragma('vm:entry-point')
Future<void> _fcmBackgroundHandler(RemoteMessage message) async {
  // Background messages are handled; dish detail will refresh on next open
  // via getInitialMessage / onMessageOpenedApp in the router.
  debugPrint('FCM background message: ${message.data}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Switch Google Maps Android to Virtual Display (AndroidView) mode.
  //
  // The default since google_maps_flutter_android 2.12 is Hybrid Composition
  // (SurfaceAndroidView), where the native map view creates full-screen overlay
  // surfaces that intercept ALL touches — breaking both map panning and Flutter
  // overlay widgets (search bar, buttons) placed above the map in a Stack.
  //
  // Virtual Display composites the map into Flutter's rendering pipeline;
  // all touches route through Flutter's normal gesture system, so overlays
  // and map panning both work correctly.
  final mapsImpl = GoogleMapsFlutterPlatform.instance;
  if (mapsImpl is GoogleMapsFlutterAndroid) {
    mapsImpl.useAndroidViewSurface = false;
  }

  await Firebase.initializeApp();

  // Register the background message handler before runApp.
  FirebaseMessaging.onBackgroundMessage(_fcmBackgroundHandler);

  // Handle terminated-state notification tap. For MVP, navigating to home
  // lets the user find the dish from there once the app is fully initialized.
  final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
  String? initialLocation;
  if (initialMessage != null &&
      initialMessage.data['type'] == 'classification_complete') {
    // Route directly to the dish if an ID was provided; fall back to home.
    final dishId = initialMessage.data['dish_id'];
    if (dishId != null && (dishId as String).isNotEmpty) {
      initialLocation = '/dish/$dishId';
    }
  }

  runApp(ProviderScope(child: RemembiteApp(initialLocation: initialLocation)));
}

class RemembiteApp extends ConsumerStatefulWidget {
  final String? initialLocation;
  const RemembiteApp({super.key, this.initialLocation});

  @override
  ConsumerState<RemembiteApp> createState() => _RemembiteAppState();
}

class _RemembiteAppState extends ConsumerState<RemembiteApp> {
  @override
  void initState() {
    super.initState();
    // Handle notification taps while the app is running in the background.
    // This fires when the user taps a notification and the app is brought
    // to the foreground from a background (not terminated) state.
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      if (message.data['type'] == 'classification_complete') {
        final dishId = message.data['dish_id'];
        if (dishId != null && (dishId as String).isNotEmpty) {
          // Use GoRouter to navigate. Access via context once the widget tree
          // is mounted (this listener fires after the app is visible).
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              GoRouter.of(context).push('/dish/$dishId');
            }
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(syncWorkerProvider); // boot the sync worker
    ref.watch(billingServiceProvider); // boot billing + restore purchases
    final router = ref.watch(
      appRouterProvider(initialLocation: widget.initialLocation),
    );
    return MaterialApp.router(
      title: 'Remembite',
      theme: AppTheme.dark,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
