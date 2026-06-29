import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../config/api_config.dart';

class SocketService {
  IO.Socket? _socket;

  bool get isConnected => _socket?.connected ?? false;

  void connect() {
    // Si ya hay un socket, limpiarlo antes de crear uno nuevo
    if (_socket != null) {
      _socket!.dispose();
      _socket = null;
    }

    _socket = IO.io(ApiConfig.socketUrl, IO.OptionBuilder()
        .setTransports(['websocket'])
        .enableReconnection()
        .setReconnectionAttempts(999)
        .setReconnectionDelay(1000)
        .disableAutoConnect()
        .build());

    _socket!.onConnect((_) => print('[SOCKET] Conectado: ${_socket?.id}'));
    _socket!.onDisconnect((reason) => print('[SOCKET] Desconectado: $reason'));
    _socket!.onConnectError((e) => print('[SOCKET] Error de conexion: $e'));
    _socket!.onReconnect((_) => print('[SOCKET] Reconectado'));

    _socket!.connect();
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }

  void on(String event, Function(dynamic) handler) {
    _socket?.on(event, handler);
  }

  void off(String event) {
    _socket?.off(event);
  }

  void emit(String event, dynamic data) {
    final connected = _socket?.connected ?? false;
    print('[SOCKET] emit "$event" (conectado: $connected) -> $data');
    _socket?.emit(event, data);
  }

  // ---- Sala de espera ----
  void joinRoom(String roomId, String userId) {
    emit('join_room', {'roomId': roomId, 'userId': userId});
  }

  void startGame(String roomId, String hostId) {
    emit('start_game', {'roomId': roomId, 'hostId': hostId});
  }

  void restartGame(String roomId, String hostId) {
    emit('restart_game', {'roomId': roomId, 'hostId': hostId});
  }

  void kickPlayer(String roomId, String hostId, String targetUserId) {
    emit('kick_player', {'roomId': roomId, 'hostId': hostId, 'targetUserId': targetUserId});
  }

  void reconnectGame(String roomId, String userId) {
    emit('reconnect_game', {'roomId': roomId, 'userId': userId});
  }

  // ---- Acciones de juego ----
  void declareAction(String roomId, String gameId, String actorId, String action, {String? targetId}) {
    emit('declare_action', {
      'roomId': roomId, 'gameId': gameId, 'actorId': actorId,
      'action': action, if (targetId != null) 'targetId': targetId,
    });
  }

  void challenge(String roomId, String gameId, String challengerId) {
    emit('challenge', {'roomId': roomId, 'gameId': gameId, 'challengerId': challengerId});
  }

  void block(String roomId, String gameId, String blockerId, String card) {
    emit('block', {'roomId': roomId, 'gameId': gameId, 'blockerId': blockerId, 'card': card});
  }

  void pass(String roomId, String gameId, String playerId) {
    emit('pass', {'roomId': roomId, 'gameId': gameId, 'playerId': playerId});
  }

  void acceptBlock(String roomId, String gameId, String actorId) {
    emit('accept_block', {'roomId': roomId, 'gameId': gameId, 'actorId': actorId});
  }

  void challengeBlock(String roomId, String gameId, String challengerId) {
    emit('challenge_block', {'roomId': roomId, 'gameId': gameId, 'challengerId': challengerId});
  }

  void chooseInfluence(String roomId, String gameId, String userId, String card) {
    emit('choose_influence', {'roomId': roomId, 'gameId': gameId, 'userId': userId, 'card': card});
  }

  void chooseExchange(String roomId, String gameId, String userId, List<String> cards) {
    emit('choose_exchange', {'roomId': roomId, 'gameId': gameId, 'userId': userId, 'cards': cards});
  }

  void abandonGame(String roomId, String gameId, String userId) {
    emit('abandon_game', {'roomId': roomId, 'gameId': gameId, 'userId': userId});
  }
}