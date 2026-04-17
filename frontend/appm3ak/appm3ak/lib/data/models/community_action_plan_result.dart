import 'create_help_request_input.dart';
import 'create_post_input.dart';

class CommunityActionPlanResult {
  const CommunityActionPlanResult({
    required this.action,
    this.postNature,
    this.targetAudience,
    this.postInputMode,
    this.locationSharingMode,
    this.dangerLevel,
    this.legacyType,
    this.generatedContent,
    this.helpType,
    this.requesterProfile,
    this.helpInputMode,
    this.presetMessageKey,
    this.generatedDescription,
    required this.needsAudioGuidance,
    required this.needsVisualSupport,
    required this.needsPhysicalAssistance,
    required this.needsSimpleLanguage,
    required this.isForAnotherPerson,
    this.predictedPriority,
    this.recommendedRoute,
    this.routeReason,
    this.confidence,
  });

  final String action;

  final String? postNature;
  final String? targetAudience;
  final String? postInputMode;
  final String? locationSharingMode;
  final String? dangerLevel;
  final String? legacyType;
  final String? generatedContent;

  final String? helpType;
  final String? requesterProfile;
  final String? helpInputMode;
  final String? presetMessageKey;
  final String? generatedDescription;

  final bool needsAudioGuidance;
  final bool needsVisualSupport;
  final bool needsPhysicalAssistance;
  final bool needsSimpleLanguage;
  final bool isForAnotherPerson;

  final String? predictedPriority;
  final String? recommendedRoute;
  final String? routeReason;
  final double? confidence;

  factory CommunityActionPlanResult.fromJson(Map<String, dynamic> json) {
    return CommunityActionPlanResult(
      action: json['action'] as String? ?? 'create_post',
      postNature: json['postNature'] as String?,
      targetAudience: json['targetAudience'] as String?,
      postInputMode: json['postInputMode'] as String?,
      locationSharingMode: json['locationSharingMode'] as String?,
      dangerLevel: json['dangerLevel'] as String?,
      legacyType: json['legacyType'] as String?,
      generatedContent: json['generatedContent'] as String?,
      helpType: json['helpType'] as String?,
      requesterProfile: json['requesterProfile'] as String?,
      helpInputMode: json['helpInputMode'] as String?,
      presetMessageKey: json['presetMessageKey'] as String?,
      generatedDescription: json['generatedDescription'] as String?,
      needsAudioGuidance: json['needsAudioGuidance'] == true,
      needsVisualSupport: json['needsVisualSupport'] == true,
      needsPhysicalAssistance: json['needsPhysicalAssistance'] == true,
      needsSimpleLanguage: json['needsSimpleLanguage'] == true,
      isForAnotherPerson: json['isForAnotherPerson'] == true,
      predictedPriority: json['predictedPriority'] as String?,
      recommendedRoute: json['recommendedRoute'] as String?,
      routeReason: json['routeReason'] as String?,
      confidence: (json['confidence'] as num?)?.toDouble(),
    );
  }

  bool shouldAutoNavigate({double minConfidence = 0.85}) {
    final route = recommendedRoute?.trim();
    final conf = confidence;
    return route != null && route.isNotEmpty && conf != null && conf >= minConfidence;
  }

  CreatePostInput toCreatePostInput() {
    return CreatePostInput(
      contenu: generatedContent ?? '',
      type: legacyType ?? 'general',
      postNature: postNature,
      targetAudience: targetAudience,
      inputMode: postInputMode,
      isForAnotherPerson: isForAnotherPerson,
      needsAudioGuidance: needsAudioGuidance,
      needsVisualSupport: needsVisualSupport,
      needsPhysicalAssistance: needsPhysicalAssistance,
      needsSimpleLanguage: needsSimpleLanguage,
      locationSharingMode: locationSharingMode,
      dangerLevel: dangerLevel,
    );
  }

  CreateHelpRequestInput toCreateHelpRequestInput({
    required double latitude,
    required double longitude,
  }) {
    return CreateHelpRequestInput(
      description: generatedDescription,
      latitude: latitude,
      longitude: longitude,
      helpType: helpType,
      inputMode: helpInputMode,
      requesterProfile: requesterProfile,
      needsAudioGuidance: needsAudioGuidance,
      needsVisualSupport: needsVisualSupport,
      needsPhysicalAssistance: needsPhysicalAssistance,
      needsSimpleLanguage: needsSimpleLanguage,
      isForAnotherPerson: isForAnotherPerson,
      presetMessageKey: presetMessageKey,
    );
  }
}

