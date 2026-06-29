import {
  Entity, PrimaryGeneratedColumn, Column, CreateDateColumn,
} from 'typeorm';

@Entity('games')
export class GameEntity {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'room_id' })
  roomId: string;

  @Column({ name: 'deck_variant' })
  deckVariant: number;

  @CreateDateColumn({ name: 'started_at' })
  startedAt: Date;

  @Column({ name: 'finished_at', nullable: true, type: 'timestamptz' })
  finishedAt: Date;

  @Column({ name: 'winner_id', nullable: true })
  winnerId: string;
}