import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/game_provider.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class LobbyScreen extends ConsumerStatefulWidget {
  const LobbyScreen({super.key});

  @override
  ConsumerState<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends ConsumerState<LobbyScreen> {
  final _api = ApiService();
  final _auth = AuthService();
  final _roomNameCtrl = TextEditingController(text: 'Mi mesa');
  final _codeCtrl = TextEditingController();
  int _maxPlayers = 4;
  String _reactionMode = 'timer';
  int _reactionTime = 30;
  bool _inLobby = false;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final notifier = ref.read(gameProvider.notifier);
    notifier.socket.on('game_started', (_) {
      if (mounted) Navigator.pushReplacementNamed(context, '/game');
    });
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(gameProvider.notifier);
    ref.watch(gameProvider);

    return Scaffold(
      backgroundColor: CoupTheme.burgundyDeep,
      body: CoupBackground(
        child: SafeArea(
          child: Column(
            children: [
              _topBar(notifier),
              Expanded(
                child: _inLobby ? _buildWaitingRoom(notifier) : _buildJoinCreate(notifier),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar(GameNotifier notifier) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        gradient: CoupTheme.panelGradient,
        border: Border(bottom: BorderSide(color: CoupTheme.gold.withOpacity(0.5), width: 1.5)),
      ),
      child: Row(
        children: [
          Text('Coup Digital', style: CoupTheme.titleMedium),
          const Spacer(),
          if ((notifier.role ?? '') == 'Admin')
            IconButton(
              icon: const Icon(Icons.admin_panel_settings, color: CoupTheme.goldBright),
              tooltip: 'Gestión de usuarios',
              onPressed: () => Navigator.pushNamed(context, '/admin'),
            ),
          IconButton(
            icon: const Icon(Icons.bar_chart, color: CoupTheme.goldBright),
            tooltip: 'Mi perfil',
            onPressed: () => Navigator.pushNamed(context, '/stats'),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: CoupTheme.parchmentDim),
            tooltip: 'Salir',
            onPressed: () async {
              await _auth.logout();
              notifier.socket.disconnect();
              if (mounted) Navigator.pushReplacementNamed(context, '/');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildJoinCreate(GameNotifier notifier) {
    final isFree = notifier.role == 'Free';
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Hola, ${notifier.username ?? ''}', style: CoupTheme.titleMedium),
          const SizedBox(height: 2),
          Row(
            children: [
              Icon(Icons.shield_moon, size: 14, color: isFree ? CoupTheme.parchmentDim : CoupTheme.goldBright),
              const SizedBox(width: 6),
              Text('Rango: ${notifier.role ?? ''}',
                  style: TextStyle(color: isFree ? CoupTheme.parchmentDim : CoupTheme.goldBright, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 22),

          if (!isFree) ...[
            GoldFrame(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.add_circle_outline, color: CoupTheme.goldBright, size: 20),
                    const SizedBox(width: 8),
                    Text('Crear mesa', style: CoupTheme.titleMedium.copyWith(fontSize: 18)),
                  ]),
                  const SizedBox(height: 16),
                  CoupField(label: 'Nombre de la mesa', controller: _roomNameCtrl, icon: Icons.edit_outlined),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Máx. jugadores', style: CoupTheme.label),
                      Slider(
                        value: _maxPlayers.toDouble(),
                        min: 2, max: 12, divisions: 10,
                        activeColor: CoupTheme.goldBright,
                        inactiveColor: CoupTheme.goldDark.withOpacity(0.4),
                        label: _maxPlayers.toString(),
                        onChanged: (v) => setState(() => _maxPlayers = v.toInt()),
                      ),
                    ])),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: CoupTheme.ink.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: CoupTheme.gold.withOpacity(0.5)),
                      ),
                      child: Text('$_maxPlayers', style: const TextStyle(color: CoupTheme.goldBright, fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    Text('Modo reacción:', style: CoupTheme.label),
                    const SizedBox(width: 12),
                    _choiceChip('Timer', _reactionMode == 'timer', () => setState(() => _reactionMode = 'timer')),
                    const SizedBox(width: 8),
                    _choiceChip('Paso', _reactionMode == 'pass', () => setState(() => _reactionMode = 'pass')),
                  ]),
                  if (_reactionMode == 'timer') ...[
                    const SizedBox(height: 8),
                    Row(children: [
                      Text('Tiempo:', style: CoupTheme.label),
                      Expanded(child: Slider(
                        value: _reactionTime.toDouble(), min: 5, max: 60, divisions: 11,
                        activeColor: CoupTheme.goldBright,
                        inactiveColor: CoupTheme.goldDark.withOpacity(0.4),
                        label: '${_reactionTime}s',
                        onChanged: (v) => setState(() => _reactionTime = v.toInt()),
                      )),
                      Text('${_reactionTime}s', style: const TextStyle(color: CoupTheme.goldBright)),
                    ]),
                  ],
                  const SizedBox(height: 16),
                  GoldButton(
                    label: 'Crear Mesa',
                    icon: Icons.add,
                    loading: _loading,
                    onPressed: _loading ? null : () => _createRoom(notifier),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          GoldFrame(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.vpn_key_outlined, color: CoupTheme.goldBright, size: 20),
                  const SizedBox(width: 8),
                  Text('Unirse por código', style: CoupTheme.titleMedium.copyWith(fontSize: 18)),
                ]),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(child: CoupField(
                    label: '',
                    hint: '000000',
                    controller: _codeCtrl,
                    keyboardType: TextInputType.number,
                    textStyle: const TextStyle(color: CoupTheme.parchment, fontSize: 22, letterSpacing: 6, fontWeight: FontWeight.bold),
                  )),
                  const SizedBox(width: 12),
                  GoldButton(
                    label: 'Unirse',
                    expand: false,
                    loading: _loading,
                    onPressed: _loading ? null : () => _joinRoom(notifier),
                  ),
                ]),
              ],
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: 16),
            CoupError(_error!),
          ],
        ],
      ),
    );
  }

  Widget _buildWaitingRoom(GameNotifier notifier) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(children: [
            Text('Sala de espera', style: CoupTheme.titleMedium),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: CoupTheme.ink.withOpacity(0.45),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: CoupTheme.gold.withOpacity(0.6)),
              ),
              child: Row(children: [
                Text('Código: ', style: CoupTheme.label),
                Text(notifier.roomCode ?? '', style: const TextStyle(color: CoupTheme.goldBright, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 4)),
              ]),
            ),
          ]),
          const SizedBox(height: 18),
          Expanded(
            child: ListView.builder(
              itemCount: notifier.lobbyPlayers.length,
              itemBuilder: (_, i) {
                final p = notifier.lobbyPlayers[i];
                final isMe = p['userId'] == notifier.userId;
                final isHost = p['userId'] == notifier.hostId;
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: isMe ? CoupTheme.panelGradient : null,
                    color: isMe ? null : CoupTheme.ink.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isMe ? CoupTheme.goldBright : CoupTheme.goldDark.withOpacity(0.4),
                      width: isMe ? 1.5 : 1,
                    ),
                  ),
                  child: Row(children: [
                    Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(
                        color: CoupTheme.ink.withOpacity(0.5),
                        shape: BoxShape.circle,
                        border: Border.all(color: isHost ? CoupTheme.goldBright : CoupTheme.goldDark.withOpacity(0.6)),
                      ),
                      child: Icon(isHost ? Icons.workspace_premium : Icons.person, color: isHost ? CoupTheme.goldBright : CoupTheme.parchmentDim, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Text(p['username'] ?? '', style: const TextStyle(color: CoupTheme.parchment, fontSize: 16, fontWeight: FontWeight.w600)),
                    if (isMe) Text(' (tú)', style: CoupTheme.label),
                    if (isHost) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.star, color: CoupTheme.goldBright, size: 16),
                    ],
                    const Spacer(),
                    if (notifier.isHost && !isMe && !isHost)
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, color: CoupTheme.blood, size: 22),
                        onPressed: () => notifier.socket.kickPlayer(notifier.roomId!, notifier.userId!, p['userId']),
                      ),
                  ]),
                );
              },
            ),
          ),
          if (notifier.isHost)
            GoldButton(
              label: 'Iniciar Partida',
              icon: Icons.play_arrow,
              onPressed: notifier.lobbyPlayers.length >= 2 ? notifier.startGame : null,
            )
          else
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: CoupTheme.ink.withOpacity(0.3),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: CoupTheme.goldDark.withOpacity(0.4)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: CoupTheme.gold),
                  ),
                  const SizedBox(width: 12),
                  Text('Esperando al anfitrión...', style: CoupTheme.subtitle),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _choiceChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          gradient: selected ? CoupTheme.goldButton : null,
          color: selected ? null : CoupTheme.ink.withOpacity(0.4),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? CoupTheme.goldBright : CoupTheme.goldDark.withOpacity(0.5)),
        ),
        child: Text(label, style: TextStyle(
          color: selected ? CoupTheme.ink : CoupTheme.parchmentDim,
          fontWeight: FontWeight.bold, fontSize: 13)),
      ),
    );
  }

  Future<void> _createRoom(GameNotifier notifier) async {
    setState(() { _loading = true; _error = null; });
    try {
      final room = await _api.createRoom(
        name: _roomNameCtrl.text.trim(),
        maxPlayers: _maxPlayers,
        reactionMode: _reactionMode,
        reactionTimeSeconds: _reactionTime,
      );
      notifier.joinRoom(room['id'], room['code'], room['hostId']);
      setState(() => _inLobby = true);
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _joinRoom(GameNotifier notifier) async {
    final code = _codeCtrl.text.trim();
    if (code.length != 6) { setState(() => _error = 'El código debe tener 6 dígitos'); return; }
    setState(() { _loading = true; _error = null; });
    try {
      final room = await _api.joinRoom(code);
      notifier.joinRoom(room['id'], room['code'], room['hostId']);
      setState(() => _inLobby = true);
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      setState(() => _loading = false);
    }
  }
}