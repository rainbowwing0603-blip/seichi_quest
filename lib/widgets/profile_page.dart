import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import 'profile_avatar.dart';

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

  static const _ageGroups = <String>[
    '10代以下',
    '20代',
    '30代',
    '40代',
    '50代',
    '60代',
    '70代以上',
    '回答しない',
  ];

  bool _isLoading = true;
  bool _isSaving = false;

  String? _errorMessage;
  String? _ageGroup;
  String _avatarKey = 'adventurer';

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
          _errorMessage =
              'ログイン情報を取得できませんでした。';
        });
        return;
      }

      final data = await _client
          .from('profiles')
          .select(
            'display_name, age_group, avatar_key',
          )
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) {
        return;
      }

      _displayNameController.text =
          data?['display_name']?.toString() ?? '';

      final loadedAgeGroup =
          data?['age_group']?.toString();

      final loadedAvatarKey =
          data?['avatar_key']?.toString();

      setState(() {
        _ageGroup =
            _ageGroups.contains(loadedAgeGroup)
                ? loadedAgeGroup
                : null;

        _avatarKey =
            profileAvatarOptionForKey(
              loadedAvatarKey,
            ).key;

        _isLoading = false;
      });
    } catch (error, stackTrace) {
      debugPrint(
        '[PROFILE] load failed unexpectedly: $error',
      );
      debugPrint(
        '[PROFILE] load stackTrace: $stackTrace',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage =
            'プロフィールを読み込めませんでした。';
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
        _errorMessage =
            'ログイン情報を取得できませんでした。';
      });
      return;
    }

    final displayName =
        _displayNameController.text;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await _client.from('profiles').upsert(
        {
          'id': user.id,
          'display_name': displayName,
          'age_group': _ageGroup,
          'avatar_key': _avatarKey,
          'updated_at':
              DateTime.now()
                  .toUtc()
                  .toIso8601String(),
        },
        onConflict: 'id',
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'プロフィールを保存しました。',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.of(context).pop(true);
    } on supabase.PostgrestException catch (error) {
      debugPrint(
        '[PROFILE] save failed: '
        'code=${error.code}, '
        'message=${error.message}, '
        'details=${error.details}, '
        'hint=${error.hint}',
      );

      if (!mounted) {
        return;
      }

      String message =
          'プロフィールを保存できませんでした。';

      if (error.code == '23505') {
        message =
            'その表示名はすでに使用されています。';
      } else if (error.code == '23514') {
        message =
            '入力内容を確認してください。';
      }

      setState(() {
        _isSaving = false;
        _errorMessage = message;
      });
    } catch (error, stackTrace) {
      debugPrint(
        '[PROFILE] save failed unexpectedly: $error',
      );
      debugPrint(
        '[PROFILE] stackTrace: $stackTrace',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isSaving = false;
        _errorMessage =
            'プロフィールを保存できませんでした。';
      });
    }
  }

  String? _validateDisplayName(
    String? value,
  ) {
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
      backgroundColor:
          const Color(0xFFF7F5FB),
      appBar: AppBar(
        title: const Text('プロフィール'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child:
                  CircularProgressIndicator(),
            )
          : SafeArea(
              child:
                  SingleChildScrollView(
                padding:
                    const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: ProfileAvatar(
                          avatarKey: _avatarKey,
                          size: 96,
                        ),
                      ),
                      const SizedBox(height: 28),

                      _buildSection(
                        title: 'アバター',
                        description:
                            'マイページに表示するアイコンを選択します。',
                        child: Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children:
                              profileAvatarOptions
                                  .map(
                            (option) {
                              final selected =
                                  option.key ==
                                      _avatarKey;

                              return InkWell(
                                borderRadius:
                                    BorderRadius
                                        .circular(50),
                                onTap: () {
                                  setState(() {
                                    _avatarKey =
                                        option.key;
                                  });
                                },
                                child: Column(
                                  mainAxisSize:
                                      MainAxisSize.min,
                                  children: [
                                    ProfileAvatar(
                                      avatarKey:
                                          option.key,
                                      size: 64,
                                      iconSize: 30,
                                      selected:
                                          selected,
                                    ),
                                    const SizedBox(
                                      height: 6,
                                    ),
                                    Text(
                                      option.label,
                                      style:
                                          TextStyle(
                                        fontSize: 12,
                                        fontWeight:
                                            selected
                                                ? FontWeight
                                                    .bold
                                                : FontWeight
                                                    .normal,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ).toList(),
                        ),
                      ),

                      const SizedBox(height: 14),

                      _buildSection(
                        title: '表示名',
                        description:
                            'ランキングなどで公開される名前です。',
                        child: TextFormField(
                          controller:
                              _displayNameController,
                          maxLength: 30,
                          textInputAction:
                              TextInputAction.next,
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
                                  BorderRadius
                                      .circular(14),
                            ),
                          ),
                          validator:
                              _validateDisplayName,
                        ),
                      ),

                      const SizedBox(height: 14),

                      _buildSection(
                        title: '年代',
                        description:
                            '年代を選択できます。回答したくない場合は「回答しない」を選べます。',
                        child:
                            DropdownButtonFormField<
                                String>(
                          initialValue:
                              _ageGroup,
                          decoration:
                              InputDecoration(
                            prefixIcon:
                                const Icon(
                              Icons.cake_outlined,
                            ),
                            border:
                                OutlineInputBorder(
                              borderRadius:
                                  BorderRadius
                                      .circular(14),
                            ),
                          ),
                          hint: const Text(
                            '年代を選択',
                          ),
                          items: _ageGroups
                              .map(
                                (value) =>
                                    DropdownMenuItem<
                                        String>(
                                  value: value,
                                  child:
                                      Text(value),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              _ageGroup = value;
                            });
                          },
                        ),
                      ),

                      if (_errorMessage !=
                          null) ...[
                        const SizedBox(
                          height: 14,
                        ),
                        Container(
                          width: double.infinity,
                          padding:
                              const EdgeInsets.all(
                            14,
                          ),
                          decoration:
                              BoxDecoration(
                            color: Colors.red
                                .withValues(
                              alpha: 0.08,
                            ),
                            borderRadius:
                                BorderRadius
                                    .circular(14),
                          ),
                          child: Text(
                            _errorMessage!,
                            style:
                                const TextStyle(
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
                          onPressed: _isSaving
                              ? null
                              : _saveProfile,
                          style:
                              FilledButton.styleFrom(
                            backgroundColor:
                                const Color(
                              0xFF6A35C8,
                            ),
                            shape:
                                RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius
                                      .circular(16),
                            ),
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child:
                                      CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color:
                                        Colors.white,
                                  ),
                                )
                              : const Text(
                                  '保存する',
                                  style:
                                      TextStyle(
                                    fontSize: 16,
                                    fontWeight:
                                        FontWeight
                                            .bold,
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

  Widget _buildSection({
    required String title,
    required String description,
    required Widget child,
  }) {
    return Container(
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
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}