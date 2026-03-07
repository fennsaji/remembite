import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../network/auth_state.dart';

part 'pro_status_provider.g.dart';

/// True when the current user has an active Pro subscription.
/// Single source of truth for Pro gating in the UI.
@riverpod
bool proStatus(Ref ref) {
  final auth = ref.watch(authStateProvider).value;
  return auth?.isPro ?? false;
}
