import '../../../../data/models/comment_model.dart';
import '../../../../data/models/post_model.dart';
import '../../models/help_request_quick_preset.dart';
import 'post_detail_assistance_models.dart';
import 'post_detail_assistance_service.dart';

/// Repli **sans réseau** : extraits, listes de commentaires, mapping post → préréglage aide.
class LocalPostDetailAssistanceService implements PostDetailAssistanceService {
  static const int _maxPostExcerpt = 280;
  static const int _maxCommentsChars = 520;
  static const int _maxHelpDescription = 900;

  @override
  Future<PostSummaryResult> summarizePost(PostModel post) async {
    final raw = post.contenu.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (raw.isEmpty) {
      return PostSummaryResult(
        summary:
            'Post sans texte. Type : ${post.type.displayName}.',
        source: AssistanceSource.local,
        postId: post.id,
      );
    }
    final excerpt =
        raw.length > _maxPostExcerpt ? '${raw.substring(0, _maxPostExcerpt)}…' : raw;
    final extra = <String>[];
    if (post.obstaclePresent || post.hasPlace) {
      extra.add('signalement lieu ou obstacle');
    }
    if (post.needsSimpleLanguage == true) {
      extra.add('demande de langage simple');
    }
    final tail = extra.isEmpty ? '' : ' — ${extra.join(', ')}';
    return PostSummaryResult(
      summary:
          'Type : ${post.type.displayName}.$tail\nAperçu : $excerpt',
      source: AssistanceSource.local,
      postId: post.id,
    );
  }

  @override
  Future<CommentsSummaryResult> summarizeComments(
    PostModel post,
    List<CommentModel> comments,
  ) async {
    if (comments.isEmpty) {
      return CommentsSummaryResult(
        summary: 'Aucun commentaire pour l’instant.',
        source: AssistanceSource.local,
        postId: post.id,
        commentCount: 0,
      );
    }
    final buf = StringBuffer();
    final n = comments.length > 8 ? 8 : comments.length;
    for (var i = 0; i < n; i++) {
      final c = comments[i];
      final line = c.contenu.replaceAll(RegExp(r'\s+'), ' ').trim();
      buf.writeln('• ${c.userName} : $line');
    }
    if (comments.length > n) {
      buf.writeln('… (${comments.length - n} autre(s) commentaire(s))');
    }
    var text = buf.toString().trim();
    if (text.length > _maxCommentsChars) {
      text = '${text.substring(0, _maxCommentsChars)}…';
    }
    return CommentsSummaryResult(
      summary: 'Commentaires (${comments.length}) :\n$text',
      source: AssistanceSource.local,
      postId: post.id,
      commentCount: comments.length,
    );
  }

  @override
  HelpRequestFromPostPrefill buildHelpRequestFromPost(PostModel post) {
    final header = '[Depuis le post communauté — réf. ${post.id}]';
    final body = post.contenu.trim();
    var desc = '$header\n\n$body';
    if (desc.length > _maxHelpDescription) {
      desc = '${desc.substring(0, _maxHelpDescription)}…';
    }

    return HelpRequestFromPostPrefill(
      description: desc,
      suggestedPreset: _presetForPost(post),
      needsAudioGuidance: post.needsAudioGuidance,
      needsVisualSupport: post.needsVisualSupport,
      needsPhysicalAssistance: post.needsPhysicalAssistance,
      needsSimpleLanguage: post.needsSimpleLanguage,
      isForAnotherPerson: post.isForAnotherPerson,
    );
  }

  HelpRequestQuickPreset _presetForPost(PostModel post) {
    if (post.isForAnotherPerson == true) {
      return HelpRequestQuickPreset.forAnotherPerson;
    }
    switch (post.type) {
      case PostType.handicapMoteur:
        return HelpRequestQuickPreset.mobilityHelp;
      case PostType.handicapVisuel:
      case PostType.handicapAuditif:
        return HelpRequestQuickPreset.orientationHelp;
      case PostType.handicapCognitif:
        return HelpRequestQuickPreset.communicationHelp;
      case PostType.conseil:
      case PostType.temoignage:
      case PostType.general:
      case PostType.autre:
        if (post.obstaclePresent || post.hasPlace) {
          return HelpRequestQuickPreset.blocked;
        }
        return HelpRequestQuickPreset.orientationHelp;
    }
  }

  @override
  String buildTtsReadablePost(PostModel post) {
    final raw = post.contenu.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (raw.isEmpty) return 'Aucun texte dans ce message.';
    return '${post.userName} écrit. $raw';
  }
}
