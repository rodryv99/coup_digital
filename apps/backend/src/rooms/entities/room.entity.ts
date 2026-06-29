import {
  Entity, PrimaryGeneratedColumn, Column,
  CreateDateColumn, ManyToOne, JoinColumn,
} from 'typeorm';
import { User } from '../../users/entities/user.entity';

export enum RoomStatus {
  Waiting = 'waiting',
  InProgress = 'in_progress',
  Finished = 'finished',
}

export enum ReactionMode {
  Timer = 'timer',
  Pass = 'pass',
}

@Entity('rooms')
export class Room {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ length: 6, unique: true })
  code: string;

  @Column({ name: 'qr_payload', nullable: true, type: 'text' })
  qrPayload: string;

  @Column({ name: 'host_id' })
  hostId: string;

  @ManyToOne(() => User)
  @JoinColumn({ name: 'host_id' })
  host: User;

  @Column({ length: 100 })
  name: string;

  @Column({ name: 'max_players', default: 6 })
  maxPlayers: number;

  @Column({ name: 'turn_limit_seconds', nullable: true, type: 'smallint' })
  turnLimitSeconds: number;

  @Column({ name: 'reaction_mode', type: 'enum', enum: ReactionMode, default: ReactionMode.Timer })
  reactionMode: ReactionMode;

  @Column({ name: 'reaction_time_seconds', nullable: true, type: 'smallint' })
  reactionTimeSeconds: number;

  @Column({ type: 'enum', enum: RoomStatus, default: RoomStatus.Waiting })
  status: RoomStatus;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;
}