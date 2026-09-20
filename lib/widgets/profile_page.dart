import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../collection_history_service.dart';
import '../services/level_service.dart';
import 'profile_avatar.dart';
import 'quest_ui.dart';
import '../services/app_logger.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

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

  final LevelService _levelService = const LevelService();
  final CollectionHistoryService _historyService = CollectionHistoryService();

  LevelProgress? _levelProgress;

  supabase.SupabaseClient get _client => supabase.Supabase.instance.client;

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
          .select('display_name, age_group, avatar_key')
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) {
        return;
      }

      _displayNameController.text = data?['display_name']?.toString() ?? '';

      final loadedAgeGroup = data?['age_group']?.toString();

      final loadedAvatarKey = data?['avatar_key']?.toString();

      final totalCollected = await _historyService.loadTotalCollectionCount();

      final totalXp = _levelService.xpFromCollectedCount(totalCollected);

      final levelProgress = _levelService.progressFromXp(totalXp);

      if (!mounted) {
        return;
      }

      setState(() {
        _ageGroup = _ageGroups.contains(loadedAgeGroup) ? loadedAgeGroup : null;

        _avatarKey = profileAvatarOptionForKey(loadedAvatarKey).key;

        _levelProgress = levelProgress;

        _isLoading = false;
      });
    } catch (error, stackTrace) {
      appDebugPrint('[PROFILE] load failed unexpectedly: $error');
      appDebugPrint('[PROFILE] load stackTrace: $stackTrace');

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
      await _client.from('profiles').upsert({
        'id': user.id,
        'display_name': displayName,
        'age_group': _ageGroup,
        'avatar_key': _avatarKey,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'id');

      if (!mounted) {
        return;
      }

      QuestSnackBar.show(
        context,
        message: 'プロフィールを保存しました。',
        type: QuestNoticeType.success,
      );

      Navigator.of(context).pop(true);
    } on supabase.PostgrestException catch (error) {
      appDebugPrint(
        '[PROFILE] save failed: '
        'code=${error.code}, '
        'message=${error.message}, '
        'details=${error.details}, '
        'hint=${error.hint}',
      );

      if (!mounted) {
        return;
      }

      String message = 'プロフィールを保存できませんでした。';

      if (error.code == '23505') {
        message = 'その表示名はすでに使用されています。';
      } else if (error.code == '23514') {
        message = '入力内容を確認してください。';
      }

      setState(() {
        _isSaving = false;
        _errorMessage = message;
      });
    } catch (error, stackTrace) {
      appDebugPrint('[PROFILE] save failed unexpectedly: $error');
      appDebugPrint('[PROFILE] stackTrace: $stackTrace');

      if (!mounted) {
        return;
      }

      setState(() {
        _isSaving = false;
        _errorMessage = 'プロフィールを保存できませんでした。';
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

    if (text.characters.isEmpty || text.characters.length > 30) {
      return '表示名は1〜30文字で入力してください。';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'プロフィール',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: QuestUiTokens.ink,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: QuestUiTokens.primary,
                strokeWidth: 2.5,
              ),
            )
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      QuestGlassCard(
                        padding: const EdgeInsets.all(22),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                gradient: QuestUiTokens.primaryGradient,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: QuestUiTokens.primary.withValues(
                                      alpha: 0.18,
                                    ),
                                    blurRadius: 24,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: ProfileAvatar(
                                  avatarKey: _avatarKey,
                                  size: 96,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'ADVENTURER PROFILE',
                              style: TextStyle(
                                fontSize: 9,
                                letterSpacing: 1.45,
                                fontWeight: FontWeight.w900,
                                color: QuestUiTokens.mutedInk,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              _displayNameController.text.trim().isEmpty
                                  ? '冒険者プロフィール'
                                  : _displayNameController.text.trim(),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w900,
                                color: QuestUiTokens.ink,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const QuestStatusChip(
                              label: 'PROFILE',
                              icon: Icons.person_rounded,
                              accentColor: QuestUiTokens.cyan,
                            ),
                          ],
                        ),
                      ),

                      if (_levelProgress != null) ...[
                        const SizedBox(height: 14),
                        _buildLevelCard(_levelProgress!),
                      ],

                      const SizedBox(height: 14),

                      _buildSection(
                        title: 'アバター',
                        description: 'マイページに表示するアイコンを選択します。',
                        child: Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children: profileAvatarOptions.map((option) {
                            final selected = option.key == _avatarKey;

                            return InkWell(
                              borderRadius: BorderRadius.circular(18),
                              onTap: () {
                                setState(() {
                                  _avatarKey = option.key;
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? QuestUiTokens.primary.withValues(
                                          alpha: 0.07,
                                        )
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: selected
                                        ? QuestUiTokens.primary.withValues(
                                            alpha: 0.24,
                                          )
                                        : Colors.transparent,
                                  ),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ProfileAvatar(
                                      avatarKey: option.key,
                                      size: 64,
                                      iconSize: 30,
                                      selected: selected,
                                    ),
                                    const SizedBox(height: 7),
                                    Text(
                                      option.label,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: selected
                                            ? FontWeight.w900
                                            : FontWeight.w600,
                                        color: selected
                                            ? QuestUiTokens.primary
                                            : QuestUiTokens.mutedInk,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),

                      const SizedBox(height: 14),

                      _buildSection(
                        title: '表示名',
                        description: 'ランキングなどで公開される名前です。',
                        child: TextFormField(
                          controller: _displayNameController,
                          maxLength: 30,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            hintText: '表示名を入力',
                            prefixIcon: const Icon(
                              Icons.person_outline_rounded,
                              color: QuestUiTokens.primary,
                            ),
                            filled: true,
                            fillColor: QuestUiTokens.primary.withValues(
                              alpha: 0.035,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                QuestUiTokens.controlRadius,
                              ),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                QuestUiTokens.controlRadius,
                              ),
                              borderSide: BorderSide(
                                color: QuestUiTokens.ink.withValues(
                                  alpha: 0.06,
                                ),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                QuestUiTokens.controlRadius,
                              ),
                              borderSide: const BorderSide(
                                color: QuestUiTokens.primary,
                                width: 1.5,
                              ),
                            ),
                          ),
                          validator: _validateDisplayName,
                        ),
                      ),

                      const SizedBox(height: 14),

                      _buildSection(
                        title: '年代',
                        description: '年代を選択できます。回答したくない場合は「回答しない」を選べます。',
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () async {
                              final selected = await showModalBottomSheet<String>(
                                context: context,
                                useSafeArea: true,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                barrierColor: QuestUiTokens.ink.withValues(
                                  alpha: 0.48,
                                ),
                                builder: (sheetContext) {
                                  return Container(
                                    constraints: BoxConstraints(
                                      maxHeight:
                                          MediaQuery.sizeOf(sheetContext)
                                              .height *
                                          0.82,
                                    ),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFF6F8FC),
                                      borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(30),
                                      ),
                                    ),
                                    child: SafeArea(
                                      top: false,
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.fromLTRB(
                                              20,
                                              11,
                                              20,
                                              14,
                                            ),
                                            child: Column(
                                              children: [
                                                Container(
                                                  width: 42,
                                                  height: 4,
                                                  decoration: BoxDecoration(
                                                    color: QuestUiTokens
                                                        .mutedInk
                                                        .withValues(
                                                          alpha: 0.45,
                                                        ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          99,
                                                        ),
                                                  ),
                                                ),
                                                const SizedBox(height: 20),
                                                Row(
                                                  children: [
                                                    Container(
                                                      width: 48,
                                                      height: 48,
                                                      alignment:
                                                          Alignment.center,
                                                      decoration: BoxDecoration(
                                                        gradient: QuestUiTokens
                                                            .primaryGradient,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              16,
                                                            ),
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: QuestUiTokens
                                                                .primary
                                                                .withValues(
                                                                  alpha: 0.24,
                                                                ),
                                                            blurRadius: 16,
                                                            offset:
                                                                const Offset(
                                                                  0,
                                                                  6,
                                                                ),
                                                          ),
                                                        ],
                                                      ),
                                                      child: const Icon(
                                                        Icons.cake_outlined,
                                                        color: Colors.white,
                                                        size: 24,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 13),
                                                    const Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            'AGE GROUP',
                                                            style: TextStyle(
                                                              color:
                                                                  QuestUiTokens
                                                                      .primary,
                                                              fontSize: 9,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w900,
                                                              letterSpacing:
                                                                  1.6,
                                                            ),
                                                          ),
                                                          SizedBox(height: 3),
                                                          Text(
                                                            '年代を選択',
                                                            style: TextStyle(
                                                              color:
                                                                  QuestUiTokens
                                                                      .ink,
                                                              fontSize: 20,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w900,
                                                            ),
                                                          ),
                                                          SizedBox(height: 3),
                                                          Text(
                                                            'プロフィールに表示する年代を選べます',
                                                            style: TextStyle(
                                                              color:
                                                                  QuestUiTokens
                                                                      .mutedInk,
                                                              fontSize: 12,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          Flexible(
                                            child: SingleChildScrollView(
                                              padding:
                                                  const EdgeInsets.fromLTRB(
                                                    20,
                                                    4,
                                                    20,
                                                    20,
                                                  ),
                                              child: Column(
                                                children: _ageGroups.map((
                                                  value,
                                                ) {
                                                  final isSelected =
                                                      value == _ageGroup;

                                                  return Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          bottom: 9,
                                                        ),
                                                    child: Material(
                                                      color: Colors.transparent,
                                                      child: InkWell(
                                                        onTap: () {
                                                          Navigator.of(
                                                            sheetContext,
                                                          ).pop(value);
                                                        },
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              18,
                                                            ),
                                                        child: AnimatedContainer(
                                                          duration:
                                                              const Duration(
                                                                milliseconds:
                                                                    180,
                                                              ),
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 15,
                                                                vertical: 14,
                                                              ),
                                                          decoration: BoxDecoration(
                                                            gradient: isSelected
                                                                ? QuestUiTokens
                                                                      .primaryGradient
                                                                : null,
                                                            color: isSelected
                                                                ? null
                                                                : Colors.white,
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  18,
                                                                ),
                                                            border: Border.all(
                                                              color: isSelected
                                                                  ? Colors
                                                                        .transparent
                                                                  : QuestUiTokens
                                                                        .ink
                                                                        .withValues(
                                                                          alpha:
                                                                              0.06,
                                                                        ),
                                                            ),
                                                            boxShadow:
                                                                isSelected
                                                                ? [
                                                                    BoxShadow(
                                                                      color: QuestUiTokens
                                                                          .primary
                                                                          .withValues(
                                                                            alpha:
                                                                                0.18,
                                                                          ),
                                                                      blurRadius:
                                                                          14,
                                                                      offset:
                                                                          const Offset(
                                                                            0,
                                                                            5,
                                                                          ),
                                                                    ),
                                                                  ]
                                                                : null,
                                                          ),
                                                          child: Row(
                                                            children: [
                                                              Expanded(
                                                                child: Text(
                                                                  value,
                                                                  style: TextStyle(
                                                                    color:
                                                                        isSelected
                                                                        ? Colors
                                                                              .white
                                                                        : QuestUiTokens
                                                                              .ink,
                                                                    fontSize:
                                                                        14,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w800,
                                                                  ),
                                                                ),
                                                              ),
                                                              if (isSelected)
                                                                const Icon(
                                                                  Icons
                                                                      .check_circle_rounded,
                                                                  color: Colors
                                                                      .white,
                                                                  size: 20,
                                                                )
                                                              else
                                                                const Icon(
                                                                  Icons
                                                                      .chevron_right_rounded,
                                                                  color: QuestUiTokens
                                                                      .mutedInk,
                                                                  size: 20,
                                                                ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                }).toList(),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              );

                              if (!mounted || selected == null) {
                                return;
                              }

                              setState(() {
                                _ageGroup = selected;
                              });
                            },
                            borderRadius: BorderRadius.circular(
                              QuestUiTokens.controlRadius,
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 15,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: QuestUiTokens.cyan.withValues(
                                  alpha: 0.035,
                                ),
                                borderRadius: BorderRadius.circular(
                                  QuestUiTokens.controlRadius,
                                ),
                                border: Border.all(
                                  color: QuestUiTokens.ink.withValues(
                                    alpha: 0.06,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.cake_outlined,
                                    color: QuestUiTokens.cyan,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _ageGroup ?? '年代を選択',
                                      style: TextStyle(
                                        color: _ageGroup == null
                                            ? QuestUiTokens.mutedInk
                                            : QuestUiTokens.ink,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    color: QuestUiTokens.mutedInk,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      if (_errorMessage != null) ...[
                        const SizedBox(height: 14),
                        QuestGlassCard(
                          padding: const EdgeInsets.all(15),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                color: Colors.redAccent,
                                size: 21,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 13,
                                    height: 1.45,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 20),

                      QuestPrimaryButton(
                        label: _isSaving ? '保存中...' : '保存する',
                        icon: _isSaving
                            ? Icons.hourglass_top_rounded
                            : Icons.save_rounded,
                        onPressed: _isSaving ? null : _saveProfile,
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildLevelCard(LevelProgress progress) {
    final percent = (progress.progress * 100).round();

    return QuestGlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: QuestUiTokens.primaryGradient,
                  borderRadius: BorderRadius.circular(17),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 25,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ADVENTURER LEVEL',
                      style: TextStyle(
                        fontSize: 9,
                        letterSpacing: 1.25,
                        fontWeight: FontWeight.w900,
                        color: QuestUiTokens.mutedInk,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Lv.${progress.level}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: QuestUiTokens.ink,
                      ),
                    ),
                  ],
                ),
              ),
              QuestStatusChip(
                label: '${progress.totalXp} XP',
                icon: Icons.bolt_rounded,
                accentColor: QuestUiTokens.cyan,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Expanded(
                child: Text(
                  '次のレベルまで',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: QuestUiTokens.mutedInk,
                  ),
                ),
              ),
              Text(
                '$percent%',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: QuestUiTokens.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress.progress,
              minHeight: 9,
              backgroundColor: QuestUiTokens.primary.withValues(alpha: 0.09),
              valueColor: const AlwaysStoppedAnimation<Color>(
                QuestUiTokens.primary,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${progress.xpIntoLevel} / '
            '${progress.xpNeededForNextLevel} XP',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: QuestUiTokens.mutedInk,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required String description,
    required Widget child,
  }) {
    return QuestGlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 5,
                height: 22,
                decoration: BoxDecoration(
                  gradient: QuestUiTokens.cyanGradient,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: QuestUiTokens.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
              fontSize: 13,
              color: QuestUiTokens.mutedInk,
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
