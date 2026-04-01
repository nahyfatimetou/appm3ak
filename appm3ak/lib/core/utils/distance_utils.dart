import 'dart:math';

/// Utilitaires pour calculer les distances entre coordonnées GPS.
class DistanceUtils {
  DistanceUtils._();

  /// Rayon de la Terre en kilomètres.
  static const double earthRadiusKm = 6371.0;

  /// Calcule la distance en kilomètres entre deux points GPS
  /// en utilisant la formule de Haversine.
  static double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusKm * c;
  }

  /// Convertit des degrés en radians.
  static double _degreesToRadians(double degrees) {
    return degrees * (pi / 180);
  }

  /// Formate une distance en kilomètres pour l'affichage.
  /// 
  /// Exemples:
  /// - 0.5 km → "500 m"
  /// - 1.2 km → "1.2 km"
  /// - 15.8 km → "15.8 km"
  static String formatDistance(double distanceKm) {
    if (distanceKm < 1) {
      final meters = (distanceKm * 1000).round();
      return '$meters m';
    } else if (distanceKm < 10) {
      return '${distanceKm.toStringAsFixed(1)} km';
    } else {
      return '${distanceKm.round()} km';
    }
  }
}





