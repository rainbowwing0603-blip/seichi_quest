import 'package:flutter/material.dart';

/// AdMobバナーは現在 lib/main.dart のBottomNavigationBar直上で
/// 1つだけ表示しています。
///
/// このウィジェットは旧実装との互換性のため残していますが、
/// ここから広告を生成しないことで二重表示を防ぎます。
class BannerAdWidget extends StatelessWidget {
  const BannerAdWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
