import { Controller, Get, Param, UseGuards, ParseUUIDPipe } from '@nestjs/common';
import { StatsService } from './stats.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { User } from '../users/entities/user.entity';

@Controller('stats')
@UseGuards(JwtAuthGuard)
export class StatsController {
  constructor(private statsService: StatsService) {}

  // CU-29: mis estadísticas
  @Get('me')
  getMyStats(@CurrentUser() user: User) {
    return this.statsService.getUserStats(user.id);
  }

  // Estadísticas de cualquier usuario
  @Get(':userId')
  getUserStats(@Param('userId', ParseUUIDPipe) userId: string) {
    return this.statsService.getUserStats(userId);
  }
}