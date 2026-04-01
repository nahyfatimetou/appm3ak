import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { AccessibilityService } from '../accessibility/accessibility.service';
import type {
  ImageAccessibilityResult,
  SimplifyTextResult,
} from '../accessibility/accessibility.service';

/**
 * Couche IA **Communauté** (équivalent métier de `M3akVisionService` pour le port M3AK) :
 * description d’images (Gemini → Ollama), FALC, résumé commentaires, score urgence.
 * Délègue à {@link AccessibilityService} pour une seule implémentation (pas de duplication).
 *
 * Routes exposées : `GET /community/vision/capabilities`, `POST /community/vision/simplify-text`,
 * et analyse image via `GET .../posts/:id/images/:index/audio-description` → {@link describePostImage}.
 */
@Injectable()
export class CommunityVisionService implements OnModuleInit {
  private readonly logger = new Logger(CommunityVisionService.name);

  constructor(private readonly accessibility: AccessibilityService) {}

  onModuleInit(): void {
    this.logger.log(
      'CommunityVisionService prêt — FALC + analyse photo via AccessibilityService (Gemini / Ollama).',
    );
  }

  /** GET /community/vision/capabilities — flags + ping Ollama + Gemini. */
  async getCapabilities() {
    return this.accessibility.getFeatureFlagsWithOllamaPing();
  }

  /** POST /community/vision/simplify-text — FALC pour le contenu des posts. */
  async simplifyTextFalc(
    text: string,
    level = 'facile',
  ): Promise<SimplifyTextResult> {
    return this.accessibility.simplifyText(text, level);
  }

  /** Analyse image d’un post (Gemini, puis Ollama, puis repli). */
  async describePostImage(params: {
    postContenu: string;
    imageIndex: number;
    imagePath: string;
  }): Promise<ImageAccessibilityResult> {
    return this.accessibility.generateImageAudioDescription(params);
  }

  async flashSummaryFromComments(commentTexts: string[]) {
    return this.accessibility.flashSummaryFromComments(commentTexts);
  }

  async getUrgencyScore(description: string) {
    return this.accessibility.getUrgencyScore(description);
  }
}
