import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'quest_ui.dart';

class QuestLicensePage extends StatefulWidget {
  const QuestLicensePage({super.key});

  @override
  State<QuestLicensePage> createState() => _QuestLicensePageState();
}

class _QuestLicensePageState extends State<QuestLicensePage> {
  late final Future<List<_QuestLicenseEntry>> _licensesFuture;

  @override
  void initState() {
    super.initState();
    _licensesFuture = _loadLicenses();
  }

  Future<List<_QuestLicenseEntry>> _loadLicenses() async {
    final entries = <String, List<LicenseParagraph>>{};

    await for (final entry in LicenseRegistry.licenses) {
      final packages = entry.packages.isEmpty
          ? const <String>['その他']
          : entry.packages;

      for (final package in packages) {
        entries
            .putIfAbsent(package, () => <LicenseParagraph>[])
            .addAll(entry.paragraphs);
      }
    }

    final result =
        entries.entries
            .map(
              (entry) => _QuestLicenseEntry(
                packageName: entry.key,
                paragraphs: List<LicenseParagraph>.unmodifiable(entry.value),
              ),
            )
            .toList()
          ..sort(
            (a, b) => a.packageName.toLowerCase().compareTo(
              b.packageName.toLowerCase(),
            ),
          );

    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: QuestUiTokens.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'ライセンス',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: QuestUiTokens.ink,
          ),
        ),
      ),
      body: FutureBuilder<List<_QuestLicenseEntry>>(
        future: _licensesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(
                color: QuestUiTokens.primary,
                strokeWidth: 2.5,
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: QuestGlassCard(
                  padding: const EdgeInsets.all(22),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        color: QuestUiTokens.primary,
                        size: 36,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'ライセンス情報を読み込めませんでした。',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: QuestUiTokens.ink,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          final licenses = snapshot.data ?? const <_QuestLicenseEntry>[];

          if (licenses.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: QuestGlassCard(
                  padding: const EdgeInsets.all(22),
                  child: const Text(
                    '表示できるライセンス情報がありません。',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: QuestUiTokens.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            );
          }

          return SafeArea(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
              itemCount: licenses.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return QuestGlassCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'OPEN SOURCE LICENSES',
                          style: TextStyle(
                            fontSize: 9,
                            letterSpacing: 1.4,
                            fontWeight: FontWeight.w900,
                            color: QuestUiTokens.mutedInk,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${licenses.length}件のパッケージで使用している'
                          'オープンソースライセンス情報です。',
                          style: const TextStyle(
                            color: QuestUiTokens.ink,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            height: 1.55,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final license = licenses[index - 1];

                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => _QuestLicenseDetailPage(entry: license),
                      ),
                    );
                  },
                  child: QuestGlassCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 16,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: QuestUiTokens.primary.withValues(
                              alpha: 0.10,
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.description_outlined,
                            color: QuestUiTokens.primary,
                            size: 21,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                license.packageName,
                                style: const TextStyle(
                                  color: QuestUiTokens.ink,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${license.paragraphs.length} '
                                'ライセンス項目',
                                style: const TextStyle(
                                  color: QuestUiTokens.mutedInk,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: QuestUiTokens.mutedInk,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _QuestLicenseDetailPage extends StatelessWidget {
  const _QuestLicenseDetailPage({required this.entry});

  final _QuestLicenseEntry entry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: QuestUiTokens.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          entry.packageName,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            color: QuestUiTokens.ink,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
          child: QuestGlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'LICENSE',
                  style: TextStyle(
                    fontSize: 9,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w900,
                    color: QuestUiTokens.mutedInk,
                  ),
                ),
                const SizedBox(height: 14),
                for (var i = 0; i < entry.paragraphs.length; i++) ...[
                  SelectableText(
                    entry.paragraphs[i].text,
                    style: TextStyle(
                      color: QuestUiTokens.ink,
                      fontSize: 13,
                      height: 1.55,
                      fontWeight: entry.paragraphs[i].indent == 0
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                  if (i != entry.paragraphs.length - 1)
                    const SizedBox(height: 14),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuestLicenseEntry {
  const _QuestLicenseEntry({
    required this.packageName,
    required this.paragraphs,
  });

  final String packageName;
  final List<LicenseParagraph> paragraphs;
}
