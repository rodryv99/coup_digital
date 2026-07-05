import 'package:flutter/material.dart';

/// Sistema de diseño "Coup Digital" — estética de traición renacentista.
/// Paleta: granate profundo, oro viejo, pergamino, verde veneno, sangre.
/// No contiene lógica de negocio: solo colores, estilos y widgets decorativos.
class CoupTheme {
  // ---- Paleta ----
  static const Color burgundyDeep   = Color(0xFF2B0A10); // fondo más oscuro
  static const Color burgundy        = Color(0xFF4A0E1A); // fondo principal
  static const Color burgundyPanel   = Color(0xFF3A0C16); // paneles
  static const Color goldBright      = Color(0xFFE8C065); // oro claro (acentos)
  static const Color gold            = Color(0xFFC79A45); // oro medio
  static const Color goldDark        = Color(0xFF8A6A2E); // oro sombra
  static const Color parchment       = Color(0xFFEAD9B0); // texto claro
  static const Color parchmentDim    = Color(0xFFB8A37E); // texto secundario
  static const Color blood           = Color(0xFFB23A3A); // peligro / error
  static const Color poison          = Color(0xFF4F8A6B); // confirmar / éxito
  static const Color ink             = Color(0xFF1A0508); // sombras profundas

  // ---- Tipografía ----
  // Usamos las fuentes serif del sistema para un look de manuscrito sin assets extra.
  static const String displayFont = 'serif';

  static TextStyle titleLarge = const TextStyle(
    fontFamily: displayFont,
    color: goldBright,
    fontSize: 34,
    fontWeight: FontWeight.bold,
    letterSpacing: 1.5,
    shadows: [Shadow(color: Colors.black54, offset: Offset(0, 2), blurRadius: 4)],
  );

  static TextStyle titleMedium = const TextStyle(
    fontFamily: displayFont,
    color: goldBright,
    fontSize: 22,
    fontWeight: FontWeight.bold,
    letterSpacing: 1.0,
  );

  static TextStyle subtitle = const TextStyle(
    fontFamily: displayFont,
    color: parchmentDim,
    fontSize: 15,
    fontStyle: FontStyle.italic,
    letterSpacing: 0.5,
  );

  static TextStyle body = const TextStyle(
    color: parchment,
    fontSize: 14,
  );

  static TextStyle label = const TextStyle(
    color: parchmentDim,
    fontSize: 12,
    letterSpacing: 0.5,
  );

  // ---- Gradientes ----
  static const LinearGradient bgGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [burgundy, burgundyDeep],
  );

  static const LinearGradient goldButton = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [goldBright, gold, goldDark],
  );

  static const LinearGradient panelGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF45101C), Color(0xFF2E0810)],
  );
}

/// Fondo de pantalla con degradado granate y viñeta sutil.
class CoupBackground extends StatelessWidget {
  final Widget child;
  const CoupBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: CoupTheme.bgGradient),
      child: Stack(
        children: [
          // Viñeta radial oscura en las esquinas
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  radius: 1.1,
                  colors: [
                    Colors.transparent,
                    CoupTheme.ink.withOpacity(0.55),
                  ],
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

/// Panel con borde dorado doble, estilo marco de retrato.
class GoldFrame extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? fill;
  const GoldFrame({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.fill,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: fill == null ? CoupTheme.panelGradient : null,
        color: fill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CoupTheme.gold, width: 2),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 16, offset: const Offset(0, 8)),
        ],
      ),
      padding: const EdgeInsets.all(3),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: CoupTheme.goldDark.withOpacity(0.6), width: 1),
        ),
        padding: padding,
        child: child,
      ),
    );
  }
}

/// Botón dorado principal con degradado y relieve.
class GoldButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;
  final bool expand;
  const GoldButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.loading = false,
    this.expand = true,
  });

  @override
  Widget build(BuildContext context) {
    final content = loading
        ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: CoupTheme.ink))
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[Icon(icon, color: CoupTheme.ink, size: 20), const SizedBox(width: 8)],
              Text(label, style: const TextStyle(
                fontFamily: CoupTheme.displayFont,
                color: CoupTheme.ink, fontSize: 17, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
            ],
          );

    return Opacity(
      opacity: onPressed == null && !loading ? 0.5 : 1,
      child: GestureDetector(
        onTap: loading ? null : onPressed,
        child: Container(
          width: expand ? double.infinity : null,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          decoration: BoxDecoration(
            gradient: CoupTheme.goldButton,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: CoupTheme.goldBright, width: 1),
            boxShadow: [
              BoxShadow(color: CoupTheme.goldDark.withOpacity(0.6), blurRadius: 8, offset: const Offset(0, 3)),
            ],
          ),
          alignment: Alignment.center,
          child: content,
        ),
      ),
    );
  }
}

/// Botón secundario (contorno dorado, fondo oscuro).
class OutlineButton2 extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final Color accent;
  final bool expand;
  const OutlineButton2({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.accent = CoupTheme.gold,
    this.expand = true,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onPressed == null ? 0.5 : 1,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: expand ? double.infinity : null,
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 22),
          decoration: BoxDecoration(
            color: CoupTheme.ink.withOpacity(0.4),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: accent, width: 1.5),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[Icon(icon, color: accent, size: 18), const SizedBox(width: 8)],
              Text(label, style: TextStyle(
                fontFamily: CoupTheme.displayFont,
                color: accent, fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Campo de texto temático.
class CoupField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final IconData? icon;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextStyle? textStyle;
  final String? hint;
  final void Function(String)? onSubmitted;
  const CoupField({
    super.key,
    required this.label,
    required this.controller,
    this.icon,
    this.obscure = false,
    this.keyboardType,
    this.textStyle,
    this.hint,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      onSubmitted: onSubmitted,
      style: textStyle ?? const TextStyle(color: CoupTheme.parchment, fontSize: 16),
      cursorColor: CoupTheme.goldBright,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(color: CoupTheme.parchmentDim.withOpacity(0.5)),
        labelStyle: const TextStyle(color: CoupTheme.parchmentDim),
        floatingLabelStyle: const TextStyle(color: CoupTheme.goldBright),
        prefixIcon: icon != null ? Icon(icon, color: CoupTheme.goldDark) : null,
        filled: true,
        fillColor: CoupTheme.ink.withOpacity(0.35),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: CoupTheme.goldDark.withOpacity(0.6), width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: CoupTheme.goldBright, width: 1.6),
        ),
      ),
    );
  }
}

/// Caja de error con estilo de sello de cera roto.
class CoupError extends StatelessWidget {
  final String message;
  const CoupError(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CoupTheme.blood.withOpacity(0.18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: CoupTheme.blood.withOpacity(0.6)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: CoupTheme.blood, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: const TextStyle(color: CoupTheme.blood, fontSize: 13))),
        ],
      ),
    );
  }
}