import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../data/models/comment_model.dart';
import '../../../data/models/post_model.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/community_providers.dart';
import '../widgets/post_image_gallery.dart';

/// Écran de détails d'un post avec commentaires.
class PostDetailScreen extends ConsumerStatefulWidget {
  const PostDetailScreen({required this.postId, super.key});

  final String postId;

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  final _commentController = TextEditingController();
  bool _isSubmittingComment = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitComment() async {
    if (_commentController.text.trim().isEmpty) return;

    setState(() => _isSubmittingComment = true);

    try {
      await ref.read(createCommentProvider((
        postId: widget.postId,
        contenu: _commentController.text.trim(),
      )).future);

      _commentController.clear();
      // Rafraîchir les commentaires
      ref.invalidate(postCommentsProvider(widget.postId));
      // Rafraîchir le post pour mettre à jour le nombre de commentaires
      ref.invalidate(postByIdProvider(widget.postId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmittingComment = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final strings =
        AppStrings.fromPreferredLanguage(user?.preferredLanguage?.name);
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    final postAsync = ref.watch(postByIdProvider(widget.postId));
    final commentsAsync = ref.watch(postCommentsProvider(widget.postId));
    final flashSummaryAsync =
        ref.watch(commentsFlashSummaryProvider(widget.postId));

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(strings.postDetails),
      ),
      body: postAsync.when(
        data: (post) {
          return Column(
            children: [
              // Post principal
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // En-tête du post
                      _PostHeader(post: post),
                      const SizedBox(height: 16),
                      Divider(color: theme.colorScheme.outline),
                      const SizedBox(height: 16),
                      Text(
                        post.contenu,
                        style: theme.textTheme.bodyLarge,
                      ),
                      if (post.images != null && post.images!.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        PostImageGallery(images: post.images!),
                      ],
                      const SizedBox(height: 24),
                      // Commentaires
                      Text(
                        strings.comments,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      flashSummaryAsync.when(
                        data: (flash) {
                          if (flash.summary.trim().isEmpty) {
                            return const SizedBox.shrink();
                          }
                          return Card(
                            color: theme.colorScheme.surfaceContainerHighest,
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Résumé rapide',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    flash.summary,
                                    style: theme.textTheme.bodyMedium,
                                    softWrap: true,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                      commentsAsync.when(
                        data: (comments) {
                          if (comments.isEmpty) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32),
                                child: Text(
                                  strings.noComments,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            );
                          }
                          return Column(
                            children: comments.map((comment) {
                              return _CommentCard(comment: comment);
                            }).toList(),
                          );
                        },
                        loading: () => const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(),
                          ),
                        ),
                        error: (error, stack) => Center(
                          child: Text(
                            strings.errorLoadingComments,
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Zone de commentaire
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  border: Border(
                    top: BorderSide(color: theme.colorScheme.outline),
                  ),
                ),
                child: SafeArea(
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _commentController,
                          decoration: InputDecoration(
                            hintText: strings.writeComment,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          maxLines: null,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _submitComment(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _isSubmittingComment ? null : _submitComment,
                        icon: _isSubmittingComment
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Icon(Icons.send, color: primary),
                        style: IconButton.styleFrom(
                          backgroundColor: primary.withValues(alpha: 0.1),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
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
                strings.errorLoadingPost,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.pop(),
                child: Text(strings.goBack),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PostHeader extends StatelessWidget {
  const _PostHeader({required this.post});

  final PostModel post;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

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

    return Row(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: typeColor.withValues(alpha: 0.12),
          child: Icon(typeIcon, size: 24, color: typeColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                post.userName,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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

class _CommentCard extends StatelessWidget {
  const _CommentCard({required this.comment});

  final CommentModel comment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: primary.withValues(alpha: 0.12),
              child: Icon(
                Icons.person,
                size: 18,
                color: primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    comment.userName,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (comment.createdAt != null)
                    Text(
                      _formatDate(comment.createdAt!),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    comment.contenu,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
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

