import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

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
      backgroundColor: CoupTheme.burgundyDeep,
      body: CoupBackground(
        child: SafeArea(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                decoration: BoxDecoration(
                  gradient: CoupTheme.panelGradient,
                  border: Border(bottom: BorderSide(color: CoupTheme.gold.withOpacity(0.5), width: 1.5)),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: CoupTheme.parchmentDim),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Text('Mi perfil', style: CoupTheme.titleMedium),
                  ],
                ),
              ),
              Container(
                color: CoupTheme.ink.withOpacity(0.3),
                child: TabBar(
                  controller: _tabs,
                  indicatorColor: CoupTheme.goldBright,
                  labelColor: CoupTheme.goldBright,
                  unselectedLabelColor: CoupTheme.parchmentDim,
                  labelStyle: const TextStyle(fontFamily: CoupTheme.displayFont, fontWeight: FontWeight.bold),
                  tabs: const [Tab(text: 'Estadísticas'), Tab(text: 'Historial')],
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: CoupTheme.gold))
                    : TabBarView(
                        controller: _tabs,
                        children: [_buildStats(), _buildHistory()],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStats() {
    if (_stats == null) return Center(child: Text('Sin datos', style: CoupTheme.subtitle));
    final s = _stats!;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            crossAxisCount: 2,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: 1.4,
            children: [
              _statCard('${s['gamesPlayed'] ?? 0}', 'Partidas jugadas', Icons.sports_esports, CoupTheme.parchment),
              _statCard('${s['wins'] ?? 0}', 'Victorias', Icons.emoji_events, CoupTheme.goldBright),
              _statCard('${s['losses'] ?? 0}', 'Derrotas', Icons.dangerous_outlined, CoupTheme.blood),
              _statCard('${(s['winRate'] ?? 0.0).toStringAsFixed(0)}%', '% Victorias', Icons.military_tech, CoupTheme.poison),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statCard(String value, String label, IconData icon, Color color) {
    return GoldFrame(
      padding: const EdgeInsets.all(12),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: color, size: 30),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(fontFamily: CoupTheme.displayFont, color: color, fontSize: 28, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: CoupTheme.label, textAlign: TextAlign.center),
      ]),
    );
  }

  Widget _buildHistory() {
    if (_history.isEmpty) {
      return Center(child: Text('Sin partidas finalizadas', style: CoupTheme.subtitle));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _history.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final g = _history[i];
        final won = g['won'] == true;
        final date = g['finishedAt'] != null
            ? DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(g['finishedAt']))
            : '';
        final accent = won ? CoupTheme.goldBright : CoupTheme.blood;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: CoupTheme.ink.withOpacity(0.3),
            borderRadius: BorderRadius.circular(10),
            border: Border(left: BorderSide(color: accent, width: 4)),
          ),
          child: Row(children: [
            Icon(won ? Icons.emoji_events : Icons.dangerous_outlined, color: accent, size: 30),
            const SizedBox(width: 14),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(won ? 'Victoria' : 'Derrota',
                  style: TextStyle(fontFamily: CoupTheme.displayFont, color: accent, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 2),
              Text('${g['deckVariant'] ?? 15} cartas · $date', style: CoupTheme.label),
            ]),
          ]),
        );
      },
    );
  }
}