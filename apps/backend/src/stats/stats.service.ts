import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { UserStatsEntity } from './entities/user-stats.entity';

@Injectable()
export class StatsService {
  constructor(
    @InjectRepository(UserStatsEntity) private statsRepo: Repository<UserStatsEntity>,
  ) {}

  // CU-29: estadísticas de un usuario
  async getUserStats(userId: string) {
    let stats = await this.statsRepo.findOne({ where: { userId } });
    if (!stats) {
      // Devuelve ceros si no hay registro aún
      return {
        userId,
        gamesPlayed: 0,
        wins: 0,
        losses: 0,
        winRate: 0,
        avgPlayers: 0,
      };
    }
    return {
      userId: stats.userId,
      gamesPlayed: stats.gamesPlayed,
      wins: stats.wins,
      losses: stats.losses,
      winRate: Number(stats.winRate),
      avgPlayers: Number(stats.avgPlayers),
    };
  }

  // Actualiza stats al finalizar una partida
  async recordGameResult(
    participants: { userId: string; won: boolean }[],
    playerCount: number,
  ): Promise<void> {
    for (const p of participants) {
      let stats = await this.statsRepo.findOne({ where: { userId: p.userId } });

      if (!stats) {
        stats = this.statsRepo.create({
          userId: p.userId,
          gamesPlayed: 0,
          wins: 0,
          losses: 0,
          avgPlayers: 0,
        });
      }

      const prevTotal = stats.gamesPlayed;
      stats.gamesPlayed += 1;
      if (p.won) stats.wins += 1;
      else stats.losses += 1;

      // Promedio incremental de jugadores
      stats.avgPlayers =
        (Number(stats.avgPlayers) * prevTotal + playerCount) / stats.gamesPlayed;

      stats.winRate = stats.gamesPlayed > 0
        ? (stats.wins / stats.gamesPlayed) * 100
        : 0;

      await this.statsRepo.save(stats);
    }
  }
}