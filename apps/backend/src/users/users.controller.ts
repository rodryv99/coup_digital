import {
  Controller, Get, Patch, Delete, Param, Body,
  Query, UseGuards, ParseUUIDPipe, ParseIntPipe,
  DefaultValuePipe, Post,
} from '@nestjs/common';
import { UsersService } from './users.service';
import { UpdateUserDto } from './dto/update-user.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { Role } from '../common/enums/role.enum';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { User } from './entities/user.entity';

@Controller('users')
@UseGuards(JwtAuthGuard, RolesGuard)
export class UsersController {
  constructor(private usersService: UsersService) {}

  @Get()
  @Roles(Role.Admin)
  findAll(
    @Query('page', new DefaultValuePipe(1), ParseIntPipe) page: number,
    @Query('limit', new DefaultValuePipe(20), ParseIntPipe) limit: number,
    @Query('search') search?: string,
  ) {
    return this.usersService.findAll(page, limit, search);
  }

  @Get('me')
  getMe(@CurrentUser() user: User) {
    const { passwordHash, ...safe } = user as any;
    return safe;
  }

  // Perfil propio: nombre visible y/o avatar (permanente)
  @Patch('me')
  updateMe(
    @CurrentUser() user: User,
    @Body() body: { username?: string; avatar?: string | null },
  ) {
    return this.usersService.updateProfile(user.id, {
      username: body.username,
      avatar: body.avatar,
    });
  }

  // Cambio de contraseña propio
  @Post('me/password')
  changeMyPassword(
    @CurrentUser() user: User,
    @Body() body: { currentPassword: string; newPassword: string },
  ) {
    return this.usersService.changePassword(user.id, body.currentPassword, body.newPassword);
  }

  // CU-30: registrar/actualizar token FCM del dispositivo
  @Post('me/fcm-token')
  updateFcmToken(@CurrentUser() user: User, @Body('fcmToken') fcmToken: string) {
    return this.usersService.updateFcmToken(user.id, fcmToken);
  }

  @Get(':id')
  @Roles(Role.Admin)
  findOne(@Param('id', ParseUUIDPipe) id: string) {
    return this.usersService.findById(id);
  }

  @Patch(':id')
  async update(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateUserDto,
    @CurrentUser() currentUser: User,
  ) {
    if (currentUser.role !== Role.Admin) {
      if (currentUser.id !== id) {
        return { message: 'No autorizado' };
      }
      delete dto.role;
    }
    return this.usersService.update(id, dto);
  }

  @Delete(':id')
  async remove(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() currentUser: User,
  ) {
    if (currentUser.role !== Role.Admin && currentUser.id !== id) {
      return { message: 'No autorizado' };
    }
    await this.usersService.remove(id);
    return { message: 'Usuario eliminado' };
  }
}