import 'package:flutter/material.dart';
import '../services/admin_service.dart';
import '../theme/app_theme.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final _admin = AdminService();
  final _searchCtrl = TextEditingController();
  List<dynamic> _users = [];
  bool _loading = true;
  String? _error;
  int _page = 1;
  int _total = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _admin.listUsers(page: _page, search: _searchCtrl.text.trim());
      setState(() {
        _users = data['data'] ?? [];
        _total = data['total'] ?? 0;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _loading = false;
      });
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
                    Text('Gestión de usuarios', style: CoupTheme.titleMedium.copyWith(fontSize: 20)),
                    const Spacer(),
                    IconButton(icon: const Icon(Icons.refresh, color: CoupTheme.goldBright), onPressed: _load),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: CoupField(
                  label: '',
                  hint: 'Buscar por nombre o email...',
                  controller: _searchCtrl,
                  icon: Icons.search,
                  onSubmitted: (_) => _load(),
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: CoupError(_error!),
                ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: CoupTheme.gold))
                    : _users.isEmpty
                        ? Center(child: Text('Sin usuarios', style: CoupTheme.subtitle))
                        : ListView.separated(
                            padding: const EdgeInsets.all(12),
                            itemCount: _users.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (_, i) => _userCard(_users[i]),
                          ),
              ),
              if (_total > 20)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left, color: CoupTheme.parchmentDim),
                        onPressed: _page > 1 ? () { setState(() => _page--); _load(); } : null,
                      ),
                      Text('Página $_page', style: const TextStyle(color: CoupTheme.parchment)),
                      IconButton(
                        icon: const Icon(Icons.chevron_right, color: CoupTheme.parchmentDim),
                        onPressed: _page * 20 < _total ? () { setState(() => _page++); _load(); } : null,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _userCard(Map<String, dynamic> user) {
    final role = user['role'] ?? 'Free';
    final status = user['status'] ?? 'active';
    final blocked = status == 'blocked';

    Color roleColor;
    switch (role) {
      case 'Admin': roleColor = CoupTheme.blood; break;
      case 'Pro': roleColor = CoupTheme.goldBright; break;
      default: roleColor = CoupTheme.parchmentDim;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CoupTheme.ink.withOpacity(0.3),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: blocked ? CoupTheme.blood.withOpacity(0.7) : CoupTheme.goldDark.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: roleColor.withOpacity(0.18),
                  shape: BoxShape.circle,
                  border: Border.all(color: roleColor.withOpacity(0.6)),
                ),
                child: Icon(Icons.person, color: roleColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user['username'] ?? '',
                        style: const TextStyle(color: CoupTheme.parchment, fontWeight: FontWeight.bold, fontSize: 15)),
                    Text(user['email'] ?? '', style: CoupTheme.label),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: roleColor.withOpacity(0.18), borderRadius: BorderRadius.circular(8), border: Border.all(color: roleColor.withOpacity(0.5))),
                child: Text(role, style: TextStyle(color: roleColor, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
              if (blocked) ...[
                const SizedBox(width: 6),
                const Icon(Icons.block, color: CoupTheme.blood, size: 18),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _smallBtn('Cambiar rol', Icons.swap_vert, CoupTheme.gold, () => _changeRole(user)),
              blocked
                  ? _smallBtn('Activar', Icons.check_circle, CoupTheme.poison, () => _setStatus(user['id'], 'active'))
                  : _smallBtn('Bloquear', Icons.block, CoupTheme.blood, () => _setStatus(user['id'], 'blocked')),
              _smallBtn('Eliminar', Icons.delete_outline, CoupTheme.blood, () => _confirmDelete(user)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _smallBtn(String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  void _changeRole(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: CoupTheme.burgundyPanel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: CoupTheme.gold)),
        title: Text('Rol de ${user['username']}', style: const TextStyle(color: CoupTheme.parchment)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['Free', 'Pro', 'Admin'].map((r) => ListTile(
            title: Text(r, style: const TextStyle(color: CoupTheme.parchment)),
            trailing: user['role'] == r ? const Icon(Icons.check, color: CoupTheme.goldBright) : null,
            onTap: () async {
              Navigator.pop(dialogCtx);
              await _doUpdate(user['id'], role: r);
            },
          )).toList(),
        ),
      ),
    );
  }

  void _confirmDelete(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: CoupTheme.burgundyPanel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: CoupTheme.gold)),
        title: const Text('¿Eliminar usuario?', style: TextStyle(color: CoupTheme.parchment)),
        content: Text('Se eliminará a ${user['username']} permanentemente.', style: const TextStyle(color: CoupTheme.parchmentDim)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancelar', style: TextStyle(color: CoupTheme.parchmentDim))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              try {
                await _admin.deleteUser(user['id']);
                _load();
              } catch (e) {
                _showSnack(e.toString().replaceAll('Exception: ', ''));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: CoupTheme.blood),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  Future<void> _setStatus(String id, String status) async {
    await _doUpdate(id, status: status);
  }

  Future<void> _doUpdate(String id, {String? role, String? status}) async {
    try {
      await _admin.updateUser(id, role: role, status: status);
      _load();
    } catch (e) {
      _showSnack(e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _showSnack(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }
}