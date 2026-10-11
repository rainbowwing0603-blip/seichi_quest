# 汎用コンテンツ基盤

## 目的
上毛かるた専用構造から、観光・店舗・商品・企業・作品/IP等を同一基盤で扱える構造へ拡張する。

## 実装済み
`contents`、`event_contents`、`places`、`content_blocks` と、Flutter側 `ContentBlock` / `ContentBlockService` / `ContentBlockPresentationPolicy` / `ContentBlockRenderer`。

ContentBlockTypeは `text / image / link / unsupported`。未知typeはunsupportedとして扱い、描画対象から除外するため後方互換性を確保する。

## Roleと表示優先度
role未指定はdefault。現行PresentationPolicyでは picture_card → reading_card → reading → その他 の優先順位で、同順位はdisplay_order、さらにidで安定ソートする。

render可能条件は、textはbody有り、imageはmedia_path有り、linkはhttp/httpsかつhost有り。無効・空ブロックは描画しない。

## Story preview
`story`、`history`、`field_guide`、`description` 等の対象blockは、未獲得状態でもRewarded Adによる1時間限定プレビューの対象になり得る。これはContentBlockの表示権だけを一時的に与えるもので、stamp/achievement/cardの獲得状態を変更しない。

プレビュー期限はSupabase server clockを基準に判定し、アプリ再開時・resume時・毎分で期限を再評価する。通信失敗時は安全側としてプレビューを終了する。

## Legacy fallback
render可能blockのroleに応じて旧reading/description/imageを隠す。readingがあればlegacy readingを、description/aboutがあればlegacy descriptionを、picture_cardがあればlegacy imageをフォールバック表示しない。汎用データ未整備でも旧データで画面を成立させる移行設計。

## コラボ
読み札、絵札、解説、関連画像、店舗・商品情報、注意事項、外部リンク等を固定カラムの増殖ではなくblock/metadataで表現する。特定IP専用テーブル・専用画面を原則作らない。

## 権利
DB/Storageに画像が存在することと公開許諾は別。権利確認を公開判断源とする。

## 上毛かるたの利用許諾

上毛かるたの画像利用は、群馬県の許諾通知に従う。2026年10月1日付の許諾（許諾第08-01054号）は、スマートフォン向け位置情報周遊アプリ「聖地クエスト」での全絵札・全読み札の利用を対象とし、利用期間は2027年3月31日まで。

- 絵札・読み札を改変しない。
- 絵札全体が見えるように表示し、読み札の文字が読めるようにする。
- 画像の縮小・拡大時は縦横比を維持する。
- 表記は「上毛かるた」とする。
- 許諾番号を許諾対象物件に原則明示する。
- 利用後30日以内に利用報告書と利用状況が分かる写真を提出する。
- 継続利用する場合は、利用期間満了前に更新申請する。

許諾書の原本・写真は個人名等を含むため、公開リポジトリには格納しない。運用記録は `docs/legal/jomo_karuta_permission.md` を参照する。
