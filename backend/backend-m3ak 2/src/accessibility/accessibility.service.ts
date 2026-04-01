import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { readFile } from 'fs/promises';
import { basename, join } from 'path';
import { existsSync } from 'fs';
import { getUploadsRoot } from '../common/upload-paths';

/** Analyse image (LLaVA / Ollama) + repli texte — handicap visuel */
export type ImageAccessibilityResult = {
  /** Texte pour affichage & TTS (alias historique) */
  audioDescription: string;
  /** Description détaillée (lecture + synthèse vocale « Lire à voix haute ») */
  description: string;
  /** Résumé court pour l’UI (ex. « Obstacle détecté : poubelle ») — optionnel */
  displaySummary?: string | null;
  textDetected: string | null;
  source: 'vision' | 'text_fallback';
};

/** Réponse alignée sur le modèle Flutter SimplifiedTextModel */
export type SimplifyTextResult = {
  simplifiedText: string;
  keyPoints: string[];
  level: string;
  originalWordCount: number;
  simplifiedWordCount: number;
  /** `ollama` si LLM local, `heuristic` si règles sans Ollama */
  source: 'ollama' | 'heuristic';
};

function countWords(s: string): number {
  const t = s.trim();
  if (!t) return 0;
  return t.split(/\s+/).filter(Boolean).length;
}

/**
 * Par défaut : Ollama **activé** si la variable est absente (repli heuristique si injoignable).
 * Pour désactiver explicitement : `OLLAMA_ENABLED=false`.
 */
function isOllamaEnabled(config: ConfigService): boolean {
  const raw = config.get<string>('OLLAMA_ENABLED');
  if (raw == null || String(raw).trim() === '') {
    return true;
  }
  const v = String(raw).trim().toLowerCase();
  if (v === 'false' || v === '0' || v === 'no' || v === 'off') {
    return false;
  }
  return v === 'true' || v === '1' || v === 'yes' || v === 'on';
}

/** Gemini (Google AI) : clé API pour analyse d’image avant repli Ollama. */
function isGeminiConfigured(config: ConfigService): boolean {
  const dis = config.get<string>('GEMINI_ENABLED');
  if (dis != null && String(dis).trim() !== '') {
    const v = String(dis).trim().toLowerCase();
    if (v === 'false' || v === '0' || v === 'no' || v === 'off') {
      return false;
    }
  }
  const k =
    config.get<string>('GEMINI_API_KEY') ??
    config.get<string>('GOOGLE_AI_API_KEY');
  return k != null && String(k).trim() !== '';
}

function guessMimeTypeFromPath(filePath: string): string {
  const lower = filePath.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.gif')) return 'image/gif';
  return 'image/jpeg';
}

/** Extrait le texte d’une réponse JSON Ollama (/api/generate ou /api/chat). */
function extractOllamaText(data: unknown): string | null {
  if (!data || typeof data !== 'object') return null;
  const o = data as Record<string, unknown>;
  if (typeof o.response === 'string' && o.response.trim()) {
    return o.response.trim();
  }
  const msg = o.message as { content?: unknown } | undefined;
  if (msg?.content != null) {
    if (typeof msg.content === 'string' && msg.content.trim()) {
      return msg.content.trim();
    }
    // Certaines versions renvoient `content` en tableau de blocs (multimodal).
    if (Array.isArray(msg.content)) {
      const parts = msg.content
        .map((b) => {
          if (typeof b === 'string') return b;
          if (b && typeof b === 'object' && 'text' in b) {
            const t = (b as { text?: unknown }).text;
            return typeof t === 'string' ? t : '';
          }
          return '';
        })
        .join('')
        .trim();
      if (parts) return parts;
    }
  }
  return null;
}

/** Retire guillemets / échappements parasites en fin de chaîne (repli heuristique). */
function stripDecorativeQuotes(s: string): string {
  let t = s.trim();
  while (
    (t.startsWith('"') && t.endsWith('"')) ||
    (t.startsWith('«') && t.endsWith('»')) ||
    (t.startsWith("'") && t.endsWith("'"))
  ) {
    t = t.slice(1, -1).trim();
  }
  return t.replace(/^\\+"/, '').replace(/\\+"$/, '').trim();
}

/**
 * Prompt FALC « radical » — force un résultat très court (démo / latence CPU).
 */
function buildFalcSystemPrompt(level: string, texteSource: string): string {
  // Prompt radical pour réduire drastiquement la longueur des réponses.
  // (Conserve la variable texteSource, même si le prompt original mentionne originalText.)
  return `Agis comme un traducteur pour enfants.
Interdiction d'utiliser des mots compliqués.
Résume ce texte en 2 phrases de 5 mots maximum.
EXEMPLE : 'Le trottoir est cassé. C'est dangereux.'
TEXTE : ${texteSource}`;
}

/**
 * Simplification : Ollama local (gratuit) si OLLAMA_ENABLED=true, sinon heuristiques.
 */
@Injectable()
export class AccessibilityService implements OnModuleInit {
  private readonly logger = new Logger(AccessibilityService.name);

  constructor(private readonly config: ConfigService) {}

  onModuleInit(): void {
    const f = this.getFeatureFlags();
    if (isGeminiConfigured(this.config)) {
      this.logger.log(
        `Gemini Vision (Google AI) — modèle ${
          this.config.get<string>('GEMINI_VISION_MODEL') ?? 'gemini-2.0-flash'
        } (analyse image prioritaire si clé présente)`,
      );
    }
    if (!f.ollamaEnabled) {
      this.logger.warn(
        `Ollama désactivé (OLLAMA_ENABLED=false ou prod sans variable). ` +
          `Simplification FALC + analyse photo → repli heuristique / texte. ` +
          `En local : OLLAMA_ENABLED=true, terminal « ollama serve », puis « ollama pull ${f.textModel} » et « ollama pull ${f.visionModel} ».`,
      );
    } else {
      this.logger.log(
        `Ollama activé — ${f.ollamaBaseUrl} | texte=${f.textModel} | vision=${f.visionModel}`,
      );
      const vm = (this.config.get<string>('OLLAMA_VISION_MODEL') ?? 'llava').trim();
      if (
        !vm ||
        (/^mistral/i.test(vm) &&
          !/llava|bakllava|moondream|minicpm/i.test(vm.toLowerCase()))
      ) {
        this.logger.warn(
          `OLLAMA_VISION_MODEL="${vm || '(vide)'}" : pour les images il faut un modèle vision (ex. llava). Un modèle texte seul ne « voit » pas les photos.`,
        );
      }
    }
  }

  /** Pour l’app : savoir si l’IA locale (Ollama) est censée être active. */
  getFeatureFlags(): {
    ollamaEnabled: boolean;
    ollamaBaseUrl: string;
    textModel: string;
    visionModel: string;
  } {
    // textModel / visionModel : identiques aux noms retournés par `ollama list` (ex. llava, llava:latest).
    return {
      ollamaEnabled: isOllamaEnabled(this.config),
      ollamaBaseUrl: (
        this.config.get<string>('OLLAMA_BASE_URL') ?? 'http://127.0.0.1:11434'
      ).replace(/\/$/, ''),
      textModel: (this.config.get<string>('OLLAMA_MODEL') ?? 'llama3.2').trim(),
      visionModel: (this.config.get<string>('OLLAMA_VISION_MODEL') ?? 'llava').trim(),
    };
  }

  /**
   * GET /accessibility/features — mêmes flags + test HTTP vers Ollama (`/api/tags`, 5 s max).
   */
  async getFeatureFlagsWithOllamaPing(): Promise<
    ReturnType<AccessibilityService['getFeatureFlags']> & {
      ollamaReachable: boolean;
      ollamaPingMessage?: string;
      geminiConfigured: boolean;
      geminiModel: string;
    }
  > {
    const flags = this.getFeatureFlags();
    const geminiExtra = {
      geminiConfigured: isGeminiConfigured(this.config),
      geminiModel:
        this.config.get<string>('GEMINI_VISION_MODEL') ?? 'gemini-2.0-flash',
    };
    if (!flags.ollamaEnabled) {
      return {
        ...flags,
        ...geminiExtra,
        ollamaReachable: false,
        ollamaPingMessage: 'OLLAMA_ENABLED=false dans .env',
      };
    }
    const tagsUrl = `${flags.ollamaBaseUrl}/api/tags`;
    try {
      const res = await fetch(tagsUrl, {
        signal: AbortSignal.timeout(5000),
      });
      if (res.ok) {
        return { ...flags, ...geminiExtra, ollamaReachable: true };
      }
      return {
        ...flags,
        ...geminiExtra,
        ollamaReachable: false,
        ollamaPingMessage: `Ollama HTTP ${res.status} (${tagsUrl})`,
      };
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      return {
        ...flags,
        ...geminiExtra,
        ollamaReachable: false,
        ollamaPingMessage: `${msg} — lancer « ollama serve » et vérifier OLLAMA_BASE_URL`,
      };
    }
  }

  /**
   * POST /accessibility/simplify-text — tente Ollama puis repli heuristique.
   */
  async simplifyText(text: string, level = 'facile'): Promise<SimplifyTextResult> {
    if (!isOllamaEnabled(this.config)) {
      this.logger.debug(
        `simplify-text → heuristic : OLLAMA_ENABLED≠true (.env) ; si activé → POST ${this.config.get<string>('OLLAMA_BASE_URL') ?? 'http://127.0.0.1:11434'}/api/generate`,
      );
    }
    if (isOllamaEnabled(this.config)) {
      try {
        const ollama = await this.simplifyWithOllama(text, level);
        if (ollama) return ollama;
        this.logger.warn(
          'Ollama simplification sans résultat utile (réponse vide ou HTTP) → heuristic',
        );
      } catch (e) {
        this.logger.warn(`Ollama simplification échouée, repli heuristique: ${e}`);
      }
    }
    return this.simplifyTextHeuristic(text, level);
  }

  /** Modèles texte à essayer si le premier n’est pas installé (ex. seulement llava). */
  private getTextModelCandidates(): string[] {
    const primary = (
      this.config.get<string>('OLLAMA_MODEL') ?? 'llama3.2'
    ).trim();
    const extra = (
      this.config.get<string>('OLLAMA_TEXT_MODEL_FALLBACK') ??
      'llama3.2,llama3,mistral,llava'
    )
      .split(',')
      .map((s) => s.trim())
      .filter(Boolean);
    const merged = [primary, ...extra];
    return [...new Set(merged)];
  }

  private async simplifyWithOllama(
    text: string,
    level: string,
  ): Promise<SimplifyTextResult | null> {
    const baseUrl = (
      this.config.get<string>('OLLAMA_BASE_URL') ?? 'http://127.0.0.1:11434'
    ).replace(/\/$/, '');
    const original = text.replace(/\s+/g, ' ').trim();
    const originalWordCount = countWords(original);
    if (!original) {
      return this.simplifyTextHeuristic(text, level);
    }

    const maxIn = Number(
      this.config.get<string>('OLLAMA_SIMPLIFY_MAX_INPUT_CHARS') ?? '3200',
    );
    const cap = Number.isFinite(maxIn) && maxIn > 500 ? maxIn : 3200;
    let sourceForModel = original;
    if (original.length > cap) {
      sourceForModel =
        original.slice(0, cap) +
        '\n\n[… passage tronqué pour accélérer la réponse — texte long …]';
    }
    const prompt = buildFalcSystemPrompt(level, sourceForModel);

    // Valeurs par défaut plus courtes pour éviter des délais énormes.
    const timeoutMs = Number(
      this.config.get<string>('OLLAMA_TIMEOUT_MS') ?? '20000',
    );
    const numPredict = Number(
      this.config.get<string>('OLLAMA_SIMPLIFY_NUM_PREDICT') ?? '50',
    );
    const np = Number.isFinite(numPredict)
      ? Math.min(Math.max(numPredict, 20), 160)
      : 50;

    const generateUrl = `${baseUrl}/api/generate`;
    const models = this.getTextModelCandidates();
    const t = Number.isFinite(timeoutMs) ? timeoutMs : 120000;

    console.log('Appel Ollama FALC (simplify) lancé…');

    for (const model of models) {
      try {
        const res = await fetch(generateUrl, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            model,
            prompt,
            stream: false,
            options: {
              num_predict: np,
              temperature: 0.25,
              top_k: 20,
              top_p: 0.9,
            },
          }),
          signal: AbortSignal.timeout(t),
        });

        const rawJson = await res.text();
        let data: unknown;
        try {
          data = JSON.parse(rawJson) as unknown;
        } catch {
          data = null;
        }

        if (!res.ok) {
          this.logger.warn(
            `Ollama simplify model=${model} HTTP ${res.status} — ${rawJson.slice(0, 400)}`,
          );
          continue;
        }

        const simplifiedText = extractOllamaText(data);
        if (!simplifiedText) {
          this.logger.warn(`Ollama simplify model=${model} réponse vide`);
          continue;
        }

        const simplifiedWordCount = countWords(simplifiedText);
        const keyPoints = this.extractKeyPointsFromText(simplifiedText, original);

        if (model !== models[0]) {
          this.logger.log(`Simplification FALC via modèle de repli : ${model}`);
        }

        return {
          simplifiedText,
          keyPoints,
          level: level || 'facile',
          originalWordCount,
          simplifiedWordCount,
          source: 'ollama',
        };
      } catch (e) {
        this.logger.warn(`Ollama simplify model=${model} erreur: ${e}`);
      }
    }

    return null;
  }

  private extractKeyPointsFromText(simplified: string, fallback: string): string[] {
    const bySentence = simplified
      .split(/(?<=[.!?])\s+/)
      .map((s) => s.trim())
      .filter((s) => s.length > 0);
    if (bySentence.length) {
      // Ne pas tronquer : on laisse afficher la phrase entière.
      return bySentence.slice(0, 5);
    }
    return [fallback];
  }

  /** Simplification heuristique (sans LLM) */
  private simplifyTextHeuristic(text: string, level = 'facile'): SimplifyTextResult {
    const original = text.replace(/\s+/g, ' ').trim();
    const originalWordCount = countWords(original);

    let simplified = original;

    const replacements: [RegExp, string][] = [
      [/cependant/gi, 'mais'],
      [/néanmoins/gi, 'mais'],
      [/toutefois/gi, 'mais'],
      [/afin de/gi, 'pour'],
      [/dans le but de/gi, 'pour'],
      [/il est important de noter que/gi, 'Note :'],
      [/il convient de/gi, 'il faut'],
      [/permet de/gi, 'permet'],
      [/concernant/gi, 'sur'],
      [/également/gi, 'aussi'],
      [/nécessite/gi, 'a besoin de'],
      [/difficile/gi, 'dur'],
      [/faciliter/gi, 'aider'],
    ];

    for (const [re, rep] of replacements) {
      simplified = simplified.replace(re, rep);
    }

    const sentences = simplified.split(/(?<=[.!?])\s+/).filter(Boolean);
    const shortened: string[] = [];
    for (const sent of sentences) {
      const w = countWords(sent);
      if (w > 22) {
        const words = sent.split(/\s+/);
        const mid = Math.ceil(words.length / 2);
        shortened.push(words.slice(0, mid).join(' ') + '.');
        shortened.push(words.slice(mid).join(' '));
      } else {
        shortened.push(sent);
      }
    }
    simplified = shortened.join(' ').replace(/\s+/g, ' ').trim();

    const keyPointsRaw = sentences
      .slice(0, 5)
      .map((s) => stripDecorativeQuotes(s.trim()))
      .filter((s) => s.length > 0);

    simplified = stripDecorativeQuotes(simplified);
    const simplifiedWordCount = countWords(simplified);

    return {
      simplifiedText: simplified || stripDecorativeQuotes(original),
      // Ne pas tronquer : garder le texte complet.
      keyPoints: keyPointsRaw.length ? keyPointsRaw : [stripDecorativeQuotes(original)],
      level: level || 'facile',
      originalWordCount,
      simplifiedWordCount,
      source: 'heuristic',
    };
  }

  /**
   * Estime l'urgence d'une demande d'aide (1-5).
   * Si OLLAMA_ENABLED=true et Ollama est dispo : LLM local, sinon heuristique locale (zéro frais).
   */
  async getUrgencyScore(description: string): Promise<number> {
    const text = description.replace(/\s+/g, ' ').trim();
    if (!text) return 1;

    if (isOllamaEnabled(this.config)) {
      try {
        const s = await this.getUrgencyScoreWithOllama(text);
        if (s != null) return s;
      } catch (e) {
        this.logger.warn(`Ollama urgency score échoué, repli heuristique: ${e}`);
      }
    }
    return this.getUrgencyScoreHeuristic(text);
  }

  private async getUrgencyScoreWithOllama(description: string): Promise<number | null> {
    const baseUrl = (
      this.config.get<string>('OLLAMA_BASE_URL') ?? 'http://127.0.0.1:11434'
    ).replace(/\/$/, '');
    const model = this.config.get<string>('OLLAMA_MODEL') ?? 'llama3.2';
    const timeoutMs = Number(this.config.get<string>('OLLAMA_TIMEOUT_MS') ?? '120000');

    const prompt = `Sur une échelle de 1 à 5, quelle est l'urgence de cette demande d'aide ?
1 = pas urgent, 5 = urgence immédiate.
Réponds UNIQUEMENT par un nombre entre 1 et 5. Aucune autre phrase.

Demande:
${description}`;

    const res = await fetch(`${baseUrl}/api/generate`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        model,
        prompt,
        stream: false,
        options: { num_predict: 12, temperature: 0.1 },
      }),
      signal: AbortSignal.timeout(Number.isFinite(timeoutMs) ? timeoutMs : 120000),
    });

    if (!res.ok) return null;
    const data = (await res.json()) as { response?: string };
    const raw = (data.response ?? '').toString();
    const match = raw.match(/[1-5]/);
    if (!match) return null;
    const n = Number(match[0]);
    if (!Number.isFinite(n)) return null;
    return Math.max(1, Math.min(5, n));
  }

  private getUrgencyScoreHeuristic(description: string): number {
    const t = description.toLowerCase();

    const urgentKeywords = [
      'urgence',
      'immédiat',
      'immediat',
      'tout de suite',
      'danger',
      'grave',
      'sang',
      'saigne',
      'détresse',
      'detresse',
      'douleur intense',
      'inconscient',
    ];

    const todayKeywords = ["aujourd'hui", 'vite', 'rapidement', 'au plus tard', 'ce soir'];

    if (urgentKeywords.some((k) => t.includes(k))) return 5;
    if (todayKeywords.some((k) => t.includes(k))) return 4;

    return 3;
  }

  /**
   * Résumé flash des commentaires — Ollama si activé, sinon heuristique.
   */
  async flashSummaryFromComments(commentTexts: string[]): Promise<{
    summary: string;
    keyPoints: string[];
    readingTimeSeconds: number;
    wordReduction: number;
  }> {
    if (isOllamaEnabled(this.config)) {
      try {
        const o = await this.flashSummaryWithOllama(commentTexts);
        if (o) return o;
      } catch (e) {
        this.logger.warn(`Ollama flash summary échoué, repli heuristique: ${e}`);
      }
    }
    return Promise.resolve(this.flashSummaryHeuristic(commentTexts));
  }

  private async flashSummaryWithOllama(commentTexts: string[]): Promise<{
    summary: string;
    keyPoints: string[];
    readingTimeSeconds: number;
    wordReduction: number;
  } | null> {
    const full = commentTexts.join(' ').replace(/\s+/g, ' ').trim();
    const originalWords = countWords(full);
    if (!full) {
      return {
        summary: 'Aucun commentaire pour résumer.',
        keyPoints: [],
        readingTimeSeconds: 0,
        wordReduction: 0,
      };
    }

    const baseUrl = (
      this.config.get<string>('OLLAMA_BASE_URL') ?? 'http://127.0.0.1:11434'
    ).replace(/\/$/, '');
    const model =
      this.config.get<string>('OLLAMA_MODEL') ?? 'llama3.2';
    const timeoutMs = Number(
      this.config.get<string>('OLLAMA_TIMEOUT_MS') ?? '120000',
    );

    const maxFlash = 2800;
    const fullCapped =
      full.length > maxFlash ? `${full.slice(0, maxFlash)} […]` : full;

    const prompt = `Résume les commentaires suivants en français en 2 à 4 phrases très courtes, vocabulaire simple. Une seule réponse continue, pas de liste numérotée.

Commentaires:
${fullCapped}

Résumé:`;

    const res = await fetch(`${baseUrl}/api/generate`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        model,
        prompt,
        stream: false,
        options: { num_predict: 220, temperature: 0.35 },
      }),
      signal: AbortSignal.timeout(Number.isFinite(timeoutMs) ? timeoutMs : 120000),
    });

    if (!res.ok) return null;
    const data = (await res.json()) as { response?: string };
    const summary = (data.response ?? '').trim().replace(/\s+/g, ' ');
    if (!summary) return null;

    const summaryWords = countWords(summary);
    const sentences = summary.split(/(?<=[.!?])\s+/).map((s) => s.trim()).filter(Boolean);
    const keyPoints = sentences.slice(0, 5);

    return {
      summary,
      keyPoints: keyPoints.length ? keyPoints : [summary],
      readingTimeSeconds: Math.max(5, Math.round(summaryWords / 3)),
      wordReduction: Math.max(0, originalWords - summaryWords),
    };
  }

  private flashSummaryHeuristic(commentTexts: string[]): {
    summary: string;
    keyPoints: string[];
    readingTimeSeconds: number;
    wordReduction: number;
  } {
    const full = commentTexts.join(' ').replace(/\s+/g, ' ').trim();
    const originalWords = countWords(full);
    if (!full) {
      return {
        summary: 'Aucun commentaire pour résumer.',
        keyPoints: [],
        readingTimeSeconds: 0,
        wordReduction: 0,
      };
    }

    const sentences = full.split(/(?<=[.!?])\s+/).filter((s) => s.trim().length > 0);
    const picked = sentences.slice(0, 4);
    const summary = picked.join(' ');
    const summaryWords = countWords(summary);
    const keyPointsFull = picked.map((s) => s.trim()).filter((s) => s.length > 0);

    return {
      summary,
      keyPoints: keyPointsFull,
      readingTimeSeconds: Math.max(5, Math.round(summaryWords / 3)),
      wordReduction: Math.max(0, originalWords - summaryWords),
    };
  }

  /**
   * Description détaillée pour une image (handicap visuel).
   * Ordre : 1) Gemini (GEMINI_API_KEY) si configuré, 2) Ollama vision (LLaVA), 3) Ollama texte-only, 4) repli statique.
   */
  async generateImageAudioDescription(params: {
    postContenu: string;
    imageIndex: number;
    imagePath: string;
  }): Promise<ImageAccessibilityResult> {
    const { postContenu, imageIndex, imagePath } = params;
    const context = postContenu.replace(/\s+/g, ' ').trim();
    const fileHint = imagePath.split('/').pop() ?? `image_${imageIndex + 1}`;
    const absolutePath = this.resolveUploadedFilePath(imagePath);

    if (!existsSync(absolutePath)) {
      this.logger.warn(
        `Fichier image introuvable pour analyse : ${absolutePath} (stocké : ${imagePath})`,
      );
    } else {
      try {
        const buffer = await readFile(absolutePath);
        const mime = guessMimeTypeFromPath(imagePath);

        if (isGeminiConfigured(this.config)) {
          try {
            const gemini = await this.analyzeImageWithGemini(
              buffer,
              mime,
              context,
              imageIndex,
            );
            if (gemini) {
              return {
                audioDescription: gemini.fullText,
                description: gemini.fullText,
                displaySummary: gemini.displaySummary,
                textDetected: gemini.textDetected,
                source: 'vision',
              };
            }
          } catch (e) {
            this.logger.warn(`Gemini vision échoué, repli Ollama : ${e}`);
          }
        }

        if (isOllamaEnabled(this.config)) {
          try {
            const vision = await this.analyzeImageWithOllamaVision(
              buffer,
              context,
              imageIndex,
            );
            if (vision) {
              return {
                audioDescription: vision.description,
                description: vision.description,
                displaySummary: vision.displaySummary,
                textDetected: vision.textDetected,
                source: 'vision',
              };
            }
          } catch (e) {
            this.logger.warn(
              `Vision Ollama indisponible ou erreur, repli texte: ${e}`,
            );
          }
        }
      } catch (e) {
        this.logger.warn(`Lecture fichier image : ${e}`);
      }
    }

    if (isOllamaEnabled(this.config)) {
      try {
        const text = await this.imageAudioWithOllama(context, imageIndex, fileHint);
        if (text) {
          return {
            audioDescription: text,
            description: text,
            textDetected: null,
            source: 'text_fallback',
          };
        }
      } catch (e) {
        this.logger.warn(`Ollama audio description échouée, repli: ${e}`);
      }
    }

    const snippet = context.length > 400 ? `${context.slice(0, 400)}…` : context;
    const fallback = `Description pour l’image ${imageIndex + 1} du post. Fichier : ${fileHint}. Contexte du message : ${snippet}`;
    return {
      audioDescription: fallback,
      description: fallback,
      displaySummary: null,
      textDetected: null,
      source: 'text_fallback',
    };
  }

  /**
   * Gemini multimodal (Google AI) : description audio + texte détecté + variante FALC du texte.
   */
  private async analyzeImageWithGemini(
    imageBuffer: Buffer,
    mimeType: string,
    postContext: string,
    imageIndex: number,
  ): Promise<{
    fullText: string;
    textDetected: string | null;
    displaySummary: string | null;
  } | null> {
    const apiKey = (
      this.config.get<string>('GEMINI_API_KEY') ??
      this.config.get<string>('GOOGLE_AI_API_KEY') ??
      ''
    ).trim();
    if (!apiKey) return null;

    const modelName =
      this.config.get<string>('GEMINI_VISION_MODEL')?.trim() ||
      'gemini-2.0-flash';
    const timeoutMs = Number(
      this.config.get<string>('GEMINI_VISION_TIMEOUT_MS') ?? '120000',
    );
    const t = Number.isFinite(timeoutMs) ? timeoutMs : 120000;

    const { GoogleGenerativeAI } = await import('@google/generative-ai');
    const genAI = new GoogleGenerativeAI(apiKey);
    const model = genAI.getGenerativeModel({ model: modelName });

    const prompt = `Tu es un assistant d'accessibilité pour personnes déficientes visuelles (module communauté).

Réponds UNIQUEMENT avec un JSON valide (pas de markdown), forme exacte :
{"affichage":"...","description":"...","texteBrut":null ou "chaîne","falc":"..."}

- affichage : une ligne courte pour l’écran (résumé immédiat, ex. « Obstacle détecté : poubelle »).
- description : texte détaillé en français simple (FALC) pour lecture complète et synthèse vocale.
- texteBrut : texte visible sur l’image recopié fidèlement, ou null.
- falc : version FALC du texteBrut ; "" si pas de texte.

Contexte du post (image n°${imageIndex + 1}) :
${postContext || '(aucun)'}`;

    const result = await Promise.race([
      model.generateContent([
        { text: prompt },
        {
          inlineData: {
            mimeType,
            data: imageBuffer.toString('base64'),
          },
        },
      ]),
      new Promise<never>((_, reject) =>
        setTimeout(() => reject(new Error(`Gemini timeout ${t}ms`)), t),
      ),
    ]);

    const raw = result.response.text().trim();
    const parsed = this.parseGeminiVisionJson(raw);
    if (!parsed) {
      this.logger.warn(`Gemini : réponse non JSON, utilisation du texte brut`);
      return {
        fullText: raw,
        textDetected: null,
        displaySummary: null,
      };
    }

    let fullText = parsed.description.trim();
    if (parsed.texteBrut && parsed.falc.trim()) {
      fullText += `\n\n---\nTexte sur l’image (version simple FALC) :\n${parsed.falc.trim()}`;
    } else if (parsed.texteBrut) {
      fullText += `\n\n---\nTexte lu sur l’image :\n${parsed.texteBrut.trim()}`;
    } else if (parsed.falc.trim()) {
      fullText += `\n\n---\nTexte simplifié :\n${parsed.falc.trim()}`;
    }

    const displaySummary =
      parsed.affichage.trim().length > 0 ? parsed.affichage.trim().slice(0, 240) : null;

    return {
      fullText,
      textDetected: parsed.texteBrut,
      displaySummary,
    };
  }

  private parseGeminiVisionJson(raw: string): {
    affichage: string;
    description: string;
    texteBrut: string | null;
    falc: string;
  } | null {
    let t = raw.trim();
    const fence = /^```(?:json)?\s*([\s\S]*?)```$/im.exec(t);
    if (fence) t = fence[1].trim();
    const start = t.indexOf('{');
    const end = t.lastIndexOf('}');
    if (start >= 0 && end > start) {
      t = t.slice(start, end + 1);
    }
    try {
      const o = JSON.parse(t) as Record<string, unknown>;
      const description =
        typeof o.description === 'string' ? o.description : '';
      if (!description.trim()) return null;
      const affichageRaw = o.affichage ?? o.displaySummary;
      const affichage =
        typeof affichageRaw === 'string' ? affichageRaw : '';
      let texteBrut: string | null = null;
      if (o.texteBrut === null || o.texteBrut === undefined) {
        texteBrut = null;
      } else {
        const s = String(o.texteBrut).trim();
        texteBrut = s.length ? s : null;
      }
      const falc = typeof o.falc === 'string' ? o.falc : '';
      return { affichage, description, texteBrut, falc };
    } catch {
      return null;
    }
  }

  /**
   * Reconstruit le chemin disque : `uploads/photo.jpg` ou `uploads/community/photo.jpg`
   * (évite de ne garder que le basename, ce qui cassait les sous-dossiers).
   */
  private resolveUploadedFilePath(storedPath: string): string {
    const root = getUploadsRoot();
    const normalized = storedPath.replace(/\\/g, '/').replace(/^\/+/, '');
    const prefix = 'uploads/';
    if (!normalized.startsWith(prefix)) {
      return join(root, basename(normalized));
    }
    const rel = normalized.slice(prefix.length);
    if (rel.includes('..')) {
      this.logger.warn(`Chemin upload rejeté (..): ${storedPath}`);
      return join(root, basename(rel));
    }
    return join(root, rel);
  }

  private getVisionModelCandidates(): string[] {
    const rawPrimary = (
      this.config.get<string>('OLLAMA_VISION_MODEL') ?? 'llava'
    ).trim();

    // Pour les images : éviter un modèle text-only (ex. mistral) ou une valeur vide.
    const primary =
      !rawPrimary || /^mistral/i.test(rawPrimary)
        ? 'llava' // Doit être écrit exactement comme dans Ollama
        : rawPrimary;
    const extra = (
      this.config.get<string>('OLLAMA_VISION_MODEL_FALLBACK') ??
      'llava,llava:latest,bakllava'
    )
      .split(',')
      .map((s) => s.trim())
      .filter(Boolean);
    return [...new Set([primary, ...extra])].filter(Boolean);
  }

  /**
   * Ollama + modèle vision (LLaVA, etc.) : `/api/generate` avec images, puis secours `/api/chat`.
   */
  private async analyzeImageWithOllamaVision(
    imageBuffer: Buffer,
    postContext: string,
    imageIndex: number,
  ): Promise<{
    description: string;
    textDetected: string | null;
    displaySummary: string | null;
  } | null> {
    const baseUrl = (
      this.config.get<string>('OLLAMA_BASE_URL') ?? 'http://127.0.0.1:11434'
    ).replace(/\/$/, '');
    // L'analyse vision est très coûteuse : timeout et num_predict par défaut
    // réduits pour une expérience plus réactive.
    const timeoutMs = Number(
        this.config.get<string>('OLLAMA_VISION_TIMEOUT_MS') ??
        this.config.get<string>('OLLAMA_TIMEOUT_MS') ??
        '60000',
    );
    const t = Number.isFinite(timeoutMs) ? timeoutMs : 180000;

    const visionPredict = Number(
      this.config.get<string>('OLLAMA_VISION_NUM_PREDICT') ?? '180',
    );
    const vnp = Number.isFinite(visionPredict)
      ? Math.min(Math.max(visionPredict, 100), 400)
      : 180;

    const imageBase64 = imageBuffer.toString('base64');

    const prompt = `Module communauté — analyse d’image pour accessibilité (non-voyants / malvoyants).

Réponds UNIQUEMENT avec un JSON valide UTF-8 (pas de markdown, pas de texte hors JSON), exactement de la forme :
{"affichage":"...","description_audio":"...","texte_lu":"..."}

- affichage : UNE ligne courte pour l’écran (max ~120 caractères), synthèse immédiate. Ex. : "Obstacle détecté : poubelle sur le trottoir"
- description_audio : texte détaillé en français simple (FALC), plusieurs phrases, pour synthèse vocale et lecture complète. Décris obstacles, passage, couleurs, position (gauche/droite), danger éventuel.
- texte_lu : tout texte visible sur l’image recopié fidèlement, ou la chaîne "aucun" si rien à lire.

Contexte du post (image ${imageIndex + 1}) :
${postContext || '(aucun)'}`;

    const models = this.getVisionModelCandidates();
    this.logger.log(
      `Vision Ollama : requête /api/generate avec modèles (ordre) = [${models.join(', ')}] — le 1er disponible dans « ollama list » sera utilisé`,
    );

    console.log('Appel à Llava lancé…');

    for (const model of models) {
      const genUrl = `${baseUrl}/api/generate`;
      try {
        const res = await fetch(genUrl, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            model:
              !model || /^mistral/i.test(model.trim())
                ? 'llava' // Doit être écrit exactement comme dans Ollama
                : model,
            prompt,
            images: [imageBase64],
            stream: false,
            options: {
              num_predict: vnp,
              temperature: 0.2,
            },
          }),
          signal: AbortSignal.timeout(t),
        });

        const rawBody = await res.text();
        let data: unknown;
        try {
          data = JSON.parse(rawBody) as unknown;
        } catch {
          data = null;
        }

        if (res.ok) {
          const raw = extractOllamaText(data)?.trim() ?? '';
          if (raw) {
            if (model !== models[0]) {
              this.logger.log(`Vision Ollama via modèle de repli : ${model}`);
            }
            return this.parseOllamaVisionResponse(raw);
          }
        } else {
          this.logger.warn(
            `Ollama vision generate model=${model} HTTP ${res.status} — ${rawBody.slice(0, 400)}`,
          );
        }

        const chatTry = await this.analyzeImageWithOllamaVisionChat(
          baseUrl,
          model,
          prompt,
          imageBase64,
          t,
        );
        if (chatTry) {
          this.logger.log(`Vision Ollama via /api/chat (secours) model=${model}`);
          return chatTry;
        }
      } catch (e) {
        this.logger.warn(`Ollama vision model=${model} erreur: ${e}`);
      }
    }

    return null;
  }

  /** Secours si `/api/generate` ne renvoie pas de texte (certaines versions Ollama). */
  private async analyzeImageWithOllamaVisionChat(
    baseUrl: string,
    model: string,
    prompt: string,
    imageBase64: string,
    timeoutMs: number,
  ): Promise<{
    description: string;
    textDetected: string | null;
    displaySummary: string | null;
  } | null> {
    const chatUrl = `${baseUrl}/api/chat`;
    try {
      const res = await fetch(chatUrl, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          model:
            !model || /^mistral/i.test(model.trim())
              ? 'llava' // Doit être écrit exactement comme dans Ollama
              : model,
          messages: [
            {
              role: 'user',
              content: prompt,
              images: [imageBase64],
            },
          ],
          stream: false,
        }),
        signal: AbortSignal.timeout(timeoutMs),
      });
      const rawBody = await res.text();
      let data: unknown;
      try {
        data = JSON.parse(rawBody) as unknown;
      } catch {
        return null;
      }
      if (!res.ok) {
        this.logger.warn(
          `Ollama vision chat model=${model} HTTP ${res.status} — ${rawBody.slice(0, 400)}`,
        );
        return null;
      }
      const raw = extractOllamaText(data)?.trim() ?? '';
      if (!raw) return null;
      return this.parseOllamaVisionResponse(raw);
    } catch (e) {
      this.logger.warn(`Ollama vision chat: ${e}`);
      return null;
    }
  }

  /**
   * JSON prioritaire (affichage + description_audio + texte_lu), sinon repli ancien format TEXTE_LISIBLE.
   */
  private parseOllamaVisionResponse(raw: string): {
    description: string;
    textDetected: string | null;
    displaySummary: string | null;
  } {
    const trimmed = raw.trim();
    let t = trimmed;
    const fence = /^```(?:json)?\s*([\s\S]*?)```$/im.exec(t);
    if (fence) t = fence[1].trim();
    const start = t.indexOf('{');
    const end = t.lastIndexOf('}');
    if (start >= 0 && end > start) {
      try {
        const o = JSON.parse(t.slice(start, end + 1)) as Record<string, unknown>;
        const aff =
          o.affichage ?? o.affichage_court ?? o.displaySummary ?? o.display;
        const audio =
          o.description_audio ??
          o.description_detaillee ??
          o.descriptionAudio ??
          o.description;
        const lu = o.texte_lu ?? o.texteLu ?? o.texte_brut;
        if (typeof audio === 'string' && audio.trim()) {
          const displaySummary =
            typeof aff === 'string' && aff.trim()
              ? aff.trim().slice(0, 240)
              : null;
          let textDetected: string | null = null;
          if (lu !== null && lu !== undefined) {
            const s = String(lu).trim();
            const low = s.toLowerCase();
            if (s && low !== 'aucun' && low !== 'rien') textDetected = s;
          }
          return {
            description: audio.trim(),
            textDetected,
            displaySummary,
          };
        }
      } catch {
        /* repli legacy */
      }
    }
    const legacy = this.parseVisionOutputLegacy(trimmed);
    return { ...legacy, displaySummary: null };
  }

  private parseVisionOutputLegacy(raw: string): {
    description: string;
    textDetected: string | null;
  } {
    const re = /\nTEXTE_LISIBLE:\s*(.+)$/ims;
    const m = raw.match(re);
    if (!m) {
      return { description: raw.trim(), textDetected: null };
    }
    const textDetectedRaw = m[1].trim();
    const description = raw.replace(re, '').trim();
    const lower = textDetectedRaw.toLowerCase();
    const textDetected =
      lower === 'aucun' || lower === 'rien' || textDetectedRaw === ''
        ? null
        : textDetectedRaw;
    return { description, textDetected };
  }

  private async imageAudioWithOllama(
    postContenu: string,
    imageIndex: number,
    fileHint: string,
  ): Promise<string | null> {
    const baseUrl = (
      this.config.get<string>('OLLAMA_BASE_URL') ?? 'http://127.0.0.1:11434'
    ).replace(/\/$/, '');
    const model = this.config.get<string>('OLLAMA_MODEL') ?? 'llama3.2';
    const timeoutMs = Number(this.config.get<string>('OLLAMA_TIMEOUT_MS') ?? '20000');

    const prompt = `Tu rédiges une description audio pour une personne aveugle ou malvoyante.
L’image ${imageIndex + 1} accompagne un post sur un réseau social d’accessibilité.
Tu n’as pas vu l’image : déduis un contenu plausible et utile à partir du texte du post et du nom de fichier.
Réponds UNIQUEMENT en français, 3 à 6 phrases courtes, vocabulaire simple, ton neutre et bienveillant.
Ne dis pas que tu n’as pas vu l’image ; décris ce que le post suggère visuellement (scène, ambiance, éléments probables).

Nom fichier : ${fileHint}
Texte du post :
${postContenu || '(vide)'}`;

    const res = await fetch(`${baseUrl}/api/generate`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        model,
        prompt,
        stream: false,
        options: { num_predict: 90, temperature: 0.3 },
      }),
      signal: AbortSignal.timeout(Number.isFinite(timeoutMs) ? timeoutMs : 120000),
    });

    if (!res.ok) return null;
    const data = (await res.json()) as { response?: string };
    const out = (data.response ?? '').trim().replace(/\s+/g, ' ');
    return out || null;
  }
}
