import 'package:flutter/material.dart';

import '../services/device_control_service.dart';

class AdminControlsScreen extends StatefulWidget {
  const AdminControlsScreen({super.key});

  @override
  State<AdminControlsScreen> createState() => _AdminControlsScreenState();
}

class _AdminControlsScreenState extends State<AdminControlsScreen> {
  bool _isAdminActive = false;
  bool _blockUninstall = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    setState(() => _isLoading = true);
    final active = await DeviceControlService().checkAdminStatus();
    setState(() {
      _isAdminActive = active;
      _isLoading = false;
    });
  }

  Future<void> _activateAdmin() async {
    setState(() => _isLoading = true);
    final active = await DeviceControlService().activateAdmin();
    setState(() {
      _isAdminActive = active;
      _isLoading = false;
    });

    if (active) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Device Admin Activated Successfully'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _lockDevice() async {
    final result = await DeviceControlService().lockDevice();
    if (result) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Device Locked Successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Failed to lock device'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _toggleUninstallBlock(bool block) async {
    final result = await DeviceControlService().blockUninstall(block: block);
    if (result) {
      setState(() => _blockUninstall = block);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(block ? '✅ Uninstall Blocked' : '✅ Uninstall Allowed'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Controls'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _checkStatus,
          ),
        ],
      ),
      body: Container(
        padding: const EdgeInsets.all(16),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
          children: [
            _buildStatusCard(),
            const SizedBox(height: 16),
            _buildControlsCard(),
            const SizedBox(height: 16),
            _buildLockOptionsCard(),
            const Spacer(),
            _buildUninstallBlockCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      elevation: 4,
      child: Container(
        padding: const EdgeInsets.all(16),
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Admin Status',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  _isAdminActive ? Icons.check_circle : Icons.cancel,
                  color: _isAdminActive ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  _isAdminActive
                      ? '✅ Admin is Active'
                      : '❌ Admin is Inactive',
                  style: TextStyle(
                    color: _isAdminActive ? Colors.green : Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (!_isAdminActive)
                  ElevatedButton(
                    onPressed: _activateAdmin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                    ),
                    child: const Text('Activate'),
                  ),
              ],
            ),
            if (!_isAdminActive)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'আপনাকে ডিভাইস অ্যাডমিন অ্যাক্টিভেট করতে হবে',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlsCard() {
    return Card(
      elevation: 4,
      child: Container(
        padding: const EdgeInsets.all(16),
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quick Controls',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isAdminActive ? _lockDevice : null,
                    icon: const Icon(Icons.lock),
                    label: const Text('Lock Device'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isAdminActive ? _lockDevice : null,
                    icon: const Icon(Icons.lock_open),
                    label: const Text('Unlock'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLockOptionsCard() {
    return Card(
      elevation: 4,
      child: Container(
        padding: const EdgeInsets.all(16),
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Lock Options',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.schedule, color: Colors.blue),
              title: const Text('Schedule Lock'),
              subtitle: const Text('নির্দিষ্ট সময়ে লক করবে'),
              trailing: Switch(
                value: false,
                onChanged: _isAdminActive ? (value) {} : null,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.warning, color: Colors.orange),
              title: const Text('Emergency Lock'),
              subtitle: const Text('জরুরী অবস্থায় তৎক্ষণাৎ লক'),
              trailing: Switch(
                value: false,
                onChanged: _isAdminActive ? (value) {} : null,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.calendar_today, color: Colors.purple),
              title: const Text('Lock by Date'),
              subtitle: const Text('নির্দিষ্ট তারিখে লক করবে'),
              trailing: Switch(
                value: false,
                onChanged: _isAdminActive ? (value) {} : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUninstallBlockCard() {
    return Card(
      elevation: 4,
      child: Container(
        padding: const EdgeInsets.all(16),
        width: double.infinity,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Uninstall Protection',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _blockUninstall ? '🔒 Uninstall Blocked' : '🔓 Uninstall Allowed',
                  style: TextStyle(
                    color: _blockUninstall ? Colors.green : Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            Switch(
              value: _blockUninstall,
              onChanged: _isAdminActive ? _toggleUninstallBlock : null,
              activeColor: Colors.green,
            ),
          ],
        ),
      ),
    );
  }
}