import 'dart:convert';

import 'package:calculator/utlis/method_secure_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

const String credentialsStorageKey = 'saved_credentials';
const int maxSavedCredentials = 15;

class ThirdScreen extends StatefulWidget {
  const ThirdScreen({super.key});

  @override
  State<ThirdScreen> createState() => _ThirdScreenState();
}

class _ThirdScreenState extends State<ThirdScreen> {
  final TextEditingController _platformController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passkeyController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  List<_SavedCredential> _savedCredentials = const [];
  final Set<int> _visiblePasswordIndexes = <int>{};
  String _apkVersionLabel = 'APK Version --';

  String _safeString(dynamic value) {
    return value?.toString() ?? '';
  }

  @override
  void initState() {
    super.initState();
    _loadCredentials();
    _loadAppVersion();
  }

  @override
  void dispose() {
    _platformController.dispose();
    _usernameController.dispose();
    _passkeyController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadCredentials() async {
    final storedValue = await loadSecureValue(credentialsStorageKey);
    final decodedList = _decodeCredentials(storedValue);

    if (!mounted) {
      return;
    }

    setState(() {
      _savedCredentials = decodedList;
    });
  }

  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();

      if (!mounted) {
        return;
      }

      setState(() {
        _apkVersionLabel =
            'APK Version ${packageInfo.version}+${packageInfo.buildNumber}';
      });
    } catch (_) {}
  }

  List<_SavedCredential> _decodeCredentials(String? rawValue) {
    if (rawValue == null || rawValue.isEmpty) {
      return [];
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(rawValue);
    } catch (_) {
      return [];
    }

    if (decoded is! List) {
      return [];
    }

    return decoded
        .whereType<Map>()
        .map(
          (item) => _SavedCredential(
            platform: _safeString(item['platform']),
            username: _safeString(item['username']),
            passkey: _safeString(item['passkey']),
            password: _safeString(item['password']),
          ),
        )
        .where((item) => item.username.isNotEmpty || item.password.isNotEmpty)
        .take(maxSavedCredentials)
        .toList();
  }

  Future<void> _persistCredentials(List<_SavedCredential> credentials) async {
    final payload = jsonEncode(
      credentials
          .map(
            (item) => {
              'platform': item.platform,
              'username': item.username,
              'passkey': item.passkey,
              'password': item.password,
            },
          )
          .toList(),
    );
    await saveSecureValue(credentialsStorageKey, payload);
  }

  Future<void> _saveCredential() async {
    final platform = _platformController.text.trim();
    final username = _usernameController.text.trim();
    final passkey = _passkeyController.text.trim();
    final password = _passwordController.text;

    if (platform.isEmpty || username.isEmpty || passkey.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Platform, username, passkey and password are required.'),
        ),
      );
      return;
    }

    final updatedCredentials = List<_SavedCredential>.from(_savedCredentials);
    final existingIndex = updatedCredentials.indexWhere(
      (item) => item.platform == platform && item.username == username,
    );

    if (existingIndex >= 0) {
      updatedCredentials[existingIndex] = _SavedCredential(
        platform: platform,
        username: username,
        passkey: passkey,
        password: password,
      );
    } else {
      if (updatedCredentials.length >= maxSavedCredentials) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Only $maxSavedCredentials credentials can be saved.')),
        );
        return;
      }

        updatedCredentials.add(
          _SavedCredential(
            platform: platform,
            username: username,
            passkey: passkey,
            password: password,
          ),
        );
    }

    await _persistCredentials(updatedCredentials);

    if (!mounted) {
      return;
    }

    setState(() {
      _savedCredentials = updatedCredentials;
      _platformController.clear();
      _usernameController.clear();
      _passkeyController.clear();
      _passwordController.clear();
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Credential saved')));
  }

  Future<void> _deleteCredential(int index) async {
    final updatedCredentials = List<_SavedCredential>.from(_savedCredentials)
      ..removeAt(index);

    if (updatedCredentials.isEmpty) {
      await deleteSecureValue(credentialsStorageKey);
    } else {
      await _persistCredentials(updatedCredentials);
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _savedCredentials = updatedCredentials;
      _visiblePasswordIndexes.remove(index);
      final shiftedIndexes =
          _visiblePasswordIndexes.where((item) => item > index).toList();
      _visiblePasswordIndexes.removeAll(shiftedIndexes);
      _visiblePasswordIndexes.addAll(
        shiftedIndexes.map((item) => item - 1),
      );
    });
  }

  Future<void> _clearAllCredentials() async {
    await deleteSecureValue(credentialsStorageKey);

    if (!mounted) {
      return;
    }

    setState(() {
      _savedCredentials = [];
      _visiblePasswordIndexes.clear();
      _platformController.clear();
      _usernameController.clear();
      _passkeyController.clear();
      _passwordController.clear();
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('All credentials cleared')));
  }

  void _fillCredential(_SavedCredential credential) {
    setState(() {
      _platformController.text = credential.platform;
      _usernameController.text = credential.username;
      _passkeyController.text = credential.passkey;
      _passwordController.text = credential.password;
    });
  }

  void _toggleSavedPasswordVisibility(int index) {
    setState(() {
      if (_visiblePasswordIndexes.contains(index)) {
        _visiblePasswordIndexes.remove(index);
      } else {
        _visiblePasswordIndexes.add(index);
      }
    });
  }

  Future<void> _copyPassword(String password) async {
    await Clipboard.setData(ClipboardData(text: password));

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Password copied')));
  }

  Future<void> _copyPasskey(String passkey) async {
    await Clipboard.setData(ClipboardData(text: passkey));

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Passkey copied')));
  }

  InputDecoration _buildInputDecoration({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Saved Credentials')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Securely store up to $maxSavedCredentials username and password pairs on this device.',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Text(
                _apkVersionLabel,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black54,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _platformController,
                decoration: _buildInputDecoration(
                  label: 'Platform',
                  icon: Icons.language_outlined,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _usernameController,
                decoration: _buildInputDecoration(
                  label: 'Username',
                  icon: Icons.person_outline,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passkeyController,
                decoration: _buildInputDecoration(
                  label: 'Passkey',
                  icon: Icons.key_outlined,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: _buildInputDecoration(
                  label: 'Password',
                  icon: Icons.lock_outline,
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _saveCredential,
                child: Text(
                  _savedCredentials.any(
                        (item) =>
                            item.platform == _platformController.text.trim() &&
                            item.username == _usernameController.text.trim(),
                      )
                      ? 'Update'
                      : 'Save',
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _savedCredentials.isEmpty ? null : _clearAllCredentials,
                child: const Text('Clear All'),
              ),
              const SizedBox(height: 20),
              Text(
                'Saved Items (${_savedCredentials.length}/$maxSavedCredentials)',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _savedCredentials.isEmpty
                    ? const Center(child: Text('No credentials saved yet'))
                    : ListView.separated(
                        itemCount: _savedCredentials.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final credential = _savedCredentials[index];
                          final isPasswordVisible = _visiblePasswordIndexes
                              .contains(index);
                          return Card(
                            child: ListTile(
                              onTap: () {
                                _fillCredential(credential);
                              },
                              // leading: CircleAvatar(
                              //   child: Text('${index + 1}'),
                              // ),
                              title: Text(
                                credential.platform.isEmpty
                                    ? 'Unknown Platform'
                                    : credential.platform,
                              ),
                              subtitle: Text(
                                '${credential.username}\n'
                                '${credential.passkey.isEmpty ? '--' : '*' * credential.passkey.length.clamp(0, 24)}\n'
                                '${isPasswordVisible ? credential.password : '*' * credential.password.length.clamp(0, 24)}',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'Copy passkey',
                                    onPressed: () async {
                                      await _copyPasskey(credential.passkey);
                                    },
                                    icon: const Icon(Icons.key_outlined),
                                  ),
                                  IconButton(
                                    tooltip: 'Copy password',
                                    onPressed: () async {
                                      await _copyPassword(credential.password);
                                    },
                                    icon: const Icon(Icons.password_outlined),
                                  ),
                                  IconButton(
                                    tooltip: 'Delete',
                                    onPressed: () async {
                                      await _deleteCredential(index);
                                    },
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SavedCredential {
  const _SavedCredential({
    String? platform,
    String? username,
    String? passkey,
    String? password,
  }) : platform = platform ?? '',
       username = username ?? '',
       passkey = passkey ?? '',
       password = password ?? '';

  final String platform;
  final String username;
  final String passkey;
  final String password;
}
