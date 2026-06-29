export enum Card {
  Duke = 'Duke',
  Assassin = 'Assassin',
  Captain = 'Captain',
  Ambassador = 'Ambassador',
  Contessa = 'Contessa',
}

export enum ActionType {
  Income = 'income',
  ForeignAid = 'foreign_aid',
  Coup = 'coup',
  Tax = 'tax',
  Assassinate = 'assassinate',
  Steal = 'steal',
  Exchange = 'exchange',
}

export type GamePhase =
  | 'awaiting_action'
  | 'awaiting_reaction'
  | 'awaiting_block_reaction'
  | 'awaiting_influence_loss'
  | 'awaiting_exchange'
  | 'finished';

export type AfterInfluenceLoss = 'execute_pending' | 'advance_turn';

export interface PlayerState {
  userId: string;
  username: string;
  seatOrder: number;
  coins: number;
  influences: Card[];
  revealed: Card[];
  eliminated: boolean;
}

export interface PendingAction {
  actorId: string;
  action: ActionType;
  targetId?: string;
}

export interface PendingBlock {
  blockerId: string;
  claimedCard: Card;
}

export interface PendingInfluenceLoss {
  userId: string;
  cause: string;
  afterResolution: AfterInfluenceLoss;
}

export interface PendingExchange {
  userId: string;
  drawnCards: Card[];
}

export interface GameLogEntry {
  turn: number;
  actorId: string;
  action: string;
  targetId?: string;
  result: string;
}

export interface GameConfig {
  reactionMode: 'timer' | 'pass';
  reactionTimeSeconds: number;
}

export interface GameState {
  gameId: string;
  roomId: string;
  players: PlayerState[];
  deck: Card[];
  currentTurnIndex: number;
  turnNumber: number;
  phase: GamePhase;
  config: GameConfig;

  pendingAction?: PendingAction;
  pendingBlock?: PendingBlock;
  pendingInfluenceLoss?: PendingInfluenceLoss;
  pendingExchange?: PendingExchange;
  passedPlayers: string[];
  reactionDeadline?: number;

  winnerId?: string;
  log: GameLogEntry[];
}