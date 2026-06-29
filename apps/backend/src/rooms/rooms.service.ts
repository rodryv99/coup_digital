import {
  Injectable, NotFoundException, BadRequestException,
  ForbiddenException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import * as QRCode from 'qrcode';
import { Room, RoomStatus } from './entities/room.entity';
import { RoomPlayer } from './entities/room-player.entity';
import { CreateRoomDto } from './dto/create-room.dto';
import { RedisService } from '../redis/redis.service';
import { Role } from '../common/enums/role.enum';
import { User } from '../users/entities/user.entity';

@Injectable()
export class RoomsService {
  constructor(
    @InjectRepository(Room) private roomRepo: Repository<Room>,
    @InjectRepository(RoomPlayer) private playerRepo: Repository<RoomPlayer>,
    private redis: RedisService,
  ) {}

  private generateCode(): string {
    return Math.floor(100000 + Math.random() * 900000).toString();
  }

  async create(dto: CreateRoomDto, user: User): Promise<Room> {
    if (user.role === Role.Free) {
      throw new ForbiddenException('Solo usuarios Pro o Admin pueden crear mesas');
    }

    let code = this.generateCode();
    let exists = await this.roomRepo.findOne({ where: { code } });
    while (exists) {
      code = this.generateCode();
      exists = await this.roomRepo.findOne({ where: { code } });
    }

    const qrPayload = JSON.stringify({ code, app: 'coup-digital' });
    const qrDataUrl = await QRCode.toDataURL(qrPayload);

    const room = this.roomRepo.create({
      ...dto,
      code,
      qrPayload: qrDataUrl,
      hostId: user.id,
    });

    const saved = await this.roomRepo.save(room);

    await this.redis.set(
      `room:${saved.id}`,
      JSON.stringify({ status: 'waiting', players: [] }),
    );

    await this.addPlayer(saved.id, user.id);
    return saved;
  }

  async findByCode(code: string): Promise<Room> {
    const room = await this.roomRepo.findOne({ where: { code } });
    if (!room) throw new NotFoundException('Mesa no encontrada');
    return room;
  }

  async findById(id: string): Promise<Room> {
    const room = await this.roomRepo.findOne({ where: { id } });
    if (!room) throw new NotFoundException('Mesa no encontrada');
    return room;
  }

  async joinByCode(code: string, userId: string): Promise<Room> {
    const room = await this.findByCode(code);
    if (room.status !== RoomStatus.Waiting) {
      throw new BadRequestException('La partida ya comenzó o finalizó');
    }
    const players = await this.playerRepo.find({ where: { roomId: room.id } });
    if (players.length >= room.maxPlayers) {
      throw new BadRequestException('La mesa está llena');
    }
    const alreadyIn = players.find(p => p.userId === userId);
    if (!alreadyIn) {
      await this.addPlayer(room.id, userId);
    }
    return room;
  }

  async addPlayer(roomId: string, userId: string): Promise<void> {
    const player = this.playerRepo.create({ roomId, userId });
    await this.playerRepo.save(player);
    await this.redis.sadd(`room:${roomId}:players`, userId);
  }

  async removePlayer(roomId: string, userId: string): Promise<void> {
    await this.playerRepo.delete({ roomId, userId });
    await this.redis.srem(`room:${roomId}:players`, userId);
  }

  async getPlayers(roomId: string): Promise<RoomPlayer[]> {
    return this.playerRepo.find({
      where: { roomId },
      relations: ['user'],
    });
  }

  async kickPlayer(roomId: string, hostId: string, targetUserId: string): Promise<void> {
    const room = await this.findById(roomId);
    if (room.hostId !== hostId) {
      throw new ForbiddenException('Solo el anfitrión puede expulsar jugadores');
    }
    if (targetUserId === hostId) {
      throw new BadRequestException('El anfitrión no puede expulsarse a sí mismo');
    }
    await this.removePlayer(roomId, targetUserId);
  }

  async startGame(roomId: string, hostId: string): Promise<void> {
    const room = await this.findById(roomId);
    if (room.hostId !== hostId) {
      throw new ForbiddenException('Solo el anfitrión puede iniciar la partida');
    }
    const players = await this.getPlayers(roomId);
    if (players.length < 2) {
      throw new BadRequestException('Se necesitan al menos 2 jugadores');
    }
    await this.roomRepo.update(roomId, { status: RoomStatus.InProgress });
  }

  async resetToWaiting(roomId: string): Promise<void> {
    await this.roomRepo.update(roomId, { status: RoomStatus.Waiting });
  }

  async isHost(roomId: string, userId: string): Promise<boolean> {
    const room = await this.findById(roomId);
    return room.hostId === userId;
  }
}