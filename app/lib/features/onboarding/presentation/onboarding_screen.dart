import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_client.dart';
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

const _dishAttributes = {
  'Butter Chicken': (
    spice: 0.2,
    sweet: 0.0,
    type: 'main',
    cuisine: 'North Indian',
  ),
  'Biryani': (spice: 0.5, sweet: 0.0, type: 'main', cuisine: 'North Indian'),
  'Masala Dosa': (
    spice: 0.2,
    sweet: 0.0,
    type: 'main',
    cuisine: 'South Indian',
  ),
  'Chole Bhature': (
    spice: 0.5,
    sweet: 0.0,
    type: 'main',
    cuisine: 'North Indian',
  ),
  'Paneer Tikka': (
    spice: 0.5,
    sweet: 0.0,
    type: 'starter',
    cuisine: 'North Indian',
  ),
  'Vada Pav': (spice: 0.2, sweet: 0.0, type: 'snack', cuisine: 'Indian Street'),
  'Pani Puri': (
    spice: 0.5,
    sweet: 0.0,
    type: 'snack',
    cuisine: 'Indian Street',
  ),
  'Idli Sambar': (
    spice: 0.0,
    sweet: 0.0,
    type: 'main',
    cuisine: 'South Indian',
  ),
  'Dal Makhani': (
    spice: 0.2,
    sweet: 0.0,
    type: 'main',
    cuisine: 'North Indian',
  ),
  'Gulab Jamun': (spice: 0.0, sweet: 0.8, type: 'dessert', cuisine: 'Indian'),
  'Pav Bhaji': (spice: 0.5, sweet: 0.0, type: 'main', cuisine: 'Indian Street'),
  'Aloo Paratha': (
    spice: 0.2,
    sweet: 0.0,
    type: 'bread',
    cuisine: 'North Indian',
  ),
  'Samosa': (spice: 0.2, sweet: 0.0, type: 'starter', cuisine: 'North Indian'),
  'Rajma Chawal': (
    spice: 0.2,
    sweet: 0.0,
    type: 'main',
    cuisine: 'North Indian',
  ),
  'Khichdi': (spice: 0.0, sweet: 0.0, type: 'main', cuisine: 'Indian'),
};

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _currentIndex = 0;
  String? _selectedReaction;
  final Map<String, String> _collectedReactions = {};
  bool _submitting = false;

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
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.accent,
                    ),
                    minHeight: 4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_currentIndex + 1} of ${_bootstrapDishes.length}',
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: AppColors.mutedText),
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
                        onPressed: _submitting ? null : () => _advance(null),
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
                        onPressed: (_selectedReaction != null && !_submitting)
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
                    onPressed: _submitting ? null : () => _submitAndFinish(),
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
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(color: AppColors.primaryText),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'It gets smarter with every dish you try.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppColors.secondaryText),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: _submitting ? null : () => _submitAndFinish(),
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
    final dish = _bootstrapDishes[_currentIndex];
    if (reaction != null) {
      _collectedReactions[dish] = reaction;
    }
    if (_currentIndex < _bootstrapDishes.length - 1) {
      setState(() {
        _currentIndex++;
        _selectedReaction = null;
      });
    } else {
      // Last dish — submit and go home
      await _submitAndFinish();
    }
  }

  Future<void> _submitAndFinish() async {
    setState(() => _submitting = true);
    try {
      final dio = ref.read(apiClientProvider);
      final items = _collectedReactions.entries.map((e) {
        final attrs = _dishAttributes[e.key];
        return {
          'dish_name': e.key,
          'reaction': e.value,
          'spice_score': attrs?.spice ?? 0.0,
          'sweetness_score': attrs?.sweet ?? 0.0,
          'dish_type': attrs?.type ?? 'main',
          'cuisine': attrs?.cuisine ?? 'Indian',
        };
      }).toList();

      await dio.post('/users/me/bootstrap', data: {'reactions': items});

      const storage = FlutterSecureStorage();
      await storage.write(key: 'has_bootstrapped', value: 'true');
    } catch (_) {
      // Network error — still mark done so user isn't stuck in onboarding loop
      const storage = FlutterSecureStorage();
      await storage.write(key: 'has_bootstrapped', value: 'true');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
    if (mounted) context.go('/home');
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
          Text('🍽️', style: const TextStyle(fontSize: 56)),
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
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.secondaryText),
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
                      color: isSelected ? AppColors.accent : AppColors.border,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(emoji, style: const TextStyle(fontSize: 28)),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
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
