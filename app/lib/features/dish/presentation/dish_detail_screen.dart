import 'dart:async';
import 'dart:ui' as ui;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/billing/pro_status_provider.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/auth_state.dart';
import '../../../core/theme/app_theme.dart';
import '../data/dish_repository.dart';
import '../../restaurant/presentation/session_state.dart';

part 'dish_detail_screen.g.dart';

@riverpod
Future<DishDetail> dishDetail(Ref ref, String id) =>
    ref.watch(dishRepositoryProvider).getDishDetail(id);

const _reactions = [
  ('🔥', 'so_yummy', 'So Yummy'),
  ('😋', 'tasty', 'Tasty'),
  ('🙂', 'pretty_good', 'Pretty Good'),
  ('😐', 'meh', 'Meh'),
  ('🤢', 'never_again', 'Never Again'),
];

const _spiceOptions = [
  ('Mild', 0.2),
  ('Med', 0.5),
  ('Hot', 0.9),
];

const _sweetnessOptions = [
  ('Low', 0.2),
  ('Medium', 0.5),
  ('Sweet', 0.9),
];

// Report reason options
const _reportReasons = [
  'Incorrect info',
  'Duplicate dish',
  'Inappropriate content',
  'Other',
];

class DishDetailScreen extends ConsumerStatefulWidget {
  final String dishId;
  const DishDetailScreen({super.key, required this.dishId});

  @override
  ConsumerState<DishDetailScreen> createState() => _DishDetailScreenState();
}

class _DishDetailScreenState extends ConsumerState<DishDetailScreen> {
  String? _selectedReaction;
  String? _selectedSpice;
  String? _selectedSweetness;
  final _notesController = TextEditingController();
  bool _saving = false;
  StreamSubscription<RemoteMessage>? _fcmSubscription;

  @override
  void initState() {
    super.initState();
    _fcmSubscription = FirebaseMessaging.onMessage.listen((message) {
      if (message.data['type'] == 'classification_complete' &&
          message.data['dish_id'] == widget.dishId) {
        ref.invalidate(dishDetailProvider(widget.dishId));
      }
    });
  }

  @override
  void dispose() {
    _fcmSubscription?.cancel();
    _notesController.dispose();
    super.dispose();
  }

  void _showMoreOptions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.elevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.flag_outlined,
                  color: AppColors.secondaryText),
              title: const Text(
                'Report this dish',
                style: TextStyle(color: AppColors.primaryText),
              ),
              onTap: () {
                Navigator.of(context).pop();
                // Use State.mounted (always available), not BuildContext.mounted
                if (mounted) {
                  _showReportSheet(context, widget.dishId);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showReportSheet(BuildContext context, String dishId) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.elevated,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ReportDishSheet(dishId: dishId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dishAsync = ref.watch(dishDetailProvider(widget.dishId));
    final auth = ref.watch(authStateProvider).value;
    final isPro = ref.watch(proStatusProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: IconButton(
          icon:
              const Icon(Icons.arrow_back, color: AppColors.primaryText),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert,
                color: AppColors.secondaryText),
            onPressed: () => _showMoreOptions(context),
            tooltip: 'More options',
          ),
        ],
      ),
      body: dishAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
        error: (e, _) => Center(
          child: Text('Error: $e',
              style: const TextStyle(color: AppColors.error)),
        ),
        data: (dish) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Dish name
            Text(
              dish.name,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AppColors.primaryText,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            if (dish.category != null) ...[
              const SizedBox(height: 4),
              Text(
                dish.category!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.mutedText,
                    ),
              ),
            ],
            if (dish.price != null) ...[
              const SizedBox(height: 4),
              Text(
                '₹${dish.price}',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.secondaryText,
                    ),
              ),
            ],
            const SizedBox(height: 28),

            // Reaction picker
            _SectionLabel(label: 'YOUR REACTION'),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: _reactions.map((r) {
                final (emoji, value, label) = r;
                final isSelected = _selectedReaction == value;
                return GestureDetector(
                  onTap: () =>
                      setState(() => _selectedReaction = value),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.accent.withValues(alpha: 0.15)
                          : AppColors.elevated,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.accent
                            : AppColors.border,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(emoji,
                            style: const TextStyle(fontSize: 24)),
                        const SizedBox(height: 2),
                        Text(
                          label,
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: isSelected
                                        ? AppColors.accent
                                        : AppColors.mutedText,
                                    fontSize: 9,
                                  ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Spice vote
            _SectionLabel(label: 'SPICE LEVEL'),
            const SizedBox(height: 12),
            _VoteRow(
              options: _spiceOptions
                  .map((s) => (s.$1, s.$2.toString()))
                  .toList(),
              selected: _selectedSpice,
              onSelect: (v) => setState(() => _selectedSpice = v),
            ),
            const SizedBox(height: 20),

            // Sweetness vote
            _SectionLabel(label: 'SWEETNESS'),
            const SizedBox(height: 12),
            _VoteRow(
              options: _sweetnessOptions
                  .map((s) => (s.$1, s.$2.toString()))
                  .toList(),
              selected: _selectedSweetness,
              onSelect: (v) => setState(() => _selectedSweetness = v),
            ),
            const SizedBox(height: 24),

            // AI signal card
            _buildAiSignalCard(context, dish, isPro),

            // Private notes
            _SectionLabel(label: 'PRIVATE NOTES'),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              maxLines: 3,
              style: const TextStyle(color: AppColors.primaryText),
              decoration: const InputDecoration(
                hintText: 'Only you can see these…',
                hintStyle: TextStyle(color: AppColors.mutedText),
              ),
            ),
            const SizedBox(height: 32),

            // Save button
            ElevatedButton(
              onPressed: (_selectedReaction != null || _selectedSpice != null) && !_saving
                  ? () => _save(dish, auth)
                  : null,
              child: _saving
                  ? const Text('Saving…')
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiSignalCard(BuildContext context, DishDetail dish, bool isPro) {
    if (dish.attributeState == 'classifying') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Shimmer.fromColors(
          baseColor: AppColors.elevated,
          highlightColor: AppColors.border,
          child: Container(
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.elevated,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
    }

    if (dish.attributeState == 'classified' &&
        dish.attributePriors != null &&
        dish.voteCount >= 10) {
      if (!isPro) {
        return _LockedAiSignalCard(
          onUpgrade: () => context.push('/upgrade'),
        );
      }

      final priors = dish.attributePriors!;
      final spiceScore =
          priors.finalSpiceScore ?? priors.spiceScore;
      final sweetScore =
          priors.finalSweetnessScore ?? priors.sweetnessScore;

      return Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.proSurface,
                AppColors.surface,
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.proAccent.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _SectionLabel(label: 'AI SIGNAL'),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.proAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'PRO',
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(
                              color: AppColors.proAccent, fontSize: 9),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _AttributeBar(
                      label: '🌶 Spice',
                      value: spiceScore,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _AttributeBar(
                      label: '🍬 Sweet',
                      value: sweetScore,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${priors.cuisine} • ${priors.dishType}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.mutedText,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Future<void> _save(DishDetail dish, AuthUser? auth) async {
    if (auth == null) return;
    setState(() => _saving = true);

    try {
      final repo = ref.read(dishRepositoryProvider);

      if (_selectedReaction != null) {
        await repo.upsertReaction(
          userId: auth.id,
          dishId: dish.id,
          reaction: _selectedReaction!,
        );
        // Notify restaurant session state for passive rating trigger
        ref
            .read(restaurantSessionStateProvider(dish.restaurantId).notifier)
            .incrementReaction();
      }

      if (_selectedSpice != null) {
        await repo.upsertAttributeVote(
          dishId: dish.id,
          attribute: 'spice',
          value: double.parse(_selectedSpice!),
        );
      }

      if (_selectedSweetness != null) {
        await repo.upsertAttributeVote(
          dishId: dish.id,
          attribute: 'sweetness',
          value: double.parse(_selectedSweetness!),
        );
      }

      if (mounted) {
        setState(() => _saving = false);
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
        setState(() => _saving = false);
      }
    }
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 24, height: 2, color: AppColors.accent),
        const SizedBox(width: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.secondaryText,
                letterSpacing: 0.8,
              ),
        ),
      ],
    );
  }
}

class _VoteRow extends StatelessWidget {
  final List<(String, String)> options;
  final String? selected;
  final ValueChanged<String> onSelect;

  const _VoteRow({
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: options.map((opt) {
        final (label, value) = opt;
        final isSelected = selected == value;
        return Expanded(
          child: GestureDetector(
            onTap: () => onSelect(value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.accent
                    : AppColors.elevated,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected
                      ? AppColors.accent
                      : AppColors.border,
                ),
              ),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: isSelected
                          ? AppColors.background
                          : AppColors.secondaryText,
                    ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _AttributeBar extends StatelessWidget {
  final String label;
  final double value; // 0.0–1.0

  const _AttributeBar({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.secondaryText,
              ),
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value.clamp(0.0, 1.0),
            backgroundColor: AppColors.elevated,
            valueColor:
                const AlwaysStoppedAnimation<Color>(AppColors.accent),
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Report Dish Bottom Sheet
// ─────────────────────────────────────────────

class _ReportDishSheet extends ConsumerStatefulWidget {
  final String dishId;
  const _ReportDishSheet({required this.dishId});

  @override
  ConsumerState<_ReportDishSheet> createState() => _ReportDishSheetState();
}

class _ReportDishSheetState extends ConsumerState<_ReportDishSheet> {
  String _selectedReason = _reportReasons.first;
  bool _submitting = false;

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      final dio = ref.read(apiClientProvider);
      await dio.post('/reports', data: {
        'entity_type': 'dish',
        'entity_id': widget.dishId,
        'reason': _selectedReason,
      });
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Thanks for the report!',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            backgroundColor: AppColors.accentPress,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().contains('SocketException') || e.toString().contains('connection')
            ? 'No connection. Please try again.'
            : 'Failed to submit report. Please try again.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: AppColors.error,
          ),
        );
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Report Dish',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.primaryText,
                  fontFamily: 'Fraunces',
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Help us keep dish info accurate and appropriate.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.mutedText,
                ),
          ),
          const SizedBox(height: 16),
          ..._reportReasons.map((reason) => RadioListTile<String>(
                value: reason,
                groupValue: _selectedReason,
                onChanged: (v) {
                  if (v != null) setState(() => _selectedReason = v);
                },
                title: Text(
                  reason,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.primaryText,
                      ),
                ),
                activeColor: AppColors.accent,
                contentPadding: EdgeInsets.zero,
                dense: true,
              )),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed:
                      _submitting ? null : () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.secondaryText,
                    side: const BorderSide(color: AppColors.border),
                    minimumSize: const Size(0, 48),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.background,
                          ),
                        )
                      : const Text('Submit'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────

class _LockedAiSignalCard extends StatelessWidget {
  final VoidCallback onUpgrade;
  const _LockedAiSignalCard({required this.onUpgrade});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: 4, sigmaY: 4),
            child: Text(
              '🔥 You\'ll probably love this',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(color: AppColors.primaryText),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.lock_outline,
                  color: AppColors.mutedText, size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Unlock predictions — upgrade to Pro',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.mutedText),
                ),
              ),
              TextButton(
                onPressed: onUpgrade,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  minimumSize: Size.zero,
                ),
                child: const Text('Upgrade',
                    style: TextStyle(color: AppColors.accent)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
