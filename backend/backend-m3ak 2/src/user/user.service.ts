import {
  Injectable,
  ConflictException,
  NotFoundException,
} from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import * as bcrypt from 'bcryptjs';
import { User, UserDocument } from './schemas/user.schema';
import { CreateUserDto } from './dto/create-user.dto';
import { UpdateUserDto } from './dto/update-user.dto';
import { Role } from './enums/role.enum';

@Injectable()
export class UserService {
  constructor(
    @InjectModel(User.name) private userModel: Model<UserDocument>,
  ) {}

  async create(
    createUserDto: CreateUserDto,
    photoProfil?: string,
  ): Promise<Omit<UserDocument, 'password'>> {
    const existing = await this.userModel
      .findOne({ email: createUserDto.email.toLowerCase() })
      .exec();
    if (existing) {
      throw new ConflictException('Cet email est déjà utilisé');
    }

    const hashedPassword = await bcrypt.hash(createUserDto.password, 10);

    const user = await this.userModel.create({
      ...createUserDto,
      email: createUserDto.email.toLowerCase(),
      password: hashedPassword,
      role: createUserDto.role ?? Role.HANDICAPE,
      photoProfil: photoProfil ?? null,
      animalAssistance: createUserDto.animalAssistance ?? false,
      disponible: createUserDto.disponible ?? false,
      noteMoyenne: 0,
      trustPoints: 0,
      statut: createUserDto.statut ?? 'ACTIF',
      langue: createUserDto.langue ?? 'fr',
      partenaire: createUserDto.partenaire ?? false,
    });

    return this.toUserResponse(user);
  }

  async findAll(params: {
    page?: number;
    limit?: number;
    role?: string;
    search?: string;
  }): Promise<{
    data: Omit<UserDocument, 'password'>[];
    total: number;
    page: number;
    limit: number;
    totalPages: number;
  }> {
    const page = Math.max(1, params.page ?? 1);
    const limit = Math.min(100, Math.max(1, params.limit ?? 10));
    const skip = (page - 1) * limit;

    const filter: Record<string, unknown> = {};
    if (params.role) {
      filter.role = params.role;
    }
    if (params.search && params.search.trim()) {
      const search = params.search.trim();
      filter.$or = [
        { email: { $regex: search, $options: 'i' } },
        { nom: { $regex: search, $options: 'i' } },
        { prenom: { $regex: search, $options: 'i' } },
      ];
    }

    const [users, total] = await Promise.all([
      this.userModel
        .find(filter)
        .select('-password')
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(limit)
        .exec(),
      this.userModel.countDocuments(filter).exec(),
    ]);
    const data = users.map((u: UserDocument) => this.toUserResponse(u));

    return {
      data,
      total,
      page,
      limit,
      totalPages: Math.ceil(total / limit),
    };
  }

  async findOne(id: string): Promise<Omit<UserDocument, 'password'>> {
    const user = await this.userModel.findById(id).exec();
    if (!user) {
      throw new NotFoundException('Utilisateur non trouvé');
    }
    return this.toUserResponse(user);
  }

  async findByEmail(email: string): Promise<UserDocument | null> {
    return this.userModel
      .findOne({ email: email.toLowerCase() })
      .select('+password')
      .exec();
  }

  async findByIdWithPassword(id: string): Promise<UserDocument | null> {
    return this.userModel.findById(id).select('+password').exec();
  }

  async findAccompagnantsDisponibles(lat?: number, lon?: number): Promise<Omit<UserDocument, 'password'>[]> {
    const filter = { role: Role.ACCOMPAGNANT, disponible: true, statut: 'ACTIF' };
    const accompagnants: UserDocument[] = await this.userModel
      .find(filter)
      .select('-password')
      .sort({ noteMoyenne: -1 })
      .exec();
    return accompagnants.map((u: UserDocument) => this.toUserResponse(u));
  }

  async update(
    id: string,
    updateUserDto: UpdateUserDto,
    photoProfil?: string,
  ): Promise<Omit<UserDocument, 'password'>> {
    const update: Record<string, unknown> = { ...updateUserDto };
    if (photoProfil !== undefined) {
      update.photoProfil = photoProfil;
    }

    const user = await this.userModel
      .findByIdAndUpdate(id, { $set: update }, { new: true })
      .exec();

    if (!user) {
      throw new NotFoundException('Utilisateur non trouvé');
    }

    return this.toUserResponse(user);
  }

  async updateNoteMoyenne(userId: string, noteMoyenne: number): Promise<void> {
    await this.userModel.findByIdAndUpdate(userId, { $set: { noteMoyenne } }).exec();
  }

  /** Incrémente les points de confiance (aide communauté). */
  async addTrustPoints(userId: string, delta: number): Promise<void> {
    if (!delta) return;
    await this.userModel
      .findByIdAndUpdate(userId, { $inc: { trustPoints: delta } }, { new: true })
      .exec();
  }

  async remove(id: string): Promise<void> {
    const result = await this.userModel.findByIdAndDelete(id).exec();
    if (!result) {
      throw new NotFoundException('Utilisateur non trouvé');
    }
  }

  toUserResponse(user: UserDocument): Omit<UserDocument, 'password'> {
    const obj = user.toObject();
    delete (obj as Record<string, unknown>).password;
    return obj as Omit<UserDocument, 'password'>;
  }
}
