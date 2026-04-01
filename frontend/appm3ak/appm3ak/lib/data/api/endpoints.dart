/// Endpoints de la nouvelle API Ma3ak.
class Endpoints {
  Endpoints._();

  // ——— Auth ———
  static const String authLogin = '/auth/login';
  static const String authGoogle = '/auth/google';
  static const String authConfigTest = '/auth/config-test';

  // ——— User ———
  static const String userRegister = '/user/register';
  static const String userMe = '/user/me';
  static const String userMePhoto = '/user/me/photo';

  // ——— Dossier médical (HANDICAPE) ———
  static const String medicalRecords = '/medical-records';
  static const String medicalRecordsMe = '/medical-records/me';

  // ——— Alertes SOS ———
  static const String sosAlerts = '/sos-alerts';
  static const String sosAlertsMe = '/sos-alerts/me';
  static String sosAlertsNearby(double lat, double lng) =>
      '/sos-alerts/nearby?latitude=$lat&longitude=$lng';

  // ——— Contacts urgence ———
  static const String emergencyContacts = '/emergency-contacts';
  static const String emergencyContactsMe = '/emergency-contacts/me';
  static String emergencyContactId(String id) => '/emergency-contacts/$id';

  // ——— Transport ———
  static const String transport = '/transport';
  static String transportMatching(double lat, double lng) =>
      '/transport/matching?latitude=$lat&longitude=$lng';
  static String transportById(String id) => '/transport/$id';
  static String transportAccept(String id) => '/transport/$id/accept';
  static String transportCancel(String id) => '/transport/$id/cancel';
  static const String transportMe = '/transport/me';
  static const String transportAvailable = '/transport/available';

  // ——— Évaluations transport ———
  static String transportReviewsByTransportId(String transportId) =>
      '/transport-reviews/transport/$transportId';

  // ——— Lieux accessibles ———
  static const String lieux = '/lieux';
  static String lieuxNearby(double lat, double lng, [double? maxDistance]) {
    final q = 'latitude=$lat&longitude=$lng';
    return maxDistance != null
        ? '/lieux/nearby?$q&maxDistance=$maxDistance'
        : '/lieux/nearby?$q';
  }
  static String lieuById(String id) => '/lieux/$id';

  // ——— Réservations lieux ———
  static const String lieuReservations = '/lieu-reservations';
  static const String lieuReservationsMe = '/lieu-reservations/me';
  static String lieuReservationStatut(String id) =>
      '/lieu-reservations/$id/statut';

  // ——— Communauté ———
  static const String communityPosts = '/community/posts';
  static const String communityPostsForMe = '/community/posts/for-me';
  static String communityPostById(String id) => '/community/posts/$id';
  static String communityPostImageAudio(String postId, int imageIndex) =>
      '/community/posts/$postId/images/$imageIndex/audio-description';
  static String communityPostComments(String postId) =>
      '/community/posts/$postId/comments';
  static String communityPostCommentsFlashSummary(String postId) =>
      '/community/posts/$postId/comments/flash-summary';
  static const String communityHelpRequests = '/community/help-requests';
  static String communityHelpRequestStatut(String id) =>
      '/community/help-requests/$id/statut';
  static String communityHelpRequestAccept(String id) =>
      '/community/help-requests/$id/accept';

  /// IA posts (FALC + ping Ollama/Gemini) — préféré au préfixe `/accessibility/*`.
  static const String communityVisionCapabilities = '/community/vision/capabilities';
  static const String communityVisionSimplifyText = '/community/vision/simplify-text';

  // ——— Accessibilité / IA (alias historiques, même backend) ———
  static const String accessibilityFeatures = '/accessibility/features';
  static const String accessibilitySimplifyText = '/accessibility/simplify-text';

  // ——— Éducation ———
  static const String educationModules = '/education/modules';
  static String educationModuleById(String id) => '/education/modules/$id';
  static const String educationProgress = '/education/progress';

  // ——— Notifications ———
  static const String notifications = '/notifications';
  static String notificationRead(String id) => '/notifications/$id/read';
  static const String notificationsReadAll = '/notifications/read-all';
}
