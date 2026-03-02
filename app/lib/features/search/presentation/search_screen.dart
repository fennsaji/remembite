import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/theme/app_theme.dart';
import '../data/search_repository.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  SearchResults? _results;
  bool _loading = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onQueryChanged() {
    _debounce?.cancel();
    if (_controller.text.trim().isEmpty) {
      setState(() => _results = null);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), _search);
  }

  Future<void> _search() async {
    final q = _controller.text.trim();
    if (q.isEmpty) return;
    setState(() => _loading = true);
    try {
      final results =
          await ref.read(searchRepositoryProvider).search(q);
      if (mounted) setState(() => _results = results);
    } catch (_) {
      if (mounted) setState(() => _results = null);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: IconButton(
          icon:
              const Icon(Icons.arrow_back, color: AppColors.primaryText),
          onPressed: () => context.pop(),
        ),
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          autofocus: true,
          style: const TextStyle(color: AppColors.primaryText),
          decoration: InputDecoration(
            hintText: 'Search restaurants or dishes…',
            hintStyle:
                const TextStyle(color: AppColors.mutedText),
            border: InputBorder.none,
            suffixIcon: _controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close,
                        color: AppColors.mutedText, size: 18),
                    onPressed: () {
                      _controller.clear();
                      setState(() => _results = null);
                    },
                  )
                : null,
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 6,
        itemBuilder: (_, __) => Shimmer.fromColors(
          baseColor: AppColors.elevated,
          highlightColor: AppColors.border,
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.elevated,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      );
    }

    if (_controller.text.isEmpty) {
      return const Center(
        child: Text(
          'Search for restaurants or dishes',
          style: TextStyle(color: AppColors.mutedText),
        ),
      );
    }

    if (_results == null || _results!.isEmpty) {
      return Center(
        child: Text(
          'No results for "${_controller.text}"',
          style: const TextStyle(color: AppColors.mutedText),
        ),
      );
    }

    return ListView(
      children: [
        if (_results!.restaurants.isNotEmpty) ...[
          _SectionHeader(label: 'RESTAURANTS'),
          ..._results!.restaurants.map(
            (r) => ListTile(
              onTap: () => context.push('/restaurant/${r.id}'),
              leading: const Icon(Icons.restaurant,
                  color: AppColors.accent, size: 20),
              title: Text(r.name,
                  style: const TextStyle(color: AppColors.primaryText)),
              subtitle: Text(
                [r.cuisineType, r.city]
                    .whereType<String>()
                    .join(' · '),
                style:
                    const TextStyle(color: AppColors.mutedText, fontSize: 12),
              ),
              trailing: r.avgRating != null
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star_rounded,
                            color: AppColors.accent, size: 14),
                        const SizedBox(width: 2),
                        Text(
                          r.avgRating!.toStringAsFixed(1),
                          style: const TextStyle(
                              color: AppColors.secondaryText,
                              fontSize: 12),
                        ),
                      ],
                    )
                  : null,
            ),
          ),
        ],
        if (_results!.dishes.isNotEmpty) ...[
          _SectionHeader(label: 'DISHES'),
          ..._results!.dishes.map(
            (d) => ListTile(
              onTap: () => context.push('/dish/${d.id}'),
              leading: const Icon(Icons.local_dining_outlined,
                  color: AppColors.secondaryText, size: 20),
              title: Text(d.name,
                  style: const TextStyle(color: AppColors.primaryText)),
              subtitle: Text(
                d.restaurantName,
                style:
                    const TextStyle(color: AppColors.mutedText, fontSize: 12),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
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
      ),
    );
  }
}
