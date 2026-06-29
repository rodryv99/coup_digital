import {
  Injectable, UnauthorizedException, BadRequestException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import * as bcrypt from 'bcrypt';
import { UsersService } from '../users/users.service';
import { CreateUserDto } from '../users/dto/create-user.dto';
import { LoginDto } from '../users/dto/login.dto';
import { UserStatus } from '../common/enums/user-status.enum';
import { User } from '../users/entities/user.entity';

@Injectable()
export class AuthService {
  constructor(
    private usersService: UsersService,
    private jwtService: JwtService,
    private config: ConfigService,
  ) {}

  async register(dto: CreateUserDto) {
    const user = await this.usersService.create(dto);
    return { message: 'Usuario registrado correctamente', userId: user.id };
  }

  async login(dto: LoginDto) {
    const user = await this.usersService.findByEmailOrUsername(dto.identifier);

    if (!user) {
      throw new UnauthorizedException('Credenciales inválidas');
    }

    // Verificar si está bloqueado
    if (user.lockedUntil && user.lockedUntil > new Date()) {
      const minutes = Math.ceil((user.lockedUntil.getTime() - Date.now()) / 60000);
      throw new UnauthorizedException(
        `Cuenta bloqueada temporalmente. Intenta en ${minutes} minuto(s)`,
      );
    }

    if (user.status === UserStatus.Inactive) {
      throw new UnauthorizedException('Cuenta inactiva');
    }

    const passwordValid = await bcrypt.compare(dto.password, user.passwordHash);
    if (!passwordValid) {
      await this.usersService.incrementFailedAttempts(user);
      throw new UnauthorizedException('Credenciales inválidas');
    }

    await this.usersService.resetFailedAttempts(user);
    return this.generateTokens(user);
  }

  async refreshTokens(user: User) {
    return this.generateTokens(user);
  }

  private generateTokens(user: User) {
    const payload = { sub: user.id, username: user.username, role: user.role };

    const accessToken = this.jwtService.sign(payload, {
      secret: this.config.get('JWT_SECRET'),
      expiresIn: this.config.get('JWT_EXPIRATION') ?? '15m',
    });

    const refreshToken = this.jwtService.sign(payload, {
      secret: this.config.get('JWT_REFRESH_SECRET'),
      expiresIn: this.config.get('JWT_REFRESH_EXPIRATION') ?? '7d',
    });

    return { accessToken, refreshToken, role: user.role };
  }
}