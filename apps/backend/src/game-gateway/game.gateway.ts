import {
  WebSocketGateway, WebSocketServer, SubscribeMessage,
  MessageBody, ConnectedSocket, OnGatewayConnection,
  OnGatewayDisconnect, OnGatewayInit,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { Logger } from '@nestjs/common';
import { RoomsService } from '../rooms/rooms.service';
import { GameService } from '../game/game.service';
import { RedisService } from '../redis/redis.service';
import { CoupEngine } from '../game/engine/coup-engine';
import { ActionType, Card } from '../game/engine/types';

@WebSocketGateway({ cors: { origin: '*' } })
export class GameGateway implements OnGatewayConnection, OnGatewayDisconnect, OnGatewayInit {
  @WebSocketServer()
  server: Server;

  private readonly logger = new Logger('GameGateway');

  constructor(
    private roomsService: RoomsService,
    private gameService: GameService,
    private redis: RedisService,
  ) {}

  afterInit() {
    this.gameService.setTimeoutCallback(async (gameId, roomId) => {
      try {
        await this.gameService.resolveTimeout(gameId);
        await this.broadcastGameState(roomId, gameId);
      } catch (err: any) {
        this.logger.error(`Reaction timeout error: ${err.message}`);
      }
    });
  }

  async handleConnection(client: Socket) {
    this.logger.log(`Cliente conectado: ${client.id}`);
  }

  async handleDisconnect(client: Socket) {
    this.logger.log(`Cliente desconectado: ${client.id}`);
    const roomId = await this.redis.get(`socket:${client.id}:room`);
    if (roomId) {
      await this.redis.hdel(`room:${roomId}:sockets`, client.id);
      await this.redis.del(`socket:${client.id}:room`);
      this.server.to(roomId).emit('player_disconnected', { socketId: client.id });
    }
  }

  @SubscribeMessage('reconnect_game')
  async handleReconnect(
    @MessageBody() data: { roomId: string; userId: string },
    @ConnectedSocket() client: Socket,
  ) {
    try {
      client.join(data.roomId);
      await this.redis.hset(`room:${data.roomId}:sockets`, client.id, data.userId);
      await this.redis.set(`socket:${client.id}:room`, data.roomId);
      const gameId = await this.redis.get(`room:${data.roomId}:game`);
      if (gameId) {
        const state = await this.gameService.getState(gameId);
        client.emit('public_state', CoupEngine.publicView(state));
        client.emit('your_hand', CoupEngine.privateHand(state, data.userId));
      } else {
        await this.emitRoomState(data.roomId);
      }
    } catch (err: any) {
      client.emit('error', { message: err.message });
    }
  }

  @SubscribeMessage('join_room')
  async handleJoinRoom(
    @MessageBody() data: { roomId: string; userId: string },
    @ConnectedSocket() client: Socket,
  ) {
    try {
      client.join(data.roomId);
      await this.redis.hset(`room:${data.roomId}:sockets`, client.id, data.userId);
      await this.redis.set(`socket:${client.id}:room`, data.roomId);
      await this.emitRoomState(data.roomId);
    } catch (err: any) {
      client.emit('action_error', { message: err.message });
    }
  }

  @SubscribeMessage('kick_player')
  async handleKickPlayer(
    @MessageBody() data: { roomId: string; hostId: string; targetUserId: string },
    @ConnectedSocket() client: Socket,
  ) {
    try {
      await this.roomsService.kickPlayer(data.roomId, data.hostId, data.targetUserId);
      this.server.to(data.roomId).emit('player_kicked', { userId: data.targetUserId });
      await this.emitRoomState(data.roomId);
    } catch (err: any) {
      client.emit('action_error', { message: err.message });
    }
  }

  @SubscribeMessage('start_game')
  async handleStartGame(
    @MessageBody() data: { roomId: string; hostId: string },
    @ConnectedSocket() client: Socket,
  ) {
    try {
      await this.roomsService.startGame(data.roomId, data.hostId);
      const state = await this.gameService.startGame(data.roomId);
      this.server.to(data.roomId).emit('game_started', { gameId: state.gameId });
      await this.broadcastGameState(data.roomId, state.gameId);
    } catch (err: any) {
      client.emit('action_error', { message: err.message });
    }
  }

  @SubscribeMessage('restart_game')
  async handleRestartGame(
    @MessageBody() data: { roomId: string; hostId: string },
    @ConnectedSocket() client: Socket,
  ) {
    try {
      const state = await this.gameService.restartGame(data.roomId, data.hostId);
      this.server.to(data.roomId).emit('game_started', { gameId: state.gameId });
      await this.broadcastGameState(data.roomId, state.gameId);
    } catch (err: any) {
      client.emit('action_error', { message: err.message });
    }
  }

  @SubscribeMessage('declare_action')
  async handleDeclareAction(
    @MessageBody() data: { roomId: string; gameId: string; actorId: string; action: ActionType; targetId?: string },
    @ConnectedSocket() client: Socket,
  ) {
    try {
      await this.gameService.declareAction(data.gameId, data.actorId, data.action, data.targetId);
      await this.broadcastGameState(data.roomId, data.gameId);
    } catch (err: any) {
      this.logger.error(`declare_action FALLO: ${err.message}`);
      client.emit('action_error', { message: err.message });
    }
  }

  @SubscribeMessage('challenge')
  async handleChallenge(
    @MessageBody() data: { roomId: string; gameId: string; challengerId: string },
    @ConnectedSocket() client: Socket,
  ) {
    try {
      await this.gameService.challenge(data.gameId, data.challengerId);
      await this.broadcastGameState(data.roomId, data.gameId);
    } catch (err: any) {
      this.logger.error(`challenge FALLO: ${err.message}`);
      client.emit('action_error', { message: err.message });
    }
  }

  @SubscribeMessage('block')
  async handleBlock(
    @MessageBody() data: { roomId: string; gameId: string; blockerId: string; card: Card },
    @ConnectedSocket() client: Socket,
  ) {
    try {
      await this.gameService.block(data.gameId, data.blockerId, data.card);
      await this.broadcastGameState(data.roomId, data.gameId);
    } catch (err: any) {
      this.logger.error(`block FALLO: ${err.message}`);
      client.emit('action_error', { message: err.message });
    }
  }

  @SubscribeMessage('pass')
  async handlePass(
    @MessageBody() data: { roomId: string; gameId: string; playerId: string },
    @ConnectedSocket() client: Socket,
  ) {
    try {
      await this.gameService.pass(data.gameId, data.playerId);
      await this.broadcastGameState(data.roomId, data.gameId);
    } catch (err: any) {
      this.logger.error(`pass FALLO: ${err.message}`);
      client.emit('action_error', { message: err.message });
    }
  }

  @SubscribeMessage('accept_block')
  async handleAcceptBlock(
    @MessageBody() data: { roomId: string; gameId: string; actorId: string },
    @ConnectedSocket() client: Socket,
  ) {
    try {
      await this.gameService.acceptBlock(data.gameId, data.actorId);
      await this.broadcastGameState(data.roomId, data.gameId);
    } catch (err: any) {
      this.logger.error(`accept_block FALLO: ${err.message}`);
      client.emit('action_error', { message: err.message });
    }
  }

  @SubscribeMessage('challenge_block')
  async handleChallengeBlock(
    @MessageBody() data: { roomId: string; gameId: string; challengerId: string },
    @ConnectedSocket() client: Socket,
  ) {
    try {
      this.logger.log(`challenge_block recibido de ${data.challengerId} en game ${data.gameId}`);
      await this.gameService.challengeBlock(data.gameId, data.challengerId);
      await this.broadcastGameState(data.roomId, data.gameId);
      this.logger.log(`challenge_block procesado OK`);
    } catch (err: any) {
      this.logger.error(`challenge_block FALLO: ${err.message}`);
      this.logger.error(err.stack);
      client.emit('action_error', { message: err.message });
    }
  }

  @SubscribeMessage('choose_influence')
  async handleChooseInfluence(
    @MessageBody() data: { roomId: string; gameId: string; userId: string; card: Card },
    @ConnectedSocket() client: Socket,
  ) {
    try {
      this.logger.log(`choose_influence recibido de ${data.userId}, carta ${data.card}`);
      await this.gameService.chooseInfluence(data.gameId, data.userId, data.card);
      await this.broadcastGameState(data.roomId, data.gameId);
      this.logger.log(`choose_influence procesado OK`);
    } catch (err: any) {
      this.logger.error(`choose_influence FALLO: ${err.message}`);
      this.logger.error(err.stack);
      client.emit('action_error', { message: err.message });
    }
  }

  @SubscribeMessage('choose_exchange')
  async handleChooseExchange(
    @MessageBody() data: { roomId: string; gameId: string; userId: string; cards: Card[] },
    @ConnectedSocket() client: Socket,
  ) {
    try {
      await this.gameService.chooseExchange(data.gameId, data.userId, data.cards);
      await this.broadcastGameState(data.roomId, data.gameId);
    } catch (err: any) {
      this.logger.error(`choose_exchange FALLO: ${err.message}`);
      client.emit('action_error', { message: err.message });
    }
  }

  @SubscribeMessage('abandon_game')
  async handleAbandonGame(
    @MessageBody() data: { roomId: string; gameId: string; userId: string },
    @ConnectedSocket() client: Socket,
  ) {
    try {
      await this.gameService.abandonGame(data.gameId, data.userId);
      this.server.to(data.roomId).emit('player_abandoned', { userId: data.userId });
      await this.broadcastGameState(data.roomId, data.gameId);
    } catch (err: any) {
      this.logger.error(`abandon_game FALLO: ${err.message}`);
      client.emit('action_error', { message: err.message });
    }
  }

  private async emitRoomState(roomId: string) {
    const players = await this.roomsService.getPlayers(roomId);
    this.server.to(roomId).emit('room_state', {
      roomId,
      players: players.map((p) => ({
        userId: p.userId,
        username: p.user?.username,
        joinedAt: p.joinedAt,
      })),
    });
  }

  private async broadcastGameState(roomId: string, gameId: string) {
    const state = await this.gameService.getState(gameId);
    this.server.to(roomId).emit('public_state', CoupEngine.publicView(state));

    const sockets = await this.redis.hgetall(`room:${roomId}:sockets`);
    for (const [socketId, userId] of Object.entries(sockets)) {
      this.server.to(socketId).emit('your_hand', CoupEngine.privateHand(state, userId));
    }

    if (state.phase === 'finished') {
      this.server.to(roomId).emit('game_over', {
        winnerId: state.winnerId,
        winnerUsername: state.players.find(p => p.userId === state.winnerId)?.username,
      });
    }
  }
}