import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'quest_ui.dart';

class LegalInfoPage extends StatelessWidget {
  const LegalInfoPage({super.key});

  static final Uri _privacyPolicyUri = Uri.parse(
    'https://rainbowwing0603-blip.github.io/seichi_quest/privacy/',
  );
  static final Uri _accountDeletionUri = Uri.parse(
    'https://rainbowwing0603-blip.github.io/seichi_quest/account-deletion/',
  );

  Future<void> _openUrl(BuildContext context, Uri uri) async {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      QuestSnackBar.show(
        context,
        message: 'ページを開けませんでした。通信状態を確認してください。',
        type: QuestNoticeType.error,
      );
    }
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
          'プライバシー・データ管理',
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
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PRIVACY & DATA',
                    style: TextStyle(
                      fontSize: 9,
                      letterSpacing: 1.3,
                      fontWeight: FontWeight.w900,
                      color: QuestUiTokens.mutedInk,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'データの取り扱いと削除',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      color: QuestUiTokens.ink,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '位置情報、アカウント、獲得履歴、広告などのデータの'
                    '取り扱いと、アカウント削除方法を確認できます。',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.55,
                      color: QuestUiTokens.mutedInk,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _LegalLinkTile(
              icon: Icons.privacy_tip_outlined,
              title: 'プライバシーポリシー',
              subtitle: '収集する情報・利用目的・外部サービスを確認',
              onTap: () => _openUrl(context, _privacyPolicyUri),
            ),
            const SizedBox(height: 12),
            _LegalLinkTile(
              icon: Icons.person_remove_alt_1_outlined,
              title: 'アカウント削除について',
              subtitle: 'アプリを利用できない場合のWeb削除手続き',
              onTap: () => _openUrl(context, _accountDeletionUri),
            ),
            const SizedBox(height: 14),
            const QuestGlassCard(
              padding: EdgeInsets.all(16),
              child: Text(
                'アプリ内から削除する場合は「マイページ → 設定・管理 → '
                'アカウント → アカウントを削除」を利用できます。',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.55,
                  color: QuestUiTokens.mutedInk,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegalLinkTile extends StatelessWidget {
  const _LegalLinkTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: QuestGlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: QuestUiTokens.primary.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: QuestUiTokens.primary, size: 22),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: QuestUiTokens.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        height: 1.4,
                        color: QuestUiTokens.mutedInk,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.open_in_new_rounded,
                color: QuestUiTokens.mutedInk,
                size: 19,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
