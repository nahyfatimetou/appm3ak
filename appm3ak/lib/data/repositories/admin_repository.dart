import 'package:dio/dio.dart';

import '../api/api_client.dart';
import '../api/endpoints.dart';
import '../models/location_model.dart';

/// Repository pour gérer les fonctionnalités admin.
class AdminRepository {
  AdminRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  /// Récupère les lieux en attente de modération.
  Future<List<LocationModel>> getPendingLocations() async {
    try {
      final response = await _api.dio.get(Endpoints.adminLieuxPending);
      final data = response.data;
      
      List<dynamic> locationsList;
      if (data is List) {
        locationsList = data;
      } else if (data is Map && data.containsKey('data')) {
        locationsList = data['data'] as List;
      } else {
        locationsList = [];
      }
      
      return locationsList
          .map((json) => LocationModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('❌ [AdminRepository] Erreur getPendingLocations: $e');
      rethrow;
    }
  }

  /// Récupère tous les lieux avec filtres (admin).
  Future<({
    List<LocationModel> locations,
    int total,
    int page,
    int totalPages,
  })> getAllLocations({
    String? statut,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await _api.dio.get(
        Endpoints.adminLieux(statut, page, limit),
      );
      final data = response.data as Map<String, dynamic>;
      
      final locationsList = (data['data'] as List<dynamic>? ?? [])
          .map((json) => LocationModel.fromJson(json as Map<String, dynamic>))
          .toList();
      
      return (
        locations: locationsList,
        total: data['total'] as int? ?? 0,
        page: data['page'] as int? ?? 1,
        totalPages: data['totalPages'] as int? ?? 1,
      );
    } catch (e) {
      print('❌ [AdminRepository] Erreur getAllLocations: $e');
      rethrow;
    }
  }

  /// Approuve un lieu.
  Future<LocationModel> approveLocation(String locationId) async {
    try {
      final response = await _api.dio.patch(
        Endpoints.adminLieuApprove(locationId),
      );
      return LocationModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      print('❌ [AdminRepository] Erreur approveLocation:');
      print('   Status Code: ${e.response?.statusCode}');
      print('   Response Data: ${e.response?.data}');
      rethrow;
    } catch (e) {
      print('❌ [AdminRepository] Erreur inattendue approveLocation: $e');
      rethrow;
    }
  }

  /// Rejette un lieu.
  Future<LocationModel> rejectLocation(String locationId, {String? reason}) async {
    try {
      final response = await _api.dio.patch(
        Endpoints.adminLieuReject(locationId),
        data: reason != null ? {'reason': reason} : null,
      );
      return LocationModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      print('❌ [AdminRepository] Erreur rejectLocation:');
      print('   Status Code: ${e.response?.statusCode}');
      print('   Response Data: ${e.response?.data}');
      rethrow;
    } catch (e) {
      print('❌ [AdminRepository] Erreur inattendue rejectLocation: $e');
      rethrow;
    }
  }
}


