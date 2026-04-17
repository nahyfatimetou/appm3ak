import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:go_router/go_router.dart';

import '../../../core/enums/type_handicap.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../data/models/comment_model.dart';
import '../../../data/models/post_model.dart';
import '../../../data/repositories/community_repository.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/community_providers.dart';
import '../../../providers/post_detail_assistance_provider.dart';
import '../../../widgets/verified_helper_badge.dart';

/// Écran de détails d'un post avec commentaires.
class PostDetailScreen extends ConsumerStatefulWidget {
  const PostDetailScreen({required this.postId, super.key});

  final String postId;

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  final _commentController = TextEditingController();
  final FlutterTts _flutterTts = FlutterTts();
  bool _isSubmittingComment = false;
  bool _merciBusy = false;
  bool _obstacleBusy = false;
  String? _lastSpokenPostKey;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initTts());
  }

  Future<void> _initTts() async {
    await _flutterTts.awaitSpeakCompletion(true);
    await _flutterTts.setSpeechRate(0.45);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
  }

  @override
  void dispose() {
    _flutterTts.stop();
    _commentController.dispose();
    super.dispose();
  }


  Future<void> _speakDescription(String text) async {
    final t = text.trim();
    if (t.isEmpty) return;
    try {
      // Langue TTS selon préférence utilisateur (FR/AR).
      final user = ref.read(authStateProvider).valueOrNull;
      final lang = (user?.preferredLanguage?.name ?? '').toLowerCase();
      final ttsLang = lang == 'ar' ? 'ar' : 'fr-FR';
      await _flutterTts.stop();
      await _flutterTts.setLanguage(ttsLang);
      await _flutterTts.speak(t);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            kIsWeb
                ? 'Synthèse vocale (web) indisponible : essayez la voix du navigateur.'
                : 'Synthèse vocale indisponible.',
          ),
        ),
      );
    }
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
      await ref.read(authStateProvider.notifier).refreshUser();
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

  Future<void> _toggleMerci() async {
    if (_merciBusy) return;
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connectez-vous pour remercier ce signalement.')),
      );
      return;
    }
    setState(() => _merciBusy = true);
    try {
      await ref.read(communityRepositoryProvider).togglePostMerci(widget.postId);
      ref.invalidate(postMerciStateProvider(widget.postId));
      ref.invalidate(postByIdProvider(widget.postId));
      ref.invalidate(communityFeedProvider((page: 1, limit: 20, smart: false)));
      ref.invalidate(communityFeedProvider((page: 1, limit: 20, smart: true)));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _merciBusy = false);
    }
  }

  Future<void> _voteObstacle(bool confirm) async {
    if (_obstacleBusy) return;
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;
    setState(() => _obstacleBusy = true);
    try {
      await ref.read(communityRepositoryProvider).validatePostObstacle(
            postId: widget.postId,
            confirm: confirm,
          );
      ref.invalidate(postByIdProvider(widget.postId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Merci, votre avis est enregistré.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _obstacleBusy = false);
    }
  }

  Future<void> _confirmDeletePostAsAdmin() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Modération'),
        content: const Text(
          'Supprimer ce post du flux ? (spam ou contenu inapproprié)',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ref.read(communityRepositoryProvider).deletePostAdmin(widget.postId);
      ref.invalidate(communityFeedProvider((page: 1, limit: 20, smart: false)));
      ref.invalidate(communityFeedProvider((page: 1, limit: 20, smart: true)));
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
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
        ref.watch(postCommentsFlashSummaryProvider(widget.postId));
    ref.watch(postMerciStateProvider(widget.postId));

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(strings.postDetails),
        actions: [
          if (user?.isAdmin == true)
            PopupMenuButton<String>(
              icon: const Icon(Icons.admin_panel_settings_outlined),
              tooltip: 'Modération',
              onSelected: (v) {
                if (v == 'delete') _confirmDeletePostAsAdmin();
              },
              itemBuilder: (ctx) => const [
                PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.delete_outline),
                    title: Text('Supprimer ce post'),
                    subtitle: Text('Spam ou photo inappropriée'),
                  ),
                ),
              ],
            ),
        ],
      ),
      body: postAsync.when(
        data: (post) {
          final handicap = TypeHandicap.fromApiString(user?.typeHandicap);
          final wantsTts = handicap == TypeHandicap.visuel;

          final hasContent = post.contenu.trim().isNotEmpty;

          // Lecture automatique du texte du post pour les utilisateurs
          // handicap visuel (non-voyants), une seule fois par ouverture.
          if (wantsTts && hasContent) {
            final ttsText =
                ref.read(postDetailAssistanceProvider).buildTtsReadablePost(post);
            final postKey = '${post.id}|${ttsText.hashCode}';
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              if (!mounted) return;
              if (_lastSpokenPostKey == postKey) return;
              _lastSpokenPostKey = postKey;
              await _speakDescription(ttsText);
            });
          }

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _PostHeader(post: post),
                      const SizedBox(height: 16),
                      Card(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Semantics(
                                header: true,
                                child: Text(
                                  'Contenu du post',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                post.contenu,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  height: 1.45,
                                ),
                                softWrap: true,
                              ),
                              if (wantsTts) ...[
                                const SizedBox(height: 12),
                                FilledButton.tonalIcon(
                                  onPressed: () => _speakDescription(
                                    ref
                                        .read(postDetailAssistanceProvider)
                                        .buildTtsReadablePost(post),
                                  ),
                                  style: FilledButton.styleFrom(
                                    minimumSize: const Size(170, 48),
                                  ),
                                  icon: const Icon(Icons.volume_up_outlined),
                                  label: const Text('Lire le texte'),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      if (post.images != null && post.images!.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        ...post.images!.map((path) {
                          final url = CommunityRepository.uploadUrl(path);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                url,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                loadingBuilder: (_, child, progress) {
                                  if (progress == null) return child;
                                  return SizedBox(
                                    height: 200,
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        value: progress.expectedTotalBytes !=
                                                null
                                            ? progress.cumulativeBytesLoaded /
                                                progress.expectedTotalBytes!
                                            : null,
                                      ),
                                    ),
                                  );
                                },
                                errorBuilder: (_, _, _) => Container(
                                  height: 120,
                                  color: theme
                                      .colorScheme.surfaceContainerHighest,
                                  alignment: Alignment.center,
                                  child: const Icon(Icons.broken_image),
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                      const SizedBox(height: 16),
                      flashSummaryAsync.when(
                        data: (flash) {
                          if (flash.summary.trim().isEmpty) return const SizedBox.shrink();
                          return Card(
                            margin: EdgeInsets.zero,
                            color: theme.colorScheme.surfaceContainerHigh,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Résumé rapide',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      _MetaChip(
                                        icon: Icons.groups_2_outlined,
                                        label:
                                            'Public: ${post.targetAudience ?? 'all'}',
                                      ),
                                      _MetaChip(
                                        icon: Icons.category_outlined,
                                        label:
                                            'Nature: ${post.postNature ?? 'information'}',
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    flash.summary,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        loading: () => const SizedBox.shrink(),
                        error: (_, _) => const SizedBox.shrink(),
                      ),
                      const SizedBox(height: 16),
                      Card(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Actions rapides',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: () {
                                    final pre = ref
                                        .read(postDetailAssistanceProvider)
                                        .buildHelpRequestFromPost(post);
                                    context.push('/create-help-request', extra: pre);
                                  },
                                  style: FilledButton.styleFrom(
                                    minimumSize: const Size(double.infinity, 52),
                                  ),
                                  icon: const Icon(Icons.emergency_share_outlined),
                                  label: const Text('Demander de l’aide'),
                                ),
                              ),
                              const SizedBox(height: 10),
                              ref.watch(postMerciStateProvider(widget.postId)).when(
                                    data: (merci) {
                                      final isAuthor =
                                          user != null && user.id == post.userId;
                                      return Row(
                                        children: [
                                          Expanded(
                                            child: OutlinedButton.icon(
                                              onPressed: (_merciBusy ||
                                                      user == null ||
                                                      isAuthor)
                                                  ? null
                                                  : _toggleMerci,
                                              icon: _merciBusy
                                                  ? const SizedBox(
                                                      width: 16,
                                                      height: 16,
                                                      child:
                                                          CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                      ),
                                                    )
                                                  : const Icon(
                                                      Icons.volunteer_activism_outlined,
                                                    ),
                                              label: Text(
                                                'Moi aussi concerné (${merci.merciCount})',
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                    loading: () => const SizedBox.shrink(),
                                    error: (_, __) => const SizedBox.shrink(),
                                  ),
                              if (post.showsObstacleValidation) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: (_obstacleBusy || user == null)
                                            ? null
                                            : () => _voteObstacle(true),
                                        icon: const Icon(Icons.check_circle_outline),
                                        label: const Text('Toujours là'),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: (_obstacleBusy || user == null)
                                            ? null
                                            : () => _voteObstacle(false),
                                        icon: const Icon(Icons.cancel_outlined),
                                        label: const Text('Plus là'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _PostAssistSection(post: post),
                      const SizedBox(height: 24),
                      // Commentaires
                      Text(
                        strings.comments,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Liste des commentaires
                      commentsAsync.when(
                        data: (comments) {
                          if (comments.isEmpty) {
                            return Card(
                              margin: EdgeInsets.zero,
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.chat_bubble_outline,
                                      size: 34,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      strings.noComments,
                                      textAlign: TextAlign.center,
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }
                          return Card(
                            margin: EdgeInsets.zero,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                children: comments.map((comment) {
                                  return _CommentCard(comment: comment);
                                }).toList(),
                              ),
                            ),
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
              Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  border: Border(
                    top: BorderSide(color: theme.colorScheme.outline),
                  ),
                ),
                child: SafeArea(
                  child: Semantics(
                    container: true,
                    label: 'Saisie de commentaire',
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _commentController,
                            decoration: InputDecoration(
                              hintText: strings.writeComment,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              filled: true,
                              fillColor: theme.colorScheme.surfaceContainerLow,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                            minLines: 1,
                            maxLines: 4,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _submitComment(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: _isSubmittingComment ? null : _submitComment,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(52, 52),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: _isSubmittingComment
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.send),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
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
                  textAlign: TextAlign.center,
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
      ),
    );
  }
}

/// Résumés accessibles + lien vers demande d’aide (couche [PostDetailAssistanceService]).
class _PostAssistSection extends ConsumerWidget {
  const _PostAssistSection({required this.post});

  final PostModel post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final postSummary =
        ref.watch(postDetailAssistancePostSummaryProvider(post.id));
    final commentsSummary =
        ref.watch(postDetailAssistanceCommentsSummaryProvider(post.id));

    return Card(
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Aperçu accessible',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            _AccessibleField(
              label: 'Type',
              value: post.type.displayName,
            ),
            _AccessibleField(
              label: 'Nature',
              value: post.postNature ?? 'information',
            ),
            const SizedBox(height: 8),
            postSummary.when(
              data: (r) => _AccessibleField(
                label: 'Aperçu',
                value: r.summary,
              ),
              loading: () => const LinearProgressIndicator(minHeight: 2),
              error: (_, __) => _AccessibleField(
                label: 'Aperçu',
                value: 'Résumé indisponible.',
              ),
            ),
            const SizedBox(height: 8),
            commentsSummary.when(
              data: (r) => _AccessibleField(
                label: 'Commentaires (aperçu)',
                value: r.summary,
              ),
              loading: () => const SizedBox(
                height: 4,
                child: LinearProgressIndicator(minHeight: 2),
              ),
              error: (_, __) => _AccessibleField(
                label: 'Commentaires (aperçu)',
                value: 'Aperçu commentaires indisponible.',
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: null,
              icon: const Icon(Icons.volume_up_outlined),
              label: const Text('Lecture audio (bientôt)'),
            ),
          ],
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

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
                if (post.user?.partenaire == true)
                  const PartnerOrgBadge(compact: true),
                VerifiedHelperBadge(
                  trustPoints: post.user?.trustPoints ?? 0,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MetaChip(
                  icon: Icons.badge_outlined,
                  label: post.type.displayName,
                  color: typeColor,
                ),
                if ((post.targetAudience ?? '').trim().isNotEmpty)
                  _MetaChip(
                    icon: Icons.groups_2_outlined,
                    label: post.targetAudience!,
                  ),
                if ((post.postNature ?? '').trim().isNotEmpty)
                  _MetaChip(
                    icon: Icons.category_outlined,
                    label: post.postNature!,
                  ),
                if (post.obstaclePresent)
                  _MetaChip(
                    icon: Icons.warning_amber_outlined,
                    label: 'Obstacle signalé',
                    color: primary,
                  ),
              ],
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
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          comment.userName,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (comment.user?.partenaire == true)
                        const PartnerOrgBadge(compact: true),
                      VerifiedHelperBadge(
                        trustPoints: comment.user?.trustPoints ?? 0,
                      ),
                    ],
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

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
    this.color,
  });

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = color ?? theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: c),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: c,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _AccessibleField extends StatelessWidget {
  const _AccessibleField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.35),
          ),
        ],
      ),
    );
  }
}

