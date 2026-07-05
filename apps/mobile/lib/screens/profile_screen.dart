import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../providers/game_provider.dart';
import '../theme/app_theme.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _api = ApiService();
  final _auth = AuthService();
  final _usernameCtrl = TextEditingController();
  final _currentPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  String? _avatar; // data URL base64 actual
  bool _loading = true;
  bool _savingProfile = false;
  bool _savingPass = false;
  String? _profileMsg;
  bool _profileError = false;
  String? _passMsg;
  bool _passError = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final me = await _api.getMe();
      setState(() {
        _usernameCtrl.text = me['username'] ?? '';
        _avatar = me['avatar'];
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  ImageProvider? get _avatarImage {
    if (_avatar == null || _avatar!.isEmpty) return null;
    try {
      final b64 = _avatar!.contains(',') ? _avatar!.split(',').last : _avatar!;
      return MemoryImage(base64Decode(b64));
    } catch (_) {
      return null;
    }
  }

  Future<void> _pickAvatar() async {
    XFile? file;
    try {
      file = await ImagePicker().pickImage(
          source: ImageSource.gallery, maxWidth: 512, imageQuality: 85);
    } catch (e) {
      setState(() { _profileMsg = 'No se pudo abrir la galeria: $e'; _profileError = true; });
      return;
    }
    if (file == null) return;

    try {
      final bytes = await file.readAsBytes();
      String dataUrl;
      final decoded = img.decodeImage(bytes);
      if (decoded != null) {
        // Recorte cuadrado centrado + reduccion a 128px (~10-15KB)
        final side = decoded.width < decoded.height ? decoded.width : decoded.height;
        final cropped = img.copyCrop(decoded,
            x: (decoded.width - side) ~/ 2, y: (decoded.height - side) ~/ 2,
            width: side, height: side);
        final small = img.copyResize(cropped, width: 128, height: 128);
        dataUrl = 'data:image/jpeg;base64,${base64Encode(img.encodeJpg(small, quality: 82))}';
      } else if (bytes.length <= 150000) {
        // Respaldo: si no se pudo decodificar pero es liviana, se usa tal cual
        dataUrl = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      } else {
        setState(() { _profileMsg = 'Formato de imagen no soportado'; _profileError = true; });
        return;
      }
      setState(() { _avatar = dataUrl; _profileMsg = null; });
    } catch (e) {
      setState(() { _profileMsg = 'Error al procesar la imagen: $e'; _profileError = true; });
    }
  }

  Future<void> _saveProfile() async {
    setState(() { _savingProfile = true; _profileMsg = null; });
    try {
      final res = await _api.updateProfile(
        username: _usernameCtrl.text.trim(),
        avatar: _avatar,
      );
      final newName = res['username'] ?? _usernameCtrl.text.trim();
      await _auth.setUsername(newName);
      ref.read(gameProvider.notifier).username = newName;
      setState(() { _profileMsg = 'Perfil actualizado'; _profileError = false; });
    } catch (e) {
      setState(() {
        _profileMsg = e.toString().replaceAll('Exception: ', '');
        _profileError = true;
      });
    } finally {
      setState(() => _savingProfile = false);
    }
  }

  Future<void> _changePassword() async {
    if (_newPassCtrl.text != _confirmPassCtrl.text) {
      setState(() { _passMsg = 'Las contraseñas nuevas no coinciden'; _passError = true; });
      return;
    }
    setState(() { _savingPass = true; _passMsg = null; });
    try {
      await _api.changePassword(
        currentPassword: _currentPassCtrl.text,
        newPassword: _newPassCtrl.text,
      );
      _currentPassCtrl.clear();
      _newPassCtrl.clear();
      _confirmPassCtrl.clear();
      setState(() { _passMsg = 'Contraseña actualizada'; _passError = false; });
    } catch (e) {
      setState(() {
        _passMsg = e.toString().replaceAll('Exception: ', '');
        _passError = true;
      });
    } finally {
      setState(() => _savingPass = false);
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
                    Text('Mi cuenta', style: CoupTheme.titleMedium),
                  ],
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: CoupTheme.gold))
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: Column(
                            children: [
                              // ---- Perfil ----
                              GoldFrame(
                                child: Column(
                                  children: [
                                    GestureDetector(
                                      onTap: _pickAvatar,
                                      child: Stack(
                                        children: [
                                          CircleAvatar(
                                            radius: 52,
                                            backgroundColor: CoupTheme.ink.withOpacity(0.5),
                                            backgroundImage: _avatarImage,
                                            child: _avatarImage == null
                                                ? const Icon(Icons.person, color: CoupTheme.goldDark, size: 52)
                                                : null,
                                          ),
                                          Positioned(
                                            bottom: 0, right: 0,
                                            child: Container(
                                              padding: const EdgeInsets.all(6),
                                              decoration: BoxDecoration(
                                                gradient: CoupTheme.goldButton,
                                                shape: BoxShape.circle,
                                                border: Border.all(color: CoupTheme.goldBright),
                                              ),
                                              child: const Icon(Icons.camera_alt, color: CoupTheme.ink, size: 16),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text('Toca la foto para cambiarla', style: CoupTheme.label),
                                    const SizedBox(height: 18),
                                    CoupField(
                                      label: 'Nombre de usuario (visible en partida)',
                                      controller: _usernameCtrl,
                                      icon: Icons.badge_outlined,
                                    ),
                                    if (_profileMsg != null) ...[
                                      const SizedBox(height: 12),
                                      _profileError
                                          ? CoupError(_profileMsg!)
                                          : Text(_profileMsg!, style: const TextStyle(color: CoupTheme.poison, fontWeight: FontWeight.bold)),
                                    ],
                                    const SizedBox(height: 16),
                                    GoldButton(
                                      label: 'Guardar perfil',
                                      icon: Icons.save_outlined,
                                      loading: _savingProfile,
                                      onPressed: _savingProfile ? null : _saveProfile,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                              // ---- Contrasena ----
                              GoldFrame(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(children: [
                                      const Icon(Icons.lock_outline, color: CoupTheme.goldBright, size: 20),
                                      const SizedBox(width: 8),
                                      Text('Cambiar contraseña', style: CoupTheme.titleMedium.copyWith(fontSize: 18)),
                                    ]),
                                    const SizedBox(height: 16),
                                    CoupField(label: 'Contraseña actual', controller: _currentPassCtrl, icon: Icons.lock_open, obscure: true),
                                    const SizedBox(height: 12),
                                    CoupField(label: 'Nueva contraseña', controller: _newPassCtrl, icon: Icons.lock_outline, obscure: true),
                                    const SizedBox(height: 12),
                                    CoupField(label: 'Confirmar nueva contraseña', controller: _confirmPassCtrl, icon: Icons.lock_outline, obscure: true),
                                    if (_passMsg != null) ...[
                                      const SizedBox(height: 12),
                                      _passError
                                          ? CoupError(_passMsg!)
                                          : Text(_passMsg!, style: const TextStyle(color: CoupTheme.poison, fontWeight: FontWeight.bold)),
                                    ],
                                    const SizedBox(height: 16),
                                    GoldButton(
                                      label: 'Actualizar contraseña',
                                      icon: Icons.key,
                                      loading: _savingPass,
                                      onPressed: _savingPass ? null : _changePassword,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}