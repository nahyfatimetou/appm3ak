import {
  Controller,
  Get,
  Post,
  Patch,
  Body,
  Param,
  Query,
  ParseIntPipe,
  UseGuards,
  UseInterceptors,
  UploadedFiles,
} from '@nestjs/common';
import { FilesInterceptor } from '@nestjs/platform-express';
import {
  ApiTags,
  ApiOperation,
  ApiBearerAuth,
  ApiConsumes,
  ApiBody,
} from '@nestjs/swagger';
import { diskStorage } from 'multer';
import { extname } from 'path';
import { randomUUID } from 'crypto';
import { CommunityService } from './community.service';
import { CommunityVisionService } from './community-vision.service';
import { SimplifyTextDto } from '../accessibility/dto/simplify-text.dto';
import { CreatePostDto } from './dto/create-post.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { UserDocument } from '../user/schemas/user.schema';
import { getUploadsRoot, UPLOADS_PUBLIC_PREFIX } from '../common/upload-paths';

const postImageStorage = diskStorage({
  destination: getUploadsRoot(),
  filename: (_, file, cb) => {
    const ext = extname(file.originalname) || '.jpg';
    cb(null, `post-${randomUUID()}${ext}`);
  },
});

@ApiTags('Community')
@Controller('community')
export class CommunityController {
  constructor(
    private readonly communityService: CommunityService,
    private readonly communityVision: CommunityVisionService,
  ) {}

  @Get('vision/capabilities')
  @ApiOperation({
    summary:
      'IA communauté (FALC + analyse photo) : flags Ollama/Gemini, ping — même schéma que GET /accessibility/features',
  })
  async getVisionCapabilities() {
    return this.communityVision.getCapabilities();
  }

  @Post('vision/simplify-text')
  @ApiOperation({
    summary:
      'Simplifier le texte d’un post (FALC) — même comportement que POST /accessibility/simplify-text',
  })
  async simplifyTextCommunity(@Body() body: SimplifyTextDto) {
    return this.communityVision.simplifyTextFalc(body.text, body.level ?? 'facile');
  }

  @Post('posts')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @UseInterceptors(
    FilesInterceptor('images', 10, {
      storage: postImageStorage,
      limits: { fileSize: 5 * 1024 * 1024 },
      fileFilter: (_, file, cb) => {
        const allowed = /jpeg|jpg|png|gif|webp/i;
        const ext = extname(file.originalname);
        if (allowed.test(ext) || allowed.test(file.mimetype)) {
          cb(null, true);
        } else {
          cb(new Error('Type de fichier non autorisé'), false);
        }
      },
    }),
  )
  @ApiConsumes('multipart/form-data')
  @ApiBody({
    schema: {
      type: 'object',
      required: ['contenu', 'type'],
      properties: {
        contenu: { type: 'string' },
        type: { type: 'string' },
        images: {
          type: 'array',
          items: { type: 'string', format: 'binary' },
        },
      },
    },
  })
  @ApiOperation({ summary: 'Créer un post (texte + jusqu’à 10 images optionnelles)' })
  async createPost(
    @CurrentUser() user: UserDocument,
    @Body() body: CreatePostDto,
    @UploadedFiles() files?: Express.Multer.File[],
  ) {
    const paths = (files ?? []).map(
      (f) => `${UPLOADS_PUBLIC_PREFIX}/${f.filename}`,
    );
    return this.communityService.createPost(
      user._id.toString(),
      body.contenu,
      body.type,
      paths,
    );
  }

  @Get('posts')
  @ApiOperation({
    summary: 'Liste des posts (pagination, filtre optionnel par type)',
  })
  async getPosts(
    @Query('page') page?: string,
    @Query('limit') limit?: string,
    @Query('type') type?: string,
  ) {
    return this.communityService.getPosts(
      page ? parseInt(page, 10) : 1,
      limit ? parseInt(limit, 10) : 20,
      type,
    );
  }

  @Get('posts/for-me')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({
    summary:
      'Liste des posts filtrée selon le profil (HANDICAPE + typeHandicap) — smart filter',
  })
  async getPostsForMe(
    @CurrentUser() user: UserDocument,
    @Query('page') page?: string,
    @Query('limit') limit?: string,
  ) {
    return this.communityService.getPostsForViewerProfile(
      page ? parseInt(page, 10) : 1,
      limit ? parseInt(limit, 10) : 20,
      user._id.toString(),
    );
  }

  @Post('posts/:postId/comments')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Commenter un post' })
  async createComment(
    @Param('postId') postId: string,
    @CurrentUser() user: UserDocument,
    @Body() body: { contenu: string },
  ) {
    return this.communityService.createComment(postId, user._id.toString(), body.contenu);
  }

  @Get('posts/:postId/comments')
  @ApiOperation({ summary: 'Commentaires d\'un post' })
  async getComments(@Param('postId') postId: string) {
    return this.communityService.getComments(postId);
  }

  @Get('posts/:postId/comments/flash-summary')
  @ApiOperation({ summary: 'Résumé flash des commentaires (accessibilité)' })
  async getCommentsFlashSummary(@Param('postId') postId: string) {
    return this.communityService.getCommentsFlashSummary(postId);
  }

  @Get('posts/:postId/images/:imageIndex/audio-description')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({
    summary:
      'Description audio IA pour une image (Handicapé, Accompagnant ou Admin — JWT requis)',
  })
  async getPostImageAudioDescription(
    @Param('postId') postId: string,
    @Param('imageIndex', ParseIntPipe) imageIndex: number,
    @CurrentUser() user: UserDocument,
  ) {
    return this.communityService.getPostImageAudioDescription(
      postId,
      imageIndex,
      user._id.toString(),
    );
  }

  @Get('posts/:id')
  @ApiOperation({ summary: 'Détail d\'un post' })
  async getPost(@Param('id') id: string) {
    return this.communityService.getPost(id);
  }

  @Post('help-requests')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Créer une demande d\'aide' })
  async createHelpRequest(
    @CurrentUser() user: UserDocument,
    @Body() body: { description: string; latitude: number; longitude: number },
  ) {
    return this.communityService.createHelpRequest(
      user._id.toString(),
      body.description,
      body.latitude,
      body.longitude,
    );
  }

  @Get('help-requests')
  @ApiOperation({ summary: 'Liste des demandes d\'aide' })
  async getHelpRequests(
    @Query('page') page?: string,
    @Query('limit') limit?: string,
  ) {
    return this.communityService.getHelpRequests(
      page ? parseInt(page, 10) : 1,
      limit ? parseInt(limit, 10) : 20,
    );
  }

  @Post('help-requests/:id/statut')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Mettre à jour le statut d\'une demande' })
  async updateHelpRequestStatut(
    @Param('id') id: string,
    @Body() body: { statut: string },
  ) {
    return this.communityService.updateHelpRequestStatut(id, body.statut);
  }

  @Patch('help-requests/:id/accept')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Accepter une demande d\'aide' })
  async acceptHelpRequest(
    @Param('id') id: string,
    @CurrentUser() user: UserDocument,
  ) {
    const helperName = `${(user.prenom ?? '').toString().trim()} ${(user.nom ?? '').toString().trim()}`.trim();
    return this.communityService.acceptHelpRequest(id, user._id.toString(), helperName);
  }
}
