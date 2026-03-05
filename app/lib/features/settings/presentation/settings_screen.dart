import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/billing/pro_status_provider.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/auth_state.dart';
import '../../../core/sync/sync_worker.dart';
import '../../../core/theme/app_theme.dart';

// ─────────────────────────────────────────────
// Settings Screen
// ─────────────────────────────────────────────

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  // Session-only: preference not persisted across restarts (Phase 7)
  bool _syncEnabled = true;
  bool _exportLoading = false;

  Future<void> _launchUrl(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not open link')));
      }
    }
  }

  Future<void> _handleSignOut() async {
    await ref.read(authStateProvider.notifier).signOut();
    if (mounted) context.go('/auth/sign-in');
  }

  Future<void> _exportData() async {
    setState(() => _exportLoading = true);
    try {
      final response = await ref
          .read(apiClientProvider)
          .get<dynamic>('/users/me/export');
      final jsonString = jsonEncode(response.data);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/remembite_export.json');
      await file.writeAsString(jsonString);
      if (!mounted) return;
      await Share.shareXFiles([
        XFile(file.path, mimeType: 'application/json'),
      ], subject: 'Remembite Data Export');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Export failed. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _exportLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStateProvider).value;
    final isPro = ref.watch(proStatusProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.primaryText,
        elevation: 0,
        title: Text(
          'Settings',
          style: GoogleFonts.dmSans(
            color: AppColors.primaryText,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          // ── ACCOUNT ──────────────────────────────
          const _SectionHeader(label: 'ACCOUNT'),
          _SettingsRow(
            icon: Icons.person_outline,
            title: auth?.displayName ?? '',
            subtitle: auth?.email,
          ),
          _SettingsRow(
            icon: Icons.logout,
            title: 'Sign Out',
            titleColor: AppColors.error,
            iconColor: AppColors.error,
            onTap: _handleSignOut,
          ),

          const SizedBox(height: 20),

          // ── SUBSCRIPTION ─────────────────────────
          const _SectionHeader(label: 'SUBSCRIPTION'),
          if (!isPro)
            _SettingsRow(
              icon: Icons.workspace_premium_outlined,
              title: 'Free Plan',
              subtitle: 'Upgrade to Pro for AI predictions',
              trailing: TextButton(
                onPressed: () => context.push('/upgrade'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Upgrade',
                  style: GoogleFonts.dmSans(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              onTap: () => context.push('/upgrade'),
            )
          else
            _SettingsRow(
              icon: Icons.workspace_premium_outlined,
              title: 'Pro Active',
              subtitle: 'Manage subscription',
              trailing: const Icon(
                Icons.open_in_new,
                size: 16,
                color: AppColors.accent,
              ),
              onTap: () => _launchUrl(
                'https://play.google.com/store/account/subscriptions',
              ),
            ),

          const SizedBox(height: 20),

          // ── SYNC & DATA ──────────────────────────
          const _SectionHeader(label: 'SYNC & DATA'),
          if (!isPro) ...[
            _SettingsRow(
              icon: Icons.sync_outlined,
              title: 'Cloud Sync',
              subtitle: 'Pro feature',
              trailing: const _ProBadge(),
              onTap: () => context.push('/upgrade'),
            ),
            _SettingsRow(
              icon: Icons.download_outlined,
              title: 'Export Data',
              subtitle: 'Pro feature',
              trailing: const _ProBadge(),
              onTap: () => context.push('/upgrade'),
            ),
          ] else ...[
            _SettingsRow(
              icon: Icons.sync_outlined,
              title: 'Cloud Sync',
              subtitle: 'Syncs your data across devices',
              trailing: Switch(
                value: _syncEnabled,
                activeColor: AppColors.accent,
                onChanged: (value) {
                  setState(() => _syncEnabled = value);
                  if (value) {
                    ref.read(syncWorkerProvider.notifier).setPaused(false);
                    ref.read(syncWorkerProvider.notifier).syncNow();
                  } else {
                    ref.read(syncWorkerProvider.notifier).setPaused(true);
                  }
                },
              ),
            ),
            _SettingsRow(
              icon: Icons.download_outlined,
              title: 'Export Data',
              subtitle: 'Download all your data as JSON',
              trailing: _exportLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.accent,
                      ),
                    )
                  : null,
              onTap: _exportLoading ? null : _exportData,
            ),
          ],

          const SizedBox(height: 20),

          // ── ABOUT ────────────────────────────────
          const _SectionHeader(label: 'ABOUT'),
          _SettingsRow(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            onTap: () => _launchUrl('https://remembite.com/privacy'),
          ),
          _SettingsRow(
            icon: Icons.help_outline,
            title: 'Help & Support',
            onTap: () => _launchUrl('mailto:support@remembite.com'),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Section Header
// ─────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Row(
        children: [
          Container(width: 24, height: 2, color: AppColors.accent),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.dmSans(
              color: AppColors.secondaryText,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Settings Row
// ─────────────────────────────────────────────

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? titleColor;
  final Color? iconColor;

  const _SettingsRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.titleColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveTitleColor = titleColor ?? AppColors.primaryText;
    final effectiveIconColor = iconColor ?? AppColors.secondaryText;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      onTap: onTap,
      leading: Icon(icon, color: effectiveIconColor, size: 22),
      title: Text(
        title,
        style: GoogleFonts.dmSans(
          color: effectiveTitleColor,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: GoogleFonts.dmSans(
                color: AppColors.mutedText,
                fontSize: 12,
              ),
            )
          : null,
      trailing: trailing,
    );
  }
}

// ─────────────────────────────────────────────
// Pro Badge
// ─────────────────────────────────────────────

class _ProBadge extends StatelessWidget {
  const _ProBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'PRO',
        style: GoogleFonts.dmSans(
          color: AppColors.accent,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
