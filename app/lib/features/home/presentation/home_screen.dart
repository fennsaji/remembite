import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              floating: true,
              backgroundColor: AppColors.background,
              title: const _SearchBar(),
              titleSpacing: 16,
            ),
            const SliverPadding(
              padding: EdgeInsets.all(16),
              sliver: SliverToBoxAdapter(
                // TODO Phase 1: recently visited + nearby restaurants
                child: Center(
                  child: Text(
                    'Home — Phase 1',
                    style: TextStyle(color: AppColors.mutedText),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {}, // TODO Phase 1: scan menu
        backgroundColor: AppColors.accent,
        icon: const Icon(Icons.document_scanner_outlined),
        label: const Text('Scan Menu'),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {}, // TODO Phase 1: navigate to search
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.search, color: AppColors.mutedText, size: 18),
            const SizedBox(width: 8),
            Text(
              'Search restaurants or dishes…',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.mutedText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
