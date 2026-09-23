# GPS・獲得判定仕様

## 基本
Geolocatorで高精度位置情報を取得し、物理地点への訪問を判定する。獲得は単なる端末内距離判定だけに依存せず、`record_place_visit_and_collect` 系RPCを通してサーバー側で成立させる設計へ移行している。

## 訪問情報
送信対象は place_id、client_visit_id、visited_at、latitude、longitude、accuracy_meters、source、metadata。

## 誤獲得対策
アプリは直前のスタンプ判定位置を保持し、GPS急跳びを考慮する。StampEligibilityPolicy等へ判定ロジックを分離している。地点半径はDB側Place/Seichiに保持する。

## 低精度警告
非常に低い位置精度は獲得可否とは別状態として扱う。現在は概ねaccuracy > 500mで警告状態となる実装。ユーザーが×で警告を閉じた場合、低精度が継続する間は再表示しない。精度が回復するとdismiss状態をリセットし、その後再び低精度になれば警告を再表示する。

## NEXT
未獲得地点から自動選択でき、ユーザー手動指定も可能。推奨巡回ルート開始時はルート先頭をNEXTとして復元する。

## 要確認
GPS判定値を変更する場合は、端末側PolicyだけでなくサーバーRPC、Place.radius_meters、旧Seichi.stamp_radius_metersとの整合を同時に確認する。
