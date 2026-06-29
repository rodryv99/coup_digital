import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { GameEntity } from '../game/entities/game.entity';
import { ActionLogEntity } from './entities/action-log.entity';
import { GameLogEntry } from '../game/engine/types';

@Injectable()
export class HistoryService {
  constructor(
    @InjectRepository(GameEntity) private gameRepo: Repository<GameEntity>,
    @InjectRepository(ActionLogEntity) private logRepo: Repository<ActionLogEntity>,
  ) {}

  // CU-28: historial de partidas de un usuario, orden cronológico inverso
  async getUserHistory(userId: string, page = 1, limit = 20) {
    const qb = this.gameRepo
      .createQueryBuilder('game')
      .innerJoin('room_players', 'rp', 'rp.room_id = game.room_id')
      .where('rp.user_id = :userId', { userId })
      .andWhere('game.finished_at IS NOT NULL')
      .orderBy('game.finished_at', 'DESC')
      .skip((page - 1) * limit)
      .take(limit);

    const [games, total] = await qb.getManyAndCount();

    return {
      data: games.map((g) => ({
        gameId: g.id,
        roomId: g.roomId,
        deckVariant: g.deckVariant,
        startedAt: g.startedAt,
        finishedAt: g.finishedAt,
        winnerId: g.winnerId,
        won: g.winnerId === userId,
      })),
      total,
      page,
      limit,
    };
  }

  // Detalle del log de acciones de una partida
  async getGameLog(gameId: string) {
    const logs = await this.logRepo.find({
      where: { gameId },
      order: { createdAt: 'ASC' },
    });
    return logs;
  }

  // Persiste el log completo de una partida finalizada
  async persistGameLog(gameId: string, log: GameLogEntry[]): Promise<void> {
    if (!log.length) return;
    const entities = log.map((entry) =>
      this.logRepo.create({
        gameId,
        turnNumber: entry.turn,
        actorId: entry.actorId,
        actionType: entry.action,
        targetId: entry.targetId ?? null,
        result: entry.result,
      }),
    );
    await this.logRepo.save(entities);
  }
}