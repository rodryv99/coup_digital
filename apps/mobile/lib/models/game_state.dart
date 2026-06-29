class PlayerPublicState {
  final String userId;
  final String username;
  final int seatOrder;
  final int coins;
  final int influenceCount;
  final List<String> revealed;
  final bool eliminated;

  PlayerPublicState({
    required this.userId,
    required this.username,
    required this.seatOrder,
    required this.coins,
    required this.influenceCount,
    required this.revealed,
    required this.eliminated,
  });

  factory PlayerPublicState.fromJson(Map<String, dynamic> j) => PlayerPublicState(
    userId: j['userId'] ?? '',
    username: j['username'] ?? '',
    seatOrder: j['seatOrder'] ?? 0,
    coins: j['coins'] ?? 0,
    influenceCount: j['influenceCount'] ?? 0,
    revealed: List<String>.from(j['revealed'] ?? []),
    eliminated: j['eliminated'] ?? false,
  );
}

class PendingAction {
  final String actorId;
  final String action;
  final String? targetId;

  PendingAction({required this.actorId, required this.action, this.targetId});

  factory PendingAction.fromJson(Map<String, dynamic> j) => PendingAction(
    actorId: j['actorId'] ?? '',
    action: j['action'] ?? '',
    targetId: j['targetId'],
  );
}

class PendingBlock {
  final String blockerId;
  final String claimedCard;

  PendingBlock({required this.blockerId, required this.claimedCard});

  factory PendingBlock.fromJson(Map<String, dynamic> j) => PendingBlock(
    blockerId: j['blockerId'] ?? '',
    claimedCard: j['claimedCard'] ?? '',
  );
}

class PendingInfluenceLoss {
  final String userId;

  PendingInfluenceLoss({required this.userId});

  factory PendingInfluenceLoss.fromJson(Map<String, dynamic> j) =>
      PendingInfluenceLoss(userId: j['userId'] ?? '');
}

class LogEntry {
  final int turn;
  final String actorId;
  final String action;
  final String? targetId;
  final String result;

  LogEntry({
    required this.turn,
    required this.actorId,
    required this.action,
    this.targetId,
    required this.result,
  });

  factory LogEntry.fromJson(Map<String, dynamic> j) => LogEntry(
    turn: j['turn'] ?? 0,
    actorId: j['actorId'] ?? '',
    action: j['action'] ?? '',
    targetId: j['targetId'],
    result: j['result'] ?? '',
  );
}

class PublicGameState {
  final String gameId;
  final int turnNumber;
  final String currentTurnUserId;
  final String phase;
  final List<PlayerPublicState> players;
  final PendingAction? pendingAction;
  final PendingBlock? pendingBlock;
  final PendingInfluenceLoss? pendingInfluenceLoss;
  final List<String> passedPlayers;
  final int? reactionDeadline;
  final String? winnerId;
  final List<LogEntry> log;

  PublicGameState({
    required this.gameId,
    required this.turnNumber,
    required this.currentTurnUserId,
    required this.phase,
    required this.players,
    this.pendingAction,
    this.pendingBlock,
    this.pendingInfluenceLoss,
    required this.passedPlayers,
    this.reactionDeadline,
    this.winnerId,
    required this.log,
  });

  factory PublicGameState.fromJson(Map<String, dynamic> j) => PublicGameState(
    gameId: j['gameId'] ?? '',
    turnNumber: j['turnNumber'] ?? 0,
    currentTurnUserId: j['currentTurnUserId'] ?? '',
    phase: j['phase'] ?? '',
    players: (j['players'] as List? ?? [])
        .map((p) => PlayerPublicState.fromJson(p))
        .toList(),
    pendingAction: j['pendingAction'] != null
        ? PendingAction.fromJson(j['pendingAction'])
        : null,
    pendingBlock: j['pendingBlock'] != null
        ? PendingBlock.fromJson(j['pendingBlock'])
        : null,
    pendingInfluenceLoss: j['pendingInfluenceLoss'] != null
        ? PendingInfluenceLoss.fromJson(j['pendingInfluenceLoss'])
        : null,
    passedPlayers: List<String>.from(j['passedPlayers'] ?? []),
    reactionDeadline: j['reactionDeadline'],
    winnerId: j['winnerId'],
    log: (j['log'] as List? ?? []).map((e) => LogEntry.fromJson(e)).toList(),
  );

  PlayerPublicState? get currentPlayer {
    try {
      return players.firstWhere((p) => p.userId == currentTurnUserId);
    } catch (_) {
      return null;
    }
  }
}

class PrivateHand {
  final String userId;
  final List<String> influences;
  final List<String>? pendingExchange;

  PrivateHand({
    required this.userId,
    required this.influences,
    this.pendingExchange,
  });

  factory PrivateHand.fromJson(Map<String, dynamic> j) => PrivateHand(
    userId: j['userId'] ?? '',
    influences: List<String>.from(j['influences'] ?? []),
    pendingExchange: j['pendingExchange'] != null
        ? List<String>.from(j['pendingExchange'])
        : null,
  );
}