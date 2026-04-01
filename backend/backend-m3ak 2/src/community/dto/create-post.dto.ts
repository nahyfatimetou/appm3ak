import { ApiProperty } from '@nestjs/swagger';
import { IsIn, IsString, MinLength } from 'class-validator';
import { POST_TYPE_VALUES } from '../enums/post-type.enum';

export class CreatePostDto {
  @ApiProperty({ description: 'Contenu du post' })
  @IsString()
  @MinLength(1, { message: 'Le contenu est requis' })
  contenu: string;

  @ApiProperty({
    description: 'Type de post (enum alignée Flutter / Nest `PostTypeCommunity`)',
    enum: POST_TYPE_VALUES,
    example: 'general',
  })
  @IsString()
  @MinLength(1, { message: 'Le type est requis' })
  @IsIn(POST_TYPE_VALUES, { message: 'Type de post invalide' })
  type: string;
}
