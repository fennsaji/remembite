import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../data/pending_edit_count_provider.dart';

// ─────────────────────────────────────────────
// Model
// ─────────────────────────────────────────────

class EditSuggestion {
  final String id;
  final String entityType;
  final String entityId;
  final String field;
  final String proposedValue;
  final String suggestedBy;
  final String status;
  final int netVotes;
  final String createdAt;

  const EditSuggestion({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.field,
    required this.proposedValue,
    required this.suggestedBy,
    required this.status,
    required this.netVotes,
    required this.createdAt,
  });

  factory EditSuggestion.fromJson(Map<String, dynamic> json) {
    return EditSuggestion(
      id: json['id'] as String,
      entityType: json['entity_type'] as String,
      entityId: json['entity_id'] as String,
      field: json['field'] as String,
      proposedValue: json['proposed_value'] as String,
      suggestedBy: json['suggested_by'] as String,
      status: json['status'] as String,
      netVotes: (json['net_votes'] as num).toInt(),
      createdAt: json['created_at'] as String,
    );
  }
}

// ─────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────

class PendingEditsScreen extends ConsumerStatefulWidget {
  final String restaurantId;
  const PendingEditsScreen({super.key, required this.restaurantId});

  @override
  ConsumerState<PendingEditsScreen> createState() => _PendingEditsScreenState();
}

class _PendingEditsScreenState extends ConsumerState<PendingEditsScreen> {
  List<EditSuggestion>? _suggestions;
  bool _loading = true;
  String? _error;

  // Track which suggestion IDs are currently voting to prevent double-taps.
  final Set<String> _votingIds = {};

  @override
  void initState() {
    super.initState();
    _fetchSuggestions();
  }

  Future<void> _fetchSuggestions() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dio = ref.read(apiClientProvider);
      final response = await dio.get(
        '/edit-suggestions',
        queryParameters: {
          'entity_type': 'restaurant',
          'entity_id': widget.restaurantId,
          'status': 'pending',
        },
      );
      final data = (response.data as List<dynamic>)
          .map((e) => EditSuggestion.fromJson(e as Map<String, dynamic>))
          .toList();
      if (mounted) {
        setState(() {
          _suggestions = data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _vote(String suggestionId, String vote) async {
    if (_votingIds.contains(suggestionId)) return;
    if (!mounted) return;
    setState(() => _votingIds.add(suggestionId));

    try {
      final dio = ref.read(apiClientProvider);
      await dio.post(
        '/edit-suggestions/$suggestionId/vote',
        data: {'vote': vote},
      );
      // Remove from voting set before refresh so stale IDs don't leak
      if (mounted) setState(() => _votingIds.remove(suggestionId));
      // Refresh independently — errors here don't mis-report vote failure
      await _fetchSuggestions();
      if (mounted) ref.invalidate(pendingEditCountProvider(widget.restaurantId));
    } catch (e) {
      if (mounted) {
        setState(() => _votingIds.remove(suggestionId));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to submit vote. Please try again.',
              style: const TextStyle(fontFamily: 'DM Sans'),
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  String _fieldLabel(String field) => switch (field) {
        'name' => 'Name',
        'city' => 'City',
        'cuisine_type' => 'Cuisine Type',
        'category' => 'Category',
        'price' => 'Price',
        _ => field,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primaryText),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Community Edits',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.primaryText,
                fontFamily: 'Fraunces',
              ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.mutedText),
            tooltip: 'Refresh',
            onPressed: _fetchSuggestions,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: AppColors.error, size: 40),
              const SizedBox(height: 16),
              Text(
                'Could not load edits.',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.primaryText,
                      fontFamily: 'DM Sans',
                    ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _fetchSuggestions,
                child: const Text(
                  'Retry',
                  style: TextStyle(color: AppColors.accent, fontFamily: 'DM Sans'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final suggestions = _suggestions ?? [];

    if (suggestions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_outline,
                  color: AppColors.accent, size: 48),
              const SizedBox(height: 16),
              Text(
                'No pending edits',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.primaryText,
                      fontFamily: 'DM Sans',
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'This restaurant has no community edits awaiting review.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.mutedText,
                      fontFamily: 'DM Sans',
                    ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.accent,
      backgroundColor: AppColors.elevated,
      onRefresh: _fetchSuggestions,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        itemCount: suggestions.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) => _EditSuggestionCard(
          suggestion: suggestions[i],
          fieldLabel: _fieldLabel(suggestions[i].field),
          isVoting: _votingIds.contains(suggestions[i].id),
          onVote: (vote) => _vote(suggestions[i].id, vote),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Card widget
// ─────────────────────────────────────────────

class _EditSuggestionCard extends StatelessWidget {
  final EditSuggestion suggestion;
  final String fieldLabel;
  final bool isVoting;
  final void Function(String vote) onVote;

  const _EditSuggestionCard({
    required this.suggestion,
    required this.fieldLabel,
    required this.isVoting,
    required this.onVote,
  });

  @override
  Widget build(BuildContext context) {
    final netVotes = suggestion.netVotes;
    final netVotesLabel = netVotes >= 0 ? '+$netVotes' : '$netVotes';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Field label badge
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.elevated,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  fieldLabel.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.secondaryText,
                        letterSpacing: 0.8,
                        fontFamily: 'DM Sans',
                      ),
                ),
              ),
              const Spacer(),
              // Net votes display
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: netVotes >= 0
                      ? AppColors.accentMuted
                      : AppColors.elevated,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: netVotes >= 0
                        ? AppColors.accent
                        : AppColors.border,
                  ),
                ),
                child: Text(
                  '$netVotesLabel votes',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: netVotes >= 0
                            ? AppColors.accent
                            : AppColors.mutedText,
                        fontFamily: 'DM Sans',
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Proposed value
          Text(
            suggestion.proposedValue,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.primaryText,
                  fontFamily: 'DM Sans',
                ),
          ),
          const SizedBox(height: 16),

          // Vote buttons
          Row(
            children: [
              Expanded(
                child: _VoteButton(
                  label: 'Upvote',
                  icon: Icons.thumb_up_outlined,
                  activeColor: AppColors.accent,
                  isLoading: isVoting,
                  onTap: () => onVote('up'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _VoteButton(
                  label: 'Downvote',
                  icon: Icons.thumb_down_outlined,
                  activeColor: AppColors.error,
                  isLoading: isVoting,
                  onTap: () => onVote('down'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VoteButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color activeColor;
  final bool isLoading;
  final VoidCallback onTap;

  const _VoteButton({
    required this.label,
    required this.icon,
    required this.activeColor,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.elevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: isLoading
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: activeColor,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: activeColor, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: activeColor,
                          fontFamily: 'DM Sans',
                        ),
                  ),
                ],
              ),
      ),
    );
  }
}
