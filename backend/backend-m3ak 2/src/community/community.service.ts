import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { CommunityVisionService } from './community-vision.service';
import { UserService } from '../user/user.service';
import { Post, PostDocument } from './schemas/post.schema';
import { Comment, CommentDocument } from './schemas/comment.schema';
import { HelpRequest, HelpRequestDocument } from './schemas/help-request.schema';
import { postTypesForHandicapProfile } from './enums/type-handicap.enum';
import { Role } from '../user/enums/role.enum';

const TRUST_POINTS_COMMENT = 2;
const TRUST_POINTS_ACCEPT_HELP = 10;

@Injectable()
export class CommunityService {
  constructor(
    @InjectModel(Post.name) private postModel: Model<PostDocument>,
    @InjectModel(Comment.name) private commentModel: Model<CommentDocument>,
    @InjectModel(HelpRequest.name) private helpRequestModel: Model<HelpRequestDocument>,
    private readonly communityVision: CommunityVisionService,
    private readonly userService: UserService,
    private readonly config: ConfigService,
  ) {}

  // Posts
  async createPost(userId: string, contenu: string, type: string, imagePaths: string[] = []) {
    return this.postModel.create({
      userId: new Types.ObjectId(userId),
      contenu,
      type,
      images: imagePaths,
    });
  }

  async getPosts(page = 1, limit = 20, type?: string) {
    const skip = (page - 1) * limit;
    const filter: Record<string, unknown> = {};
    if (type?.trim()) {
      filter.type = type.trim();
    }
    const [data, total] = await Promise.all([
      this.postModel
        .find(filter)
        .populate('userId', '-password')
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(limit)
        .exec(),
      this.postModel.countDocuments(filter).exec(),
    ]);
    return { data, total, page, limit, totalPages: Math.ceil(total / limit) };
  }

  /**
   * Filtre intelligent selon `role` + `typeHandicap` (Enums côté API, alignés Flutter).
   */
  async getPostsForViewerProfile(page = 1, limit = 20, viewerUserId: string) {
    const user = await this.userService.findOne(viewerUserId);
    const types = postTypesForHandicapProfile(
      user.role as string,
      user.typeHandicap as string | null,
    );
    const skip = (page - 1) * limit;
    const filter: Record<string, unknown> = {};
    if (types.length > 0) {
      filter.type = { $in: types };
    }
    const [data, total] = await Promise.all([
      this.postModel
        .find(filter)
        .populate('userId', '-password')
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(limit)
        .exec(),
      this.postModel.countDocuments(filter).exec(),
    ]);
    return {
      data,
      total,
      page,
      limit,
      totalPages: Math.ceil(total / limit),
      matchedTypes: types,
    };
  }

  async getPost(id: string) {
    const post = await this.postModel.findById(id).populate('userId', '-password').exec();
    if (!post) throw new NotFoundException('Post non trouvé');
    return post;
  }

  // Comments
  async createComment(postId: string, userId: string, contenu: string) {
    const post = await this.postModel.findById(postId).exec();
    if (!post) throw new NotFoundException('Post non trouvé');
    const comment = await this.commentModel.create({
      postId: new Types.ObjectId(postId),
      userId: new Types.ObjectId(userId),
      contenu,
    });
    await this.userService.addTrustPoints(userId, TRUST_POINTS_COMMENT);
    return comment;
  }

  async getComments(postId: string) {
    return this.commentModel
      .find({ postId: new Types.ObjectId(postId) })
      .populate('userId', '-password')
      .sort({ createdAt: 1 })
      .exec();
  }

  async getCommentsFlashSummary(postId: string) {
    const post = await this.postModel.findById(postId).exec();
    if (!post) throw new NotFoundException('Post non trouvé');
    const comments = await this.commentModel
      .find({ postId: new Types.ObjectId(postId) })
      .select('contenu')
      .lean()
      .exec();
    const texts = comments.map((c) => String((c as { contenu: string }).contenu ?? ''));
    return this.communityVision.flashSummaryFromComments(texts);
  }

  // Help Requests
  async createHelpRequest(userId: string, description: string, latitude: number, longitude: number) {
    const urgencyScore = await this.communityVision.getUrgencyScore(description);
    return this.helpRequestModel.create({
      userId: new Types.ObjectId(userId),
      description,
      latitude,
      longitude,
      statut: 'EN_ATTENTE',
      urgencyScore,
    });
  }

  async getHelpRequests(page = 1, limit = 20) {
    const skip = (page - 1) * limit;
    const [data, total] = await Promise.all([
      this.helpRequestModel.find().populate('userId', '-password').sort({ createdAt: -1 }).skip(skip).limit(limit).exec(),
      this.helpRequestModel.countDocuments().exec(),
    ]);
    return { data, total, page, limit, totalPages: Math.ceil(total / limit) };
  }

  async updateHelpRequestStatut(id: string, statut: string) {
    const hr = await this.helpRequestModel.findByIdAndUpdate(id, { $set: { statut } }, { new: true }).exec();
    if (!hr) throw new NotFoundException('Demande non trouvée');
    return hr;
  }

  async acceptHelpRequest(id: string, acceptedBy: string, helperName: string) {
    const existing = await this.helpRequestModel.findById(id).exec();
    if (!existing) throw new NotFoundException('Demande non trouvée');
    if (existing.statut !== 'EN_ATTENTE') {
      throw new BadRequestException('Cette demande ne peut plus être acceptée');
    }

    const hr = await this.helpRequestModel
      .findByIdAndUpdate(
        id,
        {
          $set: {
            statut: 'EN_COURS',
            acceptedBy: new Types.ObjectId(acceptedBy),
            helperName,
          },
        },
        { new: true },
      )
      .exec();

    if (!hr) throw new NotFoundException('Demande non trouvée');
    await this.userService.addTrustPoints(acceptedBy, TRUST_POINTS_ACCEPT_HELP);
    return hr;
  }

  async getPostImageAudioDescription(
    postId: string,
    imageIndex: number,
    viewerUserId: string,
  ) {
    const skipRole =
      String(this.config.get('AUDIO_DESCRIPTION_SKIP_ROLE_CHECK') ?? '')
        .trim()
        .toLowerCase() === 'true';
    if (!skipRole) {
      const viewer = await this.userService.findOne(viewerUserId);
      const role = String(viewer.role).toUpperCase();
      const allowed =
        role === Role.HANDICAPE ||
        role === Role.ACCOMPAGNANT ||
        role === Role.ADMIN;
      if (!allowed) {
        throw new ForbiddenException(
          'La description IA des images est réservée aux profils Handicapé, Accompagnant ou Admin.',
        );
      }
    }
    const post = await this.postModel.findById(postId).exec();
    if (!post) throw new NotFoundException('Post non trouvé');
    const images = post.images ?? [];
    if (imageIndex < 0 || imageIndex >= images.length) {
      throw new BadRequestException('Index d’image invalide');
    }
    const imagePath = images[imageIndex];
    return this.communityVision.describePostImage({
      postContenu: post.contenu,
      imageIndex,
      imagePath,
    });
  }
}
