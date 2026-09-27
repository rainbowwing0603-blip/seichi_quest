# ドメインモデル

## 中核モデル
- Event: クエスト/キャンペーン単位。slug、名称、説明、開催期間、地域、画像、表示テーマ等。
- Place: 実在する物理地点。緯度経度、半径、住所、カテゴリ、位置情報の内部検証情報等。
- Content: 収集可能な内容。type、content_key、title、description、image、metadata。
- EventContent: Event・Content・Placeを結ぶ。表示順、期間、有効状態、イベント内呼称、metadataを持つ。
- ContentBlock: Contentの説明・画像等を順序付きブロックとして表現する汎用表示単位。
- PlaceVisit: ユーザーが物理地点を訪れた事実。
- CollectionHistory: 訪問から成立したコンテンツ獲得履歴。event_content_idを収集単位の正規IDとする。
- Profile: 公開表示名・アバター等。
- Achievement / EventAchievement: 実績定義とイベントごとの採用・順序。
- Announcement / AnnouncementRead: アプリ内お知らせと既読状態。
- CollectionSeries / Region: 全国規模の収集シリーズと地域集約。
- LocationSecurityState / Event: 位置不正検知のサーバー状態・監査イベント。
- AppReleasePolicy: platform別のlatest/minimum build、store URL、更新メッセージ。

## レガシー
旧 `seichi` テーブルは移行互換を経て2026-09-25に廃止済み。新規コード・DB仕様では復活させず、Event / Content / Place / EventContentを正本とする。

## 設計意図
EventとContentを直接一体化しない。ContentとPlaceも一体化しない。これにより、同一地点で複数収集、期間限定コンテンツ、店舗・商品・IP等を共通構造で扱える。

## ID
主要エンティティはUUID。Achievementはtext ID。端末からの訪問はclient_visit_idを持ち、再送時の重複制御に利用する。
