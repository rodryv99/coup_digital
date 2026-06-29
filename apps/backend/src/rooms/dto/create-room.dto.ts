import { IsString, IsInt, IsEnum, IsOptional, Min, Max, MinLength, MaxLength } from 'class-validator';
import { ReactionMode } from '../entities/room.entity';

export class CreateRoomDto {
  @IsString()
  @MinLength(3)
  @MaxLength(100)
  name: string;

  @IsInt()
  @Min(2)
  @Max(12)
  maxPlayers: number;

  @IsEnum(ReactionMode)
  reactionMode: ReactionMode;

  @IsOptional()
  @IsInt()
  @Min(10)
  @Max(300)
  turnLimitSeconds?: number;

  @IsOptional()
  @IsInt()
  @Min(5)
  @Max(60)
  reactionTimeSeconds?: number;
}