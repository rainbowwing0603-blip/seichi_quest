import 'package:flutter/material.dart';

/// 聖地クエスト共通のビジュアルトークン。
///
/// MAP UI 2.0を基準に、各画面で色・角丸・影の表現が
/// バラバラにならないための共通値を定義する。
abstract final class QuestUiTokens {
  static const Color primary = Color(0xFF5968E8);
  static const Color primaryDeep = Color(0xFF403A9F);
  static const Color cyan = Color(0xFF25A9C7);
  static const Color ink = Color(0xFF102A43);
  static const Color mutedInk = Color(0xFF60758A);

  static const double cardRadius = 26;
  static const double controlRadius = 17;
  static const double chipRadius = 15;

  static const LinearGradient glassGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xDDFBFDFF), Color(0xD8F4F8FF), Color(0xD8EEECFF)],
  );

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF7C89FA), Color(0xFF5968E8), Color(0xFF403A9F)],
  );

  static const LinearGradient cyanGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF42C8DC), Color(0xFF167B9B)],
  );
}

/// MAP UI 2.0と同じ軽量ガラス表現を使う共通カード。
///
/// BackdropFilterは使用せず、半透明グラデーションと影だけで
/// ガラス感を出すため、通常画面でも扱いやすい。
class QuestGlassCard extends StatelessWidget {
  const QuestGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.margin,
    this.borderRadius = QuestUiTokens.cardRadius,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: QuestUiTokens.glassGradient,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.72),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: QuestUiTokens.ink.withValues(alpha: 0.12),
            blurRadius: 22,
            offset: const Offset(0, 9),
          ),
          BoxShadow(
            color: QuestUiTokens.primary.withValues(alpha: 0.10),
            blurRadius: 23,
            spreadRadius: 1,
          ),
        ],
      ),
      child: child,
    );
  }
}

/// 天気・獲得数・状態など、小さな情報を表示する共通チップ。
class QuestStatusChip extends StatelessWidget {
  const QuestStatusChip({
    super.key,
    required this.label,
    this.icon,
    this.accentColor = QuestUiTokens.primary,
  });

  final String label;
  final IconData? icon;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(QuestUiTokens.chipRadius),
        color: Colors.white.withValues(alpha: 0.68),
        border: Border.all(color: accentColor.withValues(alpha: 0.20)),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.10),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 17, color: accentColor),
            const SizedBox(width: 7),
          ],
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: QuestUiTokens.ink,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 聖地クエスト共通の主操作ボタン。
class QuestPrimaryButton extends StatelessWidget {
  const QuestPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final button = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(QuestUiTokens.controlRadius),
        gradient: onPressed == null
            ? LinearGradient(
                colors: [
                  QuestUiTokens.mutedInk.withValues(alpha: 0.35),
                  QuestUiTokens.mutedInk.withValues(alpha: 0.22),
                ],
              )
            : QuestUiTokens.primaryGradient,
        boxShadow: onPressed == null
            ? null
            : [
                BoxShadow(
                  color: QuestUiTokens.primary.withValues(alpha: 0.28),
                  blurRadius: 16,
                  offset: const Offset(0, 7),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(QuestUiTokens.controlRadius),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20, color: Colors.white),
                  const SizedBox(width: 9),
                ],
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (!expand) {
      return button;
    }

    return SizedBox(width: double.infinity, child: button);
  }
}

/// UI 2.0共通のモーダルダイアログ。
///
/// レベルアップ・実績解除・クエスト完了などの演出を、
/// MAP UI 2.0と同じビジュアル言語で統一する。
class QuestDialog extends StatelessWidget {
  const QuestDialog({
    super.key,
    required this.title,
    required this.actionLabel,
    required this.onAction,
    this.icon,
    this.iconText,
    this.subtitle,
    this.content,
    this.actionIcon,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.isDestructive = false,
    this.accentColor = QuestUiTokens.primary,
  }) : assert(icon == null || iconText == null),
       assert((secondaryActionLabel == null) == (onSecondaryAction == null));

  final String title;
  final String actionLabel;
  final VoidCallback onAction;
  final IconData? icon;
  final String? iconText;
  final String? subtitle;
  final Widget? content;
  final IconData? actionIcon;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;
  final bool isDestructive;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final effectiveAccentColor = isDestructive
        ? const Color(0xFFD94B5B)
        : accentColor;

    return Dialog(
      elevation: 0,
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: QuestGlassCard(
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
          borderRadius: 28,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 82,
                  height: 82,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        effectiveAccentColor.withValues(alpha: 0.22),
                        Colors.white.withValues(alpha: 0.78),
                      ],
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.85),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: effectiveAccentColor.withValues(alpha: 0.20),
                        blurRadius: 22,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: iconText != null
                      ? Text(
                          iconText!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 46),
                        )
                      : Icon(
                          icon ?? Icons.auto_awesome_rounded,
                          size: 44,
                          color: effectiveAccentColor,
                        ),
                ),
                const SizedBox(height: 18),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: QuestUiTokens.ink,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                  ),
                ),
                if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    subtitle!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: QuestUiTokens.mutedInk,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.45,
                    ),
                  ),
                ],
                if (content != null) ...[const SizedBox(height: 20), content!],
                const SizedBox(height: 22),
                if (isDestructive)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: onAction,
                      icon: Icon(actionIcon ?? Icons.warning_amber_rounded),
                      label: Text(actionLabel),
                      style: FilledButton.styleFrom(
                        backgroundColor: effectiveAccentColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            QuestUiTokens.controlRadius,
                          ),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  )
                else
                  QuestPrimaryButton(
                    label: actionLabel,
                    icon: actionIcon,
                    onPressed: onAction,
                  ),
                if (secondaryActionLabel != null) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: onSecondaryAction,
                      style: TextButton.styleFrom(
                        foregroundColor: QuestUiTokens.mutedInk,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      child: Text(secondaryActionLabel!),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum QuestNoticeType { info, success, warning, error }

class QuestSnackBar {
  const QuestSnackBar._();

  static void show(
    BuildContext context, {
    required String message,
    QuestNoticeType type = QuestNoticeType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    final messenger = ScaffoldMessenger.of(context);
    final visual = _visualFor(type);

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.transparent,
          elevation: 0,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          padding: EdgeInsets.zero,
          duration: duration,
          content: Container(
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: visual.color.withValues(alpha: 0.24),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: visual.color.withValues(alpha: 0.16),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: visual.color.withValues(alpha: 0.12),
                  ),
                  child: Icon(visual.icon, color: visual.color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: QuestUiTokens.ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
  }

  static _QuestNoticeVisual _visualFor(QuestNoticeType type) {
    return switch (type) {
      QuestNoticeType.info => const _QuestNoticeVisual(
        icon: Icons.info_outline_rounded,
        color: QuestUiTokens.primary,
      ),
      QuestNoticeType.success => const _QuestNoticeVisual(
        icon: Icons.check_circle_outline_rounded,
        color: Color(0xFF2BAA76),
      ),
      QuestNoticeType.warning => const _QuestNoticeVisual(
        icon: Icons.warning_amber_rounded,
        color: Color(0xFFE49B35),
      ),
      QuestNoticeType.error => const _QuestNoticeVisual(
        icon: Icons.error_outline_rounded,
        color: Color(0xFFD94B5B),
      ),
    };
  }
}

class _QuestNoticeVisual {
  const _QuestNoticeVisual({required this.icon, required this.color});

  final IconData icon;
  final Color color;
}
