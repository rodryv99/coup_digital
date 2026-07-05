import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';
import '../providers/game_provider.dart';
import '../theme/app_theme.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController(text: 'password123');
  bool _isLogin = true;
  bool _loading = false;
  String? _error;
  final _auth = AuthService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CoupTheme.burgundyDeep,
      body: CoupBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Emblema
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      gradient: CoupTheme.goldButton,
                      shape: BoxShape.circle,
                      border: Border.all(color: CoupTheme.goldBright, width: 2),
                      boxShadow: [
                        BoxShadow(color: CoupTheme.goldDark.withOpacity(0.6), blurRadius: 16, spreadRadius: 1),
                      ],
                    ),
                    child: const Icon(Icons.shield, color: CoupTheme.ink, size: 46),
                  ),
                  const SizedBox(height: 16),
                  Text('Coup Digital', style: CoupTheme.titleLarge),
                  const SizedBox(height: 2),
                  Text('El juego de la traición', style: CoupTheme.subtitle),
                  const SizedBox(height: 32),

                  GoldFrame(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      children: [
                        // Selector de pestañas
                        Row(
                          children: [
                            _tabButton('Iniciar sesión', _isLogin, () => setState(() { _isLogin = true; _error = null; })),
                            const SizedBox(width: 10),
                            _tabButton('Registrarse', !_isLogin, () => setState(() { _isLogin = false; _error = null; })),
                          ],
                        ),
                        const SizedBox(height: 22),

                        CoupField(label: 'Alias de Infiltrado', controller: _usernameCtrl, icon: Icons.person_outline),
                        if (!_isLogin) ...[
                          const SizedBox(height: 14),
                          CoupField(label: 'Correo', controller: _emailCtrl, icon: Icons.mail_outline, keyboardType: TextInputType.emailAddress),
                        ],
                        const SizedBox(height: 14),
                        CoupField(label: 'Contraseña', controller: _passwordCtrl, icon: Icons.lock_outline, obscure: true),

                        if (_error != null) ...[
                          const SizedBox(height: 16),
                          CoupError(_error!),
                        ],

                        const SizedBox(height: 24),
                        GoldButton(
                          label: _isLogin ? 'Iniciar sesión' : 'Crear cuenta',
                          icon: _isLogin ? Icons.login : Icons.person_add_alt,
                          loading: _loading,
                          onPressed: _loading ? null : _submit,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tabButton(String text, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            gradient: active ? CoupTheme.goldButton : null,
            color: active ? null : CoupTheme.ink.withOpacity(0.4),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: active ? CoupTheme.goldBright : CoupTheme.goldDark.withOpacity(0.5), width: 1.2),
          ),
          child: Text(text,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: CoupTheme.displayFont,
                  color: active ? CoupTheme.ink : CoupTheme.parchmentDim,
                  fontWeight: FontWeight.bold,
                  fontSize: 13)),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    setState(() { _loading = true; _error = null; });
    try {
      if (_isLogin) {
        await _auth.login(_usernameCtrl.text.trim(), _passwordCtrl.text);
      } else {
        await _auth.register(_usernameCtrl.text.trim(), _emailCtrl.text.trim(), _passwordCtrl.text);
        await _auth.login(_usernameCtrl.text.trim(), _passwordCtrl.text);
      }
      await ref.read(gameProvider.notifier).init();
      if (mounted) Navigator.pushReplacementNamed(context, '/lobby');
    } catch (e) {
      setState(() { _error = e.toString().replaceAll('Exception: ', ''); });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}