import {
  Controller, Post, Get, Delete, Param, Body,
  UseGuards, ParseUUIDPipe,
} from '@nestjs/common';
import { RoomsService } from './rooms.service';
import { CreateRoomDto } from './dto/create-room.dto';
import { JoinRoomDto } from './dto/join-room.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { User } from '../users/entities/user.entity';

@Controller('rooms')
@UseGuards(JwtAuthGuard)
export class RoomsController {
  constructor(private roomsService: RoomsService) {}

  @Post()
  create(@Body() dto: CreateRoomDto, @CurrentUser() user: User) {
    return this.roomsService.create(dto, user);
  }

  @Post('join')
  joinByCode(@Body() dto: JoinRoomDto, @CurrentUser() user: User) {
    return this.roomsService.joinByCode(dto.code, user.id);
  }

  @Post('join/qr')
  joinByQr(@Body() dto: JoinRoomDto, @CurrentUser() user: User) {
    return this.roomsService.joinByCode(dto.code, user.id);
  }

  @Get(':id/players')
  getPlayers(@Param('id', ParseUUIDPipe) id: string) {
    return this.roomsService.getPlayers(id);
  }

  @Delete(':id/players/:userId')
  kickPlayer(
    @Param('id', ParseUUIDPipe) id: string,
    @Param('userId', ParseUUIDPipe) userId: string,
    @CurrentUser() user: User,
  ) {
    return this.roomsService.kickPlayer(id, user.id, userId);
  }
}