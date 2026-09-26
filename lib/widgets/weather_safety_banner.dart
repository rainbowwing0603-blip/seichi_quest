import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'quest_ui.dart';

class WeatherSafetyBanner extends StatelessWidget {
  const WeatherSafetyBanner({super.key, required this.message, this.onOpenDetails});

  final String message;
  final VoidCallback? onOpenDetails;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xF9FFF8E9),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onOpenDetails ??
            () {
              launchUrl(
                Uri.parse('https://www.jma.go.jp/bosai/'),
                mode: LaunchMode.externalApplication,
              );
            },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              const Icon(
                Icons.health_and_safety_outlined,
                color: QuestUiTokens.primaryDeep,
                size: 22,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message,
                      style: const TextStyle(
                        color: QuestUiTokens.ink,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      '気象庁の防災情報を確認する',
                      style: TextStyle(
                        color: QuestUiTokens.primaryDeep,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.open_in_new_rounded,
                color: QuestUiTokens.primaryDeep,
                size: 17,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
