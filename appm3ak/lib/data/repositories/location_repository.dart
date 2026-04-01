import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

import '../api/api_client.dart';
import '../api/endpoints.dart';
import '../models/location_model.dart';
import '../../core/config/app_config.dart';

/// Repository pour gérer les lieux accessibles.
class LocationRepository {
  LocationRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  /// Récupère tous les lieux approuvés.
  Future<List<LocationModel>> getAllLocations() async {
    try {
      final response = await _api.dio.get(Endpoints.lieux);
      final responseData = response.data;
      
      // Le backend retourne soit une liste directement, soit un objet avec pagination { data, total, ... }
      List<dynamic> data;
      if (responseData is List) {
        data = responseData;
      } else if (responseData is Map && responseData.containsKey('data')) {
        data = responseData['data'] as List;
      } else {
        data = [];
      }
      
      return data
          .map((json) {
            // Adapter les champs du backend au modèle Flutter
            final adaptedJson = _adaptLieuJson(json as Map<String, dynamic>);
            return LocationModel.fromJson(adaptedJson);
          })
          .toList();
    } catch (e) {
      print('❌ [LocationRepository] Erreur getAllLocations: $e');
      rethrow;
    }
  }
  
  /// Adapte les champs du backend au modèle Flutter
  Map<String, dynamic> _adaptLieuJson(Map<String, dynamic> json) {
    final adapted = Map<String, dynamic>.from(json);
    
    // Adapter typeLieu -> categorie
    if (json.containsKey('typeLieu') && !json.containsKey('categorie')) {
      adapted['categorie'] = json['typeLieu'];
    }
    
    // Extraire latitude/longitude depuis location si nécessaire
    if (json.containsKey('location') && json['location'] is Map) {
      final location = json['location'] as Map<String, dynamic>;
      if (location.containsKey('coordinates') && location['coordinates'] is List) {
        final coords = location['coordinates'] as List;
        if (coords.length >= 2) {
          // MongoDB GeoJSON: [longitude, latitude]
          adapted['longitude'] = coords[0];
          adapted['latitude'] = coords[1];
        }
      }
    }
    
    // S'assurer que latitude et longitude existent
    if (!adapted.containsKey('latitude') && json.containsKey('latitude')) {
      adapted['latitude'] = json['latitude'];
    }
    if (!adapted.containsKey('longitude') && json.containsKey('longitude')) {
      adapted['longitude'] = json['longitude'];
    }
    
    // Adapter ville si manquante (peut être dans adresse ou utiliser une valeur par défaut)
    if (!adapted.containsKey('ville') || adapted['ville'] == null) {
      if (adapted.containsKey('adresse') && adapted['adresse'] is String) {
        final adresse = adapted['adresse'] as String;
        // Essayer d'extraire la ville de l'adresse (dernier élément après virgule)
        final parts = adresse.split(',');
        if (parts.length > 1) {
          adapted['ville'] = parts.last.trim();
        } else {
          adapted['ville'] = 'Tunis'; // Valeur par défaut
        }
      } else {
        adapted['ville'] = 'Tunis'; // Valeur par défaut
      }
    }
    
    // Adapter les champs optionnels
    if (!adapted.containsKey('statut')) {
      adapted['statut'] = 'APPROVED'; // Par défaut approuvé pour les lieux existants
    }
    
    return adapted;
  }

  /// Récupère les lieux à proximité.
  /// [maxDistance] est en kilomètres, sera converti en mètres pour le backend.
  Future<List<LocationModel>> getNearbyLocations({
    required double latitude,
    required double longitude,
    double? maxDistance,
  }) async {
    try {
      // Convertir les kilomètres en mètres pour le backend
      // Le backend attend maxDistance en mètres (par défaut 5000 m = 5 km)
      final maxDistanceMeters = maxDistance != null ? (maxDistance * 1000).toInt() : null;
      
      print('🔵 [LocationRepository] getNearbyLocations:');
      print('   Latitude: $latitude');
      print('   Longitude: $longitude');
      print('   MaxDistance (km): $maxDistance');
      print('   MaxDistance (m): $maxDistanceMeters');
      
      final url = Endpoints.lieuxNearby(latitude, longitude, maxDistanceMeters?.toDouble());
      print('   URL: $url');
      
      final response = await _api.dio.get(url);
      final responseData = response.data;
      
      print('✅ [LocationRepository] Réponse reçue:');
      print('   Type: ${responseData.runtimeType}');
      print('   Status: ${response.statusCode}');
      
      // Le backend retourne soit une liste directement, soit un objet avec pagination
      List<dynamic> data;
      if (responseData is List) {
        data = responseData;
        print('   Nombre de lieux trouvés: ${data.length}');
      } else if (responseData is Map && responseData.containsKey('data')) {
        data = responseData['data'] as List;
        print('   Nombre de lieux trouvés (pagination): ${data.length}');
      } else {
        print('   ⚠️ Format de réponse inattendu: $responseData');
        data = [];
      }
      
      final locations = data
          .map((json) {
            try {
              final adaptedJson = _adaptLieuJson(json as Map<String, dynamic>);
              return LocationModel.fromJson(adaptedJson);
            } catch (e) {
              print('⚠️ [LocationRepository] Erreur conversion lieu: $e');
              print('   JSON: $json');
              return null;
            }
          })
          .whereType<LocationModel>()
          .toList();
      
      if (locations.isEmpty && data.isNotEmpty) {
        print('⚠️ [LocationRepository] Aucun lieu converti avec succès (${data.length} lieux reçus)');
      } else {
        print('✅ [LocationRepository] ${locations.length} lieux convertis avec succès');
      }
      return locations;
    } catch (e, stackTrace) {
      print('❌ [LocationRepository] Erreur getNearbyLocations:');
      print('   Erreur: $e');
      print('   Type: ${e.runtimeType}');
      if (e is DioException) {
        print('   Status Code: ${e.response?.statusCode}');
        print('   Response Data: ${e.response?.data}');
        print('   Request URL: ${e.requestOptions.uri}');
      }
      print('   Stack: $stackTrace');
      rethrow;
    }
  }

  /// Récupère un lieu par son ID.
  Future<LocationModel> getLocationById(String id) async {
    try {
      final response = await _api.dio.get(Endpoints.lieuById(id));
      final adaptedJson = _adaptLieuJson(response.data as Map<String, dynamic>);
      return LocationModel.fromJson(adaptedJson);
    } catch (e) {
      print('❌ [LocationRepository] Erreur getLocationById: $e');
      rethrow;
    }
  }

  /// Soumet un nouveau lieu pour modération.
  Future<LocationModel> submitLocation({
    required String nom,
    required String categorie,
    required String adresse,
    required String ville,
    required double latitude,
    required double longitude,
    String? description,
    String? telephone,
    String? horaires,
    List<String>? amenities,
    List<XFile>? images,
  }) async {
    try {
      // Le backend attend typeLieu (pas categorie) et un JSON simple (pas FormData)
      // Adapter categorie -> typeLieu
      // Les catégories Flutter sont: PHARMACY, RESTAURANT, HOSPITAL, SCHOOL, SHOP, PUBLICTRANSPORT, PARK, OTHER
      // Le backend accepte n'importe quelle chaîne, on garde la même valeur
      final typeLieu = categorie; // Déjà en majuscules depuis toApiString()
      
      // Construire l'adresse complète avec la ville
      final adresseComplete = '$adresse, $ville';
      
      // Préparer les données JSON avec des types explicites pour éviter les problèmes de sérialisation
      final data = <String, dynamic>{
        'nom': nom,
        'typeLieu': typeLieu, // Backend attend typeLieu
        'adresse': adresseComplete, // Backend attend seulement adresse (sans ville séparée)
        'latitude': latitude.toDouble(), // S'assurer que c'est un double
        'longitude': longitude.toDouble(), // S'assurer que c'est un double
      };
      
      // Ajouter les champs optionnels
      if (description != null && description.isNotEmpty) {
        data['description'] = description;
      }
      
      // Note: Le backend n'a pas de champs telephone, horaires, amenities dans le DTO
      // On peut les ajouter à la description si nécessaire
      if (telephone != null && telephone.isNotEmpty) {
        final desc = data['description'] as String? ?? '';
        data['description'] = desc.isEmpty 
            ? 'Téléphone: $telephone'
            : '$desc\nTéléphone: $telephone';
      }
      
      if (horaires != null && horaires.isNotEmpty) {
        final desc = data['description'] as String? ?? '';
        data['description'] = desc.isEmpty 
            ? 'Horaires: $horaires'
            : '$desc\nHoraires: $horaires';
      }

      print('🔵 [LocationRepository] Soumission lieu:');
      print('   Nom: $nom');
      print('   Type: $typeLieu');
      print('   Adresse: $adresseComplete');
      print('   Coordonnées: $latitude, $longitude');
      print('   Data: $data');
      print('   URL: ${_api.dio.options.baseUrl}${Endpoints.lieux}');

      final response = await _api.dio.post(
        Endpoints.lieux,
        data: data,
      );
      
      print('✅ [LocationRepository] Lieu créé avec succès');
      
      // Adapter la réponse du backend au modèle Flutter
      final adaptedJson = _adaptLieuJson(response.data as Map<String, dynamic>);
      return LocationModel.fromJson(adaptedJson);
    } on DioException catch (e) {
      print('❌ [LocationRepository] Erreur DioException:');
      print('   Status Code: ${e.response?.statusCode}');
      print('   Response Data: ${e.response?.data}');
      print('   Request URL: ${e.requestOptions.uri}');
      print('   Request Data: ${e.requestOptions.data}');
      print('   Error Type: ${e.type}');
      print('   Error Message: ${e.message}');
      rethrow;
    } catch (e, stackTrace) {
      print('❌ [LocationRepository] Erreur inattendue:');
      print('   Type: ${e.runtimeType}');
      print('   Message: $e');
      print('   Stack: $stackTrace');
      rethrow;
    }
  }

  /// URL complète d'une image de lieu.
  static String imageUrl(String? filename) {
    if (filename == null || filename.isEmpty) return '';
    final base = AppConfig.uploadsBaseUrl.replaceAll(RegExp(r'/$'), '');
    final path = filename.startsWith('/') ? filename : '/uploads/$filename';
    return '$base$path';
  }
}


