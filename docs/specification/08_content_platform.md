# 汎用コンテンツ基盤

## 目的
上毛かるた専用構造から、観光・店舗・商品・企業・作品/IP等を同一基盤で扱える構造へ拡張する。

## 実装済み
`contents`、`event_contents`、`places`、`content_blocks` と、Flutter側 `ContentBlock` / `ContentBlockService` / `ContentBlockPresentationPolicy` / `ContentBlockRenderer`。

ContentBlockTypeは `text / image / link / unsupported`。未知typeはunsupportedとして扱い、描画対象から除外するため後方互換性を確保する。

## Roleと表示優先度
role未指定はdefault。現行PresentationPolicyでは picture_card → reading_card → reading → その他 の優先順位で、同順位はdisplay_order、さらにidで安定ソートする。

render可能条件は、textはbody有り、imageはmedia_path有り、linkはhttp/httpsかつhost有り。無効・空ブロックは描画しない。

## Legacy fallback
render可能blockのroleに応じて旧reading/description/imageを隠す。readingがあればlegacy readingを、description/aboutがあればlegacy descriptionを、picture_cardがあればlegacy imageをフォールバック表示しない。汎用データ未整備でも旧データで画面を成立させる移行設計。

## コラボ
読み札、絵札、解説、関連画像、店舗・商品情報、注意事項、外部リンク等を固定カラムの増殖ではなくblock/metadataで表現する。特定IP専用テーブル・専用画面を原則作らない。

## 権利
DB/Storageに画像が存在することと公開許諾は別。権利確認を公開判断源とする。
