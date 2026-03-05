import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/billing/pro_status_provider.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/auth_state.dart';

part 'profile_repository.g.dart';

// ─────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────

class TasteProfileStatus {
  final int reactionCount;
  final int threshold;
  final double progress;
  final bool complete;
  final bool insightsLocked;

  const TasteProfileStatus({
    required this.reactionCount,
    required this.threshold,
    required this.progress,
    required this.complete,
    required this.insightsLocked,
  });

  factory TasteProfileStatus.fromJson(Map<String, dynamic> json) =>
      TasteProfileStatus(
        reactionCount: (json['reaction_count'] as num?)?.toInt() ?? 0,
        threshold: (json['threshold'] as num?)?.toInt() ?? 10,
        progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
        complete: json['complete'] as bool? ?? false,
        insightsLocked: json['insights_locked'] as bool? ?? true,
      );

  static const empty = TasteProfileStatus(
    reactionCount: 0,
    threshold: 10,
    progress: 0.0,
    complete: false,
    insightsLocked: true,
  );
}

class TasteInsights {
  final bool ready;
  final int reactionCount;
  final List<String> insights;

  const TasteInsights({
    required this.ready,
    required this.reactionCount,
    required this.insights,
  });

  factory TasteInsights.fromJson(Map<String, dynamic> json) => TasteInsights(
    ready: json['ready'] as bool? ?? false,
    reactionCount: (json['reaction_count'] as num?)?.toInt() ?? 0,
    insights: (json['insights'] as List<dynamic>?)?.cast<String>() ?? [],
  );
}

// ─────────────────────────────────────────────
// Providers
// ─────────────────────────────────────────────

@riverpod
Future<TasteProfileStatus> tasteProfileStatus(Ref ref) async {
  final auth = ref.watch(authStateProvider).value;
  if (auth == null) return TasteProfileStatus.empty;
  final dio = ref.watch(apiClientProvider);
  final response = await dio.get('/users/me/taste-profile-status');
  return TasteProfileStatus.fromJson(response.data as Map<String, dynamic>);
}

@riverpod
Future<TasteInsights?> tasteInsights(Ref ref) async {
  final isPro = ref.watch(proStatusProvider);
  if (!isPro) return null;
  final dio = ref.watch(apiClientProvider);
  try {
    final response = await dio.get('/users/me/taste-insights');
    return TasteInsights.fromJson(response.data as Map<String, dynamic>);
  } catch (_) {
    return null;
  }
}
