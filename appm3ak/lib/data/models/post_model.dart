import 'package:equatable/equatable.dart';

import 'user_model.dart';

/// Type de post dans la communauté.
enum PostType {
  general,
  handicapMoteur,
  handicapVisuel,
  handicapAuditif,
  handicapCognitif,
  conseil,
  temoignage,
  autre;

  String get displayName {
    switch (this) {
      case PostType.general:
        return 'Général';
      case PostType.handicapMoteur:
        return 'Handicap moteur';
      case PostType.handicapVisuel:
        return 'Handicap visuel';
      case PostType.handicapAuditif:
        return 'Handicap auditif';
      case PostType.handicapCognitif:
        return 'Handicap cognitif';
      case PostType.conseil:
        return 'Conseil';
      case PostType.temoignage:
        return 'Témoignage';
      case PostType.autre:
        return 'Autre';
    }
  }

  static PostType? fromString(String? value) {
    if (value == null) return null;
    final v = value.toLowerCase();
    for (final type in PostType.values) {
      if (type.toApiString() == v) return type;
    }
    return null;
  }

  String toApiString() => name;
}

/// Analyse d'accessibilité par l'IA
class AccessibilityAnalysis {
  const AccessibilityAnalysis({
    this.rampe,
    this.ascenseur,
    this.toilettesAdaptees,
    this.scoreAccessibilite,
    this.description,
  });

  factory AccessibilityAnalysis.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const AccessibilityAnalysis();
    return AccessibilityAnalysis(
      rampe: json['rampe'] as bool?,
      ascenseur: json['ascenseur'] as bool?,
      toilettesAdaptees: json['toilettesAdaptees'] as bool?,
      scoreAccessibilite: (json['scoreAccessibilite'] as num?)?.toInt(),
      description: json['description'] as String?,
    );
  }

  final bool? rampe;
  final bool? ascenseur;
  final bool? toilettesAdaptees;
  final int? scoreAccessibilite;
  final String? description;

  bool get isAccessible => (rampe == true || ascenseur == true) && scoreAccessibilite != null && scoreAccessibilite! > 0;
  bool get hasWarnings => rampe == false && ascenseur == false && toilettesAdaptees == false;
}

/// Modèle représentant un post de la communauté.
class PostModel extends Equatable {
  const PostModel({
    required this.id,
    required this.userId,
    required this.contenu,
    required this.type,
    this.user,
    this.commentsCount,
    this.images,
    this.accessibilityAnalysis,
    this.createdAt,
    this.updatedAt,
  });

  factory PostModel.fromJson(Map<String, dynamic> json) {
    // Gérer le cas où userId est un objet (populated) ou un string
    String userIdStr;
    UserModel? user;
    
    if (json['userId'] is Map) {
      user = UserModel.fromJson(json['userId'] as Map<String, dynamic>);
      userIdStr = user.id;
    } else {
      userIdStr = json['userId']?.toString() ?? json['userId']?['_id']?.toString() ?? '';
    }

    return PostModel(
      id: json['id'] as String? ?? json['_id'] as String? ?? '',
      userId: userIdStr,
      contenu: json['contenu'] as String? ?? '',
      type: PostType.fromString(json['type']?.toString()) ?? PostType.general,
      user: user,
      commentsCount: json['commentsCount'] as int?,
      images: json['images'] != null
          ? List<String>.from(json['images'] as List)
          : null,
      accessibilityAnalysis: json['accessibilityAnalysis'] != null
          ? AccessibilityAnalysis.fromJson(json['accessibilityAnalysis'] as Map<String, dynamic>)
          : null,
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
  final String contenu;
  final PostType type;
  final UserModel? user; // Utilisateur qui a créé le post (si populated)
  final int? commentsCount; // Nombre de commentaires (si calculé)
  final List<String>? images; // URLs des images du post
  final AccessibilityAnalysis? accessibilityAnalysis; // Analyse IA de l'accessibilité
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Nom de l'utilisateur (si disponible).
  String get userName => user?.displayName ?? 'Utilisateur';

  /// Extrait du contenu pour l'affichage (premiers caractères).
  String get preview {
    if (contenu.length <= 100) return contenu;
    return '${contenu.substring(0, 100)}...';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'contenu': contenu,
        'type': type.toApiString(),
        'images': images,
        'accessibilityAnalysis': accessibilityAnalysis != null
            ? {
                'rampe': accessibilityAnalysis!.rampe,
                'ascenseur': accessibilityAnalysis!.ascenseur,
                'toilettesAdaptees': accessibilityAnalysis!.toilettesAdaptees,
                'scoreAccessibilite': accessibilityAnalysis!.scoreAccessibilite,
                'description': accessibilityAnalysis!.description,
              }
            : null,
        'createdAt': createdAt?.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
      };

  PostModel copyWith({
    String? id,
    String? userId,
    String? contenu,
    PostType? type,
    UserModel? user,
    int? commentsCount,
    List<String>? images,
    AccessibilityAnalysis? accessibilityAnalysis,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      PostModel(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        contenu: contenu ?? this.contenu,
        type: type ?? this.type,
        user: user ?? this.user,
        commentsCount: commentsCount ?? this.commentsCount,
        images: images ?? this.images,
        accessibilityAnalysis: accessibilityAnalysis ?? this.accessibilityAnalysis,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  @override
  List<Object?> get props => [id, userId, contenu, type, images, accessibilityAnalysis];
}





