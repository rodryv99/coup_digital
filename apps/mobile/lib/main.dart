import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/login_screen.dart';
import 'screens/lobby_screen.dart';
import 'screens/game_screen.dart';
import 'screens/stats_screen.dart';
import 'screens/admin_screen.dart';
import 'services/auth_service.dart';
import 'providers/game_provider.dart';

void main() {
  runApp(const ProviderScope(child: CoupApp()));
}

class CoupApp extends StatelessWidget {
  const CoupApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Coup Digital',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.amber, brightness: Brightness.dark),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0f1117),
        fontFamily: 'Segoe UI',
      ),
      initialRoute: '/',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/': return MaterialPageRoute(builder: (_) => const AuthGate());
          case '/login': return MaterialPageRoute(builder: (_) => const LoginScreen());
          case '/lobby': return MaterialPageRoute(builder: (_) => const LobbyScreen());
          case '/game': return MaterialPageRoute(builder: (_) => const GameScreen());
          case '/stats': return MaterialPageRoute(builder: (_) => const StatsScreen());
          case '/admin': return MaterialPageRoute(builder: (_) => const AdminScreen());
          default: return MaterialPageRoute(builder: (_) => const LoginScreen());
        }
      },
    );
  }
}

class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  Future<String>? _routeFuture;

  @override
  void initState() {
    super.initState();
    _routeFuture = _decideRoute();
  }

  Future<String> _decideRoute() async {
    final auth = AuthService();
    final loggedIn = await auth.isLoggedIn();
    if (!loggedIn) return 'login';

    // Inicializa el provider (socket + datos de usuario)
    final notifier = ref.read(gameProvider.notifier);
    await notifier.init();

    // Intenta reconectar a una partida guardada
    final reconnected = await notifier.tryReconnect();
    if (reconnected) return 'game';

    return 'lobby';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _routeFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF0f1117),
            body: Center(child: CircularProgressIndicator(color: Colors.amber)),
          );
        }
        switch (snap.data) {
          case 'game': return const GameScreen();
          case 'lobby': return const LobbyScreen();
          default: return const LoginScreen();
        }
      },
    );
  }
}