import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { ApiProperty } from '@nestjs/swagger';
import { Document, Types } from 'mongoose';

export type PostDocument = Post & Document;

@Schema({ timestamps: true, versionKey: false })
export class Post {
  @ApiProperty({ description: 'ID utilisateur' })
  @Prop({ type: Types.ObjectId, ref: 'User', required: true })
  userId: Types.ObjectId;

  @ApiProperty({ description: 'Contenu' })
  @Prop({ type: String, required: true })
  contenu: string;

  @ApiProperty({ description: 'Type de post' })
  @Prop({ type: String, required: true })
  type: string;

  @ApiProperty({ description: 'Chemins des images (dossier uploads/)', type: [String] })
  @Prop({ type: [String], default: [] })
  images: string[];

  @ApiProperty({ description: 'Date de création' })
  createdAt?: Date;
}

export const PostSchema = SchemaFactory.createForClass(Post);
