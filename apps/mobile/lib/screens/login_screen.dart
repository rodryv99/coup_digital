import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';
import '../providers/game_provider.dart';

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
      backgroundColor: const Color(0xFF0f1117),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.style, color: Colors.amber, size: 64),
                const SizedBox(height: 12),
                const Text('Coup Digital',
                    style: TextStyle(color: Colors.amber, fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text('El juego de la traición',
                    style: TextStyle(color: Colors.white54, fontSize: 14)),
                const SizedBox(height: 40),

                // Tab selector
                Row(
                  children: [
                    _tabButton('Iniciar sesión', _isLogin, () => setState(() { _isLogin = true; _error = null; })),
                    const SizedBox(width: 8),
                    _tabButton('Registrarse', !_isLogin, () => setState(() { _isLogin = false; _error = null; })),
                  ],
                ),
                const SizedBox(height: 20),

                // Formulario
                _field('Usuario', _usernameCtrl, icon: Icons.person),
                if (!_isLogin) ...[
                  const SizedBox(height: 12),
                  _field('Email', _emailCtrl, icon: Icons.email),
                ],
                const SizedBox(height: 12),
                _field('Contraseña', _passwordCtrl, icon: Icons.lock, obscure: true),

                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade900.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                  ),
                ],

                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber.shade700,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _loading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                        : Text(_isLogin ? 'Iniciar sesión' : 'Crear cuenta',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
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
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? Colors.amber.shade700 : const Color(0xFF252830),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(text,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: active ? Colors.black : Colors.white60,
                  fontWeight: FontWeight.bold,
                  fontSize: 13)),
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, {IconData? icon, bool obscure = false}) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        prefixIcon: icon != null ? Icon(icon, color: Colors.white38) : null,
        filled: true,
        fillColor: const Color(0xFF252830),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.amber)),
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