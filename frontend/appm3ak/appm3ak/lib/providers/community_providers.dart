import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../data/models/comment_model.dart';
import '../data/models/flash_summary_model.dart';
import '../data/models/help_request_model.dart';
import '../data/models/location_model.dart';
import '../data/models/post_model.dart';
import '../data/repositories/community_repository.dart';
import '../data/repositories/location_repository.dart';
import 'api_providers.dart';

// ========== LOCATION PROVIDERS ==========

final locationRepositoryProvider = Provider<LocationRepository>((ref) {
  return LocationRepository(apiClient: ref.watch(apiClientProvider));
});

final locationsProvider = FutureProvider<List<LocationModel>>((ref) async {
  final repository = ref.watch(locationRepositoryProvider);
  return repository.getAllLocations();
});

final locationByIdProvider =
    FutureProvider.family<LocationModel, String>((ref, locationId) async {
  final repository = ref.watch(locationRepositoryProvider);
  return repository.getLocationById(locationId);
});

final nearbyLocationsProvider =
    FutureProvider.family<List<LocationModel>, ({double lat, double lng, double? maxDistance})>(
  (ref, params) async {
    final repository = ref.watch(locationRepositoryProvider);
    return repository.getNearbyLocations(
      latitude: params.lat,
      longitude: params.lng,
      maxDistance: params.maxDistance,
    );
  },
);

final submitLocationProvider = FutureProvider.family<void, ({
  String nom,
  String categorie,
  String adresse,
  String ville,
  double latitude,
  double longitude,
  String? description,
  String? telephone,
  String? horaires,
  List<String>? amenities,
  List<File>? images,
})>((ref, params) async {
  final repository = ref.watch(locationRepositoryProvider);
  await repository.submitLocation(
    nom: params.nom,
    categorie: params.categorie,
    adresse: params.adresse,
    ville: params.ville,
    latitude: params.latitude,
    longitude: params.longitude,
    description: params.description,
    telephone: params.telephone,
    horaires: params.horaires,
    amenities: params.amenities,
    images: params.images,
  );
  ref.invalidate(locationsProvider);
});

// ========== COMMUNITY REPOSITORY PROVIDER ==========

final communityRepositoryProvider = Provider<CommunityRepository>((ref) {
  return CommunityRepository(apiClient: ref.watch(apiClientProvider));
});

/// GET `/community/vision/capabilities` — même couche que [CommunityVisionService] (Gemini, Ollama, FALC).
final communityVisionCapabilitiesProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final repository = ref.watch(communityRepositoryProvider);
  return repository.getCommunityVisionCapabilities();
});

/// @deprecated Utiliser [communityVisionCapabilitiesProvider].
final accessibilityFeaturesProvider = communityVisionCapabilitiesProvider;

// ========== POSTS PROVIDERS ==========

final postsProvider = FutureProvider.family<
    ({List<PostModel> posts, int total, int page, int totalPages}),
    ({int page, int limit})>((ref, params) async {
  final repository = ref.watch(communityRepositoryProvider);
  return repository.getPosts(page: params.page, limit: params.limit);
});

/// Filtre global ou smart (`for-me` backend) — un seul flux pour l’écran liste.
final communityFeedProvider = FutureProvider.family<
    ({
      List<PostModel> posts,
      int total,
      int page,
      int totalPages,
      List<String> matchedTypes,
    }),
    ({
      int page,
      int limit,
      bool smart,
    })>((ref, params) async {
  final repository = ref.watch(communityRepositoryProvider);
  if (params.smart) {
    final r = await repository.getPostsForMe(
      page: params.page,
      limit: params.limit,
    );
    return (
      posts: r.posts,
      total: r.total,
      page: r.page,
      totalPages: r.totalPages,
      matchedTypes: r.matchedTypes,
    );
  }
  final r = await repository.getPosts(
    page: params.page,
    limit: params.limit,
  );
  return (
    posts: r.posts,
    total: r.total,
    page: r.page,
    totalPages: r.totalPages,
    matchedTypes: <String>[],
  );
});

final postByIdProvider =
    FutureProvider.family<PostModel, String>((ref, postId) async {
  final repository = ref.watch(communityRepositoryProvider);
  return repository.getPostById(postId);
});

final createPostProvider = FutureProvider.family<PostModel, ({
  String contenu,
  String type,
  List<XFile>? images,
})>((ref, params) async {
  final repository = ref.watch(communityRepositoryProvider);
  final post = await repository.createPost(
    contenu: params.contenu,
    type: params.type,
    images: params.images,
  );
  ref.invalidate(postsProvider((page: 1, limit: 20)));
  ref.invalidate(communityFeedProvider((
    page: 1,
    limit: 20,
    smart: false,
  )));
  ref.invalidate(communityFeedProvider((
    page: 1,
    limit: 20,
    smart: true,
  )));
  return post;
});

// ========== COMMENTS PROVIDERS ==========

final postCommentsProvider =
    FutureProvider.family<List<CommentModel>, String>((ref, postId) async {
  final repository = ref.watch(communityRepositoryProvider);
  return repository.getPostComments(postId);
});

final postCommentsFlashSummaryProvider =
    FutureProvider.family<FlashSummaryModel, String>((ref, postId) async {
  final repository = ref.watch(communityRepositoryProvider);
  return repository.getPostCommentsFlashSummary(postId);
});

final createCommentProvider = FutureProvider.family<CommentModel, ({
  String postId,
  String contenu,
})>((ref, params) async {
  final repository = ref.watch(communityRepositoryProvider);
  final comment = await repository.createComment(
    postId: params.postId,
    contenu: params.contenu,
  );
  ref.invalidate(postCommentsProvider(params.postId));
  return comment;
});

// ========== HELP REQUESTS PROVIDERS ==========

final helpRequestsProvider = FutureProvider.family<
    ({List<HelpRequestModel> requests, int total, int page, int totalPages}),
    ({int page, int limit})>((ref, params) async {
  final repository = ref.watch(communityRepositoryProvider);
  return repository.getHelpRequests(page: params.page, limit: params.limit);
});

final createHelpRequestProvider = FutureProvider.family<HelpRequestModel, ({
  String description,
  double latitude,
  double longitude,
})>((ref, params) async {
  final repository = ref.watch(communityRepositoryProvider);
  final request = await repository.createHelpRequest(
    description: params.description,
    latitude: params.latitude,
    longitude: params.longitude,
  );
  // Invalider la liste des demandes pour rafraîchir
  ref.invalidate(helpRequestsProvider((page: 1, limit: 20)));
  return request;
});

final updateHelpRequestStatusProvider = FutureProvider.family<HelpRequestModel, ({
  String id,
  String statut,
})>((ref, params) async {
  final repository = ref.watch(communityRepositoryProvider);
  final request = await repository.updateHelpRequestStatus(
    id: params.id,
    statut: params.statut,
  );
  // Invalider la liste des demandes
  ref.invalidate(helpRequestsProvider((page: 1, limit: 20)));
  return request;
});
