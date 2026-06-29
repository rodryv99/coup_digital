import { Entity, PrimaryColumn, Column } from 'typeorm';

@Entity('user_stats')
export class UserStatsEntity {
  @PrimaryColumn({ name: 'user_id' })
  userId: string;

  @Column({ name: 'games_played', default: 0 })
  gamesPlayed: number;

  @Column({ default: 0 })
  wins: number;

  @Column({ default: 0 })
  losses: number;

  @Column({ name: 'win_rate', type: 'numeric', precision: 5, scale: 2, default: 0 })
  winRate: number;

  @Column({ name: 'avg_players', type: 'numeric', precision: 4, scale: 2, nullable: true })
  avgPlayers: number;
}