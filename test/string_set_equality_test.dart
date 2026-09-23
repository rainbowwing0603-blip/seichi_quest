import 'package:flutter_test/flutter_test.dart';

import 'package:seichi_quest/services/string_set_equality.dart';

void main() {
  test('順序に関係なく同じ文字列集合を同一と判定する', () {
    expect(
      haveSameStringValues(<String>{'a', 'b'}, <String>['b', 'a']),
      isTrue,
    );
  });

  test('要素数または内容が異なる集合を変更ありと判定する', () {
    expect(
      haveSameStringValues(<String>{'a', 'b'}, <String>['a']),
      isFalse,
    );
    expect(
      haveSameStringValues(<String>{'a', 'b'}, <String>['a', 'c']),
      isFalse,
    );
  });
}
