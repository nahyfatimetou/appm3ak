import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:go_router/go_router.dart';

import '../../../core/enums/type_handicap.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../data/models/comment_model.dart';
import '../../../data/models/image_vision_description_model.dart';
import '../../../data/models/post_model.dart';
import '../../../data/models/simplified_text_model.dart';
import '../../../data/repositories/community_repository.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/community_providers.dart';
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
  bool _isSimplifyingText = false;
  bool _prefetchStarted = false;
  String? _lastSpokenSimplifiedKey;
  String? _lastSpokenPostKey;

  String _cleanSimplifiedText(String text) {
    // Objectif: garder uniquement le contenu "humain".
    // Suppression:
    // - introductions (ex: "Voici une/un résumé du texte...")
    // - "Points clés"
    // - instructions techniques (ex: "En 2 phrases de 5 mots maximum")
    // - guillemets inutiles et balisage technique.
    if (text.trim().isEmpty) return '';

    var out = text.trim();

    // Supprimer les code fences markdown (```json ... ```).
    out = out.replaceAll(RegExp(r'```[\s\S]*?```'), '');
    out = out.replaceAll('```json', '');
    out = out.replaceAll('```JSON', '');
    out = out.replaceAll('```', '');

    // Supprimer introductions / consignes.
    out = out.replaceAll(
      RegExp(
        r'\bVoici\s+(un|une)\s+résum(?:é|ée)\b[^:]*:?\s*',
        caseSensitive: false,
        dotAll: true,
      ),
      '',
    );
    out = out.replaceAll(
      RegExp(
        r'\bEn\s+\d+\s+phrases?\s+de\s+\d+\s+mots?\s+maximum\b.*$',
        caseSensitive: false,
        multiLine: true,
        dotAll: true,
      ),
      '',
    );
    out = out.replaceAll(
      RegExp(
        r'\bPoints\s+clés\b.*$',
        multiLine: true,
        dotAll: true,
      ),
      '',
    );

    // Nettoyage markdown / puces / titres.
    out = out.replaceAll(RegExp(r'^\s*•\s*', multiLine: true), '');
    out = out.replaceAll(RegExp(r'^\s*#+\s*', multiLine: true), '');

    // Extraire prioritairement les phrases entre guillemets.
    final quoted = <String>[];
    for (final m in RegExp(r'["“](.+?)["”]').allMatches(out)) {
      final s = m.group(1)?.trim() ?? '';
      if (s.isNotEmpty) quoted.add(s);
    }
    if (quoted.isNotEmpty) {
      return quoted.join('\n').trim();
    }

    // Sinon: lignes propres (et suppression des guillemets restants).
    out = out.replaceAll('"', '');
    out = out.replaceAll('“', '');
    out = out.replaceAll('”', '');
    out = out.replaceAll('`', '');

    return out
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .join('\n')
        .trim();
  }

  List<String> _extractSimplifiedItems(SimplifiedTextModel simplified) {
    if (simplified.keyPoints.isNotEmpty) {
      // Le backend peut renvoyer des keyPoints pollués (introductions / consignes).
      // On nettoie chaque entrée et on découpe en lignes.
      final out = <String>[];
      for (final kp in simplified.keyPoints) {
        final cleaned = _cleanSimplifiedText(kp);
        if (cleaned.isEmpty) continue;
        for (final line in cleaned
            .split('\n')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)) {
          out.add(line);
        }
      }
      return out.toList(growable: false);
    }

    final cleaned = _cleanSimplifiedText(simplified.simplifiedText);
    if (cleaned.isEmpty) return const [];

    return cleaned
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
  }

  String _annotateSimplifiedSentence(String s) {
    var t = s.trim();
    if (t.isEmpty) return t;

    // Choisir emoji selon la présence de mots "danger".
    final lower = t.toLowerCase();
    const dangerWords = <String>[
      'danger',
      'dangereux',
      'risque',
      'grave',
      'évitez',
      'evitez',
      'urgence',
      'malaise',
      'douleur',
      'maladie',
    ];
    final isDanger = dangerWords.any(lower.contains);
    final emoji = isDanger ? '🚫' : '🚸';

    // Enlever guillemets restants (si le backend en met encore).
    t = t
        .replaceAll(RegExp(r'^[\"“”]+'), '')
        .replaceAll(RegExp(r'[\"“”]+$'), '')
        .trim();
    return '$emoji $t';
  }

  String _formatSimplifiedForUi(SimplifiedTextModel simplified) {
    final items = _extractSimplifiedItems(simplified);
    if (items.isEmpty) return '';

    // Résumé direct: max 6 phrases.
    return items
        .take(6)
        .map(_annotateSimplifiedSentence)
        .join('\n')
        .trim();
  }

  String _formatSimplifiedForSpeech(SimplifiedTextModel simplified) {
    final items = _extractSimplifiedItems(simplified);
    if (items.isEmpty) return '';
    return items.take(6).join('\n').trim();
  }

  String _cleanImageDescriptionText(String text) {
    var out = text.trim();
    if (out.isEmpty) return out;

    // Certains backends peuvent renvoyer une string qui ressemble à du JSON
    // encodé dans `description` (ex: "description_audio":"...").
    // On extrait la valeur de `description` en priorité, sinon `description_audio`.
    final visionMatch = RegExp(
      r'"description"\s*:\s*"((?:\\.|[^"\\])*)"',
      dotAll: true,
    ).firstMatch(out);
    final audioMatch = RegExp(
      r'"description_audio"\s*:\s*"((?:\\.|[^"\\])*)"',
      dotAll: true,
    ).firstMatch(out);

    final extracted = visionMatch?.group(1) ?? audioMatch?.group(1);
    if (extracted != null && extracted.isNotEmpty) {
      // Dé-échappement basique.
      return extracted
          .replaceAll(r'\"', '"')
          .replaceAll(r'\n', '\n')
          .replaceAll(r'\\', '\\');
    }

    return out;
  }

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

  /// Message lisible pour les erreurs API (timeouts, 403, corps Nest).
  String _readableApiError(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map<String, dynamic>) {
        final msg = data['message'];
        if (msg is String && msg.isNotEmpty) return msg;
        if (msg is List && msg.isNotEmpty) {
          final first = msg.first;
          if (first is String) return first;
          if (first is Map && first['msg'] is String) {
            return first['msg'] as String;
          }
        }
      }
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return 'Délai réseau dépassé. L’analyse photo (Ollama) peut prendre plusieurs minutes au 1ᵉʳ lancement — réessayez ou testez depuis l’app mobile. Vérifiez ollama serve.';
        default:
          break;
      }
      if (e.response?.statusCode == 401) {
        return 'Session expirée : reconnectez-vous.';
      }
      final m = e.message;
      if (m != null && m.isNotEmpty) return m;
    }
    return e.toString();
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

  Future<void> _readSimplified(String postContent) async {
    if (_isSimplifyingText) return;
    setState(() => _isSimplifyingText = true);
    final u0 = ref.read(authStateProvider).valueOrNull;
    final s0 = AppStrings.fromPreferredLanguage(u0?.preferredLanguage?.name);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            content: Row(
              children: [
                const SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Text(
                    s0.falcSimplificationLoading,
                    style: Theme.of(dialogCtx).textTheme.bodyLarge,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    try {
      final repository = ref.read(communityRepositoryProvider);
      final simplified = await repository.simplifyText(text: postContent);

      if (!mounted) return;
      context.pop();
      final user = ref.read(authStateProvider).valueOrNull;
      final isVisualUser =
          TypeHandicap.fromApiString(user?.typeHandicap) == TypeHandicap.visuel;
      final strings = AppStrings.fromPreferredLanguage(
        user?.preferredLanguage?.name,
      );
      final speechText = _formatSimplifiedForSpeech(simplified);
      final speechKey = speechText;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(strings.simplifiedVersionTitle),
              if (simplified.source != null) ...[
                const SizedBox(height: 8),
                Chip(
                  label: Text(
                    simplified.source == 'ollama'
                        ? strings.simplifySourceOllama
                        : strings.simplifySourceHeuristic,
                    style: Theme.of(ctx).textTheme.labelSmall,
                  ),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                ),
              ],
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatSimplifiedForUi(simplified),
                  softWrap: true,
                  style: Theme.of(ctx).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
          actions: [
            if (isVisualUser && speechText.isNotEmpty)
              FilledButton.icon(
                onPressed: () => _speakDescription(speechText),
                icon: const Icon(Icons.record_voice_over),
                label: const Text('Lire en audio'),
              ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Fermer'),
            ),
          ],
        ),
      );

      // Lecture automatique (une seule fois) pour les non-voyants.
      if (isVisualUser && speechKey.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;
          if (_lastSpokenSimplifiedKey == speechKey) return;
          _lastSpokenSimplifiedKey = speechKey;
          await _speakDescription(speechText);
        });
      }
    } catch (e) {
      if (!mounted) return;
      if (Navigator.of(context).canPop()) {
        context.pop();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur simplification : ${_readableApiError(e)}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSimplifyingText = false);
    }
  }

  Future<void> _loadImageAudioDescription({
    required PostModel post,
    required int imageIndex,
  }) async {
    final u0 = ref.read(authStateProvider).valueOrNull;
    final s0 = AppStrings.fromPreferredLanguage(u0?.preferredLanguage?.name);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            content: Row(
              children: [
                const SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Text(
                    s0.imageAnalysisLoading,
                    style: Theme.of(dialogCtx).textTheme.bodyLarge,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    try {
      final repository = ref.read(communityRepositoryProvider);
      final ImageVisionDescription result =
          await repository.getPostImageAccessibilityDescription(
        postId: post.id,
        imageIndex: imageIndex,
      );
      if (!mounted) return;
      context.pop();
      final u1 = ref.read(authStateProvider).valueOrNull;
      final dialogStrings =
          AppStrings.fromPreferredLanguage(u1?.preferredLanguage?.name);
      await showDialog<void>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: const Text('Description de l’image'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (result.source == 'vision')
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Analyse vision (IA)',
                        style: Theme.of(ctx).textTheme.labelSmall?.copyWith(
                              color: Theme.of(ctx).colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  if (result.displaySummary != null &&
                      result.displaySummary!.isNotEmpty) ...[
                    Text(
                      result.displaySummary!,
                      style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      dialogStrings.imageDetailForReadingAndTts,
                      style: Theme.of(ctx).textTheme.labelSmall?.copyWith(
                            color: Theme.of(ctx).colorScheme.outline,
                          ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  if (result.source == 'vision' &&
                      result.description.trim().isNotEmpty)
                    Text(
                      _cleanImageDescriptionText(result.description),
                      softWrap: true,
                    ),
                  if (result.textDetected != null &&
                      result.textDetected!.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Texte lisible sur l’image',
                      style: Theme.of(ctx).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(result.textDetected!, softWrap: true),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Fermer'),
              ),
              FilledButton.icon(
                onPressed: () => _speakDescription(
                  _cleanImageDescriptionText(result.textForSpeech),
                ),
                icon: const Icon(Icons.record_voice_over),
                label: const Text('Lire à voix haute'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      context.pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Description image : ${_readableApiError(e)}'),
          backgroundColor: Colors.red,
        ),
      );
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
    final visionCapabilitiesAsync =
        ref.watch(communityVisionCapabilitiesProvider);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(strings.postDetails),
      ),
      body: postAsync.when(
        data: (post) {
          final handicap = TypeHandicap.fromApiString(user?.typeHandicap);
          final wantsPhotoAnalysis = handicap == TypeHandicap.visuel;
          final wantsSimplify =
              handicap == TypeHandicap.cognitif || handicap == TypeHandicap.visuel;
          final wantsAny = wantsPhotoAnalysis || wantsSimplify;

          final hasImages = post.images != null && post.images!.isNotEmpty;
          final hasContent = post.contenu.trim().isNotEmpty;

          // Précharge en arrière-plan pour que le clic utilisateur soit rapide.
          if (!_prefetchStarted && wantsAny) {
            _prefetchStarted = true;
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              if (!mounted) return;
              final repository = ref.read(communityRepositoryProvider);
              try {
                if (wantsSimplify && hasContent) {
                  await repository.simplifyText(text: post.contenu);
                }
                // Important : on préchauffe même si `visionCapabilitiesAsync`
                // n'est pas encore prêt (valueOrNull peut être null au premier build).
                // Le clic utilisateur relancera en cas d'échec.
                if (wantsPhotoAnalysis && hasImages) {
                  final count = post.images?.length ?? 0;
                  final indices = count <= 2
                      ? List<int>.generate(count, (i) => i)
                      : const [0];
                  for (final imageIndex in indices) {
                    await repository.getPostImageAccessibilityDescription(
                      postId: post.id,
                      imageIndex: imageIndex,
                    );
                  }
                }
              } catch (_) {
                // On ignore: la récupération exacte sera faite au clic.
              }
            });
          }

          // Lecture automatique du texte du post pour les utilisateurs
          // handicap visuel (non-voyants), une seule fois par ouverture.
          if (wantsPhotoAnalysis && hasContent) {
            final postKey = '${post.id}|${post.contenu.hashCode}';
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              if (!mounted) return;
              if (_lastSpokenPostKey == postKey) return;
              _lastSpokenPostKey = postKey;
              await _speakDescription(post.contenu);
            });
          }

          return Column(
            children: [
              visionCapabilitiesAsync.when(
                data: (m) {
                  final geminiOk = m['geminiConfigured'] == true;
                  final ollamaOk = m['ollamaReachable'] == true;
                  if (geminiOk || ollamaOk) return const SizedBox.shrink();
                  // On masque le message d'installation/configuration Ollama.
                  // (Affichage réservé si tu veux une aide utilisateur dans une autre UI.)
                  return const SizedBox.shrink();
                },
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),
              // Post principal
              Expanded(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // En-tête du post
                      _PostHeader(post: post),
                      const SizedBox(height: 16),
                      Divider(color: theme.colorScheme.outline),
                      const SizedBox(height: 16),
                      // Contenu complet + accès explicite FALC
                      Text(
                        post.contenu,
                        style: theme.textTheme.bodyLarge,
                        softWrap: true,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        alignment: WrapAlignment.start,
                        children: [
                          FilledButton.tonalIcon(
                            onPressed: _isSimplifyingText
                                ? null
                                : () => _readSimplified(post.contenu),
                            icon: _isSimplifyingText
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: primary,
                                    ),
                                  )
                                : const Icon(Icons.auto_fix_high_outlined),
                            label: Text(strings.simplifyText),
                          ),
                          if (wantsPhotoAnalysis)
                            FilledButton.tonalIcon(
                              onPressed: () => _speakDescription(
                                post.contenu.trim(),
                              ),
                              icon: const Icon(Icons.volume_up_outlined),
                              label: const Text('Lire le texte'),
                            ),
                        ],
                      ),
                      if (post.images != null && post.images!.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        ...post.images!.asMap().entries.map((entry) {
                          final imageIndex = entry.key;
                          final path = entry.value;
                          final url = CommunityRepository.uploadUrl(path);
                          final visualProfile = isVisualHandicapProfile(
                            user?.typeHandicap,
                          );
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                ClipRRect(
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
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: TextButton.icon(
                                      onPressed: () => _loadImageAudioDescription(
                                        post: post,
                                        imageIndex: imageIndex,
                                      ),
                                      icon: Icon(
                                        visualProfile
                                            ? Icons.headphones
                                            : Icons.image_search_outlined,
                                        size: 20,
                                      ),
                                      label: Text(
                                        visualProfile
                                            ? strings.imageDescriptionAndAudio
                                            : strings.analyzeImageWithAi,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
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

                      // Résumé flash automatique (accessibilité)
                      flashSummaryAsync.when(
                        data: (flash) {
                          if (flash.summary.trim().isEmpty) return const SizedBox.shrink();
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
                        error: (_, _) => const SizedBox.shrink(),
                      ),

                      // Liste des commentaires
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
                    crossAxisAlignment: CrossAxisAlignment.end,
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
                          minLines: 1,
                          maxLines: 4,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _submitComment(),
                        ),
                      ),
                      const SizedBox(width: 4),
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
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          padding: const EdgeInsets.all(8),
                          minimumSize: const Size(40, 40),
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
              Row(
                children: [
                  Expanded(
                    child: Text(
                      post.userName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
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
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: typeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              post.type.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: theme.textTheme.labelSmall?.copyWith(
                color: typeColor,
                fontWeight: FontWeight.bold,
              ),
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

