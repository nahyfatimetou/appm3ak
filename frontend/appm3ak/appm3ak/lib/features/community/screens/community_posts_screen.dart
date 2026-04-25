import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../data/models/post_model.dart';
import '../../../data/repositories/community_repository.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/community_providers.dart';
import '../../../widgets/verified_helper_badge.dart';

/// Écran de liste des posts de la communauté.
class CommunityPostsScreen extends ConsumerStatefulWidget {
  const CommunityPostsScreen({super.key});

  @override
  ConsumerState<CommunityPostsScreen> createState() =>
      _CommunityPostsScreenState();
}

enum _PostsOwnerSegment {
  mine,
  others,
}

class _CommunityPostsScreenState extends ConsumerState<CommunityPostsScreen> {
  int _currentPage = 1;
  final int _limit = 20;
  PostType? _selectedType;
  _PostsOwnerSegment _ownerSegment = _PostsOwnerSegment.others;
  /// Filtre backend selon `role` + `typeHandicap` (endpoint `GET /community/posts/for-me`).
  bool _smartProfileFilter = false;
  bool _filtersExpanded = false;

  Future<void> _openCreatePost(BuildContext context) async {
    // Le + doit toujours ouvrir l’écran “Créer un post” (formulaire complet).
    // Les modes accessibilité restent accessibles depuis cet écran.
    await context.push('/create-post');
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final currentUserId = user?.id.trim();
    final strings =
        AppStrings.fromPreferredLanguage(user?.preferredLanguage?.name);
    final theme = Theme.of(context);

    final useSmart = _smartProfileFilter && user != null;
    final postsAsync = ref.watch(communityFeedProvider((
      page: _currentPage,
      limit: _limit,
      smart: useSmart,
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
                  strings.communityPosts,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () => _openCreatePost(context),
                  tooltip: strings.createPost,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: SegmentedButton<_PostsOwnerSegment>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment<_PostsOwnerSegment>(
                  value: _PostsOwnerSegment.mine,
                  label: Text('Mes posts'),
                  icon: Icon(Icons.person_outline),
                ),
                ButtonSegment<_PostsOwnerSegment>(
                  value: _PostsOwnerSegment.others,
                  label: Text('Posts des autres'),
                  icon: Icon(Icons.groups_outlined),
                ),
              ],
              selected: {_ownerSegment},
              onSelectionChanged: (selection) {
                final next = selection.first;
                if (next == _ownerSegment) return;
                setState(() {
                  _ownerSegment = next;
                  _currentPage = 1;
                });
              },
            ),
          ),
          ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 16),
            childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
            initiallyExpanded: _filtersExpanded,
            onExpansionChanged: (v) => setState(() => _filtersExpanded = v),
            title: const Text('Filtres'),
            subtitle: Text(
              _selectedType == null
                  ? strings.allTypes
                  : _selectedType!.displayName,
            ),
            children: [
              SizedBox(
                height: 50,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    if (user != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _TypeChip(
                          label: 'Smart (mon profil)',
                          selected: _smartProfileFilter,
                          onTap: () {
                            setState(() {
                              _smartProfileFilter = !_smartProfileFilter;
                              _currentPage = 1;
                            });
                          },
                        ),
                      ),
                    _TypeChip(
                      label: strings.allTypes,
                      selected: _selectedType == null,
                      onTap: () => setState(() => _selectedType = null),
                    ),
                    const SizedBox(width: 8),
                    ...PostType.values.map((type) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _TypeChip(
                          label: type.displayName,
                          selected: _selectedType == type,
                          onTap: () => setState(() => _selectedType = type),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
          // (Supprimé) Ancienne bannière d'aide FALC/Ollama.
          // Liste des posts
          Expanded(
            child: postsAsync.when(
              data: (data) {
                final posts = data.posts;
                final totalPages = data.totalPages;
                final matchedTypes = data.matchedTypes;

                // Filtrer par type si sélectionné
                var filtered = posts;
                if (_selectedType != null) {
                  filtered = posts
                      .where((post) => post.type == _selectedType)
                      .toList();
                }

                final hasCurrentUser = currentUserId != null && currentUserId.isNotEmpty;
                filtered = filtered.where((post) {
                  if (!hasCurrentUser) {
                    // Fallback sûr: sans utilisateur courant, "Mes posts" vide,
                    // "Posts des autres" affiche la liste.
                    return _ownerSegment == _PostsOwnerSegment.others;
                  }
                  final authorId = post.userId.trim();
                  final isMine = authorId.isNotEmpty && authorId == currentUserId;
                  return _ownerSegment == _PostsOwnerSegment.mine ? isMine : !isMine;
                }).toList();

                if (filtered.isEmpty) {
                  final emptyTitle = _ownerSegment == _PostsOwnerSegment.mine
                      ? 'Vous n’avez pas encore publié.'
                      : 'Aucune publication des autres pour le moment.';
                  final emptySubtitle = _ownerSegment == _PostsOwnerSegment.mine
                      ? strings.beFirstToPost
                      : 'Revenez plus tard ou publiez votre premier post.';
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.forum_outlined,
                          size: 64,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          emptyTitle,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          emptySubtitle,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () => _openCreatePost(context),
                          icon: const Icon(Icons.add),
                          label: Text(strings.createPost),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(communityFeedProvider((
                      page: _currentPage,
                      limit: _limit,
                      smart: useSmart,
                    )));
                  },
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      if (useSmart && matchedTypes.isNotEmpty)
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          sliver: SliverToBoxAdapter(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Filtre profil : ${matchedTypes.join(", ")}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        sliver: SliverList.builder(
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final post = filtered[index];
                            return _PostCard(
                              post: post,
                              isMine: hasCurrentUser &&
                                  post.userId.trim().isNotEmpty &&
                                  post.userId.trim() == currentUserId,
                              onTap: () => context.push(
                                '/post-detail/${post.id}',
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
                                top: BorderSide(
                                  color: theme.colorScheme.outline,
                                ),
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
                                          ref.invalidate(
                                            communityFeedProvider((
                                              page: _currentPage,
                                              limit: _limit,
                                              smart: useSmart,
                                            )),
                                          );
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
                                          ref.invalidate(
                                            communityFeedProvider((
                                              page: _currentPage,
                                              limit: _limit,
                                              smart: useSmart,
                                            )),
                                          );
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
                      strings.errorLoadingPosts,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => ref.invalidate(communityFeedProvider((
                        page: _currentPage,
                        limit: _limit,
                        smart: useSmart,
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

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: theme.colorScheme.primaryContainer,
      checkmarkColor: theme.colorScheme.onPrimaryContainer,
      labelStyle: TextStyle(
        color: selected
            ? theme.colorScheme.onPrimaryContainer
            : theme.colorScheme.onSurface,
        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({
    required this.post,
    required this.isMine,
    required this.onTap,
  });

  final PostModel post;
  final bool isMine;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    // Couleur selon le type
    Color typeColor;
    IconData typeIcon;
    switch (post.type) {
      case PostType.handicapMoteur:
        typeColor = Colors.blue;
        typeIcon = Icons.accessible;
        break;
      case PostType.handicapVisuel:
        typeColor = Colors.orange;
        typeIcon = Icons.visibility;
        break;
      case PostType.handicapAuditif:
        typeColor = Colors.purple;
        typeIcon = Icons.hearing;
        break;
      case PostType.handicapCognitif:
        typeColor = Colors.teal;
        typeIcon = Icons.psychology;
        break;
      case PostType.conseil:
        typeColor = Colors.green;
        typeIcon = Icons.lightbulb;
        break;
      case PostType.temoignage:
        typeColor = Colors.red;
        typeIcon = Icons.favorite;
        break;
      default:
        typeColor = primary;
        typeIcon = Icons.forum;
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
              // En-tête : utilisateur et type
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: typeColor.withValues(alpha: 0.12),
                    child: Icon(
                      typeIcon,
                      size: 20,
                      color: typeColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                isMine ? '${post.userName} (vous)' : post.userName,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (post.user?.partenaire == true)
                              const PartnerOrgBadge(compact: true),
                            VerifiedHelperBadge(
                              trustPoints: post.user?.trustPoints ?? 0,
                            ),
                          ],
                        ),
                        if (post.createdAt != null)
                          Text(
                            _formatDate(post.createdAt!),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: typeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      post.type.displayName,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: typeColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Contenu
              Text(
                post.contenu,
                style: theme.textTheme.bodyMedium,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
              if (post.images != null && post.images!.isNotEmpty) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    CommunityRepository.uploadUrl(post.images!.first),
                    height: 140,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              // Footer : commentaires
              Row(
                children: [
                  Icon(
                    Icons.volunteer_activism_outlined,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${post.merciCount} merci',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.comment_outlined,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    post.commentsCount != null
                        ? '${post.commentsCount} ${post.commentsCount! > 1 ? "commentaires" : "commentaire"}'
                        : 'Commenter',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
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

