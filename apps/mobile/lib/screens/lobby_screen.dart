import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/game_provider.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

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
      backgroundColor: const Color(0xFF0f1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1a1d27),
        title: const Text('Coup Digital', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.admin_panel_settings, color: Colors.amber),
              tooltip: 'Gestion de usuarios',
              onPressed: () => Navigator.pushNamed(context, '/admin'),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white70),
            onPressed: () async {
              await _auth.logout();
              notifier.socket.disconnect();
              if (mounted) Navigator.pushReplacementNamed(context, '/');
            },
          ),
        ],
      ),
      body: _inLobby ? _buildWaitingRoom(notifier) : _buildJoinCreate(notifier),
    );
  }

  Widget _buildJoinCreate(GameNotifier notifier) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Hola, ${notifier.username ?? ''}',
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          Text('Rol: ${notifier.role ?? ''}',
              style: TextStyle(color: notifier.role == 'Free' ? Colors.orange : Colors.green, fontSize: 13)),
          const SizedBox(height: 24),

          if (notifier.role != 'Free') ...[
            const Text('Crear mesa', style: TextStyle(color: Colors.amber, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _field('Nombre de la mesa', _roomNameCtrl),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Máx. jugadores', style: TextStyle(color: Colors.white60, fontSize: 12)),
                Slider(
                  value: _maxPlayers.toDouble(),
                  min: 2, max: 12, divisions: 10,
                  activeColor: Colors.amber,
                  label: _maxPlayers.toString(),
                  onChanged: (v) => setState(() => _maxPlayers = v.toInt()),
                ),
              ])),
              Text('$_maxPlayers', style: const TextStyle(color: Colors.amber, fontSize: 18, fontWeight: FontWeight.bold)),
            ]),
            Row(children: [
              const Text('Modo reacción:', style: TextStyle(color: Colors.white60, fontSize: 13)),
              const SizedBox(width: 12),
              ChoiceChip(label: const Text('Timer'), selected: _reactionMode == 'timer',
                  selectedColor: Colors.amber, labelStyle: TextStyle(color: _reactionMode == 'timer' ? Colors.black : Colors.white70),
                  onSelected: (_) => setState(() => _reactionMode = 'timer')),
              const SizedBox(width: 8),
              ChoiceChip(label: const Text('Paso'), selected: _reactionMode == 'pass',
                  selectedColor: Colors.amber, labelStyle: TextStyle(color: _reactionMode == 'pass' ? Colors.black : Colors.white70),
                  onSelected: (_) => setState(() => _reactionMode = 'pass')),
            ]),
            if (_reactionMode == 'timer') ...[
              const SizedBox(height: 8),
              Row(children: [
                const Text('Tiempo:', style: TextStyle(color: Colors.white60, fontSize: 13)),
                Expanded(child: Slider(
                  value: _reactionTime.toDouble(), min: 5, max: 60, divisions: 11,
                  activeColor: Colors.amber, label: '${_reactionTime}s',
                  onChanged: (v) => setState(() => _reactionTime = v.toInt()),
                )),
                Text('${_reactionTime}s', style: const TextStyle(color: Colors.amber)),
              ]),
            ],
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: ElevatedButton.icon(
              onPressed: _loading ? null : () => _createRoom(notifier),
              icon: const Icon(Icons.add),
              label: const Text('Crear Mesa'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber.shade700, foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            )),
            const Divider(color: Colors.white12, height: 40),
          ],

          const Text('Unirse por código', style: TextStyle(color: Colors.amber, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: TextField(
              controller: _codeCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 20, letterSpacing: 4, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                hintText: '000000',
                hintStyle: const TextStyle(color: Colors.white24, letterSpacing: 4),
                filled: true, fillColor: const Color(0xFF252830),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.amber)),
              ),
            )),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: _loading ? null : () => _joinRoom(notifier),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: _loading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Unirse'),
            ),
          ]),

          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.red.shade900.withOpacity(0.3), borderRadius: BorderRadius.circular(8)),
              child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
            ),
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
            const Text('Sala de espera', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(color: const Color(0xFF252830), borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                const Text('Código: ', style: TextStyle(color: Colors.white54, fontSize: 14)),
                Text(notifier.roomCode ?? '', style: const TextStyle(color: Colors.amber, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 3)),
              ]),
            ),
          ]),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.builder(
              itemCount: notifier.lobbyPlayers.length,
              itemBuilder: (_, i) {
                final p = notifier.lobbyPlayers[i];
                final isMe = p['userId'] == notifier.userId;
                final isHost = p['userId'] == notifier.hostId;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isMe ? const Color(0xFF2a3040) : const Color(0xFF252830),
                    borderRadius: BorderRadius.circular(10),
                    border: isMe ? Border.all(color: Colors.amber.shade700, width: 1) : null,
                  ),
                  child: Row(children: [
                    const Icon(Icons.person, color: Colors.white54),
                    const SizedBox(width: 12),
                    Text(p['username'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 15)),
                    if (isMe) const Text(' (tú)', style: TextStyle(color: Colors.white54, fontSize: 13)),
                    if (isHost) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.star, color: Colors.amber, size: 16),
                    ],
                    const Spacer(),
                    if (notifier.isHost && !isMe && !isHost)
                      IconButton(
                        icon: const Icon(Icons.remove_circle, color: Colors.redAccent, size: 20),
                        onPressed: () => notifier.socket.kickPlayer(notifier.roomId!, notifier.userId!, p['userId']),
                      ),
                  ]),
                );
              },
            ),
          ),
          if (notifier.isHost)
            SizedBox(width: double.infinity, child: ElevatedButton.icon(
              onPressed: notifier.lobbyPlayers.length >= 2 ? notifier.startGame : null,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Iniciar Partida', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ))
          else
            const Text('Esperando que el anfitrión inicie la partida...', style: TextStyle(color: Colors.white54)),
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label, labelStyle: const TextStyle(color: Colors.white54),
        filled: true, fillColor: const Color(0xFF252830),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.amber)),
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