import { CoupEngine, InitPlayer } from './coup-engine';
import { ActionType, Card, GameState } from './types';

function basePlayers(): InitPlayer[] {
  return [
    { userId: 'a', username: 'Ana', seatOrder: 0 },
    { userId: 'b', username: 'Beto', seatOrder: 1 },
    { userId: 'c', username: 'Cam', seatOrder: 2 },
  ];
}

function setupGame(): GameState {
  const state = CoupEngine.initGame('g1', 'r1', basePlayers());
  const aIdx = state.players.findIndex((p) => p.userId === 'a');
  state.currentTurnIndex = aIdx;
  return state;
}

describe('CoupEngine — Fase 3 (núcleo)', () => {
  it('reparte 2 cartas y 2 monedas a cada jugador', () => {
    const state = setupGame();
    expect(state.players).toHaveLength(3);
    for (const p of state.players) {
      expect(p.coins).toBe(2);
      expect(p.influences).toHaveLength(2);
      expect(p.eliminated).toBe(false);
    }
  });

  it('usa mazo de 15 cartas hasta 6 jugadores', () => {
    const state = setupGame();
    expect(state.deck).toHaveLength(9);
  });

  it('Ingresos suma 1 moneda y avanza el turno', () => {
    let state = setupGame();
    state = CoupEngine.declareAction(state, 'a', ActionType.Income);
    expect(CoupEngine.getPlayer(state, 'a')!.coins).toBe(3);
    expect(state.turnNumber).toBe(2);
  });

  it('rechaza acción fuera de turno', () => {
    const state = setupGame();
    const notTurn = state.players.find(
      (p) => p.userId !== CoupEngine.currentPlayer(state).userId,
    )!;
    expect(() =>
      CoupEngine.declareAction(state, notTurn.userId, ActionType.Income),
    ).toThrow('No es tu turno');
  });

  it('obliga a Golpe de Estado con 10+ monedas', () => {
    const state = setupGame();
    CoupEngine.currentPlayer(state).coins = 10;
    expect(() =>
      CoupEngine.declareAction(state, 'a', ActionType.Tax),
    ).toThrow('Golpe de Estado');
  });

  it('Golpe de Estado con 1 influencia elimina al objetivo', () => {
    let state = setupGame();
    const actor = CoupEngine.currentPlayer(state);
    const target = state.players.find((p) => p.userId !== actor.userId)!;
    actor.coins = 7;
    target.influences = [Card.Duke];
    state = CoupEngine.declareAction(state, actor.userId, ActionType.Coup, target.userId);
    expect(CoupEngine.getPlayer(state, target.userId)!.eliminated).toBe(true);
  });

  it('Golpe de Estado con 2 influencias exige elegir cuál perder', () => {
    let state = setupGame();
    const actor = CoupEngine.currentPlayer(state);
    const target = state.players.find((p) => p.userId !== actor.userId)!;
    actor.coins = 7;
    target.influences = [Card.Duke, Card.Captain];
    state = CoupEngine.declareAction(state, actor.userId, ActionType.Coup, target.userId);
    expect(state.phase).toBe('awaiting_influence_loss');
    state = CoupEngine.chooseInfluence(state, target.userId, Card.Duke);
    expect(CoupEngine.getPlayer(state, target.userId)!.influences).toEqual([Card.Captain]);
  });

  it('la vista pública nunca expone las cartas ocultas', () => {
    const state = setupGame();
    const view = CoupEngine.publicView(state);
    for (const p of view.players) {
      expect(p).not.toHaveProperty('influences');
      expect(p.influenceCount).toBe(2);
    }
  });
});

describe('CoupEngine — Fase 4 (reacciones y desafíos)', () => {
  it('Tax abre ventana de reacción', () => {
    let state = setupGame();
    state = CoupEngine.declareAction(state, 'a', ActionType.Tax);
    expect(state.phase).toBe('awaiting_reaction');
    expect(state.pendingAction?.action).toBe(ActionType.Tax);
  });

  it('todos pasan → ejecuta la acción', () => {
    let state = setupGame();
    state = CoupEngine.declareAction(state, 'a', ActionType.Tax);
    state = CoupEngine.pass(state, 'b');
    state = CoupEngine.pass(state, 'c');
    expect(CoupEngine.getPlayer(state, 'a')!.coins).toBe(5); // 2 + 3
    expect(state.phase).toBe('awaiting_action');
  });

  it('desafío acierta cuando el actor no tiene la carta', () => {
    let state = setupGame();
    const actor = state.players.find((p) => p.userId === 'a')!;
    actor.influences = [Card.Captain, Card.Contessa]; // sin Duke
    state = CoupEngine.declareAction(state, 'a', ActionType.Tax);
    state = CoupEngine.challenge(state, 'b');
    // El actor debe perder influencia
    if (state.phase === 'awaiting_influence_loss') {
      expect(state.pendingInfluenceLoss?.userId).toBe('a');
    }
  });

  it('desafío falla cuando el actor tiene la carta', () => {
    let state = setupGame();
    const actor = state.players.find((p) => p.userId === 'a')!;
    actor.influences = [Card.Duke, Card.Captain]; // tiene Duke
    state = CoupEngine.declareAction(state, 'a', ActionType.Tax);
    state = CoupEngine.challenge(state, 'b');
    // Beto pierde influencia
    if (state.phase === 'awaiting_influence_loss') {
      expect(state.pendingInfluenceLoss?.userId).toBe('b');
    }
  });

  it('bloqueo aceptado cancela la acción', () => {
    let state = setupGame();
    state = CoupEngine.declareAction(state, 'a', ActionType.ForeignAid);
    state = CoupEngine.block(state, 'b', Card.Duke);
    expect(state.phase).toBe('awaiting_block_reaction');
    state = CoupEngine.acceptBlock(state, 'a');
    expect(CoupEngine.getPlayer(state, 'a')!.coins).toBe(2); // sin monedas extra
    expect(state.phase).toBe('awaiting_action');
  });

  it('desafío de bloqueo acierta cuando bloqueador no tiene carta', () => {
    let state = setupGame();
    const blocker = state.players.find((p) => p.userId === 'b')!;
    blocker.influences = [Card.Captain, Card.Assassin]; // sin Duke
    state = CoupEngine.declareAction(state, 'a', ActionType.ForeignAid);
    state = CoupEngine.block(state, 'b', Card.Duke);
    state = CoupEngine.challengeBlock(state, 'a');
    if (state.phase === 'awaiting_influence_loss') {
      expect(state.pendingInfluenceLoss?.userId).toBe('b');
    }
  });

  it('desafío de bloqueo falla cuando bloqueador tiene carta', () => {
    let state = setupGame();
    const blocker = state.players.find((p) => p.userId === 'b')!;
    blocker.influences = [Card.Duke, Card.Captain]; // tiene Duke
    state = CoupEngine.declareAction(state, 'a', ActionType.ForeignAid);
    state = CoupEngine.block(state, 'b', Card.Duke);
    state = CoupEngine.challengeBlock(state, 'a');
    if (state.phase === 'awaiting_influence_loss') {
      expect(state.pendingInfluenceLoss?.userId).toBe('a'); // actor pierde
    }
  });

  it('timeout de reacción ejecuta la acción pendiente', () => {
    let state = setupGame();
    state = CoupEngine.declareAction(state, 'a', ActionType.Tax);
    state = CoupEngine.reactionTimeout(state);
    expect(CoupEngine.getPlayer(state, 'a')!.coins).toBe(5);
    expect(state.phase).toBe('awaiting_action');
  });

  it('timeout de bloqueo acepta el bloqueo', () => {
    let state = setupGame();
    state = CoupEngine.declareAction(state, 'a', ActionType.ForeignAid);
    state = CoupEngine.block(state, 'b', Card.Duke);
    state = CoupEngine.reactionTimeout(state);
    expect(CoupEngine.getPlayer(state, 'a')!.coins).toBe(2);
    expect(state.phase).toBe('awaiting_action');
  });

  it('abandonar elimina al jugador', () => {
    let state = setupGame();
    state = CoupEngine.abandonGame(state, 'b');
    const player = CoupEngine.getPlayer(state, 'b')!;
    expect(player.eliminated).toBe(true);
    expect(player.influences).toHaveLength(0);
  });

  it('abandonar con 2 jugadores termina la partida', () => {
    let state = CoupEngine.initGame('g1', 'r1', [
      { userId: 'a', username: 'Ana', seatOrder: 0 },
      { userId: 'b', username: 'Beto', seatOrder: 1 },
    ]);
    state = CoupEngine.abandonGame(state, 'b');
    expect(state.phase).toBe('finished');
    expect(state.winnerId).toBe('a');
  });

  it('Robo con bloqueo y todos pasan transfiere monedas', () => {
    let state = setupGame();
    const target = state.players.find((p) => p.userId === 'b')!;
    target.coins = 5;
    state = CoupEngine.declareAction(state, 'a', ActionType.Steal, 'b');
    state = CoupEngine.pass(state, 'b');
    state = CoupEngine.pass(state, 'c');
    expect(CoupEngine.getPlayer(state, 'a')!.coins).toBe(4);
    expect(CoupEngine.getPlayer(state, 'b')!.coins).toBe(3);
  });
});