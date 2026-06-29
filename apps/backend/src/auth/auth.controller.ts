import { Body, Controller, Post, UseGuards } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { AuthService } from './auth.service';
import { CreateUserDto } from '../users/dto/create-user.dto';
import { LoginDto } from '../users/dto/login.dto';
import { CurrentUser } from './decorators/current-user.decorator';
import { User } from '../users/entities/user.entity';

@Controller('auth')
export class AuthController {
  constructor(private authService: AuthService) {}

  // CU-01
  @Post('register')
  register(@Body() dto: CreateUserDto) {
    return this.authService.register(dto);
  }

  // CU-02
  @Post('login')
  login(@Body() dto: LoginDto) {
    return this.authService.login(dto);
  }

  // CU-03 — el cliente simplemente descarta los tokens;
  // aquí devolvemos confirmación. En v2 se puede implementar blacklist con Redis.
  @Post('logout')
  logout() {
    return { message: 'Sesión cerrada' };
  }

  // Refresh token
  @UseGuards(AuthGuard('jwt-refresh'))
  @Post('refresh')
  refresh(@CurrentUser() user: User) {
    return this.authService.refreshTokens(user);
  }
}