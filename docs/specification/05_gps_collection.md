# GPS・獲得判定仕様

## 基本
Geolocatorで位置情報を取得し、物理地点への訪問を判定する。現在の汎用獲得経路では、端末側のGPS品質・距離判定に加えて、`CollectionHistoryService.recordPlaceVisitAndCollect` からサーバーRPCへ訪問事実を送信し、成立した獲得履歴を受け取る。

## 端末側StampEligibilityPolicy
2026-09-23基準コードの定数は以下。
- `maxPlausibleSpeedMps = 100.0`
- `minimumAllowedAccuracyMeters = 30.0`
- `radiusAccuracyRatio = 0.5`
- 必要精度 = `max(30m, stampRadiusMeters × 0.5)`
- 距離条件 = `distanceMeters <= stampRadiusMeters`
- 経過時間が正の場合、移動速度が100m/sを超える位置変化をplausibleとは扱わない。

## 訪問情報
サーバー送信対象は place_id、client_visit_id、visited_at、latitude、longitude、accuracy_meters、source、metadata。client_visit_idはUUID v4相当を生成し、オフライン再送でも同一訪問を識別できるよう保持する。

## 低精度警告
スタンプ獲得可否とは別に、地図/NEXT表示にも影響する「非常に低い精度」状態を管理する。基準コードでは500m超を警告対象とする。ユーザーが×で閉じた場合、低精度継続中は再表示せず、精度回復でdismiss状態をリセットする。その後再び低精度になれば再表示する。

## NEXT
未獲得地点から自動選択でき、手動指定も可能。おすすめ巡回ルート開始中はルート先頭をNEXTとして復元する。

## 変更時チェック
閾値変更時は `stamp_eligibility_policy.dart`、呼出し側、Place/Seichi半径、サーバーRPCの判定を同時に確認する。端末だけ緩めてサーバーが拒否する、またはその逆の二重基準を作らない。
