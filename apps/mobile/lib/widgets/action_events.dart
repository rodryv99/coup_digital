import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/game_state.dart';
import 'card_widget.dart';

/// Traduce nombres de cartas y acciones en ingles dentro de un texto.
String traducirTexto(String s) {
  const reemplazos = {
    'foreign_aid': 'Ayuda Exterior',
    'income': 'Ingresos',
    'tax': 'Impuestos',
    'assassinate': 'Asesinato',
    'steal': 'Robo',
    'exchange': 'Intercambio',
    'coup': 'Golpe de Estado',
    'Duke': 'Duque',
    'Assassin': 'Asesino',
    'Captain': 'Capitan',
    'Ambassador': 'Embajador',
    'Contessa': 'Condesa',
  };
  var out = s;
  reemplazos.forEach((en, es) => out = out.replaceAll(en, es));
  return out;
}

/// Busca el nombre (en ingles) de una carta mencionada en un texto.
String? _cartaEnTexto(String s) {
  for (final c in ['Duke', 'Assassin', 'Captain', 'Ambassador', 'Contessa']) {
    if (s.contains(c)) return c;
  }
  return null;
}

String? _cartaDeAccion(String action) {
  switch (action) {
    case 'tax': return 'Duke';
    case 'assassinate': return 'Assassin';
    case 'steal': return 'Captain';
    case 'exchange': return 'Ambassador';
    default: return null;
  }
}

/// Evento visual para el banner animado.
class ActionEvent {
  final String title;
  final String subtitle;
  final String? card;      // carta (nombre backend) para mostrar su imagen
  final IconData? icon;    // icono alternativo si no hay carta
  final Color color;
  final bool burst;        // explosion de estrellas (momentos de impacto)

  ActionEvent({
    required this.title,
    required this.subtitle,
    this.card,
    this.icon,
    required this.color,
    this.burst = false,
  });
}

/// Convierte una entrada del log del backend en un evento visual (o null si no se anima).
ActionEvent? eventFromLog(LogEntry e, PublicGameState st, String Function(String) nameOf) {
  final actor = nameOf(e.actorId);
  final r = e.result;

  // Fin de partida
  if (e.action == 'game_over') {
    String winner = '';
    if (st.winnerId != null) winner = nameOf(st.winnerId!);
    return ActionEvent(
      title: 'Fin de la partida',
      subtitle: winner.isNotEmpty ? '$winner gana' : traducirTexto(r),
      icon: Icons.emoji_events,
      color: Colors.amber,
      burst: true,
    );
  }

  // Perdida de influencia / eliminacion
  if (e.action == 'lose_influence') {
    final card = _cartaEnTexto(r);
    final eliminado = r.contains('eliminado');
    return ActionEvent(
      title: eliminado ? '$actor eliminado' : '$actor pierde influencia',
      subtitle: traducirTexto(r),
      card: card,
      icon: eliminado ? Icons.heart_broken : Icons.visibility,
      color: Colors.redAccent,
      burst: eliminado,
    );
  }

  // Desafios (a accion o a bloqueo)
  if (e.action == 'challenge' || e.action == 'challenge_block') {
    final fallo = r.contains('fall');
    return ActionEvent(
      title: fallo ? '$actor falla el desafio' : '$actor gana el desafio',
      subtitle: traducirTexto(r),
      card: _cartaEnTexto(r),
      icon: Icons.bolt,
      color: fallo ? Colors.redAccent : Colors.greenAccent,
      burst: true,
    );
  }

  // Bloqueos
  if (e.action == 'block' || r.toLowerCase().contains('bloquea')) {
    return ActionEvent(
      title: '$actor bloquea',
      subtitle: traducirTexto(r),
      card: _cartaEnTexto(r),
      icon: Icons.shield,
      color: Colors.orangeAccent,
    );
  }

  // Declaraciones de accion
  if (r.startsWith('Declara')) {
    IconData icon;
    Color color;
    bool burst = false;
    switch (e.action) {
      case 'coup':
        icon = Icons.local_fire_department; color = Colors.deepOrange; burst = true; break;
      case 'assassinate':
        icon = Icons.gps_fixed; color = Colors.red; break;
      case 'steal':
        icon = Icons.back_hand; color = Colors.blue; break;
      case 'exchange':
        icon = Icons.swap_horiz; color = Colors.teal; break;
      case 'tax':
        icon = Icons.account_balance; color = Colors.purple; break;
      case 'foreign_aid':
        icon = Icons.handshake; color = Colors.green; break;
      default:
        icon = Icons.monetization_on; color = Colors.amber;
    }
    return ActionEvent(
      title: actor,
      subtitle: traducirTexto(r),
      card: _cartaDeAccion(e.action),
      icon: icon,
      color: color,
      burst: burst,
    );
  }

  // Resoluciones con monedas u otros resultados
  return ActionEvent(
    title: actor,
    subtitle: traducirTexto(r),
    icon: Icons.monetization_on,
    color: Colors.amber,
  );
}

/// Overlay de banners animados estilo cartoon.
/// Encolar eventos con: key.currentState?.enqueue(evento)
class ActionBannerOverlay extends StatefulWidget {
  const ActionBannerOverlay({super.key});

  @override
  State<ActionBannerOverlay> createState() => ActionBannerOverlayState();
}

class ActionBannerOverlayState extends State<ActionBannerOverlay>
    with SingleTickerProviderStateMixin {
  final List<ActionEvent> _queue = [];
  ActionEvent? _current;
  late final AnimationController _ctrl;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 550));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void enqueue(ActionEvent e) {
    _queue.add(e);
    if (!_playing) _playNext();
  }

  Future<void> _playNext() async {
    if (_queue.isEmpty) {
      _playing = false;
      if (mounted) setState(() => _current = null);
      return;
    }
    _playing = true;
    final e = _queue.removeAt(0);
    if (!mounted) return;
    setState(() => _current = e);
    try {
      await _ctrl.forward(from: 0);                    // entrada con rebote
      await Future.delayed(const Duration(milliseconds: 4800)); // lectura (~5s en pantalla)
      if (!mounted) return;
      await _ctrl.animateBack(0, duration: const Duration(milliseconds: 180), curve: Curves.easeIn);
    } catch (_) {}
    if (!mounted) return;
    _playNext();
  }

  @override
  Widget build(BuildContext context) {
    final e = _current;
    if (e == null) return const SizedBox.shrink();

    return Positioned.fill(
      child: IgnorePointer(
        child: Center(
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) {
              final t = _ctrl.value;
              final scale = Curves.elasticOut.transform(t.clamp(0.0, 1.0));
              // bamboleo cartoon: pequena rotacion que se estabiliza
              final wobble = math.sin(t * math.pi * 3) * (1 - t) * 0.09;
              return Opacity(
                opacity: t.clamp(0.0, 1.0),
                child: Transform.rotate(
                  angle: wobble,
                  child: Transform.scale(
                    scale: 0.6 + 0.4 * scale,
                    child: _banner(e, t),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _banner(ActionEvent e, double t) {
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        // Explosion de estrellas para eventos de impacto
        if (e.burst)
          ...List.generate(8, (i) {
            final ang = i * math.pi / 4;
            final dist = 70 + 60 * Curves.easeOut.transform(t);
            return Positioned(
              left: 150 + math.cos(ang) * dist - 10,
              top: 70 + math.sin(ang) * dist * 0.7 - 10,
              child: Opacity(
                opacity: ((1 - t) * 1.4).clamp(0.0, 1.0),
                child: Transform.rotate(
                  angle: ang + t * 2,
                  child: Icon(Icons.star, color: e.color, size: 14 + 10 * (1 - t)),
                ),
              ),
            );
          }),
        Container(
          width: 300,
          constraints: const BoxConstraints(minHeight: 96),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [const Color(0xFF23262f), const Color(0xFF14161c)],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: e.color, width: 2.5),
            boxShadow: [
              BoxShadow(color: e.color.withOpacity(0.45), blurRadius: 24, spreadRadius: 2),
              const BoxShadow(color: Colors.black87, blurRadius: 16, offset: Offset(0, 8)),
            ],
          ),
          child: Row(
            children: [
              if (e.card != null)
                CardWidget(cardName: e.card!, width: 58, height: 84)
              else
                Container(
                  width: 58, height: 58,
                  decoration: BoxDecoration(
                    color: e.color.withOpacity(0.18),
                    shape: BoxShape.circle,
                    border: Border.all(color: e.color, width: 2),
                  ),
                  child: Icon(e.icon ?? Icons.info, color: e.color, size: 32),
                ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: e.color, fontSize: 17, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(e.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}