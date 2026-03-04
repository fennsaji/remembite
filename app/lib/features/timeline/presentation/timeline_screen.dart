import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/theme/app_theme.dart';
import '../data/timeline_repository.dart';

part 'timeline_screen.g.dart';

@riverpod
Future<List<TimelineEntry>> timeline(Ref ref) =>
    ref.watch(timelineRepositoryProvider).getTimeline();

class TimelineScreen extends ConsumerWidget {
  const TimelineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timelineAsync = ref.watch(timelineProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        automaticallyImplyLeading: false,
        title: Text(
          'Visit Timeline',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.primaryText,
              ),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.accent,
        backgroundColor: AppColors.elevated,
        onRefresh: () => ref.refresh(timelineProvider.future),
        child: timelineAsync.when(
          loading: () => const SingleChildScrollView(
            physics: AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: 300,
              child: Center(
                child: CircularProgressIndicator(color: AppColors.accent),
              ),
            ),
          ),
          error: (e, _) => const SingleChildScrollView(
            physics: AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: 300,
              child: Center(
                child: Text(
                  'Could not load timeline.',
                  style: TextStyle(color: AppColors.mutedText),
                ),
              ),
            ),
          ),
          data: (entries) {
            if (entries.isEmpty) {
              return const SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: 300,
                  child: Center(
                    child: Text(
                      'No visits yet.\nReact to dishes to build your timeline.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.mutedText),
                    ),
                  ),
                ),
              );
            }

            // Group by month
            final grouped = <String, List<TimelineEntry>>{};
            for (final entry in entries) {
              final monthKey = _monthKey(entry.date);
              grouped.putIfAbsent(monthKey, () => []).add(entry);
            }

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 24),
              children: grouped.entries.expand((group) {
                return [
                  _MonthHeader(monthKey: group.key),
                  ...group.value.map((entry) => _VisitCard(entry: entry)),
                ];
              }).toList(),
            );
          },
        ),
      ),
    );
  }

  String _monthKey(String dateStr) {
    final date = DateTime.parse(dateStr);
    return DateFormat('MMMM yyyy').format(date);
  }
}

class _MonthHeader extends StatelessWidget {
  final String monthKey;
  const _MonthHeader({required this.monthKey});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Row(
        children: [
          Container(width: 24, height: 2, color: AppColors.accent),
          const SizedBox(width: 8),
          Text(
            monthKey.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.secondaryText,
                  letterSpacing: 0.8,
                ),
          ),
        ],
      ),
    );
  }
}

class _VisitCard extends StatelessWidget {
  final TimelineEntry entry;
  const _VisitCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final date = DateTime.parse(entry.date);
    final formattedDate = DateFormat('d MMM').format(date);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.elevated,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              formattedDate,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.secondaryText,
                  ),
            ),
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.restaurantName,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.primaryText,
                      ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: entry.reactions
                      .map((r) => _ReactionChip(reaction: r))
                      .toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReactionChip extends StatelessWidget {
  final DishReactionItem reaction;
  const _ReactionChip({required this.reaction});

  String get _emoji {
    switch (reaction.reaction) {
      case 'so_yummy': return '🔥';
      case 'tasty': return '😋';
      case 'pretty_good': return '🙂';
      case 'meh': return '😐';
      case 'never_again': return '🤢';
      default: return '•';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.elevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        '$_emoji ${reaction.dishName}',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.secondaryText,
              fontSize: 11,
            ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
