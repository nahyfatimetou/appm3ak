import 'package:equatable/equatable.dart';

/// Catégories de lieux accessibles.
enum LocationCategory {
  pharmacy,
  restaurant,
  hospital,
  school,
  shop,
  publicTransport,
  park,
  other;

  String get displayName {
    switch (this) {
      case LocationCategory.pharmacy:
        return 'Pharmacie';
      case LocationCategory.restaurant:
        return 'Restaurant';
      case LocationCategory.hospital:
        return 'Hôpital';
      case LocationCategory.school:
        return 'École';
      case LocationCategory.shop:
        return 'Magasin';
      case LocationCategory.publicTransport:
        return 'Transport public';
      case LocationCategory.park:
        return 'Parc';
      case LocationCategory.other:
        return 'Autre';
    }
  }

  static LocationCategory? fromString(String? value) {
    if (value == null) return null;
    final v = value.toUpperCase();
    for (final cat in LocationCategory.values) {
      if (cat.toApiString() == v) return cat;
    }
    return null;
  }

  String toApiString() => name.toUpperCase();
}

/// Statut de modération d'un lieu.
enum LocationStatus {
  pending,
  approved,
  rejected;

  String get displayName {
    switch (this) {
      case LocationStatus.pending:
        return 'En attente';
      case LocationStatus.approved:
        return 'Approuvé';
      case LocationStatus.rejected:
        return 'Rejeté';
    }
  }

  static LocationStatus? fromString(String? value) {
    if (value == null) return null;
    final v = value.toUpperCase();
    for (final status in LocationStatus.values) {
      if (status.toApiString() == v) return status;
    }
    return null;
  }

  String toApiString() => name.toUpperCase();
}

/// Modèle représentant un lieu accessible.
class LocationModel extends Equatable {
  const LocationModel({
    required this.id,
    required this.nom,
    required this.categorie,
    required this.adresse,
    required this.ville,
    required this.latitude,
    required this.longitude,
    this.description,
    this.telephone,
    this.horaires,
    this.images,
    this.amenities,
    this.statut = LocationStatus.pending,
    this.submittedBy,
    this.submittedByName,
    this.createdAt,
    this.updatedAt,
  });

  factory LocationModel.fromJson(Map<String, dynamic> json) {
    return LocationModel(
      id: json['id'] as String? ?? json['_id'] as String? ?? '',
      nom: json['nom'] as String? ?? '',
      categorie: LocationCategory.fromString(json['categorie']?.toString()) ??
          LocationCategory.other,
      adresse: json['adresse'] as String? ?? '',
      ville: json['ville'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      description: json['description'] as String?,
      telephone: json['telephone'] as String?,
      horaires: json['horaires'] as String?,
      images: json['images'] != null
          ? List<String>.from(json['images'] as List)
          : null,
      amenities: json['amenities'] != null
          ? List<String>.from(json['amenities'] as List)
          : null,
      statut: LocationStatus.fromString(json['statut']?.toString()) ??
          LocationStatus.pending,
      submittedBy: json['submittedBy'] as String?,
      submittedByName: json['submittedByName'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
    );
  }

  final String id;
  final String nom;
  final LocationCategory categorie;
  final String adresse;
  final String ville;
  final double latitude;
  final double longitude;
  final String? description;
  final String? telephone;
  final String? horaires;
  final List<String>? images;
  final List<String>? amenities;
  final LocationStatus statut;
  final String? submittedBy;
  final String? submittedByName;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Adresse complète pour l'affichage.
  String get fullAddress => '$adresse, $ville';

  /// Vérifie si le lieu est approuvé.
  bool get isApproved => statut == LocationStatus.approved;

  Map<String, dynamic> toJson() => {
        'id': id,
        'nom': nom,
        'categorie': categorie.toApiString(),
        'adresse': adresse,
        'ville': ville,
        'latitude': latitude,
        'longitude': longitude,
        'description': description,
        'telephone': telephone,
        'horaires': horaires,
        'images': images,
        'amenities': amenities,
        'statut': statut.toApiString(),
        'submittedBy': submittedBy,
        'submittedByName': submittedByName,
        'createdAt': createdAt?.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
      };

  LocationModel copyWith({
    String? id,
    String? nom,
    LocationCategory? categorie,
    String? adresse,
    String? ville,
    double? latitude,
    double? longitude,
    String? description,
    String? telephone,
    String? horaires,
    List<String>? images,
    List<String>? amenities,
    LocationStatus? statut,
    String? submittedBy,
    String? submittedByName,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      LocationModel(
        id: id ?? this.id,
        nom: nom ?? this.nom,
        categorie: categorie ?? this.categorie,
        adresse: adresse ?? this.adresse,
        ville: ville ?? this.ville,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        description: description ?? this.description,
        telephone: telephone ?? this.telephone,
        horaires: horaires ?? this.horaires,
        images: images ?? this.images,
        amenities: amenities ?? this.amenities,
        statut: statut ?? this.statut,
        submittedBy: submittedBy ?? this.submittedBy,
        submittedByName: submittedByName ?? this.submittedByName,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  @override
  List<Object?> get props => [
        id,
        nom,
        categorie,
        adresse,
        ville,
        latitude,
        longitude,
        statut,
      ];
}






