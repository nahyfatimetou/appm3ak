class M3akCreatePostLaunch {
  const M3akCreatePostLaunch({
    required this.initialContent,
    this.autoOpenCamera = false,
    this.autoPublishAfterCamera = false,
  });

  final String initialContent;
  final bool autoOpenCamera;
  final bool autoPublishAfterCamera;
}

