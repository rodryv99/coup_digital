import { IsString, MinLength } from 'class-validator';

export class LoginDto {
  @IsString()
  identifier: string; // username o email

  @IsString()
  @MinLength(8)
  password: string;
}