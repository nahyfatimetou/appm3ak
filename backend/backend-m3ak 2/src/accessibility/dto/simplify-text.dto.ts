import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsOptional, IsString, MinLength } from 'class-validator';

export class SimplifyTextDto {
  @ApiProperty({ description: 'Texte à simplifier (FALC / accessibilité cognitive)' })
  @IsString()
  @MinLength(1, { message: 'Le texte est requis' })
  text: string;

  @ApiPropertyOptional({
    description: 'Niveau de simplification',
    example: 'facile',
    default: 'facile',
  })
  @IsOptional()
  @IsString()
  level?: string;
}
