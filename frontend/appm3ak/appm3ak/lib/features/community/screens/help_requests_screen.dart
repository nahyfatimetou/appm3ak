import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../data/models/help_request_model.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/community_providers.dart';

/// Écran de liste des demandes d'aide de la communauté.
class HelpRequestsScreen extends ConsumerStatefulWidget {
  const HelpRequestsScreen({super.key});

  @override
  ConsumerState<HelpRequestsScreen> createState() => _HelpRequestsScreenState();
}

class _HelpRequestsScreenState extends ConsumerState<HelpRequestsScreen> {
  int _currentPage = 1;
  final int _limit = 20;
  bool _isAccepting = false;

  Future<void> _acceptHelpRequest(String helpRequestId) async {
    if (_isAccepting) return;
    setState(() => _isAccepting = true);

    try {
      final repository = ref.read(communityRepositoryProvider);
      await repository.acceptHelpRequest(id: helpRequestId);
      await ref.read(authStateProvider.notifier).refreshUser();
      ref.invalidate(helpRequestsProvider((
        page: _currentPage,
        limit: _limit,
      )));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Demande acceptée.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur acceptation: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isAccepting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final strings =
        AppStrings.fromPreferredLanguage(user?.preferredLanguage?.name);
    final theme = Theme.of(context);

    final helpRequestsAsync = ref.watch(helpRequestsProvider((
      page: _currentPage,
      limit: _limit,
    )));

    return ColoredBox(
      color: theme.scaffoldBackgroundColor,
      child: Column(
        children: [
          // Barre d'actions (remplace AppBar)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(
                bottom: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.12)),
              ),
            ),
            child: Row(
              children: [
                Text(
                  strings.helpRequests,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () => context.push('/create-help-request'),
                  tooltip: strings.createHelpRequest,
                ),
              ],
            ),
          ),
          // Contenu
          Expanded(
            child: helpRequestsAsync.when(
        data: (data) {
          final requests = data.requests;
          final totalPages = data.totalPages;

          if (requests.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.help_outline,
                    size: 64,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    strings.noHelpRequests,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    strings.beFirstToHelp,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => context.push('/create-help-request'),
                    icon: const Icon(Icons.add),
                    label: Text(strings.createHelpRequest),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(helpRequestsProvider((page: _currentPage, limit: _limit)));
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList.builder(
                    itemCount: requests.length,
                    itemBuilder: (context, index) {
                      final request = requests[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _HelpRequestCard(
                          request: request,
                          onTap: () {
                            // TODO: Navigation vers détails ou action
                          },
                          onAccept:
                              request.statut == HelpRequestStatus.enAttente
                                  ? () => _acceptHelpRequest(request.id)
                                  : null,
                          isAccepting: _isAccepting,
                        ),
                      );
                    },
                  ),
                ),
                if (totalPages > 1)
                  SliverToBoxAdapter(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        border: Border(
                          top: BorderSide(color: theme.colorScheme.outline),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left),
                            onPressed: _currentPage > 1
                                ? () {
                                    setState(() => _currentPage--);
                                    ref.invalidate(helpRequestsProvider((
                                      page: _currentPage,
                                      limit: _limit,
                                    )));
                                  }
                                : null,
                          ),
                          Text(
                            '${strings.page} $_currentPage / $totalPages',
                            style: theme.textTheme.bodyMedium,
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right),
                            onPressed: _currentPage < totalPages
                                ? () {
                                    setState(() => _currentPage++);
                                    ref.invalidate(helpRequestsProvider((
                                      page: _currentPage,
                                      limit: _limit,
                                    )));
                                  }
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    strings.errorLoadingHelpRequests,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => ref.invalidate(helpRequestsProvider((
                      page: _currentPage,
                      limit: _limit,
                    ))),
                    child: Text(strings.retry),
                  ),
                ],
              ),
            ),
          ),
          ),
        ],
      ),
    );
  }
}

class _HelpRequestCard extends StatelessWidget {
  const _HelpRequestCard({
    required this.request,
    required this.onTap,
    required this.onAccept,
    required this.isAccepting,
  });

  final HelpRequestModel request;
  final VoidCallback onTap;
  final VoidCallback? onAccept;
  final bool isAccepting;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    // Couleur selon le statut
    Color statusColor;
    IconData statusIcon;
    switch (request.statut) {
      case HelpRequestStatus.enAttente:
        statusColor = Colors.orange;
        statusIcon = Icons.access_time;
        break;
      case HelpRequestStatus.enCours:
        statusColor = Colors.blue;
        statusIcon = Icons.work;
        break;
      case HelpRequestStatus.terminee:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case HelpRequestStatus.annulee:
        statusColor = Colors.grey;
        statusIcon = Icons.cancel;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête : utilisateur et statut
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: primary.withValues(alpha: 0.12),
                    child: Icon(
                      Icons.person,
                      size: 20,
                      color: primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          request.userName,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (request.createdAt != null)
                          Text(
                            _formatDate(request.createdAt!),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(statusIcon, size: 14, color: statusColor),
                            const SizedBox(width: 4),
                            Text(
                              request.statut.displayName,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (request.urgencyScore != null &&
                          request.urgencyScore! > 4)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  size: 14,
                                  color: Colors.red,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Urgent ${request.urgencyScore}',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Description
              Text(
                request.description,
                style: theme.textTheme.bodyMedium,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              // Localisation
              Row(
                children: [
                  Icon(
                    Icons.location_on,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${request.latitude.toStringAsFixed(4)}, ${request.longitude.toStringAsFixed(4)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              if (request.statut == HelpRequestStatus.enAttente &&
                  onAccept != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: isAccepting ? null : onAccept,
                      icon: const Icon(Icons.handshake_outlined),
                      label: const Text('Accepter'),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 7) {
      return '${date.day}/${date.month}/${date.year}';
    } else if (difference.inDays > 0) {
      return 'Il y a ${difference.inDays} jour${difference.inDays > 1 ? 's' : ''}';
    } else if (difference.inHours > 0) {
      return 'Il y a ${difference.inHours} heure${difference.inHours > 1 ? 's' : ''}';
    } else if (difference.inMinutes > 0) {
      return 'Il y a ${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''}';
    } else {
      return 'À l\'instant';
    }
  }
}

