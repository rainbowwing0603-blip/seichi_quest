# 汎用コンテンツ基盤

## 目的
上毛かるた専用構造から、観光・店舗・商品・企業・作品/IP等を同一基盤で扱える構造へ拡張する。

## 実装済み基盤
`contents`、`event_contents`、`places`、`content_blocks` と、Flutter側 `ContentBlock` / `ContentBlockService` / `ContentBlockPresentationPolicy` / `ContentBlockRenderer`。

## 表示
Content本体はtitle/description/image_url/metadataを持ち、追加情報を複数のContentBlockで表現する。これにより「読み札」「絵札」「解説」「関連画像」等を固定カラムだけで増殖させない。

## かるた
読み札、絵札、札の説明等は汎用コンテンツ表現へ載せる。旧seichi.card / reading / card_image_urlは移行期間の互換データ。

## コラボ
作品画像、店舗画像、商品画像、紹介文、注意事項、リンク等をブロック/metadataで扱えるようにし、特定IP専用テーブル・専用画面を原則作らない。

## 権利
画像利用権限はデータモデル上の表示可否とは別の運用要件。許諾取得前の素材を「DBに存在するから公開可」と解釈しない。

## 将来
ブロック種別を増やす場合、既存アプリが未知のblockを安全に無視せる後方互換を維持する。
