import {
  Entity, PrimaryGeneratedColumn, Column, CreateDateColumn,
} from 'typeorm';

@Entity('action_logs')
export class ActionLogEntity {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'game_id' })
  gameId: string;

  @Column({ name: 'turn_number', type: 'smallint' })
  turnNumber: number;

  @Column({ name: 'actor_id' })
  actorId: string;

  @Column({ name: 'action_type', length: 50 })
  actionType: string;

  @Column({ name: 'target_id', nullable: true, type: 'uuid' })
  targetId: string | null;

  @Column({ nullable: true, length: 50 })
  result: string;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;
}