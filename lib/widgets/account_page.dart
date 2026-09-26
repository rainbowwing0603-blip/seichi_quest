import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import 'quest_ui.dart';
import '../services/app_error_report.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();
  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  final _recoveryOtpController = TextEditingController();
  final _recoveryPasswordController = TextEditingController();
  final _recoveryPasswordConfirmController = TextEditingController();

  bool _isSendingEmail = false;
  bool _isVerifyingOtp = false;
  bool _isSavingPassword = false;
  bool _isSigningIn = false;
  bool _isSigningOut = false;
  bool _isDeletingAccount = false;
  bool _showExistingLogin = false;
  bool _obscureLoginPassword = true;
  bool _showPasswordRecovery = false;
  bool _recoveryEmailSent = false;
  bool _recoveryVerified = false;
  bool _isSendingRecoveryEmail = false;
  bool _isVerifyingRecoveryOtp = false;
  bool _isSavingRecoveryPassword = false;
  bool _obscureRecoveryPassword = true;
  bool _emailSent = false;
  bool _emailVerified = false;
  bool _obscurePassword = true;

  String? _pendingEmail;
  String? _message;
  bool _messageIsError = false;

  supabase.SupabaseClient get _client => supabase.Supabase.instance.client;

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _recoveryOtpController.dispose();
    _recoveryPasswordController.dispose();
    _recoveryPasswordConfirmController.dispose();
    super.dispose();
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) {
      return;
    }

    setState(() {
      _message = message;
      _messageIsError = isError;
    });
  }

  void _showAuthError(supabase.AuthException error) {
    _showMessage(
      AppErrorReport.message(
        AppErrorCodes.accountAuth,
        _authErrorMessage(error),
        error: error,
      ),
      isError: true,
    );
  }

  Future<void> _sendEmailVerification() async {
    final user = _client.auth.currentUser;

    if (user == null) {
      _showMessage('ログイン状態を確認できませんでした。', isError: true);
      return;
    }

    if (!user.isAnonymous) {
      _showMessage('このアカウントはすでに登録済みです。');
      return;
    }

    final email = _emailController.text.trim();

    if (email.isEmpty ||
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      _showMessage('正しいメールアドレスを入力してください。', isError: true);
      return;
    }

    setState(() {
      _isSendingEmail = true;
      _message = null;
    });

    try {
      await _client.auth.updateUser(supabase.UserAttributes(email: email));

      if (!mounted) {
        return;
      }

      setState(() {
        _pendingEmail = email;
        _emailSent = true;
        _message = '確認メールを送信しました。メールに記載された8桁の確認コードを入力してください。';
        _messageIsError = false;
      });
    } on supabase.AuthException catch (error) {
      _showAuthError(error);
    } catch (error) {
      _showMessage(
        AppErrorReport.message(
          AppErrorCodes.accountAuth,
          'メール送信に失敗しました。通信状態を確認してもう一度お試しください。',
          error: error,
        ),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSendingEmail = false;
        });
      }
    }
  }

  Future<void> _verifyEmailOtp() async {
    final email = _pendingEmail;
    final token = _otpController.text.trim();

    if (email == null || email.isEmpty) {
      _showMessage('先にメールアドレスを登録してください。', isError: true);
      return;
    }

    if (!RegExp(r'^\d{8}$').hasMatch(token)) {
      _showMessage('8桁の確認コードを入力してください。', isError: true);
      return;
    }

    setState(() {
      _isVerifyingOtp = true;
      _message = null;
    });

    try {
      await _client.auth.verifyOTP(
        email: email,
        token: token,
        type: supabase.OtpType.emailChange,
      );

      await _client.auth.refreshSession();

      if (!mounted) {
        return;
      }

      setState(() {
        _emailVerified = true;
        _message = 'メールアドレスを確認できました。続けてパスワードを設定してください。';
        _messageIsError = false;
      });
    } on supabase.AuthException catch (error) {
      _showAuthError(error);
    } catch (error) {
      _showMessage(
        AppErrorReport.message(
          AppErrorCodes.accountAuth,
          '確認コードの認証に失敗しました。',
          error: error,
        ),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isVerifyingOtp = false;
        });
      }
    }
  }

  Future<void> _savePassword() async {
    final password = _passwordController.text;
    final passwordConfirm = _passwordConfirmController.text;

    final user = _client.auth.currentUser;
    final canSetPassword =
        _emailVerified || (user != null && !user.isAnonymous);

    if (!canSetPassword) {
      _showMessage('先にメールアドレスの確認を完了してください。', isError: true);
      return;
    }

    if (password.length < 8) {
      _showMessage('パスワードは8文字以上で入力してください。', isError: true);
      return;
    }

    if (password != passwordConfirm) {
      _showMessage('確認用パスワードが一致していません。', isError: true);
      return;
    }

    setState(() {
      _isSavingPassword = true;
      _message = null;
    });

    try {
      await _client.auth.updateUser(
        supabase.UserAttributes(password: password),
      );

      await _client.auth.refreshSession();

      if (!mounted) {
        return;
      }

      setState(() {
        _emailVerified = false;
        _passwordController.clear();
        _passwordConfirmController.clear();
        _message = 'アカウント登録が完了しました。現在の獲得データをこのアカウントで引き継げます。';
        _messageIsError = false;
      });
    } on supabase.AuthException catch (error) {
      _showAuthError(error);
    } catch (error) {
      _showMessage(
        AppErrorReport.message(
          AppErrorCodes.accountAuth,
          'パスワードの設定に失敗しました。',
          error: error,
        ),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSavingPassword = false;
        });
      }
    }
  }

  Future<void> _sendPasswordRecoveryEmail() async {
    final email = _loginEmailController.text.trim();

    if (email.isEmpty ||
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      _showMessage('正しいメールアドレスを入力してください。', isError: true);
      return;
    }

    setState(() {
      _isSendingRecoveryEmail = true;
      _message = null;
    });

    try {
      await _client.auth.resetPasswordForEmail(email);

      if (!mounted) {
        return;
      }

      setState(() {
        _recoveryEmailSent = true;
        _message = 'パスワード再設定コードを送信しました。メールに記載された8桁の確認コードを入力してください。';
        _messageIsError = false;
      });
    } on supabase.AuthException catch (error) {
      _showAuthError(error);
    } catch (error) {
      _showMessage(
        AppErrorReport.message(
          AppErrorCodes.accountAuth,
          '再設定メールの送信に失敗しました。通信状態を確認してください。',
          error: error,
        ),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSendingRecoveryEmail = false;
        });
      }
    }
  }

  Future<void> _verifyPasswordRecoveryOtp() async {
    final email = _loginEmailController.text.trim();
    final token = _recoveryOtpController.text.trim();

    if (email.isEmpty) {
      _showMessage('メールアドレスを入力してください。', isError: true);
      return;
    }

    if (!RegExp(r'^\d{8}$').hasMatch(token)) {
      _showMessage('8桁の確認コードを入力してください。', isError: true);
      return;
    }

    setState(() {
      _isVerifyingRecoveryOtp = true;
      _message = null;
    });

    try {
      await _client.auth.verifyOTP(
        email: email,
        token: token,
        type: supabase.OtpType.recovery,
      );

      await _client.auth.refreshSession();

      if (!mounted) {
        return;
      }

      setState(() {
        _recoveryVerified = true;
        _message = '確認コードを認証しました。新しいパスワードを設定してください。';
        _messageIsError = false;
      });
    } on supabase.AuthException catch (error) {
      _showAuthError(error);
    } catch (error) {
      _showMessage(
        AppErrorReport.message(
          AppErrorCodes.accountAuth,
          '確認コードの認証に失敗しました。',
          error: error,
        ),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isVerifyingRecoveryOtp = false;
        });
      }
    }
  }

  Future<void> _saveRecoveredPassword() async {
    final password = _recoveryPasswordController.text;
    final passwordConfirm = _recoveryPasswordConfirmController.text;

    if (!_recoveryVerified) {
      _showMessage('先に確認コードを認証してください。', isError: true);
      return;
    }

    if (password.length < 8) {
      _showMessage('パスワードは8文字以上で入力してください。', isError: true);
      return;
    }

    if (password != passwordConfirm) {
      _showMessage('確認用パスワードが一致していません。', isError: true);
      return;
    }

    setState(() {
      _isSavingRecoveryPassword = true;
      _message = null;
    });

    try {
      await _client.auth.updateUser(
        supabase.UserAttributes(password: password),
      );

      await _client.auth.refreshSession();

      if (!mounted) {
        return;
      }

      _recoveryPasswordController.clear();
      _recoveryPasswordConfirmController.clear();
      _recoveryOtpController.clear();

      Navigator.of(context).pop(true);
    } on supabase.AuthException catch (error) {
      _showAuthError(error);
    } catch (error) {
      _showMessage(
        AppErrorReport.message(
          AppErrorCodes.accountAuth,
          'パスワードの再設定に失敗しました。',
          error: error,
        ),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSavingRecoveryPassword = false;
        });
      }
    }
  }

  Future<void> _deleteCurrentAccount() async {
    final firstConfirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return QuestDialog(
          icon: Icons.person_remove_alt_1_rounded,
          title: 'アカウントを削除',
          subtitle: 'このアカウントに紐づくデータも削除されます',
          content: const Text(
            '獲得履歴や訪問履歴など、このアカウントに紐づくデータも削除されます。',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: QuestUiTokens.mutedInk,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.55,
            ),
          ),
          actionLabel: '次へ',
          actionIcon: Icons.arrow_forward_rounded,
          onAction: () => Navigator.of(dialogContext).pop(true),
          secondaryActionLabel: 'キャンセル',
          onSecondaryAction: () => Navigator.of(dialogContext).pop(false),
        );
      },
    );

    if (firstConfirmed != true || !mounted) {
      return;
    }

    final finalConfirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return QuestDialog(
          icon: Icons.warning_amber_rounded,
          title: '本当に削除しますか？',
          subtitle: 'この操作は取り消せません',
          content: const Text(
            '削除したアカウントでは再ログインできません。',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: QuestUiTokens.mutedInk,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.55,
            ),
          ),
          actionLabel: '完全に削除する',
          actionIcon: Icons.delete_forever_rounded,
          onAction: () => Navigator.of(dialogContext).pop(true),
          secondaryActionLabel: '戻る',
          onSecondaryAction: () => Navigator.of(dialogContext).pop(false),
          isDestructive: true,
        );
      },
    );

    if (finalConfirmed != true || !mounted) {
      return;
    }

    setState(() {
      _isDeletingAccount = true;
      _message = null;
    });

    try {
      final response = await _client.functions.invoke('delete-account');

      final data = response.data;

      if (data is! Map || data['ok'] != true) {
        String? errorMessage;

        if (data is Map) {
          errorMessage = data['error']?.toString();
        }

        throw Exception(errorMessage ?? 'アカウント削除に失敗しました。');
      }

      try {
        await _client.auth.signOut();
      } catch (_) {
        // Authユーザー自体は既に削除済みの可能性があるため、
        // サーバー側signOut失敗だけでは削除成功を取り消さない。
      }

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
    } catch (error) {
      _showMessage(
        AppErrorReport.message(
          AppErrorCodes.accountAuth,
          'アカウントの削除に失敗しました。通信状態を確認してもう一度お試しください。',
          error: error,
        ),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isDeletingAccount = false;
        });
      }
    }
  }

  Future<void> _signOutCurrentAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return QuestDialog(
          icon: Icons.logout_rounded,
          title: 'ログアウト',
          subtitle: 'このアカウントからログアウトします',
          content: const Text(
            '獲得データはアカウントに保存されているため、再ログインすると復元できます。',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: QuestUiTokens.mutedInk,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.55,
            ),
          ),
          actionLabel: 'ログアウト',
          actionIcon: Icons.logout_rounded,
          onAction: () => Navigator.of(dialogContext).pop(true),
          secondaryActionLabel: 'キャンセル',
          onSecondaryAction: () => Navigator.of(dialogContext).pop(false),
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _isSigningOut = true;
      _message = null;
    });

    try {
      await _client.auth.signOut();

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
    } on supabase.AuthException catch (error) {
      _showAuthError(error);
    } catch (error) {
      _showMessage(
        AppErrorReport.message(
          AppErrorCodes.accountAuth,
          'ログアウトに失敗しました。通信状態を確認してください。',
          error: error,
        ),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSigningOut = false;
        });
      }
    }
  }

  Future<void> _signInExistingAccount() async {
    final email = _loginEmailController.text.trim();
    final password = _loginPasswordController.text;

    if (email.isEmpty ||
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      _showMessage('正しいメールアドレスを入力してください。', isError: true);
      return;
    }

    if (password.isEmpty) {
      _showMessage('パスワードを入力してください。', isError: true);
      return;
    }

    final currentUser = _client.auth.currentUser;

    if (currentUser != null && currentUser.isAnonymous) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return QuestDialog(
            icon: Icons.switch_account_rounded,
            title: '既存アカウントでログイン',
            subtitle: 'ゲストアカウントから切り替えます',
            content: const Text(
              'ゲストアカウント側の獲得記録は、既存アカウントへ自動統合されません。',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: QuestUiTokens.mutedInk,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.55,
              ),
            ),
            actionLabel: 'ログインする',
            actionIcon: Icons.login_rounded,
            onAction: () => Navigator.of(dialogContext).pop(true),
            secondaryActionLabel: 'キャンセル',
            onSecondaryAction: () => Navigator.of(dialogContext).pop(false),
          );
        },
      );

      if (confirmed != true) {
        return;
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isSigningIn = true;
      _message = null;
    });

    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        _showMessage('ログイン状態を確認できませんでした。', isError: true);
        return;
      }

      if (!mounted) {
        return;
      }

      _loginPasswordController.clear();
      Navigator.of(context).pop(true);
    } on supabase.AuthException catch (error) {
      _showAuthError(error);
    } catch (error) {
      _showMessage(
        AppErrorReport.message(
          AppErrorCodes.accountAuth,
          'ログインに失敗しました。通信状態を確認してもう一度お試しください。',
          error: error,
        ),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSigningIn = false;
        });
      }
    }
  }

  String _authErrorMessage(supabase.AuthException error) {
    final message = error.message.toLowerCase();

    if (message.contains('invalid login credentials')) {
      return 'メールアドレスまたはパスワードが正しくありません。';
    }

    if (message.contains('email not confirmed')) {
      return 'メールアドレスの確認が完了していません。';
    }

    if (message.contains('already') && message.contains('registered')) {
      return 'このメールアドレスはすでに別のアカウントで使用されています。';
    }

    if (message.contains('already') && message.contains('exists')) {
      return 'このメールアドレスはすでに別のアカウントで使用されています。';
    }

    if (message.contains('invalid') && message.contains('email')) {
      return 'メールアドレスの形式が正しくありません。';
    }

    if (message.contains('expired')) {
      return '確認コードの有効期限が切れています。もう一度メールを送信してください。';
    }

    if (message.contains('token') || message.contains('otp')) {
      return '確認コードが正しくありません。';
    }

    if (message.contains('rate')) {
      return '短時間に操作が繰り返されました。少し時間を空けてからもう一度お試しください。';
    }

    return '認証処理に失敗しました。通信状態を確認してもう一度お試しください。';
  }

  @override
  Widget build(BuildContext context) {
    final user = _client.auth.currentUser;
    final isAnonymous = user?.isAnonymous ?? true;
    final email = user?.email ?? _pendingEmail;

    return Scaffold(
      backgroundColor: QuestUiTokens.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'アカウント',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: QuestUiTokens.ink,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
          children: [
            QuestGlassCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAccountHeader(isAnonymous: isAnonymous, email: email),
                  const SizedBox(height: 22),
                  if (_showPasswordRecovery) ...[
                    _buildPasswordRecovery(),
                  ] else if (_emailVerified) ...[
                    _buildPasswordStep(),
                  ] else if (isAnonymous) ...[
                    if (_showExistingLogin)
                      _buildExistingLogin()
                    else
                      _buildAnonymousRegistration(),
                  ] else ...[
                    _buildRegisteredAccount(email),
                  ],
                ],
              ),
            ),
            if (_message != null) ...[
              const SizedBox(height: 14),
              QuestGlassCard(
                padding: const EdgeInsets.all(15),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: _messageIsError
                            ? Colors.red.withValues(alpha: 0.08)
                            : Colors.green.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(
                        _messageIsError
                            ? Icons.error_outline_rounded
                            : Icons.check_circle_outline_rounded,
                        color: _messageIsError
                            ? Colors.redAccent
                            : Colors.green,
                        size: 21,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          _message!,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.45,
                            fontWeight: FontWeight.w700,
                            color: _messageIsError
                                ? Colors.red.shade700
                                : Colors.green.shade800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAccountHeader({
    required bool isAnonymous,
    required String? email,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            gradient: isAnonymous
                ? QuestUiTokens.cyanGradient
                : QuestUiTokens.primaryGradient,
            borderRadius: BorderRadius.circular(19),
            boxShadow: [
              BoxShadow(
                color:
                    (isAnonymous ? QuestUiTokens.cyan : QuestUiTokens.primary)
                        .withValues(alpha: 0.16),
                blurRadius: 20,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Icon(
            isAnonymous
                ? Icons.person_outline_rounded
                : Icons.verified_user_outlined,
            color: Colors.white,
            size: 28,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isAnonymous ? 'GUEST ACCOUNT' : 'PLAYER ACCOUNT',
                style: const TextStyle(
                  fontSize: 9,
                  letterSpacing: 1.3,
                  fontWeight: FontWeight.w900,
                  color: QuestUiTokens.mutedInk,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isAnonymous ? 'ゲストアカウント' : '登録済みアカウント',
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  color: QuestUiTokens.ink,
                ),
              ),
              const SizedBox(height: 7),
              QuestStatusChip(
                label: isAnonymous ? 'ゲスト' : '登録済み',
                icon: isAnonymous
                    ? Icons.person_outline_rounded
                    : Icons.verified_rounded,
                accentColor: isAnonymous
                    ? QuestUiTokens.cyan
                    : QuestUiTokens.primary,
              ),
              const SizedBox(height: 9),
              Text(
                isAnonymous
                    ? '現在のデータはこの端末の匿名アカウントに紐づいています。'
                    : email ?? 'メールアドレス登録済み',
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.45,
                  color: QuestUiTokens.mutedInk,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAnonymousRegistration() {
    if (_emailVerified) {
      return _buildPasswordStep();
    }

    if (_emailSent) {
      return _buildOtpStep();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SAVE YOUR JOURNEY',
          style: TextStyle(
            fontSize: 9,
            letterSpacing: 1.3,
            fontWeight: FontWeight.w900,
            color: QuestUiTokens.mutedInk,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'データを引き継げるようにする',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: QuestUiTokens.ink,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'メールアドレスを登録すると、機種変更や再インストール後も現在の獲得記録を引き継げるようになります。',
          style: TextStyle(
            height: 1.5,
            fontSize: 12,
            color: QuestUiTokens.mutedInk,
          ),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            labelText: 'メールアドレス',
            hintText: 'example@example.com',
            prefixIcon: const Icon(Icons.mail_outline_rounded),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.72),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(QuestUiTokens.controlRadius),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(QuestUiTokens.controlRadius),
              borderSide: BorderSide(
                color: QuestUiTokens.primary.withValues(alpha: 0.10),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(QuestUiTokens.controlRadius),
              borderSide: const BorderSide(
                color: QuestUiTokens.primary,
                width: 1.5,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        QuestPrimaryButton(
          label: _isSendingEmail ? '送信中...' : '確認メールを送信',
          icon: _isSendingEmail
              ? Icons.hourglass_top_rounded
              : Icons.mark_email_read_outlined,
          onPressed: _isSendingEmail ? null : _sendEmailVerification,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: QuestUiTokens.cyan.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(15),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.shield_outlined, size: 18, color: QuestUiTokens.cyan),
              SizedBox(width: 9),
              Expanded(
                child: Text(
                  '登録しても現在のユーザーIDは変わらないため、これまでの獲得データはそのまま引き継がれます。',
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.45,
                    color: QuestUiTokens.mutedInk,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TextButton.icon(
          onPressed: () {
            setState(() {
              _showExistingLogin = true;
              _message = null;
            });
          },
          icon: const Icon(Icons.login_outlined),
          label: const Text('すでにアカウントをお持ちの方'),
        ),
      ],
    );
  }

  Widget _buildExistingLogin() {
    if (_showPasswordRecovery) {
      return _buildPasswordRecovery();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'WELCOME BACK',
          style: TextStyle(
            fontSize: 9,
            letterSpacing: 1.3,
            fontWeight: FontWeight.w900,
            color: QuestUiTokens.mutedInk,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          '既存アカウントでログイン',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: QuestUiTokens.ink,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '以前に登録したメールアドレスとパスワードを入力してください。',
          style: TextStyle(
            height: 1.5,
            fontSize: 12,
            color: QuestUiTokens.mutedInk,
          ),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _loginEmailController,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            labelText: 'メールアドレス',
            hintText: 'example@example.com',
            prefixIcon: const Icon(Icons.mail_outline_rounded),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.72),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(QuestUiTokens.controlRadius),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(QuestUiTokens.controlRadius),
              borderSide: BorderSide(
                color: QuestUiTokens.primary.withValues(alpha: 0.10),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(QuestUiTokens.controlRadius),
              borderSide: const BorderSide(
                color: QuestUiTokens.primary,
                width: 1.5,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _loginPasswordController,
          obscureText: _obscureLoginPassword,
          onSubmitted: (_) {
            if (!_isSigningIn) {
              _signInExistingAccount();
            }
          },
          decoration: InputDecoration(
            labelText: 'パスワード',
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            suffixIcon: IconButton(
              onPressed: () {
                setState(() {
                  _obscureLoginPassword = !_obscureLoginPassword;
                });
              },
              icon: Icon(
                _obscureLoginPassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
            ),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.72),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(QuestUiTokens.controlRadius),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(QuestUiTokens.controlRadius),
              borderSide: BorderSide(
                color: QuestUiTokens.primary.withValues(alpha: 0.10),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(QuestUiTokens.controlRadius),
              borderSide: const BorderSide(
                color: QuestUiTokens.primary,
                width: 1.5,
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        QuestPrimaryButton(
          label: _isSigningIn ? 'ログイン中...' : 'ログイン',
          icon: _isSigningIn
              ? Icons.hourglass_top_rounded
              : Icons.login_outlined,
          onPressed: _isSigningIn ? null : _signInExistingAccount,
        ),
        const SizedBox(height: 6),
        Center(
          child: TextButton(
            onPressed: _isSigningIn
                ? null
                : () {
                    setState(() {
                      _showPasswordRecovery = true;
                      _recoveryEmailSent = false;
                      _recoveryVerified = false;
                      _message = null;
                    });
                  },
            child: const Text('パスワードを忘れた方'),
          ),
        ),
        Center(
          child: TextButton(
            onPressed: _isSigningIn
                ? null
                : () {
                    setState(() {
                      _showExistingLogin = false;
                      _loginPasswordController.clear();
                      _message = null;
                    });
                  },
            child: const Text('ゲストアカウントの登録に戻る'),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordRecovery() {
    if (_recoveryVerified) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const QuestStatusChip(
            label: '本人確認済み',
            icon: Icons.verified_rounded,
            accentColor: QuestUiTokens.cyan,
          ),
          const SizedBox(height: 14),
          const Text(
            '新しいパスワードを設定',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: QuestUiTokens.ink,
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _recoveryPasswordController,
            obscureText: _obscureRecoveryPassword,
            decoration: InputDecoration(
              labelText: '新しいパスワード',
              hintText: '8文字以上',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                onPressed: () {
                  setState(() {
                    _obscureRecoveryPassword = !_obscureRecoveryPassword;
                  });
                },
                icon: Icon(
                  _obscureRecoveryPassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.72),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                  QuestUiTokens.controlRadius,
                ),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _recoveryPasswordConfirmController,
            obscureText: _obscureRecoveryPassword,
            decoration: InputDecoration(
              labelText: '新しいパスワード確認',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.72),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                  QuestUiTokens.controlRadius,
                ),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 18),
          QuestPrimaryButton(
            label: _isSavingRecoveryPassword ? '更新中...' : 'パスワードを更新',
            icon: _isSavingRecoveryPassword
                ? Icons.hourglass_top_rounded
                : Icons.password_rounded,
            onPressed: _isSavingRecoveryPassword
                ? null
                : _saveRecoveredPassword,
          ),
        ],
      );
    }

    if (_recoveryEmailSent) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'VERIFY CODE',
            style: TextStyle(
              fontSize: 9,
              letterSpacing: 1.3,
              fontWeight: FontWeight.w900,
              color: QuestUiTokens.mutedInk,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            '確認コードを入力',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: QuestUiTokens.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_loginEmailController.text.trim()} に再設定コードを送信しました。',
            style: const TextStyle(
              height: 1.5,
              fontSize: 12,
              color: QuestUiTokens.mutedInk,
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _recoveryOtpController,
            keyboardType: TextInputType.number,
            maxLength: 8,
            decoration: InputDecoration(
              labelText: '8桁の確認コード',
              prefixIcon: const Icon(Icons.pin_outlined),
              counterText: '',
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.72),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                  QuestUiTokens.controlRadius,
                ),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 14),
          QuestPrimaryButton(
            label: _isVerifyingRecoveryOtp ? '確認中...' : '確認する',
            icon: _isVerifyingRecoveryOtp
                ? Icons.hourglass_top_rounded
                : Icons.verified_outlined,
            onPressed: _isVerifyingRecoveryOtp
                ? null
                : _verifyPasswordRecoveryOtp,
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: _isSendingRecoveryEmail
                  ? null
                  : _sendPasswordRecoveryEmail,
              child: const Text('再設定コードを再送'),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ACCOUNT RECOVERY',
          style: TextStyle(
            fontSize: 9,
            letterSpacing: 1.3,
            fontWeight: FontWeight.w900,
            color: QuestUiTokens.mutedInk,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'パスワードを再設定',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: QuestUiTokens.ink,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '登録済みのメールアドレスへ確認コードを送信します。',
          style: TextStyle(
            height: 1.5,
            fontSize: 12,
            color: QuestUiTokens.mutedInk,
          ),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _loginEmailController,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            labelText: 'メールアドレス',
            prefixIcon: const Icon(Icons.mail_outline_rounded),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.72),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(QuestUiTokens.controlRadius),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 18),
        QuestPrimaryButton(
          label: _isSendingRecoveryEmail ? '送信中...' : '再設定コードを送信',
          icon: _isSendingRecoveryEmail
              ? Icons.hourglass_top_rounded
              : Icons.mark_email_read_outlined,
          onPressed: _isSendingRecoveryEmail
              ? null
              : _sendPasswordRecoveryEmail,
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: () {
              setState(() {
                _showPasswordRecovery = false;
                _recoveryEmailSent = false;
                _recoveryVerified = false;
                _recoveryOtpController.clear();
                _message = null;
              });
            },
            child: const Text('ログイン画面に戻る'),
          ),
        ),
      ],
    );
  }

  Widget _buildOtpStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'VERIFY EMAIL',
          style: TextStyle(
            fontSize: 9,
            letterSpacing: 1.3,
            fontWeight: FontWeight.w900,
            color: QuestUiTokens.mutedInk,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'メールアドレスを確認',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: QuestUiTokens.ink,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${_pendingEmail ?? ''} に確認メールを送信しました。',
          style: const TextStyle(
            height: 1.5,
            fontSize: 12,
            color: QuestUiTokens.mutedInk,
          ),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          maxLength: 8,
          decoration: InputDecoration(
            labelText: '8桁の確認コード',
            prefixIcon: const Icon(Icons.pin_outlined),
            counterText: '',
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.72),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(QuestUiTokens.controlRadius),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 14),
        QuestPrimaryButton(
          label: _isVerifyingOtp ? '確認中...' : '確認する',
          icon: _isVerifyingOtp
              ? Icons.hourglass_top_rounded
              : Icons.verified_outlined,
          onPressed: _isVerifyingOtp ? null : _verifyEmailOtp,
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: _isSendingEmail ? null : _sendEmailVerification,
            child: const Text('確認メールを再送'),
          ),
        ),
        Center(
          child: TextButton(
            onPressed: () {
              setState(() {
                _emailSent = false;
                _otpController.clear();
                _message = null;
              });
            },
            child: const Text('メールアドレスを変更'),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const QuestStatusChip(
          label: 'メール確認済み',
          icon: Icons.check_circle_rounded,
          accentColor: QuestUiTokens.cyan,
        ),
        const SizedBox(height: 14),
        const Text(
          'CREATE PASSWORD',
          style: TextStyle(
            fontSize: 9,
            letterSpacing: 1.3,
            fontWeight: FontWeight.w900,
            color: QuestUiTokens.mutedInk,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'パスワードを設定',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: QuestUiTokens.ink,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '別の端末からログインするときに使用するパスワードを設定します。',
          style: TextStyle(
            height: 1.5,
            fontSize: 12,
            color: QuestUiTokens.mutedInk,
          ),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            labelText: 'パスワード',
            hintText: '8文字以上',
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            suffixIcon: IconButton(
              onPressed: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
            ),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.72),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(QuestUiTokens.controlRadius),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _passwordConfirmController,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            labelText: 'パスワード確認',
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.72),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(QuestUiTokens.controlRadius),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 18),
        QuestPrimaryButton(
          label: _isSavingPassword ? '登録中...' : 'アカウント登録を完了',
          icon: _isSavingPassword
              ? Icons.hourglass_top_rounded
              : Icons.verified_user_outlined,
          onPressed: _isSavingPassword ? null : _savePassword,
        ),
      ],
    );
  }

  Widget _buildRegisteredAccount(String? email) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const QuestStatusChip(
          label: '引き継ぎ対応',
          icon: Icons.cloud_done_outlined,
          accentColor: QuestUiTokens.cyan,
        ),
        const SizedBox(height: 14),
        const Text(
          'ACCOUNT READY',
          style: TextStyle(
            fontSize: 9,
            letterSpacing: 1.3,
            fontWeight: FontWeight.w900,
            color: QuestUiTokens.mutedInk,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'このアカウントは引き継ぎに対応しています。',
          style: TextStyle(
            fontSize: 16,
            height: 1.4,
            fontWeight: FontWeight.w900,
            color: QuestUiTokens.ink,
          ),
        ),
        if (email != null) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: QuestUiTokens.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.mail_outline_rounded,
                  size: 18,
                  color: QuestUiTokens.primary,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    email,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: QuestUiTokens.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        QuestPrimaryButton(
          label: 'パスワードを設定・変更',
          icon: Icons.password_outlined,
          onPressed: () {
            setState(() {
              _emailVerified = true;
              _message = null;
            });
          },
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton.icon(
            onPressed: () {
              setState(() {
                _showPasswordRecovery = true;
                _recoveryEmailSent = false;
                _recoveryVerified = false;
                _message = null;
              });
            },
            icon: const Icon(Icons.key_outlined),
            label: const Text('パスワードを忘れた方'),
          ),
        ),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          height: 1,
          color: QuestUiTokens.mutedInk.withValues(alpha: 0.10),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _isSigningOut ? null : _signOutCurrentAccount,
            style: OutlinedButton.styleFrom(
              foregroundColor: QuestUiTokens.ink,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  QuestUiTokens.controlRadius,
                ),
              ),
            ),
            icon: _isSigningOut
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.logout_outlined),
            label: Text(_isSigningOut ? 'ログアウト中...' : 'ログアウト'),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton.icon(
            onPressed: _isDeletingAccount || _isSigningOut
                ? null
                : _deleteCurrentAccount,
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            icon: _isDeletingAccount
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete_forever_outlined),
            label: Text(_isDeletingAccount ? '削除中...' : 'アカウントを削除'),
          ),
        ),
      ],
    );
  }
}
