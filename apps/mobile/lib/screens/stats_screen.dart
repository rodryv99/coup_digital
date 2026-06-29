import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> with SingleTickerProviderStateMixin {
  final _api = ApiService();
  late TabController _tabs;
  Map<String, dynamic>? _stats;
  List<dynamic> _history = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  Future<void> _load() async {
    try {
      final stats = await _api.getMyStats();
      final history = await _api.getMyHistory();
      setState(() {
        _stats = stats;
        _history = history['data'] ?? [];
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0f1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1a1d27),
        title: const Text('Mi perfil', style: TextStyle(color: Colors.amber)),
        iconTheme: const IconThemeData(color: Colors.white70),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.amber,
          labelColor: Colors.amber,
          unselectedLabelColor: Colors.white54,
          tabs: const [Tab(text: 'Estadísticas'), Tab(text: 'Historial')],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.amber))
          : TabBarView(
              controller: _tabs,
              children: [_buildStats(), _buildHistory()],
            ),
    );
  }

  Widget _buildStats() {
    if (_stats == null) return const Center(child: Text('Sin datos', style: TextStyle(color: Colors.white54)));
    final s = _stats!;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.4,
            children: [
              _statCard('${s['gamesPlayed'] ?? 0}', 'Partidas jugadas', Icons.sports_esports),
              _statCard('${s['wins'] ?? 0}', 'Victorias', Icons.emoji_events, Colors.amber),
              _statCard('${s['losses'] ?? 0}', 'Derrotas', Icons.sentiment_dissatisfied, Colors.redAccent),
              _statCard('${(s['winRate'] ?? 0.0).toStringAsFixed(0)}%', '% Victorias', Icons.bar_chart, Colors.green),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statCard(String value, String label, IconData icon, [Color? color]) {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFF252830), borderRadius: BorderRadius.circular(12)),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: color ?? Colors.white54, size: 28),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(color: color ?? Colors.amber, fontSize: 26, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12), textAlign: TextAlign.center),
      ]),
    );
  }

  Widget _buildHistory() {
    if (_history.isEmpty) {
      return const Center(child: Text('Sin partidas finalizadas', style: TextStyle(color: Colors.white54)));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _history.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final g = _history[i];
        final won = g['won'] == true;
        final date = g['finishedAt'] != null
            ? DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(g['finishedAt']))
            : '';
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF252830),
            borderRadius: BorderRadius.circular(10),
            border: Border(left: BorderSide(color: won ? Colors.green : Colors.redAccent, width: 3)),
          ),
          child: Row(children: [
            Icon(won ? Icons.emoji_events : Icons.sentiment_dissatisfied,
                color: won ? Colors.amber : Colors.redAccent, size: 28),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(won ? 'Victoria' : 'Derrota',
                  style: TextStyle(color: won ? Colors.green : Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 2),
              Text('${g['deckVariant'] ?? 15} cartas · $date', style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ]),
          ]),
        );
      },
    );
  }
}