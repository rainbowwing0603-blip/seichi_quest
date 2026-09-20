/// 上毛かるた固有の札順を一元管理する。
///
/// UIやデータ取得順に依存せず、どの画面・サービスでも同じ順序を使えるようにする。
abstract final class JomoKarutaOrder {
  static const List<String> cards = [
    'あ',
    'い',
    'う',
    'え',
    'お',
    'か',
    'き',
    'く',
    'け',
    'こ',
    'さ',
    'し',
    'す',
    'せ',
    'そ',
    'た',
    'ち',
    'つ',
    'て',
    'と',
    'な',
    'に',
    'ぬ',
    'ね',
    'の',
    'は',
    'ひ',
    'ふ',
    'へ',
    'ほ',
    'ま',
    'み',
    'む',
    'め',
    'も',
    'や',
    'ゆ',
    'よ',
    'ら',
    'り',
    'る',
    'れ',
    'ろ',
    'わ',
    'を',
  ];

  static int indexOf(String card) {
    final index = cards.indexOf(card.trim());
    return index == -1 ? 999 : index;
  }
}
