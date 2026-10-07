# プロダクト概要

## 目的
聖地クエストは、実在地点への訪問をGPSで確認し、イベントに紐づくコンテンツを収集するFlutterアプリである。上毛かるた×群馬を含む地域イベントに加え、全国規模の収集シリーズ、店舗・商品・企業・作品/IPコラボ等を、イベント種別ごとに画面をサイロ化せず扱えるプラットフォームを目指す。

## 実装済み
- Androidアプリ。applicationId / namespace は `jp.seichiquest.app`。
- Google Maps、現在地、NEXT、獲得範囲、heading-up。
- ズーム連動のspot / cluster / regional progress表示。
- 距離と獲得半径に連動するソナー。
- 天候・季節・時間帯と太陽方位を使う地図上の環境表現。
- GPS訪問とサーバー側獲得処理、mock location / 不自然移動に対する不正対策。
- 端末キャッシュとSupabase同期。
- イベント探索・切替、スタンプ帳、チャレンジ、ランキング、マイページ系画面。
- 汎用コンテンツブロックとSpot Detail。
- アプリ内お知らせ。
- AdMob、ローカル通知、広告配置Policy。
- Supabase Auth / Database / Storage / Edge Function。
- サーバー管理のアプリ更新Policy。
- Noto Sans JPをアプリ全体のフォントとして使用。

## 現在の本番データ
2026-09-27確認時点で、events 4、places 1328、contents 1311、event_contents 1311、content_blocks 292、profiles 114、collection_history 14。旧 `seichi` テーブルは廃止済みで、汎用モデルが正本である。

## 将来構想
全国の移動・観光クエスト、自治体・店舗・商品・企業・作品/IPとのコラボを共通モデルで扱う。キャラクター「しるべ」およびストーリーシステムは次期構想であり、この2026-09-27ベースラインにはまだ実装しない。

## 原則
「イベント」「収集物」「物理地点」を分離する。同一地点に複数コンテンツを紐付けられ、画像が無いコンテンツでもUIが破綻しないことを前提とする。ユーザー向け表示へGPS検証用・管理用メタデータを露出しない。



## 2026-10-08差分反映
Version 12（1.0.0+12）以降、以下を現行機能として追加・更新した。
- 記念カード導線をAndroid/iOS共通のコレクション機能へ統合。
- アプリ内お知らせ、更新Policy、Google Play test release運用を強化。
- AdMobのBanner / Interstitialを起動負荷とUX制約を考慮して再構成。
- スクリーンショット用のopt-in modeを追加し、広告とデバッグ用記念カード導線を非表示にできるようにした。
- 未獲得コンテンツのvisibility制御と、Rewarded Adによる1時間Story Previewを追加。
- iOSのbundle identifier、Google Maps、AdMob platform-specific unit、Codemagic unsigned buildの準備を追加。
- Webからのアカウント削除導線を追加。
