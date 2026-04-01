import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { Lieu, LieuDocument } from './schemas/lieu.schema';
import { CreateLieuDto } from './dto/create-lieu.dto';

@Injectable()
export class LieuService {
  constructor(@InjectModel(Lieu.name) private lieuModel: Model<LieuDocument>) {}

  async create(dto: CreateLieuDto, imagePaths: string[] = []) {
    const images = imagePaths.length ? imagePaths : dto.images ?? [];
    return this.lieuModel.create({
      ...dto,
      images,
      location: {
        type: 'Point',
        coordinates: [dto.longitude, dto.latitude],
      },
    });
  }

  async findAll(params?: { typeLieu?: string; page?: number; limit?: number }) {
    const filter: Record<string, unknown> = {};
    if (params?.typeLieu) filter.typeLieu = params.typeLieu;

    const page = Math.max(1, params?.page ?? 1);
    const limit = Math.min(100, Math.max(1, params?.limit ?? 20));
    const skip = (page - 1) * limit;

    const [data, total] = await Promise.all([
      this.lieuModel.find(filter).skip(skip).limit(limit).sort({ createdAt: -1 }).exec(),
      this.lieuModel.countDocuments(filter).exec(),
    ]);

    return { data, total, page, limit, totalPages: Math.ceil(total / limit) };
  }

  async findNearby(latitude: number, longitude: number, maxDistanceMeters = 5000) {
    return this.lieuModel
      .find({
        location: {
          $near: {
            $geometry: {
              type: 'Point',
              coordinates: [longitude, latitude],
            },
            $maxDistance: maxDistanceMeters,
          },
        },
      })
      .limit(50)
      .exec();
  }

  async findOne(id: string) {
    const lieu = await this.lieuModel.findById(id).exec();
    if (!lieu) throw new NotFoundException('Lieu non trouvé');
    return lieu;
  }

  async update(id: string, dto: Partial<CreateLieuDto>) {
    const update: Record<string, unknown> = { ...dto };
    if (dto.latitude != null && dto.longitude != null) {
      update.location = {
        type: 'Point',
        coordinates: [dto.longitude, dto.latitude],
      };
    }
    const lieu = await this.lieuModel.findByIdAndUpdate(id, { $set: update }, { new: true }).exec();
    if (!lieu) throw new NotFoundException('Lieu non trouvé');
    return lieu;
  }

  async remove(id: string) {
    const result = await this.lieuModel.findByIdAndDelete(id).exec();
    if (!result) throw new NotFoundException('Lieu non trouvé');
  }
}
