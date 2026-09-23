class Achievement {
  final String id;
  final String title;
  final String description;
  final String icon;
  final int requiredCount;

  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.requiredCount,
  });
}

/// 聖地クエストの実績一覧。
///
/// 現段階では「獲得した聖地数」による実績だけを定義する。
/// 実績の解除状態そのものは保存せず、現在の獲得数から判定する。
class Achievements {
  Achievements._();

  static const List<Achievement> all = [
    Achievement(
      id: 'first_step',
      title: 'はじめの一歩',
      description: '最初の聖地を獲得する',
      icon: '🌱',
      requiredCount: 1,
    ),
    Achievement(
      id: 'gunma_beginner',
      title: '群馬ビギナー',
      description: '5個の聖地を獲得する',
      icon: '🗺️',
      requiredCount: 5,
    ),
    Achievement(
      id: 'collector',
      title: 'コレクター',
      description: '10個の聖地を獲得する',
      icon: '🎒',
      requiredCount: 10,
    ),
    Achievement(
      id: 'gunma_explorer',
      title: '群馬探訪者',
      description: '20個の聖地を獲得する',
      icon: '🚗',
      requiredCount: 20,
    ),
    Achievement(
      id: 'gunma_master',
      title: '群馬マスター',
      description: '30個の聖地を獲得する',
      icon: '🏔️',
      requiredCount: 30,
    ),
    Achievement(
      id: 'gunma_conqueror',
      title: '群馬制覇',
      description: '44個すべての聖地を獲得する',
      icon: '👑',
      requiredCount: 44,
    ),
  ];
}