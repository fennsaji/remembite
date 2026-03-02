import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        automaticallyImplyLeading: false,
        title: Text(
          'Favorites',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.primaryText,
              ),
        ),
      ),
      body: const Center(
        child: Text(
          'Your favorited dishes will appear here.',
          style: TextStyle(color: AppColors.mutedText),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
