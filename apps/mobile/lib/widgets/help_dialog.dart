import 'package:flutter/material.dart';
import '../models/card_type.dart';

class HelpDialog extends StatefulWidget {
  const HelpDialog({super.key});

  @override
  State<HelpDialog> createState() => _HelpDialogState();
}

class _HelpDialogState extends State<HelpDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1a1d27),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 400,
        height: 500,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
              child: Row(
                children: [
                  const Text('Ayuda', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close, color: Colors.white70), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            TabBar(
              controller: _tabController,
              indicatorColor: Colors.amber,
              labelColor: Colors.amber,
              unselectedLabelColor: Colors.white60,
              tabs: const [Tab(text: 'Acciones'), Tab(text: 'Cartas')],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [_buildActionsTab(), _buildCardsTab()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsTab() {
    final actions = [
      ('Ingresos', 'Toma 1 moneda del tesoro. No puede ser bloqueado ni desafiado.', null),
      ('Ayuda Exterior', 'Toma 2 monedas del tesoro. Puede ser bloqueado por el Duke.', null),
      ('Golpe de Estado', 'Paga 7 monedas para eliminar una influencia rival. No puede ser bloqueado ni desafiado. Obligatorio con 10+ monedas.', null),
      ('Impuestos (Duke)', 'Toma 3 monedas del tesoro. Puede ser desafiado.', Colors.purple),
      ('Intercambio (Ambassador)', 'Intercambia cartas con el mazo. Puede ser desafiado.', Colors.green),
      ('Robo (Captain)', 'Roba 2 monedas a otro jugador. Puede ser desafiado o bloqueado por Captain/Ambassador.', Colors.blue),
      ('Asesinato (Assassin)', 'Paga 3 monedas para eliminar una influencia rival. Puede ser desafiado o bloqueado por Contessa.', Colors.blueGrey),
    ];
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: actions.length,
      separatorBuilder: (_, __) => const Divider(color: Colors.white12),
      itemBuilder: (_, i) {
        final (name, desc, color) = actions[i];
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 10, height: 10,
              margin: const EdgeInsets.only(top: 5, right: 8),
              decoration: BoxDecoration(
                color: color ?? Colors.amber,
                shape: BoxShape.circle,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 2),
                  Text(desc, style: const TextStyle(color: Colors.white60, fontSize: 12)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCardsTab() {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: CardType.values.length,
      separatorBuilder: (_, __) => const Divider(color: Colors.white12),
      itemBuilder: (_, i) {
        final card = CardType.values[i];
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 12, height: 12,
              margin: const EdgeInsets.only(top: 4, right: 8),
              decoration: BoxDecoration(color: Color(card.color), shape: BoxShape.circle),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(card.displayName, style: TextStyle(color: Color(card.color), fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 2),
                  Text(card.ability, style: const TextStyle(color: Colors.white60, fontSize: 12)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}