import 'package:equatable/equatable.dart';

import 'user_model.dart';

/// Statut d'une demande d'aide.
enum HelpRequestStatus {
  enAttente,
  enCours,
  terminee,
  annulee;

  String get displayName {
    switch (this) {
      case HelpRequestStatus.enAttente:
        return 'En attente';
      case HelpRequestStatus.enCours:
        return 'En cours';
      case HelpRequestStatus.terminee:
        return 'Terminée';
      case HelpRequestStatus.annulee:
        return 'Annulée';
    }
  }

  static HelpRequestStatus? fromString(String? value) {
    if (value == null) return null;
    final v = value.toUpperCase();
    for (final status in HelpRequestStatus.values) {
      if (status.toApiString() == v) return status;
    }
    return null;
  }

  String toApiString() {
    switch (this) {
      case HelpRequestStatus.enAttente:
        return 'EN_ATTENTE';
      case HelpRequestStatus.enCours:
        return 'EN_COURS';
      case HelpRequestStatus.terminee:
        return 'TERMINEE';
      case HelpRequestStatus.annulee:
        return 'ANNULEE';
    }
  }
}

/// Modèle représentant une demande d'aide.
class HelpRequestModel extends Equatable {
  const HelpRequestModel({
    required this.id,
    required this.userId,
    required this.description,
    required this.latitude,
    required this.longitude,
    this.statut = HelpRequestStatus.enAttente,
    this.urgencyScore,
    this.acceptedBy,
    this.helperName,
    this.user,
    this.createdAt,
    this.updatedAt,
  });

  factory HelpRequestModel.fromJson(Map<String, dynamic> json) {
    // Gérer le cas où userId est un objet (populated) ou un string
    String userIdStr;
    UserModel? user;
    
    if (json['userId'] is Map) {
      user = UserModel.fromJson(json['userId'] as Map<String, dynamic>);
      userIdStr = user.id;
    } else {
      userIdStr = json['userId']?.toString() ?? json['userId']?['_id']?.toString() ?? '';
    }

    return HelpRequestModel(
      id: json['id'] as String? ?? json['_id'] as String? ?? '',
      userId: userIdStr,
      description: json['description'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      statut: HelpRequestStatus.fromString(json['statut']?.toString()) ??
          HelpRequestStatus.enAttente,
      urgencyScore: (json['urgencyScore'] as num?)?.toInt(),
      acceptedBy: (json['acceptedBy'] as String?) ??
          json['acceptedBy']?['_id']?.toString(),
      helperName: json['helperName'] as String?,
      user: user,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
    );
  }

  final String id;
  final String userId;
  final String description;
  final double latitude;
  final double longitude;
  final HelpRequestStatus statut;
  final int? urgencyScore;
  final String? acceptedBy;
  final String? helperName;
  final UserModel? user; // Utilisateur qui a créé la demande (si populated)
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Vérifie si la demande est ouverte (peut être acceptée).
  bool get isOpen => statut == HelpRequestStatus.enAttente;

  /// Nom de l'utilisateur (si disponible).
  String get userName => user?.displayName ?? 'Utilisateur';

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'description': description,
        'latitude': latitude,
        'longitude': longitude,
        'statut': statut.toApiString(),
        'urgencyScore': urgencyScore,
        'acceptedBy': acceptedBy,
        'helperName': helperName,
        'createdAt': createdAt?.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
      };

  HelpRequestModel copyWith({
    String? id,
    String? userId,
    String? description,
    double? latitude,
    double? longitude,
    HelpRequestStatus? statut,
    int? urgencyScore,
    String? acceptedBy,
    String? helperName,
    UserModel? user,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      HelpRequestModel(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        description: description ?? this.description,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        statut: statut ?? this.statut,
        urgencyScore: urgencyScore ?? this.urgencyScore,
        acceptedBy: acceptedBy ?? this.acceptedBy,
        helperName: helperName ?? this.helperName,
        user: user ?? this.user,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  @override
  List<Object?> get props => [
        id,
        userId,
        description,
        latitude,
        longitude,
        statut,
        urgencyScore,
        acceptedBy,
        helperName,
      ];
}

