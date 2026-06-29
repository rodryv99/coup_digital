import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/game_provider.dart';
import '../models/game_state.dart';
import '../models/card_type.dart';
import '../widgets/card_widget.dart';
import '../widgets/help_dialog.dart';

String accionEnEspanol(String action) {
  switch (action) {
    case 'income': return 'Ingresos';
    case 'foreign_aid': return 'Ayuda Exterior';
    case 'coup': return 'Golpe de Estado';
    case 'tax': return 'Impuestos';
    case 'assassinate': return 'Asesinato';
    case 'steal': return 'Robo';
    case 'exchange': return 'Intercambio';
    default: return action;
  }
}

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  bool _cardsHidden = false;
  String? _pendingAction;
  List<String> _selectedExchangeCards = [];
  int _exchangeKeepCount = 0;
  bool _gameOverShown = false;

  @override
  void initState() {
    super.initState();
    final notifier = ref.read(gameProvider.notifier);
    notifier.socket.on('game_over', (data) {
      if (mounted && !_gameOverShown) {
        _gameOverShown = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showGameOverDialog(data);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameProvider);
    final notifier = ref.read(gameProvider.notifier);

    // Respaldo: si el estado dice 'finished' y aun no mostramos el dialogo, mostrarlo.
    if (gameState != null && gameState.phase == 'finished' && !_gameOverShown) {
      _gameOverShown = true;
      final winnerId = gameState.winnerId;
      String winnerName = 'Desconocido';
      if (winnerId != null) {
        try {
          winnerName = gameState.players.firstWhere((p) => p.userId == winnerId).username;
        } catch (_) {}
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showGameOverDialog({'winnerId': winnerId, 'winnerUsername': winnerName});
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0f1117),
      body: SafeArea(
        child: gameState == null
            ? const Center(child: CircularProgressIndicator(color: Colors.amber))
            : Column(
                children: [
                  _buildTopBar(gameState, notifier),
                  Expanded(child: _buildGameBody(gameState, notifier)),
                ],
              ),
      ),
    );
  }

  Widget _buildTopBar(PublicGameState state, GameNotifier notifier) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF1a1d27),
        border: Border(bottom: BorderSide(color: Color(0xFF2a2d37))),
      ),
      child: Row(
        children: [
          Text('Turno #${state.turnNumber}',
              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(width: 12),
          _phaseBadge(state.phase),
          if (state.reactionDeadline != null) ...[
            const SizedBox(width: 10),
            _TimerWidget(key: ValueKey(state.reactionDeadline), deadline: state.reactionDeadline!),
          ],
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.help_outline, color: Colors.white70),
            tooltip: 'Ayuda',
            onPressed: () => showDialog(context: context, builder: (_) => const HelpDialog()),
          ),
          IconButton(
            icon: const Icon(Icons.exit_to_app, color: Colors.redAccent),
            tooltip: 'Abandonar',
            onPressed: () => _confirmAbandon(notifier),
          ),
        ],
      ),
    );
  }

  Widget _buildGameBody(PublicGameState state, GameNotifier notifier) {
    final hand = notifier.privateHand;
    final me = state.players.firstWhere((p) => p.userId == notifier.userId,
        orElse: () => PlayerPublicState(userId: '', username: '', seatOrder: 0, coins: 0, influenceCount: 0, revealed: [], eliminated: false));

    final mustChooseInfluence = state.phase == 'awaiting_influence_loss' &&
        state.pendingInfluenceLoss?.userId == notifier.userId;

    return Column(
      children: [
        SizedBox(
          height: 175,
          child: _buildOpponents(state, notifier),
        ),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                if (state.phase == 'awaiting_reaction' || state.phase == 'awaiting_block_reaction')
                  _buildReactionZone(state, notifier),
                if (mustChooseInfluence)
                  Container(
                    margin: const EdgeInsets.all(8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3a0000),
                      border: Border.all(color: Colors.red),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Debes perder una influencia. Toca una de tus cartas abajo para revelarla.',
                      style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ),
                if (state.phase == 'awaiting_exchange' && hand?.pendingExchange != null)
                  _buildExchangeZone(hand!, notifier),
              ],
            ),
          ),
        ),
        _buildMyZone(state, me, hand, notifier, mustChooseInfluence),
      ],
    );
  }

  Widget _buildOpponents(PublicGameState state, GameNotifier notifier) {
    final opponents = state.players.where((p) => p.userId != notifier.userId).toList();
    return Padding(
      padding: const EdgeInsets.all(8),
      child: opponents.isEmpty
          ? const Center(child: Text('Esperando jugadores...', style: TextStyle(color: Colors.white54)))
          : ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: opponents.length,
              itemBuilder: (_, i) => _buildPlayerCard(opponents[i], state, notifier),
            ),
    );
  }

  Widget _buildPlayerCard(PlayerPublicState player, PublicGameState state, GameNotifier notifier) {
    final isCurrentTurn = player.userId == state.currentTurnUserId;
    return Container(
      width: 130,
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: player.eliminated ? const Color(0xFF1a1d27) : const Color(0xFF252830),
        borderRadius: BorderRadius.circular(12),
        border: isCurrentTurn ? Border.all(color: Colors.amber, width: 2) : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isCurrentTurn) const Icon(Icons.arrow_downward, color: Colors.amber, size: 14),
          Text(player.username,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: player.eliminated ? Colors.white38 : Colors.white,
                fontWeight: FontWeight.bold, fontSize: 12,
                decoration: player.eliminated ? TextDecoration.lineThrough : null,
              )),
          const SizedBox(height: 4),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.monetization_on, color: Colors.amber, size: 18),
            const SizedBox(width: 4),
            Text('${player.coins}', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 16)),
          ]),
          const SizedBox(height: 6),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 0; i < player.influenceCount; i++)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 2),
                child: CardWidget(cardName: 'back', faceDown: true, width: 34, height: 50),
              ),
          ]),
          if (player.revealed.isNotEmpty) ...[
            const SizedBox(height: 4),
            Wrap(spacing: 3, runSpacing: 3, alignment: WrapAlignment.center, children: player.revealed.map((c) {
              final ct = CardType.fromBackend(c);
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(color: Color(ct?.color ?? 0xFF555555), borderRadius: BorderRadius.circular(4)),
                child: Text(ct?.displayName ?? c, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
              );
            }).toList()),
          ],
          if (!player.eliminated && state.phase == 'awaiting_action' && _pendingAction != null) ...[
            const SizedBox(height: 6),
            SizedBox(width: double.infinity, child: OutlinedButton(
              onPressed: () {
                notifier.declareAction(_pendingAction!, targetId: player.userId);
                setState(() => _pendingAction = null);
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent, side: const BorderSide(color: Colors.redAccent),
                padding: const EdgeInsets.symmetric(vertical: 2),
                minimumSize: Size.zero,
              ),
              child: const Text('Elegir', style: TextStyle(fontSize: 11)),
            )),
          ],
        ],
      ),
    );
  }

  // Mini carta de referencia visual (la del personaje asociado a la accion/bloqueo)
  Widget _miniCardForCard(String? backendCard) {
    if (backendCard == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: CardWidget(cardName: backendCard, width: 48, height: 68),
    );
  }

  Widget _buildReactionZone(PublicGameState state, GameNotifier notifier) {
    final isActor = state.pendingAction?.actorId == notifier.userId;
    final isBlocker = state.pendingBlock?.blockerId == notifier.userId;
    final alreadyPassed = state.passedPlayers.contains(notifier.userId);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2a1a00),
        border: Border.all(color: Colors.orange),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (state.phase == 'awaiting_reaction' && state.pendingAction != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _miniCardForCard(CardType.cardForAction(state.pendingAction!.action)),
                Expanded(child: _reactionLabel(state, notifier)),
              ],
            ),
            if (!isActor) ...[
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: [
                if (['tax', 'assassinate', 'steal', 'exchange'].contains(state.pendingAction!.action))
                  _reactionBtn('Desafiar', Colors.red, alreadyPassed ? null : notifier.challenge),
                ..._blockButtons(state.pendingAction!.action, notifier, alreadyPassed),
                _reactionBtn(alreadyPassed ? 'Pasaste' : 'Pasar', Colors.blueGrey,
                    alreadyPassed ? null : notifier.pass),
              ]),
            ] else
              const Text('Esperando reacciones de otros jugadores...', style: TextStyle(color: Colors.white54, fontSize: 13)),
          ],
          if (state.phase == 'awaiting_block_reaction' && state.pendingBlock != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _miniCardForCard(state.pendingBlock!.claimedCard),
                Expanded(
                  child: Builder(builder: (_) {
                    final ct = CardType.fromBackend(state.pendingBlock!.claimedCard);
                    return Text('${_playerName(state, state.pendingBlock!.blockerId)} bloquea con ${ct?.displayName ?? state.pendingBlock!.claimedCard}',
                        style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold));
                  }),
                ),
              ],
            ),
            if (isActor) ...[
              const SizedBox(height: 8),
              Row(children: [
                _reactionBtn('Desafiar bloqueo', Colors.red, notifier.challengeBlock),
                const SizedBox(width: 8),
                _reactionBtn('Aceptar', Colors.blueGrey, notifier.acceptBlock),
              ]),
            ] else if (!isBlocker)
              const Text('El actor decidira si acepta o desafia el bloqueo.', style: TextStyle(color: Colors.white54, fontSize: 13)),
          ],
        ],
      ),
    );
  }

  Widget _buildExchangeZone(PrivateHand hand, GameNotifier notifier) {
    final pool = [...hand.influences, ...hand.pendingExchange!];
    _exchangeKeepCount = hand.influences.length;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF001a3a),
        border: Border.all(color: Colors.blue),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text('Elige $_exchangeKeepCount carta${_exchangeKeepCount > 1 ? 's' : ''} para quedarte',
              style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: pool.asMap().entries.map((e) {
            final idx = '${e.key}_${e.value}';
            final selected = _selectedExchangeCards.contains(idx);
            return CardWidget(
              cardName: e.value, width: 90, height: 130,
              selected: selected,
              onTap: () {
                setState(() {
                  if (selected) {
                    _selectedExchangeCards.remove(idx);
                  } else if (_selectedExchangeCards.length < _exchangeKeepCount) {
                    _selectedExchangeCards.add(idx);
                  }
                });
              },
            );
          }).toList()),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: _selectedExchangeCards.length == _exchangeKeepCount
                ? () {
                    final cards = _selectedExchangeCards.map((idx) {
                      final parts = idx.split('_');
                      return parts.sublist(1).join('_');
                    }).toList();
                    notifier.chooseExchange(cards);
                    setState(() => _selectedExchangeCards = []);
                  }
                : null,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
            child: Text('Confirmar (${_selectedExchangeCards.length}/$_exchangeKeepCount)'),
          ),
        ],
      ),
    );
  }

  Widget _buildMyZone(PublicGameState state, PlayerPublicState me, PrivateHand? hand, GameNotifier notifier, bool mustChooseInfluence) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: Color(0xFF1a1d27),
        border: Border(top: BorderSide(color: Color(0xFF2a2d37))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              const Text('Mis cartas', style: TextStyle(color: Colors.white70, fontSize: 13)),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF252830),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.monetization_on, color: Colors.amber, size: 26),
                      const SizedBox(width: 6),
                      Text('${me.coins}', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 22)),
                    ]),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _cardsHidden = !_cardsHidden),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: const Color(0xFF252830), borderRadius: BorderRadius.circular(8)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(_cardsHidden ? Icons.visibility_off : Icons.visibility, color: Colors.white54, size: 18),
                        const SizedBox(width: 4),
                        Text(_cardsHidden ? 'Mostrar' : 'Ocultar', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                      ]),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (mustChooseInfluence)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('Toca la carta que quieres perder',
                  style: TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold)),
            ),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (hand != null)
              ...hand.influences.map((c) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: CardWidget(
                  cardName: c,
                  faceDown: _cardsHidden && !mustChooseInfluence,
                  width: 170, height: 240,
                  onTap: mustChooseInfluence
                      ? () => _confirmLoseCard(c, notifier)
                      : null,
                ),
              ))
            else
              ...List.generate(me.influenceCount, (_) => const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: CardWidget(cardName: 'back', faceDown: true, width: 170, height: 240),
              )),
          ]),
          const SizedBox(height: 12),
          if (notifier.isMyTurn && state.phase == 'awaiting_action')
            _buildActionButtons(state, me, notifier)
          else if (!me.eliminated && state.phase == 'awaiting_action')
            Text('Turno de ${state.currentPlayer?.username ?? '...'}',
                style: const TextStyle(color: Colors.white54, fontSize: 13))
          else if (me.eliminated)
            const Text('Has sido eliminado', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          if (_pendingAction != null)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: const Color(0xFF2a1a00), borderRadius: BorderRadius.circular(8)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Flexible(child: Text('${accionEnEspanol(_pendingAction!)}: selecciona objetivo arriba',
                    style: const TextStyle(color: Colors.orange, fontSize: 12))),
                const SizedBox(width: 8),
                GestureDetector(onTap: () => setState(() => _pendingAction = null), child: const Icon(Icons.close, color: Colors.white54, size: 16)),
              ]),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(PublicGameState state, PlayerPublicState me, GameNotifier notifier) {
    final actions = [
      ('income', 'Ingresos +1', Icons.attach_money, false),
      ('foreign_aid', 'Ayuda Exterior +2', Icons.handshake, false),
      ('tax', 'Impuestos +3', Icons.account_balance, false),
      ('exchange', 'Intercambio', Icons.swap_horiz, false),
      ('steal', 'Robar', Icons.remove_circle, true),
      ('assassinate', 'Asesinar (3)', Icons.gavel, true),
      ('coup', 'Golpe (7)', Icons.flash_on, true),
    ];

    return Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.center, children: actions.map((a) {
      final (action, label, icon, needsTarget) = a;
      final disabled = me.eliminated ||
          (action == 'coup' && me.coins < 7) ||
          (action == 'assassinate' && me.coins < 3) ||
          (me.coins >= 10 && action != 'coup');

      return ElevatedButton.icon(
        onPressed: disabled ? null : () {
          if (needsTarget) {
            setState(() => _pendingAction = action);
          } else {
            notifier.declareAction(action);
          }
        },
        icon: Icon(icon, size: 14),
        label: Text(label, style: const TextStyle(fontSize: 11)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF8e44ad), foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }).toList());
  }

  Widget _reactionLabel(PublicGameState state, GameNotifier notifier) {
    final actorName = _playerName(state, state.pendingAction!.actorId);
    final targetName = state.pendingAction!.targetId != null
        ? _playerName(state, state.pendingAction!.targetId!)
        : null;
    final accion = accionEnEspanol(state.pendingAction!.action);

    final spans = <TextSpan>[
      TextSpan(text: actorName, style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
      TextSpan(text: ' declara $accion', style: const TextStyle(color: Colors.white70)),
    ];

    if (targetName != null) {
      spans.add(const TextSpan(text: ' contra ', style: TextStyle(color: Colors.white70)));
      spans.add(TextSpan(text: targetName, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)));
    }

    return RichText(text: TextSpan(children: spans));
  }

  List<Widget> _blockButtons(String action, GameNotifier notifier, bool disabled) {
    const blockCards = {
      'foreign_aid': ['Duke'],
      'assassinate': ['Contessa'],
      'steal': ['Captain', 'Ambassador'],
    };
    final cards = blockCards[action] ?? [];
    return cards.map((card) {
      final ct = CardType.fromBackend(card);
      return _reactionBtn('Bloquear (${ct?.displayName ?? card})', Colors.orange, disabled ? null : () => notifier.block(card));
    }).toList();
  }

  Widget _reactionBtn(String label, Color color, VoidCallback? onTap) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: onTap == null ? Colors.grey.shade800 : color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }

  Widget _phaseBadge(String phase) {
    const labels = {
      'awaiting_action': ('Accion', Colors.green),
      'awaiting_reaction': ('Reaccion', Colors.orange),
      'awaiting_block_reaction': ('Bloqueo', Colors.deepOrange),
      'awaiting_influence_loss': ('Perdida', Colors.red),
      'awaiting_exchange': ('Intercambio', Colors.blue),
      'finished': ('Fin', Colors.grey),
    };
    final (label, color) = labels[phase] ?? (phase, Colors.grey);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  String _playerName(PublicGameState state, String userId) {
    try { return state.players.firstWhere((p) => p.userId == userId).username; } catch (_) { return userId.length >= 6 ? userId.substring(0, 6) : userId; }
  }

  void _confirmLoseCard(String card, GameNotifier notifier) {
    final ct = CardType.fromBackend(card);
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF1a1d27),
        title: Text('Perder ${ct?.displayName ?? card}?', style: const TextStyle(color: Colors.white)),
        content: const Text('Esta carta quedara revelada y no podras usarla.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () { Navigator.pop(dialogCtx); notifier.chooseInfluence(card); },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  void _confirmAbandon(GameNotifier notifier) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF1a1d27),
        title: const Text('Abandonar?', style: TextStyle(color: Colors.white)),
        content: const Text('Seras eliminado de la partida.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              notifier.abandonGame();
              if (mounted) Navigator.pushReplacementNamed(context, '/lobby');
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Abandonar'),
          ),
        ],
      ),
    );
  }

  void _showGameOverDialog(dynamic data) {
    final winnerName = data['winnerUsername'] ?? data['winnerId'] ?? 'Desconocido';
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF1a1d27),
        title: const Text('Partida terminada!', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.emoji_events, color: Colors.amber, size: 48),
          const SizedBox(height: 12),
          Text('$winnerName gana la partida', style: const TextStyle(color: Colors.white, fontSize: 16), textAlign: TextAlign.center),
        ]),
        actions: [
          ElevatedButton(
            onPressed: () {
              _gameOverShown = false;
              ref.read(gameProvider.notifier).leaveGame();
              Navigator.pop(dialogCtx);
              if (mounted) Navigator.pushReplacementNamed(context, '/lobby');
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade700, foregroundColor: Colors.black),
            child: const Text('Volver al lobby', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _TimerWidget extends StatefulWidget {
  final int deadline;
  const _TimerWidget({super.key, required this.deadline});

  @override
  State<_TimerWidget> createState() => _TimerWidgetState();
}

class _TimerWidgetState extends State<_TimerWidget> {
  int _remaining = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _update();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _update());
  }

  void _update() {
    if (!mounted) {
      _timer?.cancel();
      return;
    }
    final r = ((widget.deadline - DateTime.now().millisecondsSinceEpoch) / 1000).ceil().clamp(0, 99);
    if (mounted) setState(() => _remaining = r);
    if (r <= 0) _timer?.cancel();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _remaining <= 5 ? Colors.red.shade900 : const Color(0xFF252830),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('${_remaining}s', style: TextStyle(
        color: _remaining <= 5 ? Colors.redAccent : Colors.amber,
        fontWeight: FontWeight.bold, fontSize: 16,
      )),
    );
  }
}