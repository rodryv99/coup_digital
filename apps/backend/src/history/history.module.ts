import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { HistoryService } from './history.service';
import { HistoryController } from './history.controller';
import { GameEntity } from '../game/entities/game.entity';
import { ActionLogEntity } from './entities/action-log.entity';

@Module({
  imports: [TypeOrmModule.forFeature([GameEntity, ActionLogEntity])],
  controllers: [HistoryController],
  providers: [HistoryService],
  exports: [HistoryService],
})
export class HistoryModule {}