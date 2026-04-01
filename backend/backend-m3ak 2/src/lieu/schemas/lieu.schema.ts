import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Document } from 'mongoose';

export type LieuDocument = Lieu & Document;

@Schema({ timestamps: true, versionKey: false })
export class Lieu {
  @ApiProperty({ description: 'Nom du lieu' })
  @Prop({ type: String, required: true })
  nom: string;

  @ApiProperty({ description: 'Adresse' })
  @Prop({ type: String, required: true })
  adresse: string;

  @ApiProperty({ description: 'Type de lieu' })
  @Prop({ type: String, required: true })
  typeLieu: string;

  @ApiProperty({ description: 'Latitude' })
  @Prop({ type: Number, required: true })
  latitude: number;

  @ApiProperty({ description: 'Longitude' })
  @Prop({ type: Number, required: true })
  longitude: number;

  @Prop({
    type: {
      type: String,
      enum: ['Point'],
      default: 'Point',
    },
    coordinates: { type: [Number], default: [0, 0] },
  })
  location: { type: string; coordinates: [number, number] };

  @ApiPropertyOptional({ description: 'Description' })
  @Prop({ type: String, default: null })
  description: string | null;

  @ApiPropertyOptional({ description: 'Score d\'accessibilité (0-100)' })
  @Prop({ type: Number, default: 0 })
  scoreAccessibilite: number;

  @ApiPropertyOptional({ description: 'Rampe disponible', default: false })
  @Prop({ type: Boolean, default: false })
  rampe: boolean;

  @ApiPropertyOptional({ description: 'Ascenseur disponible', default: false })
  @Prop({ type: Boolean, default: false })
  ascenseur: boolean;

  @ApiPropertyOptional({ description: 'Toilettes adaptées', default: false })
  @Prop({ type: Boolean, default: false })
  toilettesAdaptees: boolean;

  @ApiPropertyOptional({
    description: 'Liste des images (filenames stockés dans /uploads)',
    type: [String],
  })
  @Prop({ type: [String], default: [] })
  images: string[];

  @ApiProperty({ description: 'Date de création' })
  createdAt?: Date;
}

export const LieuSchema = SchemaFactory.createForClass(Lieu);

LieuSchema.pre('save', function (next) {
  if (this.latitude != null && this.longitude != null) {
    this.location = {
      type: 'Point',
      coordinates: [this.longitude, this.latitude],
    } as { type: string; coordinates: [number, number] };
  }
  next();
});

// Index géospatial 2dsphere pour recherche par proximité
LieuSchema.index({ location: '2dsphere' });
