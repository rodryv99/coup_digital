import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { StatsService } from './stats.service';
import { StatsController } from './stats.controller';
import { UserStatsEntity } from './entities/user-stats.entity';

@Module({
  imports: [TypeOrmModule.forFeature([UserStatsEntity])],
  controllers: [StatsController],
  providers: [StatsService],
  exports: [StatsService],
})
export class StatsModule {}