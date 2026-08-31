import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  supabase.SupabaseClient get _client =>
      supabase.Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final user = _client.auth.currentUser;

      if (user == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'ログイン情報を取得できませんでした。';
        });
        return;
      }

      final data = await _client
          .from('profiles')
          .select('display_name')
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) {
        return;
      }

      _displayNameController.text =
          data?['display_name']?.toString() ?? '';

      setState(() {
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = 'プロフィールを読み込めませんでした。';
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final user = _client.auth.currentUser;

    if (user == null) {
      setState(() {
        _errorMessage = 'ログイン情報を取得できませんでした。';
      });
      return;
    }

    final displayName = _displayNameController.text;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await _client.from('profiles').upsert(
        {
          'id': user.id,
          'display_name': displayName,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'id',
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('表示名を保存しました。'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.of(context).pop(true);
    } on supabase.PostgrestException catch (error) {
      if (!mounted) {
        return;
      }

      String message = '表示名を保存できませんでした。';

      if (error.code == '23505') {
        message = 'その表示名はすでに使用されています。';
      } else if (error.code == '23514') {
        message = '表示名は1〜30文字で入力してください。';
      }

      setState(() {
        _isSaving = false;
        _errorMessage = message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSaving = false;
        _errorMessage = '表示名を保存できませんでした。';
      });
    }
  }

  String? _validateDisplayName(String? value) {
    final text = value ?? '';

    if (text.trim().isEmpty) {
      return '表示名を入力してください。';
    }

    if (text != text.trim()) {
      return '表示名の前後に空白は使用できません。';
    }

    if (text.characters.isEmpty ||
        text.characters.length > 30) {
      return '表示名は1〜30文字で入力してください。';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F5FB),
      appBar: AppBar(
        title: const Text('プロフィール'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            gradient:
                                const LinearGradient(
                              colors: [
                                Color(0xFF6A35C8),
                                Color(0xFF9B72E8),
                              ],
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.deepPurple
                                    .withValues(alpha: 0.25),
                                blurRadius: 18,
                                offset:
                                    const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 48,
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                              BorderRadius.circular(20),
                        ),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '表示名',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'ランキングなどで公開される名前です。',
                              style: TextStyle(
                                fontSize: 13,
                                color:
                                    Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller:
                                  _displayNameController,
                              maxLength: 30,
                              textInputAction:
                                  TextInputAction.done,
                              decoration:
                                  InputDecoration(
                                hintText:
                                    '表示名を入力',
                                prefixIcon:
                                    const Icon(
                                  Icons.person_outline,
                                ),
                                border:
                                    OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(
                                    14,
                                  ),
                                ),
                              ),
                              validator:
                                  _validateDisplayName,
                              onFieldSubmitted: (_) {
                                if (!_isSaving) {
                                  _saveProfile();
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding:
                              const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.red
                                .withValues(alpha: 0.08),
                            borderRadius:
                                BorderRadius.circular(14),
                          ),
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton(
                          onPressed:
                              _isSaving
                                  ? null
                                  : _saveProfile,
                          style: FilledButton.styleFrom(
                            backgroundColor:
                                const Color(0xFF6A35C8),
                            shape:
                                RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(16),
                            ),
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child:
                                      CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  '保存する',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight:
                                        FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}