import { Injectable, NotFoundException, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { CoupEngine } from './engine/coup-engine';
import { ActionType, Card, GameState } from './engine/types';
import { GameEntity } from './entities/game.entity';
import { RedisService } from '../redis/redis.service';
import { RoomsService } from '../rooms/rooms.service';
import { HistoryService } from '../history/history.service';
import { StatsService } from '../stats/stats.service';

@Injectable()
export class GameService {
  private readonly logger = new Logger('GameService');
  private timers = new Map<string, ReturnType<typeof setTimeout>>();
  private onReactionTimeout?: (gameId: string, roomId: string) => void;

  constructor(
    @InjectRepository(GameEntity) private gameRepo: Repository<GameEntity>,
    private redis: RedisService,
    private roomsService: RoomsService,
    private historyService: HistoryService,
    private statsService: StatsService,
  ) {}

  async startGame(roomId: string): Promise<GameState> {
    const players = await this.roomsService.getPlayers(roomId);
    const room = await this.roomsService.findById(roomId);

    const deckVariant = players.length <= 6 ? 15 : 30;
    const entity = await this.gameRepo.save(
      this.gameRepo.create({ roomId, deckVariant }),
    );

    const initPlayers = players.map((p, idx) => ({
      userId: p.userId,
      username: p.user?.username ?? `jugador-${idx + 1}`,
      seatOrder: p.seatOrder ?? idx,
    }));

    const config = {
      reactionMode: (room.reactionMode ?? 'timer') as 'timer' | 'pass',
      reactionTimeSeconds: room.reactionTimeSeconds ?? 30,
    };

    const state = CoupEngine.initGame(entity.id, roomId, initPlayers, config);
    await this.saveState(state);
    await this.redis.set(`room:${roomId}:game`, state.gameId);
    return state;
  }

  async restartGame(roomId: string, hostId: string): Promise<GameState> {
    const isHost = await this.roomsService.isHost(roomId, hostId);
    if (!isHost) throw new Error('Solo el anfitrión puede iniciar una revancha');

    const prevGameId = await this.redis.get(`room:${roomId}:game`);
    if (prevGameId) {
      await this.redis.del(`game:${prevGameId}`);
    }

    await this.roomsService.resetToWaiting(roomId);
    return this.startGame(roomId);
  }

  async getState(gameId: string): Promise<GameState> {
    const raw = await this.redis.get(`game:${gameId}`);
    if (!raw) throw new NotFoundException('Partida no encontrada');
    return JSON.parse(raw) as GameState;
  }

  async saveState(state: GameState): Promise<void> {
    await this.redis.set(`game:${state.gameId}`, JSON.stringify(state));

    if (state.phase === 'finished') {
      this.clearTimer(state.gameId);
      // La persistencia en PostgreSQL (historial/estadisticas) es secundaria:
      // si falla NO debe romper el flujo de la partida en vivo. Cada bloque
      // se aisla para que un error en uno no impida los demas ni el broadcast.
      try {
        await this.gameRepo.update(state.gameId, {
          finishedAt: new Date(),
          winnerId: state.winnerId,
        });
      } catch (err: any) {
        this.logger.error(`No se pudo actualizar games (${state.gameId}): ${err.message}`);
      }
      try {
        await this.historyService.persistGameLog(state.gameId, state.log);
      } catch (err: any) {
        this.logger.error(`No se pudo persistir el historial (${state.gameId}): ${err.message}`);
      }
      try {
        await this.statsService.recordGameResult(
          state.players.map((p) => ({ userId: p.userId, won: p.userId === state.winnerId })),
          state.players.length,
        );
      } catch (err: any) {
        this.logger.error(`No se pudieron actualizar estadisticas (${state.gameId}): ${err.message}`);
      }
    }
  }

  async declareAction(gameId: string, actorId: string, action: ActionType, targetId?: string): Promise<GameState> {
    const state = await this.getState(gameId);
    const next = CoupEngine.declareAction(state, actorId, action, targetId);
    await this.saveState(next);
    if (next.phase === 'awaiting_reaction' || next.phase === 'awaiting_block_reaction') {
      this.startTimer(next);
    }
    return next;
  }

  async challenge(gameId: string, challengerId: string): Promise<GameState> {
    const state = await this.getState(gameId);
    this.clearTimer(gameId);
    const next = CoupEngine.challenge(state, challengerId);
    await this.saveState(next);
    return next;
  }

  async block(gameId: string, blockerId: string, card: Card): Promise<GameState> {
    const state = await this.getState(gameId);
    this.clearTimer(gameId);
    const next = CoupEngine.block(state, blockerId, card);
    await this.saveState(next);
    if (next.phase === 'awaiting_block_reaction') this.startTimer(next);
    return next;
  }

  async pass(gameId: string, playerId: string): Promise<GameState> {
    const state = await this.getState(gameId);
    const next = CoupEngine.pass(state, playerId);
    await this.saveState(next);
    if (next.phase !== 'awaiting_reaction') this.clearTimer(gameId);
    return next;
  }

  async acceptBlock(gameId: string, actorId: string): Promise<GameState> {
    const state = await this.getState(gameId);
    this.clearTimer(gameId);
    const next = CoupEngine.acceptBlock(state, actorId);
    await this.saveState(next);
    return next;
  }

  async challengeBlock(gameId: string, challengerId: string): Promise<GameState> {
    const state = await this.getState(gameId);
    this.clearTimer(gameId);
    const next = CoupEngine.challengeBlock(state, challengerId);
    await this.saveState(next);
    return next;
  }

  async chooseInfluence(gameId: string, userId: string, card: Card): Promise<GameState> {
    const state = await this.getState(gameId);
    const next = CoupEngine.chooseInfluence(state, userId, card);
    await this.saveState(next);
    return next;
  }

  async chooseExchange(gameId: string, userId: string, cards: Card[]): Promise<GameState> {
    const state = await this.getState(gameId);
    const next = CoupEngine.chooseExchange(state, userId, cards);
    await this.saveState(next);
    return next;
  }

  async abandonGame(gameId: string, userId: string): Promise<GameState> {
    const state = await this.getState(gameId);
    const next = CoupEngine.abandonGame(state, userId);
    await this.saveState(next);
    return next;
  }

  async resolveTimeout(gameId: string): Promise<GameState> {
    const state = await this.getState(gameId);
    const next = CoupEngine.reactionTimeout(state);
    await this.saveState(next);
    return next;
  }

  setTimeoutCallback(cb: (gameId: string, roomId: string) => void) {
    this.onReactionTimeout = cb;
  }

  private startTimer(state: GameState) {
    this.clearTimer(state.gameId);
    if (state.config.reactionMode !== 'timer') return;
    const ms = state.config.reactionTimeSeconds * 1000;
    const timer = setTimeout(() => {
      this.timers.delete(state.gameId);
      if (this.onReactionTimeout) this.onReactionTimeout(state.gameId, state.roomId);
    }, ms);
    this.timers.set(state.gameId, timer);
  }

  private clearTimer(gameId: string) {
    const timer = this.timers.get(gameId);
    if (timer) { clearTimeout(timer); this.timers.delete(gameId); }
  }
}