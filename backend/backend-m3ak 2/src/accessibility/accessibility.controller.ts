import { Body, Controller, Get, Post } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { AccessibilityService } from './accessibility.service';
import { SimplifyTextDto } from './dto/simplify-text.dto';

@ApiTags('Accessibility')
@Controller('accessibility')
export class AccessibilityController {
  constructor(private readonly accessibilityService: AccessibilityService) {}

  @Get('features')
  @ApiOperation({
    summary:
      'Indique si Ollama est activé, les modèles, et si le serveur Ollama répond (GET /api/tags)',
  })
  async getFeatures() {
    return this.accessibilityService.getFeatureFlagsWithOllamaPing();
  }

  @Post('simplify-text')
  @ApiOperation({
    summary:
      'Simplifier un texte (FALC). Si OLLAMA_ENABLED=true + Ollama local : LLM gratuit ; sinon règles locales.',
  })
  async simplifyText(@Body() body: SimplifyTextDto) {
    return this.accessibilityService.simplifyText(body.text, body.level ?? 'facile');
  }
}
