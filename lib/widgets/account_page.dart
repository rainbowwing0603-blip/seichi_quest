import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

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
      _showMessage(_authErrorMessage(error), isError: true);
    } catch (error) {
      _showMessage('メール送信に失敗しました。通信状態を確認してもう一度お試しください。', isError: true);
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
      _showMessage(_authErrorMessage(error), isError: true);
    } catch (error) {
      _showMessage('確認コードの認証に失敗しました。', isError: true);
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
      _showMessage(_authErrorMessage(error), isError: true);
    } catch (error) {
      _showMessage('パスワードの設定に失敗しました。', isError: true);
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
      _showMessage(_authErrorMessage(error), isError: true);
    } catch (error) {
      _showMessage('再設定メールの送信に失敗しました。通信状態を確認してください。', isError: true);
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
      _showMessage(_authErrorMessage(error), isError: true);
    } catch (error) {
      _showMessage('確認コードの認証に失敗しました。', isError: true);
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
      _showMessage(_authErrorMessage(error), isError: true);
    } catch (error) {
      _showMessage('パスワードの再設定に失敗しました。', isError: true);
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
        return AlertDialog(
          title: const Text('アカウントを削除'),
          content: const Text(
            'アカウントを削除すると、獲得履歴や訪問履歴など、このアカウントに紐づくデータも削除されます。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('次へ'),
            ),
          ],
        );
      },
    );

    if (firstConfirmed != true || !mounted) {
      return;
    }

    final finalConfirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('本当に削除しますか？'),
          content: const Text(
            'この操作は取り消せません。削除したアカウントでは再ログインできません。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('戻る'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text('完全に削除する'),
            ),
          ],
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
      final response = await _client.functions.invoke(
        'delete-account',
      );

      final data = response.data;

      if (data is! Map || data['ok'] != true) {
        String? errorMessage;

        if (data is Map) {
          errorMessage = data['error']?.toString();
        }

        throw Exception(
          errorMessage ?? 'アカウント削除に失敗しました。',
        );
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
        'アカウントの削除に失敗しました。通信状態を確認してもう一度お試しください。',
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
        return AlertDialog(
          title: const Text('ログアウト'),
          content: const Text(
            'このアカウントからログアウトします。獲得データはアカウントに保存されているため、再ログインすると復元できます。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('ログアウト'),
            ),
          ],
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
      _showMessage(_authErrorMessage(error), isError: true);
    } catch (error) {
      _showMessage('ログアウトに失敗しました。通信状態を確認してください。', isError: true);
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
          return AlertDialog(
            title: const Text('既存アカウントでログイン'),
            content: const Text(
              '現在のゲストアカウントから既存アカウントへ切り替えます。'
              'ゲストアカウント側の獲得記録は、既存アカウントへ自動統合されません。'
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('キャンセル'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('ログインする'),
              ),
            ],
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
      _showMessage(_authErrorMessage(error), isError: true);
    } catch (error) {
      _showMessage('ログインに失敗しました。通信状態を確認してもう一度お試しください。', isError: true);
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

    return '認証処理に失敗しました: ${error.message}';
  }

  @override
  Widget build(BuildContext context) {
    final user = _client.auth.currentUser;
    final isAnonymous = user?.isAnonymous ?? true;
    final email = user?.email ?? _pendingEmail;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F5FB),
      appBar: AppBar(
        title: const Text('アカウント'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAccountHeader(isAnonymous: isAnonymous, email: email),
                  const SizedBox(height: 22),
                  if (_showPasswordRecovery) ...[
                    _buildPasswordRecovery(),
                  ] else 
                  if (_emailVerified) ...[
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
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _messageIsError
                      ? Colors.red.withValues(alpha: 0.07)
                      : Colors.green.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _messageIsError
                          ? Icons.error_outline
                          : Icons.check_circle_outline,
                      color: _messageIsError ? Colors.red : Colors.green,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _message!,
                        style: TextStyle(
                          height: 1.4,
                          color: _messageIsError
                              ? Colors.red.shade700
                              : Colors.green.shade800,
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
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.deepPurple.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isAnonymous ? Icons.person_outline : Icons.verified_user_outlined,
            color: Colors.deepPurple,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isAnonymous ? 'ゲストアカウント' : '登録済みアカウント',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isAnonymous
                    ? '現在のデータはこの端末の匿名アカウントに紐づいています。'
                    : email ?? 'メールアドレス登録済み',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
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
          'データを引き継げるようにする',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'メールアドレスを登録すると、機種変更や再インストール後も現在の獲得記録を引き継げるようになります。',
          style: TextStyle(height: 1.5, color: Colors.grey.shade700),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          enableSuggestions: false,
          decoration: const InputDecoration(
            labelText: 'メールアドレス',
            hintText: 'example@example.com',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.mail_outline),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _isSendingEmail ? null : _sendEmailVerification,
            icon: _isSendingEmail
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.mail_outline),
            label: Text(_isSendingEmail ? '送信中...' : '確認メールを送信'),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '登録しても現在のユーザーIDは変わらないため、これまでの獲得データはそのまま引き継がれます。',
          style: TextStyle(
            fontSize: 12,
            height: 1.4,
            color: Colors.grey.shade500,
          ),
        ),
        const SizedBox(height: 18),
        const Divider(),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            onPressed: () {
              setState(() {
                _showExistingLogin = true;
                _message = null;
              });
            },
            icon: const Icon(Icons.login_outlined),
            label: const Text('すでにアカウントをお持ちの方'),
          ),
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
          '既存アカウントでログイン',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          '以前に登録したメールアドレスとパスワードを入力してください。',
          style: TextStyle(height: 1.5, color: Colors.grey.shade700),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _loginEmailController,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          enableSuggestions: false,
          decoration: const InputDecoration(
            labelText: 'メールアドレス',
            hintText: 'example@example.com',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.mail_outline),
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
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.lock_outline),
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
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _isSigningIn ? null : _signInExistingAccount,
            icon: _isSigningIn
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.login_outlined),
            label: Text(_isSigningIn ? 'ログイン中...' : 'ログイン'),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: double.infinity,
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
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
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
          const Text(
            '新しいパスワードを設定',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _recoveryPasswordController,
            obscureText: _obscureRecoveryPassword,
            decoration: InputDecoration(
              labelText: '新しいパスワード',
              hintText: '8文字以上',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                onPressed: () {
                  setState(() {
                    _obscureRecoveryPassword =
                        !_obscureRecoveryPassword;
                  });
                },
                icon: Icon(
                  _obscureRecoveryPassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _recoveryPasswordConfirmController,
            obscureText: _obscureRecoveryPassword,
            decoration: const InputDecoration(
              labelText: '新しいパスワード確認',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.lock_outline),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _isSavingRecoveryPassword
                  ? null
                  : _saveRecoveredPassword,
              child: Text(
                _isSavingRecoveryPassword ? '更新中...' : 'パスワードを更新',
              ),
            ),
          ),
        ],
      );
    }

    if (_recoveryEmailSent) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '確認コードを入力',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            '${_loginEmailController.text.trim()} に再設定コードを送信しました。',
            style: TextStyle(height: 1.5, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _recoveryOtpController,
            keyboardType: TextInputType.number,
            maxLength: 8,
            decoration: const InputDecoration(
              labelText: '8桁の確認コード',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.pin_outlined),
              counterText: '',
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _isVerifyingRecoveryOtp
                  ? null
                  : _verifyPasswordRecoveryOtp,
              child: Text(
                _isVerifyingRecoveryOtp ? '確認中...' : '確認する',
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
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
          'パスワードを再設定',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          '登録済みのメールアドレスへ確認コードを送信します。',
          style: TextStyle(height: 1.5, color: Colors.grey.shade700),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _loginEmailController,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          enableSuggestions: false,
          decoration: const InputDecoration(
            labelText: 'メールアドレス',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.mail_outline),
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _isSendingRecoveryEmail
                ? null
                : _sendPasswordRecoveryEmail,
            icon: const Icon(Icons.mark_email_read_outlined),
            label: Text(
              _isSendingRecoveryEmail ? '送信中...' : '再設定コードを送信',
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
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
          'メールアドレスを確認',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          '${_pendingEmail ?? ''} に確認メールを送信しました。',
          style: TextStyle(height: 1.5, color: Colors.grey.shade700),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          maxLength: 8,
          decoration: const InputDecoration(
            labelText: '8桁の確認コード',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.pin_outlined),
            counterText: '',
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _isVerifyingOtp ? null : _verifyEmailOtp,
            child: _isVerifyingOtp
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('確認する'),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: _isSendingEmail ? null : _sendEmailVerification,
            child: const Text('確認メールを再送'),
          ),
        ),
        SizedBox(
          width: double.infinity,
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
        const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'メールアドレスを確認しました',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const Text(
          'パスワードを設定',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          '別の端末からログインするときに使用するパスワードを設定します。',
          style: TextStyle(height: 1.5, color: Colors.grey.shade700),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            labelText: 'パスワード',
            hintText: '8文字以上',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.lock_outline),
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
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _passwordConfirmController,
          obscureText: _obscurePassword,
          decoration: const InputDecoration(
            labelText: 'パスワード確認',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.lock_outline),
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _isSavingPassword ? null : _savePassword,
            icon: _isSavingPassword
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.verified_user_outlined),
            label: Text(_isSavingPassword ? '登録中...' : 'アカウント登録を完了'),
          ),
        ),
      ],
    );
  }

  Widget _buildRegisteredAccount(String? email) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'このアカウントは引き継ぎに対応しています。',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        if (email != null) ...[
          const SizedBox(height: 14),
          Text(email, style: TextStyle(color: Colors.grey.shade700)),
        ],
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              setState(() {
                _emailVerified = true;
                _message = null;
              });
            },
            icon: const Icon(Icons.password_outlined),
            label: const Text('パスワードを設定・変更'),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
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
        const Divider(),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _isSigningOut ? null : _signOutCurrentAccount,
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
        SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            onPressed: _isDeletingAccount || _isSigningOut
                ? null
                : _deleteCurrentAccount,
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            icon: _isDeletingAccount
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete_forever_outlined),
            label: Text(
              _isDeletingAccount
                  ? '削除中...'
                  : 'アカウントを削除',
            ),
          ),
        ),
      ],
    );
  }
}
