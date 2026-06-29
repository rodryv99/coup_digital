import {
  Entity, PrimaryColumn, Column,
  CreateDateColumn, ManyToOne, JoinColumn,
} from 'typeorm';
import { Room } from './room.entity';
import { User } from '../../users/entities/user.entity';

@Entity('room_players')
export class RoomPlayer {
  @PrimaryColumn({ name: 'room_id' })
  roomId: string;

  @PrimaryColumn({ name: 'user_id' })
  userId: string;

  @ManyToOne(() => Room)
  @JoinColumn({ name: 'room_id' })
  room: Room;

  @ManyToOne(() => User)
  @JoinColumn({ name: 'user_id' })
  user: User;

  @Column({ name: 'seat_order', nullable: true, type: 'smallint' })
  seatOrder: number;

  @CreateDateColumn({ name: 'joined_at' })
  joinedAt: Date;
}