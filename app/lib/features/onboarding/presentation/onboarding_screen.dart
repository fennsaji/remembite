import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/db/app_database.dart';
import '../../../core/network/auth_state.dart';
import '../../../core/theme/app_theme.dart';

// Hardcoded bootstrapping dishes for taste calibration
const _bootstrapDishes = [
  'Butter Chicken',
  'Biryani',
  'Masala Dosa',
  'Chole Bhature',
  'Paneer Tikka',
  'Vada Pav',
  'Pani Puri',
  'Idli Sambar',
  'Dal Makhani',
  'Gulab Jamun',
  'Pav Bhaji',
  'Aloo Paratha',
  'Samosa',
  'Rajma Chawal',
  'Khichdi',
];

const _reactionEmojis = [
  ('🔥', 'so_yummy', 'Loved it'),
  ('😋', 'tasty', 'Tasty'),
  ('😐', 'meh', 'Meh'),
];

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _currentIndex = 0;
  String? _selectedReaction;

  @override
  Widget build(BuildContext context) {
    final isDone = _currentIndex >= _bootstrapDishes.length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Text(
                'Quick — let us\nlearn your taste',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppColors.primaryText,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Takes about 30 seconds. You can skip any time.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.secondaryText,
                    ),
              ),
              const SizedBox(height: 16),

              // Progress bar
              if (!isDone) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: _currentIndex / _bootstrapDishes.length,
                    backgroundColor: AppColors.elevated,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(AppColors.accent),
                    minHeight: 4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_currentIndex + 1} of ${_bootstrapDishes.length}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.mutedText,
                      ),
                ),
                const SizedBox(height: 32),

                // Dish card
                Expanded(
                  child: _DishCard(
                    dishName: _bootstrapDishes[_currentIndex],
                    selectedReaction: _selectedReaction,
                    onReactionTap: (reaction) {
                      setState(() => _selectedReaction = reaction);
                    },
                  ),
                ),
                const SizedBox(height: 24),

                // Next / Skip buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _advance(null),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.secondaryText,
                          side: const BorderSide(color: AppColors.border),
                        ),
                        child: const Text('Skip'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _selectedReaction != null
                            ? () => _advance(_selectedReaction)
                            : null,
                        child: const Text('Next'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: () => context.go('/home'),
                    child: Text(
                      'Skip All',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.mutedText,
                          ),
                    ),
                  ),
                ),
              ] else ...[
                // Done state
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🎉', style: TextStyle(fontSize: 56)),
                        const SizedBox(height: 16),
                        Text(
                          'Taste profile started!',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(color: AppColors.primaryText),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'It gets smarter with every dish you try.',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppColors.secondaryText,
                                  ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => context.go('/home'),
                  child: const Text('Start Exploring'),
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _advance(String? reaction) async {
    if (reaction != null) {
      await _saveReaction(
        dishName: _bootstrapDishes[_currentIndex],
        reaction: reaction,
      );
    }
    setState(() {
      _currentIndex++;
      _selectedReaction = null;
    });
  }

  Future<void> _saveReaction({
    required String dishName,
    required String reaction,
  }) async {
    final auth = ref.read(authStateProvider).value;
    if (auth == null) return;

    final db = ref.read(appDatabaseProvider);
    const uuid = Uuid();
    // Store locally with a stable ID derived from dish name (bootstrapping)
    await db.reactionDao.upsert(
      ReactionsCompanion(
        id: Value(uuid.v4()),
        userId: Value(auth.id),
        dishId: Value('bootstrap_${dishName.toLowerCase().replaceAll(' ', '_')}'),
        reaction: Value(reaction),
        createdAt: Value(DateTime.now()),
        syncedAt: const Value(null),
      ),
    );
  }
}

class _DishCard extends StatelessWidget {
  final String dishName;
  final String? selectedReaction;
  final ValueChanged<String> onReactionTap;

  const _DishCard({
    required this.dishName,
    required this.selectedReaction,
    required this.onReactionTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '🍽️',
            style: const TextStyle(fontSize: 56),
          ),
          const SizedBox(height: 24),
          Text(
            dishName,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.primaryText,
                  fontWeight: FontWeight.w700,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Text(
            'Have you tried it?',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.secondaryText,
                ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: _reactionEmojis.map((r) {
              final (emoji, value, label) = r;
              final isSelected = selectedReaction == value;
              return GestureDetector(
                onTap: () => onReactionTap(value),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.accent.withValues(alpha: 0.15)
                        : AppColors.elevated,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color:
                          isSelected ? AppColors.accent : AppColors.border,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(emoji,
                          style: const TextStyle(fontSize: 28)),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        style:
                            Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: isSelected
                                      ? AppColors.accent
                                      : AppColors.secondaryText,
                                ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
