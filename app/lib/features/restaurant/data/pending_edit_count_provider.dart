import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/api_client.dart';

part 'pending_edit_count_provider.g.dart';

@riverpod
Future<int> pendingEditCount(Ref ref, String restaurantId) async {
  final dio = ref.watch(apiClientProvider);
  try {
    final response = await dio.get(
      '/edit-suggestions',
      queryParameters: {
        'entity_type': 'restaurant',
        'entity_id': restaurantId,
        'status': 'pending',
      },
    );
    final data = response.data as List<dynamic>;
    return data.length;
  } catch (_) {
    return 0;
  }
}
