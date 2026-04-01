import 'package:equatable/equatable.dart';

/// Alerte SOS.
class SosAlertModel extends Equatable {
  const SosAlertModel({
    required this.id,
    required this.latitude,
    required this.longitude,
    this.statut,
    this.createdAt,
  });

  factory SosAlertModel.fromJson(Map<String, dynamic> json) {
    return SosAlertModel(
      id: json['id'] as String? ?? json['_id'] as String? ?? '',
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      statut: json['statut'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
    );
  }

  final String id;
  final double latitude;
  final double longitude;
  final String? statut;
  final DateTime? createdAt;

  @override
  List<Object?> get props => [id, latitude, longitude];
}
