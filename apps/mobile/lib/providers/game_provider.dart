import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/game_state.dart';
import '../services/socket_service.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';

class GameNotifier extends Notifier<GameState?> {
  final SocketService socket = SocketService();
  final AuthService auth = AuthService();
  final ApiService api = ApiService();

  String? userId;
  String? username;
  String? role;
  String? roomId;
  String? gameId;
  String? hostId;
  PrivateHand? privateHand;
  List<Map<String, dynamic>> lobbyPlayers = [];
  String? roomCode;

  static const _kRoomId = 'active_room_id';
  static const _kRoomCode = 'active_room_code';
  static const _kHostId = 'active_host_id';
  static const _kGameId = 'active_game_id';

  @override
  GameState? build() => null;

  Future<void> init() async {
    userId = await auth.getUserId();
    username = await auth.getUsername();
    role = await auth.getRole();
    socket.connect();
    _setupListeners();
  }

  void _setupListeners() {
    socket.on('room_state', (data) {
      lobbyPlayers = List<Map<String, dynamic>>.from(data['players'] ?? []);
      ref.notifyListeners();
    });

    socket.on('game_started', (data) {
      gameId = data['gameId'];
      _persistSession();
      ref.notifyListeners();
    });

    socket.on('public_state', (data) {
      state = PublicGameState.fromJson(data as Map<String, dynamic>);
    });

    socket.on('your_hand', (data) {
      privateHand = PrivateHand.fromJson(data as Map<String, dynamic>);
      ref.notifyListeners();
    });

    socket.on('game_over', (data) {
      _clearSession();
      ref.notifyListeners();
    });

    socket.on('player_abandoned', (_) => ref.notifyListeners());
    socket.on('player_kicked', (_) => ref.notifyListeners());
  }

  Future<void> _persistSession() async {
    final prefs = await SharedPreferences.getInstance();
    if (roomId != null) await prefs.setString(_kRoomId, roomId!);
    if (roomCode != null) await prefs.setString(_kRoomCode, roomCode!);
    if (hostId != null) await prefs.setString(_kHostId, hostId!);
    if (gameId != null) await prefs.setString(_kGameId, gameId!);
  }

  Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kRoomId);
    await prefs.remove(_kRoomCode);
    await prefs.remove(_kHostId);
    await prefs.remove(_kGameId);
  }

  // Devuelve true si habia una partida guardada y se reconecto.
  Future<bool> tryReconnect() async {
    final prefs = await SharedPreferences.getInstance();
    final savedRoom = prefs.getString(_kRoomId);
    final savedGame = prefs.getString(_kGameId);
    if (savedRoom == null || savedGame == null) return false;

    roomId = savedRoom;
    roomCode = prefs.getString(_kRoomCode);
    hostId = prefs.getString(_kHostId);
    gameId = savedGame;

    socket.reconnectGame(roomId!, userId!);
    return true;
  }

  void joinRoom(String rId, String code, String hId) {
    roomId = rId;
    roomCode = code;
    hostId = hId;
    _persistSession();
    socket.joinRoom(rId, userId!);
  }

  void startGame() {
    if (roomId != null && userId != null) socket.startGame(roomId!, userId!);
  }

  void restartGame() {
    if (roomId != null && userId != null) socket.restartGame(roomId!, userId!);
  }

  void declareAction(String action, {String? targetId}) {
    if (roomId != null && gameId != null && userId != null) {
      socket.declareAction(roomId!, gameId!, userId!, action, targetId: targetId);
    }
  }

  void challenge() {
    if (roomId != null && gameId != null && userId != null) {
      socket.challenge(roomId!, gameId!, userId!);
    }
  }

  void block(String card) {
    if (roomId != null && gameId != null && userId != null) {
      socket.block(roomId!, gameId!, userId!, card);
    }
  }

  void pass() {
    if (roomId != null && gameId != null && userId != null) {
      socket.pass(roomId!, gameId!, userId!);
    }
  }

  void acceptBlock() {
    if (roomId != null && gameId != null && userId != null) {
      socket.acceptBlock(roomId!, gameId!, userId!);
    }
  }

  void challengeBlock() {
    if (roomId != null && gameId != null && userId != null) {
      socket.challengeBlock(roomId!, gameId!, userId!);
    }
  }

  void chooseInfluence(String card) {
    if (roomId != null && gameId != null && userId != null) {
      socket.chooseInfluence(roomId!, gameId!, userId!, card);
    }
  }

  void chooseExchange(List<String> cards) {
    if (roomId != null && gameId != null && userId != null) {
      socket.chooseExchange(roomId!, gameId!, userId!, cards);
    }
  }

  void abandonGame() {
    if (roomId != null && gameId != null && userId != null) {
      socket.abandonGame(roomId!, gameId!, userId!);
    }
    _clearSession();
  }

  void leaveGame() {
    _clearSession();
    roomId = null;
    gameId = null;
    roomCode = null;
    hostId = null;
    state = null;
    privateHand = null;
  }

  void dispose() {
    socket.disconnect();
  }

  bool get isHost => userId == hostId;

  bool get isMyTurn =>
      state != null &&
      state!.currentTurnUserId == userId &&
      state!.phase == 'awaiting_action';
}

extension NotifierExt on GameNotifier {
  void notifyListeners() {
    state = state;
  }
}

final gameProvider = NotifierProvider<GameNotifier, GameState?>(() => GameNotifier());

typedef GameState = PublicGameState;