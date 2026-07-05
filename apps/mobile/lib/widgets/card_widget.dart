import 'package:flutter/material.dart';
import '../models/card_type.dart';

class CardWidget extends StatelessWidget {
  final String cardName; // nombre en inglés del backend, o 'back'
  final bool faceDown;
  final bool selected;
  final VoidCallback? onTap;
  final double width;
  final double height;

  const CardWidget({
    super.key,
    required this.cardName,
    this.faceDown = false,
    this.selected = false,
    this.onTap,
    this.width = 90,
    this.height = 130,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? Colors.amber : Colors.transparent,
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
            if (selected)
              BoxShadow(
                color: Colors.amber.withOpacity(0.5),
                blurRadius: 12,
                spreadRadius: 2,
              ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: faceDown ? _buildBack() : _buildFront(),
        ),
      ),
    );
  }

Widget _buildBack() {
    return Image.asset(
      'assets/cards/back.png',
      fit: BoxFit.cover,
      width: width,
      height: height,
      errorBuilder: (_, __, ___) => _buildFallbackBack(),
    );
  }

  Widget _buildFront() {
    final cardType = CardType.fromBackend(cardName);
    return Image.asset(
      'assets/cards/${cardName.toLowerCase()}.png',
      fit: BoxFit.cover,
      width: width,
      height: height,
      errorBuilder: (_, __, ___) => _buildFallbackFront(cardType),
    );
  }

  Widget _buildFallbackBack() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1a1d27), Color(0xFF2a2d37)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(Icons.style, color: Colors.amber.shade700, size: width * 0.4),
      ),
    );
  }

  Widget _buildFallbackFront(CardType? cardType) {
    final color = Color(cardType?.color ?? 0xFF555555);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.7)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_cardIcon(cardType), color: Colors.white, size: width * 0.35),
            SizedBox(height: height * 0.06),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                cardType?.displayName ?? cardName,
                style: TextStyle(color: Colors.white, fontSize: width * 0.13, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _cardIcon(CardType? cardType) {
    final icons = {
      CardType.duke: Icons.account_balance,
      CardType.assassin: Icons.gavel,
      CardType.captain: Icons.anchor,
      CardType.ambassador: Icons.handshake,
      CardType.contessa: Icons.favorite,
    };
    return icons[cardType] ?? Icons.help;
  }
}