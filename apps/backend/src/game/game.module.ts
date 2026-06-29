import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { GameService } from './game.service';
import { GameEntity } from './entities/game.entity';
import { RoomsModule } from '../rooms/rooms.module';
import { HistoryModule } from '../history/history.module';
import { StatsModule } from '../stats/stats.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([GameEntity]),
    RoomsModule,
    HistoryModule,
    StatsModule,
  ],
  providers: [GameService],
  exports: [GameService],
})
export class GameModule {}