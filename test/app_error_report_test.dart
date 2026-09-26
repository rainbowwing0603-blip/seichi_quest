import 'package:flutter_test/flutter_test.dart';
import 'package:seichi_quest/services/app_error_report.dart';

void main() {
  test('問い合わせ用コードを表示し、例外の詳細は画面文言へ出さない', () {
    final message = AppErrorReport.message(
      AppErrorCodes.spots,
      '聖地データを取得できませんでした。',
      error: StateError('internal diagnostic'),
    );

    expect(message, contains('SQ-MAP-01'));
    expect(message, contains('聖地データを取得できませんでした。'));
    expect(message, isNot(contains('internal diagnostic')));
  });
}
