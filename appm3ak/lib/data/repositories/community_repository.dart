import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/utils/web_file_helper.dart';
import '../api/api_client.dart';
import '../api/endpoints.dart';
import '../models/comment_model.dart';
import '../models/help_request_model.dart';
import '../models/post_model.dart';
import '../models/simplified_text_model.dart';
import '../models/accessibility_models.dart';

/// Repository pour gérer les posts et demandes d'aide de la communauté.
class CommunityRepository {
  CommunityRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  // ========== POSTS ==========

  /// Crée un nouveau post.
  Future<PostModel> createPost({
    required String contenu,
    required String type,
    List<XFile>? images,
  }) async {
    try {
      // Si des images sont fournies, utiliser FormData
      if (images != null && images.isNotEmpty) {
        final formData = FormData();
        formData.fields.addAll([
          MapEntry('contenu', contenu),
          MapEntry('type', type),
        ]);
        
        // Ajouter les images
        for (var image in images) {
          try {
            print('   📎 Lecture de l\'image: ${image.name} (path: ${image.path})');
            
            // Utiliser le helper qui gère automatiquement le web
            Uint8List bytes;
            try {
              bytes = await readXFileBytes(image);
            } catch (e) {
              print('   ❌ Erreur lors de la lecture de l\'image: $e');
              print('   Type d\'erreur: ${e.runtimeType}');
              // Si c'est une erreur de namespace, donner un message clair
              if (e.toString().contains('_Namespace') || e.toString().contains('Unsupported operation')) {
                throw Exception(
                  'Erreur de compatibilité web. '
                  'Veuillez réessayer ou utiliser l\'application mobile. '
                  'Si le problème persiste, créez un post sans image d\'abord.'
                );
              }
              rethrow;
            }
            
            final filename = image.name.isNotEmpty 
                ? image.name 
                : (image.path.split('/').last.split('\\').last.isNotEmpty
                    ? image.path.split('/').last.split('\\').last
                    : 'image.jpg');
            print('   ✅ Image lue: $filename (${bytes.length} bytes)');
            formData.files.add(
              MapEntry(
                'images',
                MultipartFile.fromBytes(
                  bytes,
                  filename: filename,
                ),
              ),
            );
          } catch (e, stackTrace) {
            print('   ❌ Erreur lors de l\'ajout de l\'image ${image.name}: $e');
            print('   Stack trace: $stackTrace');
            // Re-lancer l'erreur pour que l'utilisateur soit informé
            rethrow;
          }
        }
        
        if (formData.files.isEmpty) {
          print('   ⚠️ Aucune image valide à envoyer');
        }

        print('📤 [CommunityRepository] Envoi du post avec ${formData.files.length} image(s)');
        print('   Contenu: ${contenu.substring(0, contenu.length > 50 ? 50 : contenu.length)}...');
        print('   Type: $type');

        try {
          // Ne pas définir Content-Type - Dio le fait automatiquement avec la boundary pour FormData
          final response = await _api.dio.post(
            Endpoints.communityPosts,
            data: formData,
            options: Options(
              validateStatus: (status) => status != null && status < 500,
              // Supprimer explicitement Content-Type pour laisser Dio le gérer
              headers: {
                'Content-Type': null, // Dio ajoutera automatiquement multipart/form-data avec boundary
              },
            ),
          );
          
          if (response.statusCode != null && response.statusCode! >= 400) {
            print('❌ [CommunityRepository] Erreur HTTP: ${response.statusCode}');
            print('   Réponse: ${response.data}');
            throw Exception('Erreur lors de la publication: ${response.statusCode} - ${response.data}');
          }
          
        print('✅ [CommunityRepository] Post créé avec succès');
        print('   Status: ${response.statusCode}');
        return PostModel.fromJson(response.data as Map<String, dynamic>);
        } catch (e) {
          print('❌ [CommunityRepository] Erreur lors de l\'envoi:');
          print('   Type: ${e.runtimeType}');
          print('   Message: $e');
          if (e is DioException) {
            print('   Status Code: ${e.response?.statusCode}');
            print('   Response Data: ${e.response?.data}');
            print('   Request URL: ${e.requestOptions.uri}');
          }
          rethrow;
        }
      } else {
        // Sinon, utiliser JSON simple
        print('📤 [CommunityRepository] Envoi du post sans images');
        final response = await _api.dio.post(
          Endpoints.communityPosts,
          data: {
            'contenu': contenu,
            'type': type,
          },
          options: Options(
            headers: {
              'Content-Type': 'application/json', // JSON simple nécessite Content-Type
            },
          ),
        );
        print('✅ [CommunityRepository] Post créé avec succès');
        return PostModel.fromJson(response.data as Map<String, dynamic>);
      }
    } catch (e) {
      print('❌ [CommunityRepository] Erreur lors de la création du post:');
      print('   Type: ${e.runtimeType}');
      print('   Message: $e');
      if (e is DioException) {
        print('   Status Code: ${e.response?.statusCode}');
        print('   Response Data: ${e.response?.data}');
        print('   Request URL: ${e.requestOptions.uri}');
      }
      rethrow;
    }
  }

  /// Simplifie un texte selon la méthode FALC (Assistant d'Accessibilité Cognitive).
  Future<SimplifiedTextModel> simplifyText({
    required String text,
    String level = 'facile',
  }) async {
    try {
      final response = await _api.dio.post(
        Endpoints.simplifyText,
        data: {
          'text': text,
          'level': level,
        },
      );
      return SimplifiedTextModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      print('❌ [CommunityRepository] Erreur lors de la simplification:');
      print('   Status Code: ${e.response?.statusCode}');
      print('   Response Data: ${e.response?.data}');
      rethrow;
    }
  }

  /// Génère un résumé flash des commentaires (handicap moteur)
  Future<FlashSummaryModel> getCommentsFlashSummary(String postId) async {
    try {
      final response = await _api.dio.get(
        Endpoints.communityPostCommentsFlashSummary(postId),
      );
      return FlashSummaryModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      print('❌ [CommunityRepository] Erreur lors du résumé flash:');
      print('   Status Code: ${e.response?.statusCode}');
      print('   Response Data: ${e.response?.data}');
      rethrow;
    } catch (e) {
      print('❌ [CommunityRepository] Erreur inattendue lors du résumé flash: $e');
      rethrow;
    }
  }

  /// Génère une vidéo LSF (Langue des Signes Française)
  Future<LSFVideoModel> generateLSFVideo(String text) async {
    try {
      final response = await _api.dio.post(
        Endpoints.lsfVideo,
        data: {'text': text},
      );
      return LSFVideoModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      print('❌ [CommunityRepository] Erreur lors de la génération LSF:');
      print('   Status Code: ${e.response?.statusCode}');
      print('   Response Data: ${e.response?.data}');
      rethrow;
    } catch (e) {
      print('❌ [CommunityRepository] Erreur inattendue lors de la génération LSF: $e');
      rethrow;
    }
  }

  /// Analyse une image pour un post (Compagnon de Route).
  Future<Map<String, dynamic>> analyzePostImage({
    required String postId,
    required XFile image,
  }) async {
    final formData = FormData();
    // Pour Flutter Web, utiliser readAsBytes
    final bytes = await image.readAsBytes();
    final filename = image.name.isNotEmpty 
        ? image.name 
        : (image.path.split('/').last.split('\\').last.isNotEmpty
            ? image.path.split('/').last.split('\\').last
            : 'image.jpg');
    formData.files.add(
      MapEntry(
        'image',
        MultipartFile.fromBytes(
          bytes,
          filename: filename,
        ),
      ),
    );

    final response = await _api.dio.post(
      Endpoints.communityPostAnalyzeImage(postId),
      data: formData,
      options: Options(
        headers: {'Content-Type': 'multipart/form-data'},
      ),
    );
    return response.data as Map<String, dynamic>;
  }

  /// Récupère la liste des posts (avec pagination).
  Future<({List<PostModel> posts, int total, int page, int totalPages})> getPosts({
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _api.dio.get(
      Endpoints.communityPosts,
      queryParameters: {
        'page': page,
        'limit': limit,
      },
    );
    final data = response.data as Map<String, dynamic>;
    final postsList = data['data'] as List;
    final posts = postsList
        .map((json) => PostModel.fromJson(json as Map<String, dynamic>))
        .toList();
    return (
      posts: posts,
      total: data['total'] as int? ?? 0,
      page: data['page'] as int? ?? page,
      totalPages: data['totalPages'] as int? ?? 1,
    );
  }

  /// Récupère un post par son ID.
  Future<PostModel> getPostById(String id) async {
    final response = await _api.dio.get(Endpoints.communityPostById(id));
    return PostModel.fromJson(response.data as Map<String, dynamic>);
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
}





