import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettingsPage extends StatefulWidget {
  const AppSettingsPage({super.key});

  @override
  State<AppSettingsPage> createState() => _AppSettingsPageState();
}

class _AppSettingsPageState extends State<AppSettingsPage> {
  static const String _stampEffectKey = 'setting_stamp_effect';
  static const String _autoNextDestinationKey =
      'setting_auto_next_destination';

  bool _stampEffect = true;
  bool _autoNextDestination = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) {
      return;
    }

    setState(() {
      _stampEffect = prefs.getBool(_stampEffectKey) ?? true;
      _autoNextDestination =
          prefs.getBool(_autoNextDestinationKey) ?? true;
      _loading = false;
    });
  }

  Future<void> _setStampEffect(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_stampEffectKey, value);

    if (!mounted) {
      return;
    }

    setState(() {
      _stampEffect = value;
    });
  }

  Future<void> _setAutoNextDestination(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoNextDestinationKey, value);

    if (!mounted) {
      return;
    }

    setState(() {
      _autoNextDestination = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('アプリ設定'),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSectionTitle('聖地クエスト'),
                _buildSwitchTile(
                  icon: Icons.auto_awesome,
                  title: 'スタンプ獲得演出',
                  subtitle: '聖地を獲得したときの演出を表示します',
                  value: _stampEffect,
                  onChanged: _setStampEffect,
                ),
                _buildSwitchTile(
                  icon: Icons.navigation,
                  title: '次の目的地を自動設定',
                  subtitle: '聖地を獲得したあと、次の未獲得聖地を目的地にします',
                  value: _autoNextDestination,
                  onChanged: _setAutoNextDestination,
                ),
                const SizedBox(height: 24),
                _buildSectionTitle('情報'),
                _buildInfoTile(
                  icon: Icons.info_outline,
                  title: 'アプリバージョン',
                  value: '1.0.0',
                ),
              ],
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(
        left: 4,
        bottom: 8,
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade700,
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 4,
        ),
        secondary: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.deepPurple.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: Colors.deepPurple,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            fontSize: 12,
          ),
        ),
        value: value,
        onChanged: onChanged,
        activeThumbColor: Colors.deepPurple,
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 4,
        ),
        leading: Icon(
          icon,
          color: Colors.deepPurple,
        ),
        title: Text(title),
        trailing: Text(
          value,
          style: TextStyle(
            color: Colors.grey.shade600,
          ),
        ),
      ),
    );
  }
}