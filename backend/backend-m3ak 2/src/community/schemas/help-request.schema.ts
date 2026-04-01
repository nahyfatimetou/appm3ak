import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Document, Types } from 'mongoose';

export type HelpRequestDocument = HelpRequest & Document;

@Schema({ timestamps: true, versionKey: false })
export class HelpRequest {
  @ApiProperty({ description: 'ID utilisateur' })
  @Prop({ type: Types.ObjectId, ref: 'User', required: true })
  userId: Types.ObjectId;

  @ApiProperty({ description: 'Description de la demande' })
  @Prop({ type: String, required: true })
  description: string;

  @ApiProperty({ description: 'Latitude' })
  @Prop({ type: Number, required: true })
  latitude: number;

  @ApiProperty({ description: 'Longitude' })
  @Prop({ type: Number, required: true })
  longitude: number;

  @ApiProperty({ description: 'Statut', default: 'EN_ATTENTE' })
  @Prop({ type: String, default: 'EN_ATTENTE' })
  statut: string;

  @ApiPropertyOptional({
    description: "ID de l'utilisateur qui a accepté la demande",
    type: String,
  })
  @Prop({ type: Types.ObjectId, ref: 'User', default: null })
  acceptedBy: Types.ObjectId | null;

  @ApiPropertyOptional({
    description: "Nom affiché du bénévole (helper) après acceptation",
  })
  @Prop({ type: String, default: null })
  helperName: string | null;

  @ApiPropertyOptional({
    description: "Urgence estimée sur une échelle 1-5",
    default: 1,
  })
  @Prop({ type: Number, default: 1 })
  urgencyScore: number;

  @ApiProperty({ description: 'Date de création' })
  createdAt?: Date;
}

export const HelpRequestSchema = SchemaFactory.createForClass(HelpRequest);
