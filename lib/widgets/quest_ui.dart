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
