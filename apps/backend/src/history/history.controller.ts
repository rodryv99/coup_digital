import {
  Controller, Get, Param, Query, UseGuards,
  ParseUUIDPipe, ParseIntPipe, DefaultValuePipe,
} from '@nestjs/common';
import { HistoryService } from './history.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { User } from '../users/entities/user.entity';

@Controller('history')
@UseGuards(JwtAuthGuard)
export class HistoryController {
  constructor(private historyService: HistoryService) {}

  // CU-28: mi historial de partidas
  @Get()
  getMyHistory(
    @CurrentUser() user: User,
    @Query('page', new DefaultValuePipe(1), ParseIntPipe) page: number,
    @Query('limit', new DefaultValuePipe(20), ParseIntPipe) limit: number,
  ) {
    return this.historyService.getUserHistory(user.id, page, limit);
  }

  // Detalle del log de una partida
  @Get(':gameId/log')
  getGameLog(@Param('gameId', ParseUUIDPipe) gameId: string) {
    return this.historyService.getGameLog(gameId);
  }
}