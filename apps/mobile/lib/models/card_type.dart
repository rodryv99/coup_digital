enum CardType {
  duke,
  assassin,
  captain,
  ambassador,
  contessa;

  String get backendName {
    switch (this) {
      case CardType.duke: return 'Duke';
      case CardType.assassin: return 'Assassin';
      case CardType.captain: return 'Captain';
      case CardType.ambassador: return 'Ambassador';
      case CardType.contessa: return 'Contessa';
    }
  }

  String get displayName {
    switch (this) {
      case CardType.duke: return 'Duque';
      case CardType.assassin: return 'Asesino';
      case CardType.captain: return 'Capitán';
      case CardType.ambassador: return 'Embajador';
      case CardType.contessa: return 'Condesa';
    }
  }

  String get assetPath => 'cards/${name}.png';

  int get color {
    switch (this) {
      case CardType.duke: return 0xFF8E44AD;
      case CardType.assassin: return 0xFF2C3E50;
      case CardType.captain: return 0xFF2980B9;
      case CardType.ambassador: return 0xFF27AE60;
      case CardType.contessa: return 0xFFC0392B;
    }
  }

  String get ability {
    switch (this) {
      case CardType.duke: return 'Toma 3 monedas del tesoro (Impuestos). Bloquea Ayuda Exterior.';
      case CardType.assassin: return 'Paga 3 monedas para eliminar una influencia rival.';
      case CardType.captain: return 'Roba 2 monedas a otro jugador. Bloquea robos a ti.';
      case CardType.ambassador: return 'Intercambia cartas con el mazo. Bloquea robos a ti.';
      case CardType.contessa: return 'Bloquea asesinatos contra ti.';
    }
  }

  static CardType? fromBackend(String s) {
    try {
      return CardType.values.firstWhere((e) => e.backendName == s);
    } catch (_) {
      return null;
    }
  }

  // Devuelve el nombre de carta (backend) asociado a una accion, o null si no requiere carta.
  static String? cardForAction(String action) {
    switch (action) {
      case 'tax': return 'Duke';
      case 'assassinate': return 'Assassin';
      case 'steal': return 'Captain';
      case 'exchange': return 'Ambassador';
      default: return null; // income, foreign_aid, coup no requieren carta
    }
  }
}