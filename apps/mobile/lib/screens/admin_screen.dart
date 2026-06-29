import 'package:flutter/material.dart';
import '../services/admin_service.dart';

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
      backgroundColor: const Color(0xFF0f1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1a1d27),
        title: const Text('Gestion de usuarios', style: TextStyle(color: Colors.amber)),
        iconTheme: const IconThemeData(color: Colors.white70),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Colors.white70), onPressed: _load),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(color: Colors.white),
              onSubmitted: (_) => _load(),
              decoration: InputDecoration(
                hintText: 'Buscar por nombre o email...',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(Icons.search, color: Colors.white38),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward, color: Colors.amber),
                  onPressed: _load,
                ),
                filled: true,
                fillColor: const Color(0xFF252830),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.red.shade900.withOpacity(0.3), borderRadius: BorderRadius.circular(8)),
                child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Colors.amber))
                : _users.isEmpty
                    ? const Center(child: Text('Sin usuarios', style: TextStyle(color: Colors.white54)))
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: _users.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
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
                    icon: const Icon(Icons.chevron_left, color: Colors.white70),
                    onPressed: _page > 1 ? () { setState(() => _page--); _load(); } : null,
                  ),
                  Text('Pagina $_page', style: const TextStyle(color: Colors.white70)),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, color: Colors.white70),
                    onPressed: _page * 20 < _total ? () { setState(() => _page++); _load(); } : null,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _userCard(Map<String, dynamic> user) {
    final role = user['role'] ?? 'Free';
    final status = user['status'] ?? 'active';
    final blocked = status == 'blocked';

    Color roleColor;
    switch (role) {
      case 'Admin': roleColor = Colors.redAccent; break;
      case 'Pro': roleColor = Colors.amber; break;
      default: roleColor = Colors.white54;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF252830),
        borderRadius: BorderRadius.circular(10),
        border: blocked ? Border.all(color: Colors.red.shade900) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: roleColor.withOpacity(0.2),
                child: Icon(Icons.person, color: roleColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user['username'] ?? '',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                    Text(user['email'] ?? '',
                        style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: roleColor.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                child: Text(role, style: TextStyle(color: roleColor, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
              if (blocked) ...[
                const SizedBox(width: 6),
                const Icon(Icons.block, color: Colors.redAccent, size: 18),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _smallBtn('Cambiar rol', Icons.swap_vert, Colors.blue, () => _changeRole(user)),
              blocked
                  ? _smallBtn('Activar', Icons.check_circle, Colors.green, () => _setStatus(user['id'], 'active'))
                  : _smallBtn('Bloquear', Icons.block, Colors.orange, () => _setStatus(user['id'], 'blocked')),
              _smallBtn('Eliminar', Icons.delete, Colors.red, () => _confirmDelete(user)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _smallBtn(String label, IconData icon, Color color, VoidCallback onTap) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 14),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.2),
        foregroundColor: color,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _changeRole(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF1a1d27),
        title: Text('Rol de ${user['username']}', style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['Free', 'Pro', 'Admin'].map((r) => ListTile(
            title: Text(r, style: const TextStyle(color: Colors.white)),
            trailing: user['role'] == r ? const Icon(Icons.check, color: Colors.amber) : null,
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
        backgroundColor: const Color(0xFF1a1d27),
        title: const Text('Eliminar usuario?', style: TextStyle(color: Colors.white)),
        content: Text('Se eliminara a ${user['username']} permanentemente.', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancelar')),
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
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