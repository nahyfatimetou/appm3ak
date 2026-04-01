import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';

import '../api/api_client.dart';
import '../api/endpoints.dart';
import '../../core/config/app_config.dart';
import '../models/comment_model.dart';
import '../models/flash_summary_model.dart';
import '../models/help_request_model.dart';
import '../models/post_model.dart';
import '../models/simplified_text_model.dart';
import '../models/image_vision_description_model.dart';

/// Repository pour gérer les posts et demandes d'aide de la communauté.
class CommunityRepository {
  CommunityRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  // ---- In-memory cache (per app lifetime) ----
  // But: éviter de recalculer côté serveur si l'utilisateur reclic / reouvre.
  final Map<String, Future<SimplifiedTextModel>> _simplifyTextInFlight = {};
  final Map<String, SimplifiedTextModel> _simplifyTextCache = {};
  final Map<String, Future<ImageVisionDescription>> _imageDescInFlight = {};
  final Map<String, ImageVisionDescription> _imageDescCache = {};

  String _simplifyCacheKey({
    required String text,
    required String level,
  }) {
    final t = text.trim();
    // La clé ne stocke pas tout le texte pour garder la mémoire légère.
    return '$level|${t.length}|${t.hashCode}';
  }

  String _imageDescCacheKey({
    required String postId,
    required int imageIndex,
  }) =>
      '$postId|$imageIndex';

  /// Ollama (FALC + vision) : le backend attend le LLM ; 1ʳᵉ charge LLaVA peut dépasser 5–15 min (CPU).
  /// Sur **web**, un `connectTimeout` trop court fait un [DioExceptionType.connectionTimeout] alors que le serveur calcule encore.
  static Options _ollamaDioOptions() {
    const longWait = Duration(minutes: 45);
    if (kIsWeb) {
      return Options(
        connectTimeout: longWait,
        sendTimeout: const Duration(minutes: 5),
        receiveTimeout: longWait,
      );
    }
    return Options(
      connectTimeout: const Duration(minutes: 15),
      sendTimeout: const Duration(minutes: 5),
      receiveTimeout: longWait,
    );
  }

  /// GET `/community/vision/capabilities` — flags Gemini + Ollama + ping (via [CommunityVisionService]).
  Future<Map<String, dynamic>> getCommunityVisionCapabilities() async {
    final response = await _api.dio.get(Endpoints.communityVisionCapabilities);
    final data = response.data;
    if (data is Map<String, dynamic>) return data;
    return Map<String, dynamic>.from(data as Map);
  }

  /// @deprecated Utiliser [getCommunityVisionCapabilities].
  Future<Map<String, dynamic>> getAccessibilityFeatures() =>
      getCommunityVisionCapabilities();

  /// URL d’une image stockée côté API (`uploads/post-….jpg`).
  /// Normalise les séparateurs (évite les 404 si le chemin contient des `\` côté serveur).
  static String uploadUrl(String path) {
    if (path.isEmpty) return '';
    final base = AppConfig.uploadsBaseUrl.replaceAll(RegExp(r'/$'), '');

    var clean = path
        .replaceFirst(RegExp(r'^/'), '')
        .replaceAll(r'\', '/')
        .trim();

    final baseHasUploads = RegExp(r'/uploads$').hasMatch(base);

    // Si le backend renvoie "community/post-..." (sans "uploads/"),
    // on force le préfixe attendu par le serveur (/uploads).
    if (!baseHasUploads && !clean.startsWith('uploads/')) {
      clean = 'uploads/$clean';
    }

    // Si la config base inclut déjà "/uploads", on évite "double uploads".
    if (baseHasUploads && clean.startsWith('uploads/')) {
      clean = clean.substring('uploads/'.length);
    }

    return '$base/$clean';
  }

  static Map<String, dynamic> _normalizePostJson(Map<String, dynamic> json) {
    final m = Map<String, dynamic>.from(json);
    if (m['id'] == null && m['_id'] != null) {
      m['id'] = m['_id'].toString();
    }
    return m;
  }

  // ========== POSTS ==========

  /// Crée un nouveau post (multipart : `contenu`, `type`, fichiers `images` optionnels).
  Future<PostModel> createPost({
    required String contenu,
    required String type,
    List<XFile>? images,
  }) async {
    final formData = FormData();
    formData.fields.add(MapEntry('contenu', contenu));
    formData.fields.add(MapEntry('type', type));

    if (images != null) {
      for (final x in images) {
        if (kIsWeb) {
          final bytes = await x.readAsBytes();
          final name = x.name.isNotEmpty ? x.name : 'image.jpg';
          formData.files.add(
            MapEntry(
              'images',
              MultipartFile.fromBytes(bytes, filename: name),
            ),
          );
        } else {
          formData.files.add(
            MapEntry(
              'images',
              await MultipartFile.fromFile(
                x.path,
                filename: x.name.isNotEmpty ? x.name : null,
              ),
            ),
          );
        }
      }
    }

    final response = await _api.dio.post(
      Endpoints.communityPosts,
      data: formData,
    );
    return PostModel.fromJson(
      _normalizePostJson(response.data as Map<String, dynamic>),
    );
  }

  /// Récupère la liste des posts (avec pagination, filtre optionnel `type`).
  Future<({List<PostModel> posts, int total, int page, int totalPages})> getPosts({
    int page = 1,
    int limit = 20,
    String? type,
  }) async {
    final response = await _api.dio.get(
      Endpoints.communityPosts,
      queryParameters: {
        'page': page,
        'limit': limit,
        if (type != null && type.isNotEmpty) 'type': type,
      },
    );
    final data = response.data as Map<String, dynamic>;
    final postsList = data['data'] as List;
    final posts = postsList
        .map((json) => PostModel.fromJson(
              _normalizePostJson(json as Map<String, dynamic>),
            ))
        .toList();
    return (
      posts: posts,
      total: data['total'] as int? ?? 0,
      page: data['page'] as int? ?? page,
      totalPages: data['totalPages'] as int? ?? 1,
    );
  }

  /// Liste filtrée selon le profil (HANDICAPE + typeHandicap) — smart filter backend.
  Future<
      ({
        List<PostModel> posts,
        int total,
        int page,
        int totalPages,
        List<String> matchedTypes,
      })> getPostsForMe({
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _api.dio.get(
      Endpoints.communityPostsForMe,
      queryParameters: {
        'page': page,
        'limit': limit,
      },
    );
    final data = response.data as Map<String, dynamic>;
    final postsList = data['data'] as List;
    final posts = postsList
        .map((json) => PostModel.fromJson(
              _normalizePostJson(json as Map<String, dynamic>),
            ))
        .toList();
    final rawTypes = data['matchedTypes'];
    final matchedTypes = rawTypes is List
        ? rawTypes.map((e) => e.toString()).toList()
        : <String>[];
    return (
      posts: posts,
      total: data['total'] as int? ?? 0,
      page: data['page'] as int? ?? page,
      totalPages: data['totalPages'] as int? ?? 1,
      matchedTypes: matchedTypes,
    );
  }

  /// Analyse image (LLaVA/Ollama si configuré) + texte pour TTS — handicap visuel.
  Future<ImageVisionDescription> getPostImageAccessibilityDescription({
    required String postId,
    required int imageIndex,
  }) async {
    final key = _imageDescCacheKey(postId: postId, imageIndex: imageIndex);

    final cached = _imageDescCache[key];
    if (cached != null) return cached;

    final inFlight = _imageDescInFlight[key];
    if (inFlight != null) return inFlight;

    final future = () async {
      final response = await _api.dio.get(
        Endpoints.communityPostImageAudio(postId, imageIndex),
        options: _ollamaDioOptions(),
      );
      return ImageVisionDescription.fromJson(
        response.data as Map<String, dynamic>,
      );
    }();

    _imageDescInFlight[key] = future;
    try {
      final result = await future;
      _imageDescCache[key] = result;
      return result;
    } finally {
      // Retirer la requête en cours uniquement si on pointe toujours dessus.
      if (identical(_imageDescInFlight[key], future)) {
        _imageDescInFlight.remove(key);
      }
    }
  }

  /// Récupère un post par son ID.
  Future<PostModel> getPostById(String id) async {
    final response = await _api.dio.get(Endpoints.communityPostById(id));
    return PostModel.fromJson(
      _normalizePostJson(response.data as Map<String, dynamic>),
    );
  }

  // ========== COMMENTS ==========

  /// Ajoute un commentaire à un post.
  Future<CommentModel> createComment({
    required String postId,
    required String contenu,
  }) async {
    final response = await _api.dio.post(
      Endpoints.communityPostComments(postId),
      data: {'contenu': contenu},
    );
    return CommentModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// Récupère les commentaires d'un post.
  Future<List<CommentModel>> getPostComments(String postId) async {
    final response = await _api.dio.get(Endpoints.communityPostComments(postId));
    final list = response.data as List;
    return list
        .map((json) => CommentModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Récupère le résumé flash (accessibilité) des commentaires d'un post.
  Future<FlashSummaryModel> getPostCommentsFlashSummary(String postId) async {
    final response = await _api.dio.get(
      Endpoints.communityPostCommentsFlashSummary(postId),
    );
    return FlashSummaryModel.fromJson(response.data as Map<String, dynamic>);
  }

  // ========== ACCESSIBILITE / IA ==========

  /// Simplifie un texte en FALC (Facile à Lire et à Comprendre).
  Future<SimplifiedTextModel> simplifyText({
    required String text,
    String level = 'facile',
  }) async {
    final cleaned = text.trim();
    if (cleaned.isEmpty) {
      return SimplifiedTextModel(
        simplifiedText: '',
        keyPoints: const [],
        level: level,
        originalWordCount: 0,
        simplifiedWordCount: 0,
      );
    }

    final key = _simplifyCacheKey(text: cleaned, level: level);

    final cached = _simplifyTextCache[key];
    if (cached != null) return cached;

    final inFlight = _simplifyTextInFlight[key];
    if (inFlight != null) return inFlight;

    final future = () async {
      final response = await _api.dio.post(
        Endpoints.communityVisionSimplifyText,
        data: {
          'text': cleaned,
          'level': level,
        },
        options: _ollamaDioOptions(),
      );
      return SimplifiedTextModel.fromJson(
        response.data as Map<String, dynamic>,
      );
    }();

    _simplifyTextInFlight[key] = future;
    try {
      final result = await future;
      _simplifyTextCache[key] = result;
      return result;
    } finally {
      if (identical(_simplifyTextInFlight[key], future)) {
        _simplifyTextInFlight.remove(key);
      }
    }
  }

  // ========== HELP REQUESTS ==========

  /// Crée une nouvelle demande d'aide.
  Future<HelpRequestModel> createHelpRequest({
    required String description,
    required double latitude,
    required double longitude,
  }) async {
    final response = await _api.dio.post(
      Endpoints.communityHelpRequests,
      data: {
        'description': description,
        'latitude': latitude,
        'longitude': longitude,
      },
    );
    return HelpRequestModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// Récupère la liste des demandes d'aide (avec pagination).
  Future<({
    List<HelpRequestModel> requests,
    int total,
    int page,
    int totalPages,
  })> getHelpRequests({
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _api.dio.get(
      Endpoints.communityHelpRequests,
      queryParameters: {
        'page': page,
        'limit': limit,
      },
    );
    final data = response.data as Map<String, dynamic>;
    final requestsList = data['data'] as List;
    final requests = requestsList
        .map((json) => HelpRequestModel.fromJson(json as Map<String, dynamic>))
        .toList();
    return (
      requests: requests,
      total: data['total'] as int? ?? 0,
      page: data['page'] as int? ?? page,
      totalPages: data['totalPages'] as int? ?? 1,
    );
  }

  /// Met à jour le statut d'une demande d'aide.
  Future<HelpRequestModel> updateHelpRequestStatus({
    required String id,
    required String statut,
  }) async {
    final response = await _api.dio.post(
      Endpoints.communityHelpRequestStatut(id),
      data: {'statut': statut},
    );
    return HelpRequestModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// Accepte une demande d'aide (Matching).
  Future<HelpRequestModel> acceptHelpRequest({
    required String id,
  }) async {
    final response = await _api.dio.patch(
      Endpoints.communityHelpRequestAccept(id),
      data: {},
    );
    return HelpRequestModel.fromJson(response.data as Map<String, dynamic>);
  }
}

