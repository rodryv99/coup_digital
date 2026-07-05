import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/game_provider.dart';
import '../models/game_state.dart';
import '../models/card_type.dart';
import '../widgets/card_widget.dart';
import '../widgets/help_dialog.dart';
import '../widgets/action_events.dart';

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
  int _lastLogLen = -1;
  final GlobalKey<ActionBannerOverlayState> _bannerKey = GlobalKey<ActionBannerOverlayState>();

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

    // Detecta nuevas entradas del log y dispara los banners animados.
    ref.listen<GameState?>(gameProvider, (prev, next) {
      if (next == null) return;
      if (prev == null || _lastLogLen < 0) {
        _lastLogLen = next.log.length; // primera carga o reconexion: sin animar historial
        return;
      }
      if (next.log.length > _lastLogLen) {
        for (var i = _lastLogLen; i < next.log.length; i++) {
          final ev = eventFromLog(next.log[i], next, (id) => _playerName(next, id));
          if (ev != null) _bannerKey.currentState?.enqueue(ev);
        }
        _lastLogLen = next.log.length;
      }
    });

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
        child: Stack(
          children: [
            gameState == null
                ? const Center(child: CircularProgressIndicator(color: Colors.amber))
                : Column(
                    children: [
                      _buildTopBar(gameState, notifier),
                      Expanded(child: _buildGameBody(gameState, notifier)),
                    ],
                  ),
            ActionBannerOverlay(key: _bannerKey),
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
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF252830),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.amber.withOpacity(0.5)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Builder(builder: (_) {
                  String? myAvatar;
                  try {
                    myAvatar = state.players.firstWhere((p) => p.userId == notifier.userId).avatar;
                  } catch (_) {}
                  final imgp = _avatarOf(myAvatar);
                  return imgp != null
                      ? CircleAvatar(radius: 9, backgroundImage: imgp)
                      : const Icon(Icons.person, color: Colors.amber, size: 14);
                }),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(notifier.username ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ]),
            ),
          ),
          const SizedBox(width: 4),
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
          height: 224,
          child: _buildOpponents(state, notifier),
        ),
        _buildFeedStrip(state),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
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
          CircleAvatar(
            radius: 15,
            backgroundColor: const Color(0xFF1a1d27),
            backgroundImage: _avatarOf(player.avatar),
            child: _avatarOf(player.avatar) == null
                ? const Icon(Icons.person, color: Colors.white38, size: 16)
                : null,
          ),
          const SizedBox(height: 3),
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
          if (_passStatus(state, player) != null) ...[
            const SizedBox(height: 3),
            _passStatus(state, player)!,
          ],
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
      padding: const EdgeInsets.fromLTRB(8, 10, 10, 10),
      decoration: const BoxDecoration(
        color: Color(0xFF1a1d27),
        border: Border(top: BorderSide(color: Color(0xFF2a2d37))),
      ),
      child: LayoutBuilder(builder: (context, constraints) {
        final narrow = constraints.maxWidth < 620;
        final cardW = narrow ? 92.0 : 150.0;
        final cardH = cardW * 10 / 7;

        final cards = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (mustChooseInfluence)
              const Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: Text('Toca la carta que quieres perder',
                    style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center),
              ),
            Row(mainAxisSize: MainAxisSize.min, children: [
              if (hand != null)
                ...hand.influences.map((c) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: CardWidget(
                    cardName: c,
                    faceDown: _cardsHidden && !mustChooseInfluence,
                    width: cardW, height: cardH,
                    onTap: mustChooseInfluence ? () => _confirmLoseCard(c, notifier) : null,
                  ),
                ))
              else
                ...List.generate(me.influenceCount, (_) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: CardWidget(cardName: 'back', faceDown: true, width: cardW, height: cardH),
                )),
            ]),
          ],
        );

        final middle = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: const Color(0xFF252830), borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.monetization_on, color: Colors.amber, size: 20),
                const SizedBox(width: 4),
                Text('${me.coins}', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 18)),
              ]),
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => setState(() => _cardsHidden = !_cardsHidden),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(color: const Color(0xFF252830), borderRadius: BorderRadius.circular(8)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(_cardsHidden ? Icons.visibility_off : Icons.visibility, color: Colors.white54, size: 15),
                  const SizedBox(width: 4),
                  Text(_cardsHidden ? 'Mostrar' : 'Ocultar', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                ]),
              ),
            ),
          ],
        );

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            cards,
            const SizedBox(width: 8),
            middle,
            const SizedBox(width: 10),
            Expanded(child: _bottomRightPanel(state, me, notifier)),
          ],
        );
      }),
    );
  }

  // Panel inferior derecho: muestra la situacion actual (a que estas respondiendo)
  // y debajo los botones en vertical, siempre visibles.
  Widget _bottomRightPanel(PublicGameState state, PlayerPublicState me, GameNotifier notifier) {
    final children = <Widget>[];

    Widget info(Widget content, {Color border = Colors.orange}) => Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: const Color(0xFF2a1a00),
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: content,
    );

    Widget fullBtn(String label, Color color, VoidCallback? onTap) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: SizedBox(width: double.infinity, child: _reactionBtn(label, color, onTap)),
    );

    if (me.eliminated) {
      children.add(info(const Text('Has sido eliminado',
          style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)), border: Colors.redAccent));
    } else if (state.phase == 'awaiting_reaction' && state.pendingAction != null) {
      final isActor = state.pendingAction!.actorId == notifier.userId;
      final alreadyPassed = state.passedPlayers.contains(notifier.userId);
      children.add(info(Row(children: [
        _miniCardForCard(CardType.cardForAction(state.pendingAction!.action)),
        Expanded(child: _reactionLabel(state, notifier)),
      ])));
      if (isActor) {
        children.add(const Text('Esperando reacciones de otros jugadores...',
            style: TextStyle(color: Colors.white54, fontSize: 12)));
      } else {
        if (['tax', 'assassinate', 'steal', 'exchange'].contains(state.pendingAction!.action)) {
          children.add(fullBtn('Desafiar', Colors.red, alreadyPassed ? null : notifier.challenge));
        }
        children.addAll(_blockButtonsFull(state.pendingAction!.action, notifier, alreadyPassed));
        children.add(fullBtn(alreadyPassed ? 'Pasaste' : 'Pasar', Colors.blueGrey,
            alreadyPassed ? null : notifier.pass));
      }
    } else if (state.phase == 'awaiting_block_reaction' && state.pendingBlock != null) {
      final isActor = state.pendingAction?.actorId == notifier.userId;
      final ct = CardType.fromBackend(state.pendingBlock!.claimedCard);
      children.add(info(Row(children: [
        _miniCardForCard(state.pendingBlock!.claimedCard),
        Expanded(child: Text(
          '${_playerName(state, state.pendingBlock!.blockerId)} bloquea con ${ct?.displayName ?? state.pendingBlock!.claimedCard}',
          style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 13))),
      ])));
      if (isActor) {
        children.add(fullBtn('Desafiar bloqueo', Colors.red, notifier.challengeBlock));
        children.add(fullBtn('Aceptar bloqueo', Colors.blueGrey, notifier.acceptBlock));
      } else {
        children.add(const Text('El actor decidira si acepta o desafia el bloqueo.',
            style: TextStyle(color: Colors.white54, fontSize: 12)));
      }
    } else if (state.phase == 'awaiting_action') {
      if (notifier.isMyTurn) {
        children.add(info(const Text('Tu turno: elige una accion',
            style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 13)), border: Colors.amber));
        children.add(_buildActionButtons(state, me, notifier));
      } else {
        children.add(info(Text('Turno de ${state.currentPlayer?.username ?? '...'}',
            style: const TextStyle(color: Colors.white70, fontSize: 13)), border: Colors.white24));
      }
    }

    if (_pendingAction != null) {
      children.add(Container(
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: const Color(0xFF2a1a00), borderRadius: BorderRadius.circular(8)),
        child: Row(children: [
          Flexible(child: Text('${accionEnEspanol(_pendingAction!)}: selecciona objetivo arriba',
              style: const TextStyle(color: Colors.orange, fontSize: 11))),
          const SizedBox(width: 6),
          GestureDetector(onTap: () => setState(() => _pendingAction = null),
              child: const Icon(Icons.close, color: Colors.white54, size: 16)),
        ]),
      ));
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  List<Widget> _blockButtonsFull(String action, GameNotifier notifier, bool disabled) {
    const blockCards = {
      'foreign_aid': ['Duke'],
      'assassinate': ['Contessa'],
      'steal': ['Captain', 'Ambassador'],
    };
    final cards = blockCards[action] ?? [];
    return cards.map<Widget>((card) {
      final ct = CardType.fromBackend(card);
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: SizedBox(
          width: double.infinity,
          child: _reactionBtn('Bloquear (${ct?.displayName ?? card})', Colors.orange,
              disabled ? null : () => notifier.block(card)),
        ),
      );
    }).toList();
  }

  Widget _buildActionButtons(PublicGameState state, PlayerPublicState me, GameNotifier notifier) {
    final actions = [
      ('income', 'Ingresos +1', Icons.attach_money, false),
      ('foreign_aid', 'Ayuda Ext. +2', Icons.handshake, false),
      ('tax', 'Impuestos +3', Icons.account_balance, false),
      ('exchange', 'Intercambio', Icons.swap_horiz, false),
      ('steal', 'Robar', Icons.remove_circle, true),
      ('assassinate', 'Asesinar (3)', Icons.gavel, true),
      ('coup', 'Golpe (7)', Icons.flash_on, true),
    ];

    return LayoutBuilder(builder: (context, box) {
      final cols = box.maxWidth < 230 ? 1 : 2;
      return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: cols,
      mainAxisSpacing: 6,
      crossAxisSpacing: 6,
      childAspectRatio: cols == 1 ? 4.6 : 3.0,
      children: actions.map((a) {
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
          icon: Icon(icon, size: 13),
          label: FittedBox(fit: BoxFit.scaleDown, child: Text(label, style: const TextStyle(fontSize: 11))),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF8e44ad), foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }).toList(),
    );
    });
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
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        minimumSize: const Size(64, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: FittedBox(fit: BoxFit.scaleDown, child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold))),
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

  // Indicador de quien ya paso durante la fase de reaccion.
  Widget? _passStatus(PublicGameState state, PlayerPublicState player) {
    if (state.phase != 'awaiting_reaction' || player.eliminated) return null;
    if (state.pendingAction?.actorId == player.userId) return null; // el actor no reacciona
    final passed = state.passedPlayers.contains(player.userId);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: passed ? Colors.green.withOpacity(0.18) : Colors.white10,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: passed ? Colors.greenAccent : Colors.white24, width: 1),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(passed ? Icons.check_circle : Icons.hourglass_top,
            color: passed ? Colors.greenAccent : Colors.white38, size: 11),
        const SizedBox(width: 3),
        Text(passed ? 'Paso' : 'Pensando',
            style: TextStyle(
                color: passed ? Colors.greenAccent : Colors.white38,
                fontSize: 9, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  // Tira con las ultimas acciones + boton de historial completo.
  Widget _buildFeedStrip(PublicGameState state) {
    if (state.log.isEmpty) return const SizedBox.shrink();
    final recent = state.log.length <= 3 ? state.log : state.log.sublist(state.log.length - 3);
    return Container(
      height: 30,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              reverse: true,
              children: recent.reversed.map((e) {
                final txt = '${_playerName(state, e.actorId)}: ${traducirTexto(e.result)}';
                return Container(
                  margin: const EdgeInsets.only(left: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF252830),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Text(txt,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white60, fontSize: 11)),
                );
              }).toList(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.history, color: Colors.amber, size: 20),
            tooltip: 'Historial de la partida',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 34, minHeight: 30),
            onPressed: () => _showFullLog(state),
          ),
        ],
      ),
    );
  }

  void _showFullLog(PublicGameState state) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1a1d27),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Historial de la partida',
                style: TextStyle(color: Colors.amber, fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.separated(
                reverse: true,
                itemCount: state.log.length,
                separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 10),
                itemBuilder: (_, i) {
                  final e = state.log[state.log.length - 1 - i];
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: const Color(0xFF252830), borderRadius: BorderRadius.circular(6)),
                        child: Text('T${e.turn}', style: const TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('${_playerName(state, e.actorId)}: ${traducirTexto(e.result)}',
                            style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  ImageProvider? _avatarOf(String? avatar) {
    if (avatar == null || avatar.isEmpty) return null;
    try {
      final b64 = avatar.contains(',') ? avatar.split(',').last : avatar;
      return MemoryImage(base64Decode(b64));
    } catch (_) {
      return null;
    }
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