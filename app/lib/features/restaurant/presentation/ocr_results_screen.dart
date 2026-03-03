import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../dish/data/dish_repository.dart';
import '../data/restaurant_repository.dart';

class OcrResultsScreen extends ConsumerStatefulWidget {
  final String rawText;
  final String? restaurantId;
  final List<ParsedDishItem>? parsedDishes;

  const OcrResultsScreen({
    super.key,
    required this.rawText,
    this.restaurantId,
    this.parsedDishes,
  });

  @override
  ConsumerState<OcrResultsScreen> createState() => _OcrResultsScreenState();
}

class _OcrResultsScreenState extends ConsumerState<OcrResultsScreen> {
  late List<_DishEntry> _dishes;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.parsedDishes != null && widget.parsedDishes!.isNotEmpty) {
      _dishes = widget.parsedDishes!
          .map((d) => _DishEntry(name: d.name, selected: true))
          .toList();
    } else {
      _dishes = _parseText(widget.rawText);
    }
  }

  // Simple heuristic: split by lines, filter noise
  List<_DishEntry> _parseText(String text) {
    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) =>
            l.isNotEmpty &&
            l.length > 3 &&
            !RegExp(r'^\d+$').hasMatch(l) &&
            !RegExp(r'^[₹\d,.]+$').hasMatch(l))
        .toList();

    return lines
        .map((l) => _DishEntry(name: l, selected: true))
        .take(30)
        .toList();
  }

  Future<void> _saveDishes() async {
    if (widget.restaurantId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No restaurant selected. Scan from a restaurant page.'),
        ),
      );
      return;
    }

    final selected = _dishes.where((d) => d.selected).toList();
    if (selected.isEmpty) return;

    setState(() => _saving = true);
    try {
      await ref.read(dishRepositoryProvider).batchCreateDishes(
        widget.restaurantId!,
        selected
            .map((d) => <String, dynamic>{'name': d.name.trim()})
            .toList(),
      );
      if (mounted) {
        context.pushReplacement('/restaurant/${widget.restaurantId}');
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

  @override
  Widget build(BuildContext context) {
    final selectedCount = _dishes.where((d) => d.selected).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primaryText),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Extracted Dishes',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(color: AppColors.primaryText),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '$selectedCount selected',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.mutedText),
              ),
            ),
          ),
        ],
      ),
      body: _dishes.isEmpty
          ? const Center(
              child: Text(
                'No dishes detected. Try scanning again.',
                style: TextStyle(color: AppColors.mutedText),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              separatorBuilder: (_, __) =>
                  const Divider(color: AppColors.border, height: 1),
              itemCount: _dishes.length,
              itemBuilder: (context, i) {
                final dish = _dishes[i];
                return _DishRow(
                  dish: dish,
                  onToggle: () =>
                      setState(() => dish.selected = !dish.selected),
                  onNameChanged: (v) => setState(() => dish.name = v),
                  onDelete: () => setState(() => _dishes.removeAt(i)),
                );
              },
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: selectedCount > 0 && !_saving ? _saveDishes : null,
            child: _saving
                ? const Text('Saving…')
                : Text('Save $selectedCount Dish${selectedCount == 1 ? '' : 'es'}'),
          ),
        ),
      ),
    );
  }
}

class _DishEntry {
  String name;
  bool selected;
  _DishEntry({required this.name, required this.selected});
}

class _DishRow extends StatelessWidget {
  final _DishEntry dish;
  final VoidCallback onToggle;
  final ValueChanged<String> onNameChanged;
  final VoidCallback onDelete;

  const _DishRow({
    required this.dish,
    required this.onToggle,
    required this.onNameChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Checkbox(
            value: dish.selected,
            onChanged: (_) => onToggle(),
            activeColor: AppColors.accent,
            side: const BorderSide(color: AppColors.border),
          ),
          Expanded(
            child: TextFormField(
              initialValue: dish.name,
              onChanged: onNameChanged,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.primaryText),
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 4),
              ),
            ),
          ),
          IconButton(
            icon:
                const Icon(Icons.close, color: AppColors.mutedText, size: 18),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
