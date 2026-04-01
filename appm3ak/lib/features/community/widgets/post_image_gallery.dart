import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../data/models/post_model.dart';
import 'ai_badge.dart';

/// Galerie d'images pour un post avec badges IA.
class PostImageGallery extends StatelessWidget {
  const PostImageGallery({
    super.key,
    required this.images,
    this.accessibilityAnalysis,
    this.onImageTap,
  });

  final List<String> images;
  final AccessibilityAnalysis? accessibilityAnalysis;
  final void Function(int index)? onImageTap;

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);

    // Construire l'URL complète de l'image
    String imageUrl(String path) {
      if (path.startsWith('http')) return path;
      final base = AppConfig.uploadsBaseUrl.replaceAll(RegExp(r'/$'), '');
      return path.startsWith('/') ? '$base$path' : '$base/$path';
    }

    if (images.length == 1) {
      // Une seule image : affichage plein écran avec badge
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: GestureDetector(
                onTap: () => onImageTap?.call(0),
                child: Image.network(
                  imageUrl(images[0]),
                  width: double.infinity,
                  height: 250,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: 250,
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 250,
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: Icon(
                        Icons.broken_image,
                        size: 48,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    );
                  },
                ),
              ),
            ),
            // Badge IA si disponible
            if (accessibilityAnalysis != null)
              Positioned(
                bottom: 8,
                left: 8,
                right: 8,
                child: AIBadge(analysis: accessibilityAnalysis!, compact: false),
              ),
          ],
        ),
      );
    }

    // Plusieurs images : grille
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.0,
            ),
            itemCount: images.length > 4 ? 4 : images.length,
            itemBuilder: (context, index) {
              final isLast = index == 3 && images.length > 4;
              return Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: GestureDetector(
                      onTap: () => onImageTap?.call(index),
                      child: Image.network(
                        imageUrl(images[index]),
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            color: theme.colorScheme.surfaceContainerHighest,
                            child: Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: theme.colorScheme.surfaceContainerHighest,
                            child: Icon(
                              Icons.broken_image,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  if (isLast)
                    Container(
                      color: Colors.black54,
                      child: Center(
                        child: Text(
                          '+${images.length - 4}',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  // Badge IA compact sur la première image
                  if (index == 0 && accessibilityAnalysis != null)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: AIBadge(analysis: accessibilityAnalysis!, compact: true),
                    ),
                ],
              );
            },
          ),
          // Badge IA complet sous la grille si disponible
          if (accessibilityAnalysis != null && images.length <= 4)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: AIBadge(analysis: accessibilityAnalysis!, compact: false),
            ),
        ],
      ),
    );
  }
}

