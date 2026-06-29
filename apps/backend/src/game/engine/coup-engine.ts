import {
  Card, ActionType, GameState, PlayerState, GameConfig,
} from './types';
import { buildDeck, shuffle } from './deck';
import { ACTION_REQUIRED_CARD, isValidBlockCard } from './rules';

export interface InitPlayer {
  userId: string;
  username: string;
  seatOrder: number;
}

export class CoupEngine {

  // ========== Inicialización ==========

  static initGame(
    gameId: string, roomId: string, players: InitPlayer[], config?: GameConfig,
  ): GameState {
    if (players.length < 2 || players.length > 12) {
      throw new Error('La partida requiere entre 2 y 12 jugadores');
    }
    const deck = buildDeck(players.length);
    const ordered = [...players].sort((a, b) => a.seatOrder - b.seatOrder);

    const playerStates: PlayerState[] = ordered.map((p, idx) => ({
      userId: p.userId,
      username: p.username,
      seatOrder: idx,
      coins: 2,
      influences: [deck.pop()!, deck.pop()!],
      revealed: [],
      eliminated: false,
    }));

    const startIndex = Math.floor(Math.random() * playerStates.length);

    return {
      gameId,
      roomId,
      players: playerStates,
      deck,
      currentTurnIndex: startIndex,
      turnNumber: 1,
      phase: 'awaiting_action',
      config: config ?? { reactionMode: 'timer', reactionTimeSeconds: 30 },
      passedPlayers: [],
      log: [],
    };
  }

  // ========== Helpers ==========

  static clone(state: GameState): GameState {
    return JSON.parse(JSON.stringify(state));
  }

  static currentPlayer(state: GameState): PlayerState {
    return state.players[state.currentTurnIndex];
  }

  static getPlayer(state: GameState, userId: string): PlayerState | undefined {
    return state.players.find((p) => p.userId === userId);
  }

  static alivePlayers(state: GameState): PlayerState[] {
    return state.players.filter((p) => !p.eliminated);
  }

  // ========== Declarar acción ==========

  static declareAction(
    input: GameState, actorId: string, action: ActionType, targetId?: string,
  ): GameState {
    const state = this.clone(input);

    if (state.phase !== 'awaiting_action') {
      throw new Error('No es momento de declarar una acción');
    }

    const actor = this.currentPlayer(state);
    if (actor.userId !== actorId) throw new Error('No es tu turno');
    if (actor.eliminated) throw new Error('Estás eliminado');

    if (actor.coins >= 10 && action !== ActionType.Coup) {
      throw new Error('Con 10 o más monedas debes hacer Golpe de Estado');
    }

    // Income y Coup son inmediatos
    if (action === ActionType.Income) {
      actor.coins += 1;
      this.log(state, actor.userId, 'income', 'Ingresos: +1 moneda');
      return this.advanceTurn(state);
    }

    if (action === ActionType.Coup) {
      if (actor.coins < 7) throw new Error('Necesitas 7 monedas para un Golpe de Estado');
      const target = this.validateTarget(state, actor, targetId);
      actor.coins -= 7;
      this.log(state, actor.userId, 'coup', `Golpe de Estado contra ${target.username}`, target.userId);
      return this.requireInfluenceLoss(state, target.userId, 'coup');
    }

    // Validar objetivo para acciones dirigidas
    if (action === ActionType.Assassinate || action === ActionType.Steal) {
      this.validateTarget(state, actor, targetId);
    }

    // Pagar costos por adelantado
    if (action === ActionType.Assassinate) {
      if (actor.coins < 3) throw new Error('Necesitas 3 monedas para asesinar');
      actor.coins -= 3;
    }

    // Abrir ventana de reacción
    state.pendingAction = { actorId, action, targetId };
    state.passedPlayers = [];
    state.phase = 'awaiting_reaction';
    state.reactionDeadline = Date.now() + state.config.reactionTimeSeconds * 1000;

    this.log(
      state, actorId, action,
      `Declara ${action}${targetId ? ` contra ${this.getPlayer(state, targetId)?.username}` : ''}`,
      targetId,
    );

    return state;
  }

  // ========== Desafío de acción (CU-22) ==========

  static challenge(input: GameState, challengerId: string): GameState {
    const state = this.clone(input);

    if (state.phase !== 'awaiting_reaction') {
      throw new Error('No hay una acción que desafiar');
    }

    const pending = state.pendingAction!;
    const challenger = this.getPlayer(state, challengerId)!;
    const actor = this.getPlayer(state, pending.actorId)!;

    if (challenger.eliminated) throw new Error('Estás eliminado');
    if (challengerId === pending.actorId) throw new Error('No puedes desafiarte a ti mismo');

    const requiredCard = ACTION_REQUIRED_CARD[pending.action];
    if (!requiredCard) throw new Error('Esta acción no puede ser desafiada');

    const hasCard = actor.influences.includes(requiredCard);

    if (hasCard) {
      // Desafío falla: el actor tiene la carta, la devuelve y roba otra
      const idx = actor.influences.indexOf(requiredCard);
      actor.influences.splice(idx, 1);
      state.deck.push(requiredCard);
      state.deck = shuffle(state.deck);
      actor.influences.push(state.deck.pop()!);

      this.log(state, challengerId, 'challenge',
        `Desafió a ${actor.username} y falló — tenía ${requiredCard}`, pending.actorId);

      // El desafiante pierde influencia, luego se ejecuta la acción
      state.pendingInfluenceLoss = {
        userId: challengerId,
        cause: 'challenge_failed',
        afterResolution: 'execute_pending',
      };
      state.phase = 'awaiting_influence_loss';
      state.reactionDeadline = undefined;
      state.passedPlayers = [];

      return this.autoResolveInfluenceLoss(state);
    } else {
      // Desafío acierta: el actor no tiene la carta
      this.log(state, challengerId, 'challenge',
        `Desafió a ${actor.username} y acertó — no tenía ${requiredCard}`, pending.actorId);

      // El actor pierde influencia, acción cancelada
      state.pendingInfluenceLoss = {
        userId: pending.actorId,
        cause: 'challenge_succeeded',
        afterResolution: 'advance_turn',
      };
      state.phase = 'awaiting_influence_loss';
      state.reactionDeadline = undefined;
      state.passedPlayers = [];

      return this.autoResolveInfluenceLoss(state);
    }
  }

  // ========== Bloqueo (CU-23) ==========

  static block(input: GameState, blockerId: string, claimedCard: Card): GameState {
    const state = this.clone(input);

    if (state.phase !== 'awaiting_reaction') {
      throw new Error('No hay una acción que bloquear');
    }

    const pending = state.pendingAction!;
    const blocker = this.getPlayer(state, blockerId)!;

    if (blocker.eliminated) throw new Error('Estás eliminado');
    if (blockerId === pending.actorId) throw new Error('No puedes bloquearte a ti mismo');

    if (!isValidBlockCard(pending.action, claimedCard)) {
      throw new Error(`${claimedCard} no puede bloquear ${pending.action}`);
    }

    state.pendingBlock = { blockerId, claimedCard };
    state.phase = 'awaiting_block_reaction';
    state.passedPlayers = [];
    state.reactionDeadline = Date.now() + state.config.reactionTimeSeconds * 1000;

    this.log(state, blockerId, 'block', `Bloquea con ${claimedCard}`, pending.actorId);

    return state;
  }

  // ========== Pasar (ventana de reacción) ==========

  static pass(input: GameState, playerId: string): GameState {
    const state = this.clone(input);

    if (state.phase !== 'awaiting_reaction') {
      throw new Error('No hay una ventana de reacción activa');
    }

    const player = this.getPlayer(state, playerId);
    if (!player || player.eliminated) throw new Error('Jugador no válido');
    if (playerId === state.pendingAction?.actorId) throw new Error('El actor no necesita pasar');
    if (state.passedPlayers.includes(playerId)) throw new Error('Ya pasaste');

    state.passedPlayers.push(playerId);

    const eligible = this.alivePlayers(state)
      .filter((p) => p.userId !== state.pendingAction?.actorId);
    const allPassed = eligible.every((p) => state.passedPlayers.includes(p.userId));

    if (allPassed) {
      return this.executePendingAction(state);
    }

    return state;
  }

  // ========== Reacción a bloqueo ==========

  static acceptBlock(input: GameState, actorId: string): GameState {
    const state = this.clone(input);

    if (state.phase !== 'awaiting_block_reaction') {
      throw new Error('No hay un bloqueo pendiente');
    }
    if (actorId !== state.pendingAction?.actorId) {
      throw new Error('Solo el actor original puede aceptar el bloqueo');
    }

    this.log(state, actorId, 'accept_block', 'Aceptó el bloqueo');

    state.pendingAction = undefined;
    state.pendingBlock = undefined;
    state.reactionDeadline = undefined;
    state.passedPlayers = [];

    return this.advanceTurn(state);
  }

  static challengeBlock(input: GameState, challengerId: string): GameState {
    const state = this.clone(input);

    if (state.phase !== 'awaiting_block_reaction') {
      throw new Error('No hay un bloqueo que desafiar');
    }
    if (challengerId !== state.pendingAction?.actorId) {
      throw new Error('Solo el actor original puede desafiar el bloqueo');
    }

    const block = state.pendingBlock!;
    const blocker = this.getPlayer(state, block.blockerId)!;
    const hasCard = blocker.influences.includes(block.claimedCard);

    if (hasCard) {
      // El bloqueador tiene la carta → desafío falla
      const idx = blocker.influences.indexOf(block.claimedCard);
      blocker.influences.splice(idx, 1);
      state.deck.push(block.claimedCard);
      state.deck = shuffle(state.deck);
      blocker.influences.push(state.deck.pop()!);

      this.log(state, challengerId, 'challenge_block',
        `Desafió el bloqueo de ${blocker.username} y falló — tenía ${block.claimedCard}`,
        block.blockerId);

      // El actor pierde influencia, el bloqueo se mantiene
      state.pendingInfluenceLoss = {
        userId: challengerId,
        cause: 'block_challenge_failed',
        afterResolution: 'advance_turn',
      };
    } else {
      // El bloqueador no tiene la carta → desafío acierta
      this.log(state, challengerId, 'challenge_block',
        `Desafió el bloqueo de ${blocker.username} y acertó — no tenía ${block.claimedCard}`,
        block.blockerId);

      // El bloqueador pierde influencia, la acción procede
      state.pendingInfluenceLoss = {
        userId: block.blockerId,
        cause: 'block_challenge_succeeded',
        afterResolution: 'execute_pending',
      };
      state.pendingBlock = undefined;
    }

    state.phase = 'awaiting_influence_loss';
    state.reactionDeadline = undefined;
    state.passedPlayers = [];

    return this.autoResolveInfluenceLoss(state);
  }

  // ========== Pérdida de influencia (CU-24 / CU-25) ==========

  private static autoResolveInfluenceLoss(state: GameState): GameState {
    const pending = state.pendingInfluenceLoss!;
    const player = this.getPlayer(state, pending.userId)!;

    if (player.influences.length === 0 || player.eliminated) {
      state.pendingInfluenceLoss = undefined;
      if (pending.afterResolution === 'execute_pending') {
        return this.executePendingAction(state);
      }
      return this.advanceTurn(state);
    }

    if (player.influences.length === 1) {
      const card = player.influences.pop()!;
      player.revealed.push(card);
      player.eliminated = true;
      this.log(state, pending.userId, 'lose_influence', `Perdió ${card} y fue eliminado`);
      state.pendingInfluenceLoss = undefined;

      if (this.checkWin(state)) return state;

      if (pending.afterResolution === 'execute_pending') {
        return this.executePendingAction(state);
      }
      return this.advanceTurn(state);
    }

    // Tiene 2+ cartas: debe elegir
    return state;
  }

  static chooseInfluence(input: GameState, userId: string, card: Card): GameState {
    const state = this.clone(input);

    if (state.phase !== 'awaiting_influence_loss' || state.pendingInfluenceLoss?.userId !== userId) {
      throw new Error('No tienes una pérdida de influencia pendiente');
    }

    const player = this.getPlayer(state, userId)!;
    const idx = player.influences.indexOf(card);
    if (idx === -1) throw new Error('No tienes esa carta');

    player.influences.splice(idx, 1);
    player.revealed.push(card);
    if (player.influences.length === 0) player.eliminated = true;

    this.log(state, userId, 'lose_influence',
      `Perdió ${card}${player.eliminated ? ' y fue eliminado' : ''}`);

    const afterResolution = state.pendingInfluenceLoss!.afterResolution;
    state.pendingInfluenceLoss = undefined;

    if (this.checkWin(state)) return state;

    if (afterResolution === 'execute_pending') {
      return this.executePendingAction(state);
    }
    return this.advanceTurn(state);
  }

  // ========== Ejecutar acción pendiente ==========

  private static executePendingAction(state: GameState): GameState {
    const pending = state.pendingAction;
    if (!pending) return this.advanceTurn(state);

    const actor = this.getPlayer(state, pending.actorId)!;

    switch (pending.action) {
      case ActionType.ForeignAid:
        actor.coins += 2;
        this.log(state, actor.userId, 'foreign_aid', 'Ayuda Exterior: +2 monedas');
        break;

      case ActionType.Tax:
        actor.coins += 3;
        this.log(state, actor.userId, 'tax', 'Impuestos: +3 monedas');
        break;

      case ActionType.Steal: {
        const target = this.getPlayer(state, pending.targetId!)!;
        if (!target.eliminated) {
          const stolen = Math.min(2, target.coins);
          target.coins -= stolen;
          actor.coins += stolen;
          this.log(state, actor.userId, 'steal',
            `Robó ${stolen} moneda(s) a ${target.username}`, target.userId);
        }
        break;
      }

      case ActionType.Assassinate: {
        const target = this.getPlayer(state, pending.targetId!)!;
        if (!target.eliminated) {
          this.clearPending(state);
          return this.requireInfluenceLoss(state, target.userId, 'assassinated');
        }
        break;
      }

      case ActionType.Exchange: {
        const drawn: Card[] = [];
        if (state.deck.length > 0) drawn.push(state.deck.pop()!);
        if (state.deck.length > 0) drawn.push(state.deck.pop()!);
        state.phase = 'awaiting_exchange';
        state.pendingExchange = { userId: actor.userId, drawnCards: drawn };
        this.clearPending(state);
        this.log(state, actor.userId, 'exchange', 'Robó cartas del mazo para intercambiar');
        return state;
      }
    }

    this.clearPending(state);
    return this.advanceTurn(state);
  }

  private static requireInfluenceLoss(
    state: GameState, targetId: string, cause: string,
  ): GameState {
    const target = this.getPlayer(state, targetId)!;

    if (target.influences.length === 0 || target.eliminated) {
      return this.advanceTurn(state);
    }

    if (target.influences.length === 1) {
      const card = target.influences.pop()!;
      target.revealed.push(card);
      target.eliminated = true;
      this.log(state, targetId, 'lose_influence', `Perdió ${card} y fue eliminado`);
      if (this.checkWin(state)) return state;
      return this.advanceTurn(state);
    }

    state.phase = 'awaiting_influence_loss';
    state.pendingInfluenceLoss = { userId: targetId, cause, afterResolution: 'advance_turn' };
    return state;
  }

  // ========== Intercambio ==========

  static chooseExchange(input: GameState, userId: string, cardsToKeep: Card[]): GameState {
    const state = this.clone(input);

    if (state.phase !== 'awaiting_exchange' || state.pendingExchange?.userId !== userId) {
      throw new Error('No tienes un intercambio pendiente');
    }

    const player = this.getPlayer(state, userId)!;
    const drawn = state.pendingExchange.drawnCards;
    const pool = [...player.influences, ...drawn];
    const keepCount = player.influences.length;

    if (cardsToKeep.length !== keepCount) {
      throw new Error(`Debes quedarte con ${keepCount} carta(s)`);
    }

    const poolCopy = [...pool];
    for (const c of cardsToKeep) {
      const i = poolCopy.indexOf(c);
      if (i === -1) throw new Error('Selección de cartas inválida');
      poolCopy.splice(i, 1);
    }

    player.influences = [...cardsToKeep];
    state.deck.push(...poolCopy);
    state.deck = shuffle(state.deck);
    state.pendingExchange = undefined;

    this.log(state, userId, 'exchange', 'Completó el intercambio');
    return this.advanceTurn(state);
  }

  // ========== Timeout de reacción ==========

  static reactionTimeout(input: GameState): GameState {
    const state = this.clone(input);

    if (state.phase === 'awaiting_reaction') {
      return this.executePendingAction(state);
    }

    if (state.phase === 'awaiting_block_reaction') {
      this.log(state, state.pendingAction?.actorId ?? '', 'timeout', 'Aceptó el bloqueo por tiempo');
      this.clearPending(state);
      return this.advanceTurn(state);
    }

    return state;
  }

  // ========== Abandonar partida (CU-27) ==========

  static abandonGame(input: GameState, userId: string): GameState {
    const state = this.clone(input);
    const player = this.getPlayer(state, userId);
    if (!player || player.eliminated) return state;

    player.revealed.push(...player.influences);
    player.influences = [];
    player.eliminated = true;

    this.log(state, userId, 'abandon', `${player.username} abandonó la partida`);

    // Limpiar estados pendientes del jugador
    if (state.pendingInfluenceLoss?.userId === userId) {
      state.pendingInfluenceLoss = undefined;
    }
    if (state.pendingExchange?.userId === userId) {
      state.pendingExchange = undefined;
    }
    if (state.pendingAction?.actorId === userId) {
      this.clearPending(state);
    }

    if (this.checkWin(state)) return state;

    // Si era su turno, avanzar
    if (this.currentPlayer(state).eliminated) {
      return this.advanceTurn(state);
    }

    return state;
  }

  // ========== Internos ==========

  private static advanceTurn(state: GameState): GameState {
    if (this.checkWin(state)) return state;

    let next = state.currentTurnIndex;
    do {
      next = (next + 1) % state.players.length;
    } while (state.players[next].eliminated);

    state.currentTurnIndex = next;
    state.turnNumber += 1;
    state.phase = 'awaiting_action';
    this.clearPending(state);

    return state;
  }

  private static clearPending(state: GameState): void {
    state.pendingAction = undefined;
    state.pendingBlock = undefined;
    state.passedPlayers = [];
    state.reactionDeadline = undefined;
  }

  private static checkWin(state: GameState): boolean {
    const alive = this.alivePlayers(state);
    if (alive.length <= 1) {
      state.phase = 'finished';
      state.winnerId = alive[0]?.userId;
      this.clearPending(state);
      state.pendingInfluenceLoss = undefined;
      this.log(state, state.winnerId ?? 'none', 'game_over', 'Fin de la partida');
      return true;
    }
    return false;
  }

  private static validateTarget(
    state: GameState, actor: PlayerState, targetId?: string,
  ): PlayerState {
    if (!targetId) throw new Error('Esta acción requiere un objetivo');
    const target = this.getPlayer(state, targetId);
    if (!target) throw new Error('Objetivo no encontrado');
    if (target.userId === actor.userId) throw new Error('No puedes elegirte a ti mismo');
    if (target.eliminated) throw new Error('El objetivo ya está eliminado');
    return target;
  }

  private static log(
    state: GameState, actorId: string, action: string, result: string, targetId?: string,
  ): void {
    state.log.push({ turn: state.turnNumber, actorId, action, targetId, result });
  }

  // ========== Vistas (privacidad por diseño) ==========

  static publicView(state: GameState) {
    return {
      gameId: state.gameId,
      turnNumber: state.turnNumber,
      currentTurnUserId: state.players[state.currentTurnIndex]?.userId,
      phase: state.phase,
      pendingAction: state.pendingAction
        ? { actorId: state.pendingAction.actorId, action: state.pendingAction.action, targetId: state.pendingAction.targetId }
        : undefined,
      pendingBlock: state.pendingBlock
        ? { blockerId: state.pendingBlock.blockerId, claimedCard: state.pendingBlock.claimedCard }
        : undefined,
      pendingInfluenceLoss: state.pendingInfluenceLoss
        ? { userId: state.pendingInfluenceLoss.userId }
        : undefined,
      passedPlayers: state.passedPlayers,
      reactionDeadline: state.reactionDeadline,
      winnerId: state.winnerId,
      players: state.players.map((p) => ({
        userId: p.userId,
        username: p.username,
        seatOrder: p.seatOrder,
        coins: p.coins,
        influenceCount: p.influences.length,
        revealed: p.revealed,
        eliminated: p.eliminated,
      })),
      log: state.log,
    };
  }

  static privateHand(state: GameState, userId: string) {
    const p = this.getPlayer(state, userId);
    return {
      userId,
      influences: p?.influences ?? [],
      pendingExchange:
        state.pendingExchange?.userId === userId
          ? state.pendingExchange.drawnCards
          : undefined,
    };
  }

  static canRestart(state: GameState): boolean {
    return state.phase === 'finished';
  }
}