# ドメインモデル

## 中核モデル
- Event: クエスト/キャンペーン単位。slug、名称、説明、開催期間、都道府県、画像等。
- Place: 実在する物理地点。緯度経度、半径、住所、カテゴリ等。
- Content: 収集可能な内容。type、content_key、title、description、image、metadata。
- EventContent: Event・Content・Placeを結ぶ。表示順、期間、有効状態、metadataを持つ。
- ContentBlock: Contentの説明・画像等を順序付きブロックとして表現する汎用表示単位。
- PlaceVisit: ユーザーが物理地点を訪れた事実。
- CollectionHistory: 訪問から成立したコンテンツ獲得履歴。
- Profile: 公開表示名・アバター等。
- Achievement / EventAchievement: 実績定義とイベントごとの採用・順序。

## レガシー互換
`seichi` は44札の旧モデルを保持し、event_id / place_id / card_image_urlも持つ。現在は汎用モデルへの移行過程のため、削除せず互換層として扱う。

## 設計意図
EventとContentを直接一体化しない。ContentとPlaceも一体化しない。これにより、同一コンテンツの別イベント利用、同一地点で複数収集、期間限定コンテンツ、店舗・商品・IP等を共通構造で扱える。

## ID
主要エンティティはUUID。Achievementはtext ID。端末からの訪問はclient_visit_idを持ち、再送時の重複制御に利用する。
