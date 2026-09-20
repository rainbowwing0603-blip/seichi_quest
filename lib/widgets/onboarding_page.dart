import 'package:flutter/material.dart';

import 'quest_ui.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({
    super.key,
    required this.onComplete,
  });

  final Future<void> Function() onComplete;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();

  late final AnimationController _demoController;

  int _currentPage = 0;
  bool _isCompleting = false;

  static const int _pageCount = 4;

  @override
  void initState() {
    super.initState();

    _demoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();
  }

  @override
  void dispose() {
    _demoController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _skipTutorial() async {
    if (_isCompleting) {
      return;
    }

    setState(() {
      _isCompleting = true;
    });

    try {
      await widget.onComplete();
    } finally {
      if (mounted) {
        setState(() {
          _isCompleting = false;
        });
      }
    }
  }
  Future<void> _goNext() async {
    if (_currentPage < _pageCount - 1) {
      await _pageController.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
      return;
    }

    if (_isCompleting) {
      return;
    }

    setState(() {
      _isCompleting = true;
    });

    try {
      await widget.onComplete();
    } finally {
      if (mounted) {
        setState(() {
          _isCompleting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });

                  _demoController
                    ..reset()
                    ..repeat();
                },
                children: [
                  _buildExplorePage(),
                  _buildTravelPage(),
                  _buildCollectPage(),
                  _buildChallengePage(),
                ],
              ),
            ),
            _buildBottomControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  QuestUiTokens.primary,
                  QuestUiTokens.primaryDeep,
                ],
              ),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.explore_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 11),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '聖地クエスト',
                  style: TextStyle(
                    color: QuestUiTokens.ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  'GUNMA ADVENTURE',
                  style: TextStyle(
                    color: QuestUiTokens.mutedInk,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${_currentPage + 1} / $_pageCount',
            style: const TextStyle(
              color: QuestUiTokens.mutedInk,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),          const SizedBox(width: 6),
          TextButton(
            onPressed: _isCompleting ? null : _skipTutorial,
            style: TextButton.styleFrom(
              foregroundColor: QuestUiTokens.primary,
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'スキップ',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExplorePage() {
    return _buildTutorialPage(
      eyebrow: 'EXPLORE',
      title: '次の聖地を見つけよう',
      description: 'MAPには次に向かう聖地と距離が表示されます。',
      demo: _buildMapDemo(
        animateTravel: false,
      ),
      hintIcon: Icons.touch_app_rounded,
      hint: 'NEXT QUESTを目印に目的地を確認',
    );
  }

  Widget _buildTravelPage() {
    return _buildTutorialPage(
      eyebrow: 'GO',
      title: '現地へ向かおう',
      description: '現在地を使って聖地までの距離をリアルタイムに確認します。',
      demo: _buildMapDemo(
        animateTravel: true,
      ),
      hintIcon: Icons.radar_rounded,
      hint: '近づくほどソナーが反応',
    );
  }

  Widget _buildCollectPage() {
    return _buildTutorialPage(
      eyebrow: 'COLLECT',
      title: '着いたら自動でSTAMP GET',
      description: '獲得範囲に入るとスタンプを自動獲得。スタンプ帳に記録されます。',
      demo: _buildCollectionDemo(),
      hintIcon: Icons.auto_awesome_rounded,
      hint: 'アプリを操作しなくても自動判定',
    );
  }

  Widget _buildChallengePage() {
    return _buildTutorialPage(
      eyebrow: 'CHALLENGE',
      title: '集めるほど冒険が広がる',
      description: 'スタンプ数に応じて実績が解除されます。群馬44札の制覇を目指そう。',
      demo: _buildAchievementDemo(),
      hintIcon: Icons.my_location_rounded,
      hint: '正確な位置情報をONにしよう',
      footer:
          '次の画面で位置情報の利用を確認します。聖地への到着判定には位置情報を使用します。',
    );
  }

  Widget _buildTutorialPage({
    required String eyebrow,
    required String title,
    required String description,
    required Widget demo,
    required IconData hintIcon,
    required String hint,
    String? footer,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight - 20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eyebrow,
                  style: const TextStyle(
                    color: QuestUiTokens.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.8,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  title,
                  style: const TextStyle(
                    color: QuestUiTokens.ink,
                    fontSize: 25,
                    height: 1.15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: const TextStyle(
                    color: QuestUiTokens.mutedInk,
                    fontSize: 13,
                    height: 1.55,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 300,
                  width: double.infinity,
                  child: demo,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Icon(
                      hintIcon,
                      color: QuestUiTokens.primary,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        hint,
                        style: const TextStyle(
                          color: QuestUiTokens.ink,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                if (footer != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color:
                          QuestUiTokens.primary.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color:
                            QuestUiTokens.primary.withValues(alpha: 0.10),
                      ),
                    ),
                    child: Text(
                      footer,
                      style: const TextStyle(
                        color: QuestUiTokens.mutedInk,
                        fontSize: 11,
                        height: 1.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMapDemo({
    required bool animateTravel,
  }) {
    return QuestGlassCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(
          QuestUiTokens.cardRadius,
        ),
        child: Stack(
          children: [
            const Positioned.fill(
              child: _DemoMapBackground(),
            ),
            Positioned(
              top: 13,
              left: 13,
              right: 13,
              child: _buildMapHud(),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 118,
              bottom: 54,
              child: AnimatedBuilder(
                animation: _demoController,
                builder: (context, child) {
                  final rawProgress = animateTravel
                      ? Curves.easeInOut.transform(
                          (_demoController.value * 1.25)
                              .clamp(0.0, 1.0),
                        )
                      : 0.12;

                  final distance =
                      (850 - (rawProgress * 720))
                          .round()
                          .clamp(130, 850);

                  return Stack(
                    children: [
                      const Positioned(
                        right: 58,
                        top: 5,
                        child: _DestinationMarker(),
                      ),
                      Positioned(
                        left: 40 + (rawProgress * 125),
                        top: 76 - (rawProgress * 47),
                        child: const _CurrentLocationMarker(),
                      ),
                      if (animateTravel)
                        Positioned(
                          left: 16,
                          bottom: 2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  Colors.white.withValues(alpha: 0.90),
                              borderRadius:
                                  BorderRadius.circular(12),
                            ),
                            child: Text(
                              '目的地まで ${distance}m',
                              style: const TextStyle(
                                color: QuestUiTokens.primaryDeep,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 10,
              child: _buildNextQuestCard(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapHud() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 9,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.91),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.94),
        ),
        boxShadow: [
          BoxShadow(
            color:
                QuestUiTokens.primary.withValues(alpha: 0.10),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: const Row(
        children: [
          Icon(
            Icons.explore_rounded,
            color: QuestUiTokens.primary,
            size: 19,
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'GUNMA QUEST',
              style: TextStyle(
                color: QuestUiTokens.ink,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
          ),
          Icon(
            Icons.workspace_premium_rounded,
            color: QuestUiTokens.primaryDeep,
            size: 17,
          ),
          SizedBox(width: 4),
          Text(
            '7 / 44',
            style: TextStyle(
              color: QuestUiTokens.primaryDeep,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextQuestCard() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 9,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white,
        ),
        boxShadow: [
          BoxShadow(
            color:
                QuestUiTokens.primary.withValues(alpha: 0.14),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 35,
            height: 35,
            child: Stack(
              alignment: Alignment.center,
              children: [
                _DemoSonar(),
                Icon(
                  Icons.place_rounded,
                  color: QuestUiTokens.primary,
                  size: 22,
                ),
              ],
            ),
          ),
          SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NEXT QUEST',
                  style: TextStyle(
                    color: QuestUiTokens.primary,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  '群馬県庁',
                  style: TextStyle(
                    color: QuestUiTokens.ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.navigation_rounded,
            color: QuestUiTokens.primaryDeep,
            size: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildCollectionDemo() {
    return QuestGlassCard(
      padding: const EdgeInsets.all(13),
      child: AnimatedBuilder(
        animation: _demoController,
        builder: (context, child) {
          final acquired = _demoController.value > 0.48;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.collections_bookmark_rounded,
                    color: QuestUiTokens.primary,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '上毛かるた スタンプ帳',
                      style: TextStyle(
                        color: QuestUiTokens.ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Text(
                    '7 / 44',
                    style: TextStyle(
                      color: QuestUiTokens.primaryDeep,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Row(
                children: [
                  _DemoFilterChip(
                    label: 'すべて',
                    selected: true,
                  ),
                  SizedBox(width: 5),
                  _DemoFilterChip(
                    label: '獲得済み',
                  ),
                  SizedBox(width: 5),
                  _DemoFilterChip(
                    label: '未獲得',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: GridView.count(
                  physics:
                      const NeverScrollableScrollPhysics(),
                  crossAxisCount: 3,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 0.84,
                  children: [
                    const _DemoStampCard(
                      label: '高崎駅',
                      card: 'た',
                      collected: true,
                    ),
                    _DemoStampCard(
                      label: acquired ? '群馬県庁' : '未獲得',
                      card: 'け',
                      collected: acquired,
                      highlight: true,
                    ),
                    const _DemoStampCard(
                      label: '未獲得',
                      card: 'い',
                      collected: false,
                    ),
                  ],
                ),
              ),
              AnimatedSwitcher(
                duration:
                    const Duration(milliseconds: 260),
                child: acquired
                    ? const _DemoGetBanner(
                        key: ValueKey('get'),
                      )
                    : const _DemoApproachBanner(
                        key: ValueKey('approach'),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAchievementDemo() {
    return QuestGlassCard(
      padding: const EdgeInsets.all(14),
      child: AnimatedBuilder(
        animation: _demoController,
        builder: (context, child) {
          final progress =
              Curves.easeInOut.transform(
            _demoController.value,
          );

          final collected =
              7 + (progress * 3).floor();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.emoji_events_rounded,
                    color: QuestUiTokens.primary,
                    size: 21,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'CHALLENGES',
                    style: TextStyle(
                      color: QuestUiTokens.ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 13),
              const _DemoAchievementTile(
                icon: Icons.flag_rounded,
                title: '群馬ビギナー',
                detail: '5か所の聖地を巡る',
                value: 1,
                unlocked: true,
              ),
              const SizedBox(height: 9),
              _DemoAchievementTile(
                icon: Icons.auto_awesome_rounded,
                title: 'コレクター',
                detail: '10か所の聖地を巡る',
                value:
                    (collected / 10).clamp(0.0, 1.0),
                unlocked: collected >= 10,
              ),
              const Spacer(),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      QuestUiTokens.primary
                          .withValues(alpha: 0.09),
                      QuestUiTokens.cyan
                          .withValues(alpha: 0.08),
                    ],
                  ),
                  borderRadius:
                      BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.route_rounded,
                      color: QuestUiTokens.primary,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'JOURNEY PROGRESS',
                            style: TextStyle(
                              color:
                                  QuestUiTokens.mutedInk,
                              fontSize: 8,
                              fontWeight:
                                  FontWeight.w900,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius:
                                BorderRadius.circular(10),
                            child:
                                LinearProgressIndicator(
                              value: collected / 44,
                              minHeight: 6,
                              backgroundColor:
                                  Colors.white.withValues(
                                alpha: 0.8,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '$collected / 44',
                      style: const TextStyle(
                        color:
                            QuestUiTokens.primaryDeep,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBottomControls() {
    final lastPage =
        _currentPage == _pageCount - 1;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        20,
        8,
        20,
        18,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: List.generate(
              _pageCount,
              (index) {
                final selected =
                    index == _currentPage;

                return AnimatedContainer(
                  duration:
                      const Duration(milliseconds: 220),
                  width: selected ? 24 : 7,
                  height: 7,
                  margin:
                      const EdgeInsets.symmetric(
                    horizontal: 3,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? QuestUiTokens.primary
                        : QuestUiTokens.primary
                            .withValues(alpha: 0.18),
                    borderRadius:
                        BorderRadius.circular(10),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 13),
          QuestPrimaryButton(
            label:
                lastPage ? '冒険をはじめる' : '次へ',
            icon: lastPage
                ? Icons.explore_rounded
                : Icons.arrow_forward_rounded,
            onPressed:
                _isCompleting ? null : _goNext,
          ),
        ],
      ),
    );
  }
}

class _DemoMapBackground extends StatelessWidget {
  const _DemoMapBackground();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DemoMapPainter(),
    );
  }
}

class _DemoMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()
      ..color = const Color(0xFFEAF0ED);

    canvas.drawRect(
      Offset.zero & size,
      background,
    );

    final blockPaint = Paint()
      ..color =
          Colors.white.withValues(alpha: 0.74);

    final parkPaint = Paint()
      ..color = const Color(0xFFD7E8D8);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.05,
          size.height * 0.20,
          size.width * 0.28,
          size.height * 0.24,
        ),
        const Radius.circular(10),
      ),
      blockPaint,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.65,
          size.height * 0.30,
          size.width * 0.28,
          size.height * 0.22,
        ),
        const Radius.circular(10),
      ),
      parkPaint,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.20,
          size.height * 0.64,
          size.width * 0.30,
          size.height * 0.22,
        ),
        const Radius.circular(10),
      ),
      blockPaint,
    );

    final roadPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final road = Path()
      ..moveTo(
        -20,
        size.height * 0.74,
      )
      ..cubicTo(
        size.width * 0.25,
        size.height * 0.55,
        size.width * 0.55,
        size.height * 0.75,
        size.width + 20,
        size.height * 0.37,
      );

    canvas.drawPath(
      road,
      roadPaint,
    );

    final minorRoadPaint = Paint()
      ..color =
          Colors.white.withValues(alpha: 0.78)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(
        size.width * 0.10,
        -10,
      ),
      Offset(
        size.width * 0.56,
        size.height + 10,
      ),
      minorRoadPaint,
    );

    canvas.drawLine(
      Offset(
        size.width * 0.73,
        -10,
      ),
      Offset(
        size.width * 0.54,
        size.height + 10,
      ),
      minorRoadPaint,
    );
  }

  @override
  bool shouldRepaint(
    covariant _DemoMapPainter oldDelegate,
  ) =>
      false;
}

class _DestinationMarker extends StatelessWidget {
  const _DestinationMarker();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 74,
          height: 74,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: QuestUiTokens.primary
                .withValues(alpha: 0.10),
            border: Border.all(
              color: QuestUiTokens.primary
                  .withValues(alpha: 0.28),
              width: 2,
            ),
          ),
        ),
        Container(
          width: 42,
          height: 42,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                QuestUiTokens.primary,
                QuestUiTokens.primaryDeep,
              ],
            ),
          ),
          child: const Icon(
            Icons.place_rounded,
            color: Colors.white,
            size: 25,
          ),
        ),
      ],
    );
  }
}

class _CurrentLocationMarker
    extends StatelessWidget {
  const _CurrentLocationMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: QuestUiTokens.primary
                .withValues(alpha: 0.28),
            blurRadius: 9,
          ),
        ],
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: QuestUiTokens.cyan,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _DemoSonar extends StatelessWidget {
  const _DemoSonar();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: QuestUiTokens.primary
              .withValues(alpha: 0.22),
          width: 2,
        ),
      ),
    );
  }
}

class _DemoFilterChip extends StatelessWidget {
  const _DemoFilterChip({
    required this.label,
    this.selected = false,
  });

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 5,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: selected
              ? QuestUiTokens.primary
                  .withValues(alpha: 0.10)
              : Colors.white
                  .withValues(alpha: 0.56),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? QuestUiTokens.primary
                    .withValues(alpha: 0.18)
                : QuestUiTokens.mutedInk
                    .withValues(alpha: 0.08),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected
                ? QuestUiTokens.primaryDeep
                : QuestUiTokens.mutedInk,
            fontSize: 8,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _DemoStampCard extends StatelessWidget {
  const _DemoStampCard({
    required this.label,
    required this.card,
    required this.collected,
    this.highlight = false,
  });

  final String label;
  final String card;
  final bool collected;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: collected
            ? Colors.white.withValues(alpha: 0.90)
            : Colors.white.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: highlight && collected
              ? QuestUiTokens.primary
                  .withValues(alpha: 0.42)
              : Colors.white.withValues(alpha: 0.92),
          width: highlight && collected ? 2 : 1,
        ),
        boxShadow: highlight && collected
            ? [
                BoxShadow(
                  color: QuestUiTokens.primary
                      .withValues(alpha: 0.18),
                  blurRadius: 12,
                ),
              ]
            : null,
      ),
      child: Column(
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: collected
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFFF1EEFF),
                          Color(0xFFE8F8FB),
                        ],
                      )
                    : LinearGradient(
                        colors: [
                          Colors.white
                              .withValues(alpha: 0.42),
                          const Color(0xFFE8EEF5),
                        ],
                      ),
                borderRadius:
                    BorderRadius.circular(10),
              ),
              child: Center(
                child: collected
                    ? Text(
                        card,
                        style: const TextStyle(
                          color:
                              QuestUiTokens.primaryDeep,
                          fontSize: 27,
                          fontWeight:
                              FontWeight.w900,
                        ),
                      )
                    : Icon(
                        Icons.lock_outline_rounded,
                        color: QuestUiTokens.mutedInk
                            .withValues(alpha: 0.48),
                        size: 24,
                      ),
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: collected
                  ? QuestUiTokens.ink
                  : QuestUiTokens.mutedInk,
              fontSize: 8,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            collected ? 'STAMP GET' : 'LOCKED',
            style: TextStyle(
              color: collected
                  ? QuestUiTokens.primary
                  : QuestUiTokens.mutedInk
                      .withValues(alpha: 0.64),
              fontSize: 6.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.7,
            ),
          ),
        ],
      ),
    );
  }
}

class _DemoGetBanner extends StatelessWidget {
  const _DemoGetBanner({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(vertical: 7),
      decoration: BoxDecoration(
        color: QuestUiTokens.primary
            .withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_rounded,
            color: QuestUiTokens.primary,
            size: 16,
          ),
          SizedBox(width: 6),
          Text(
            'STAMP GET!',
            style: TextStyle(
              color: QuestUiTokens.primaryDeep,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _DemoApproachBanner
    extends StatelessWidget {
  const _DemoApproachBanner({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(vertical: 7),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.directions_walk_rounded,
            color: QuestUiTokens.mutedInk,
            size: 16,
          ),
          SizedBox(width: 6),
          Text(
            '聖地へ接近中…',
            style: TextStyle(
              color: QuestUiTokens.mutedInk,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _DemoAchievementTile
    extends StatelessWidget {
  const _DemoAchievementTile({
    required this.icon,
    required this.title,
    required this.detail,
    required this.value,
    required this.unlocked,
  });

  final IconData icon;
  final String title;
  final String detail;
  final double value;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: unlocked
            ? QuestUiTokens.primary
                .withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: unlocked
              ? QuestUiTokens.primary
                  .withValues(alpha: 0.18)
              : QuestUiTokens.mutedInk
                  .withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: unlocked
                  ? QuestUiTokens.primary
                      .withValues(alpha: 0.13)
                  : QuestUiTokens.mutedInk
                      .withValues(alpha: 0.08),
              borderRadius:
                  BorderRadius.circular(12),
            ),
            child: Icon(
              unlocked
                  ? Icons.check_rounded
                  : icon,
              color: unlocked
                  ? QuestUiTokens.primary
                  : QuestUiTokens.mutedInk,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: QuestUiTokens.ink,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  unlocked ? 'ACHIEVED' : detail,
                  style: TextStyle(
                    color: unlocked
                        ? QuestUiTokens.primary
                        : QuestUiTokens.mutedInk,
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (!unlocked) ...[
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius:
                        BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: value,
                      minHeight: 5,
                      backgroundColor:
                          QuestUiTokens.primary
                              .withValues(alpha: 0.08),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (unlocked)
            const Icon(
              Icons.workspace_premium_rounded,
              color: QuestUiTokens.primaryDeep,
              size: 20,
            ),
        ],
      ),
    );
  }
}