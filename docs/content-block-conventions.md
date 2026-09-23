# Content Block conventions

聖地クエストのイベント本文は、コンテンツ種別ごとの専用画面を増やさず、共通の Content Block と共通レンダラーで構成する。

## 原則

- block type はデータの形を表す。現在は `text` / `image` / `link`。
- role は意味を表す。閉じた enum にせず、既知 role は表示を少し最適化し、未知 role も安全に扱う。
- `metadata.visibility` はブロック単位の公開タイミングを表す。role から公開タイミングを決め打ちしない。
- `is_active=false` は配信対象外の下書き・停止、`visibility=hidden` は有効データをアプリ上で意図的に隠す用途。
- 画像は任意。画像が無いイベントでも余白や空カードを残さず成立させる。
- 複数画像は複数の `image` block として並べる。専用 gallery 型や専用画面は必須にしない。
- 既存の上毛かるた互換フィールドは移行期間だけ残し、新規機能の保存先にはしない。

## 推奨 semantic roles

| role | 主用途 |
| --- | --- |
| `default` | 汎用 |
| `hero` | 代表画像 |
| `picture_card` | 絵札などの表面画像 |
| `reading_card` | 読み札などの補助画像 |
| `reading` | 読み札本文・キャッチコピー |
| `description` / `about` | 概要・由来 |
| `history` | 歴史・背景 |
| `field_guide` | 現地で見るポイント・体験ガイド |
| `gallery` | 関連画像 |
| `product` | 商品画像 |
| `official` | 公式リンク |

この一覧は推奨語彙であり制約ではない。アニメの `character`、店舗の `menu` など将来の role を追加できる。

## visibility

- `always`: 常に表示。
- `after_collection`: スタンプ獲得後に表示。
- `hidden`: 有効なままアプリでは表示しない。
- 未設定または未知値は後方互換のため `always`。

ナビゲーションに必要な名称・場所・基本情報を獲得後限定にしない。由来、歴史、現地ガイド、追加画像などはイベントごとに `after_collection` を選べる。

## 構成例

### かるた
`picture_card`、`reading_card`、`reading`、`description`、`history`、`field_guide`、`official` を必要な分だけ使う。札画像が未許諾・未登録でも text block だけで成立させる。

### アニメ・作品コラボ
`hero`、`description`、複数 `gallery`、`history`、`official`。作品固有の情報が必要なら custom role を追加する。

### 店舗
`hero`、`description`、複数 `gallery`、`official`。画像なしでも店舗名・場所・説明だけで成立する。

### 商品
`hero` または `product`、`description`、`official`。商品固有画面を作らず同じ詳細導線を使う。

## UI契約

- 一覧カードから詳細が開けることを視覚的に示す。
- 獲得時には追加コンテンツが解放されたことを通知する。
- 詳細では獲得前後の違いを説明し、解放済み block は共通レンダラーで表示する。
- 空・不正・未対応 block は他の block の表示を壊さない。
- role ごとの装飾は共通レンダラー内の presentation として扱い、role ごとの画面クラスを作らない。

## 上毛かるた移行時の注意

現在の legacy `reading` は全文の読み札を保証しないため、公式・権利確認済みの本文を取得するまでは完全な読み札として扱わない。札画像も利用許諾が確定するまでは新規追加・差し替えを行わない。
