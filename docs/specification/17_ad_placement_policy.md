# 広告配置Policy

## 最優先原則
収益機会を増やしつつ、ゲーム体験を損なわないことを最優先とする。広告はプレイの途中へ割り込ませず、画面特性に応じて「常設バナー」「インライン」「自然な区切りのInterstitial」を使い分ける。

## 3層構成

### 1. Banner
地図など、広告を常設しても主要操作を妨げない画面ではバナーを継続表示してよい。表示時間だけを目的に画面を塞がず、UIを圧迫する場所には置かない。

現行BannerAdWidgetはAdaptive Bannerへ移行し、即採用する。ただし現行の `AdSize.banner` の高さ50dpをUX上限とし、横幅を端末に合わせるために縦方向が現行より大きくなることは許可しない。利用可能幅からanchored adaptive banner sizeを取得し、返された高さが50dp以下の場合のみ採用する。50dpを超える場合またはサイズ取得に失敗した場合は、現行50dpバナーへフォールバックする。広告未ロード時は不要な空白を残さない。

### 2. Inline
スクロール閲覧系画面ではコンテンツ間へ自然に配置する。候補はスタンプ帳、ランキング、お知らせ一覧、イベント探索。

一覧の先頭や主要CTA直前へ機械的に置かず、一定量のコンテンツを閲覧した位置に挿入する。広告ロード失敗時は空白枠を残さない。

### 3. Interstitial
全画面広告は自然な区切りだけで表示候補とする。

Release初期値:
- 起動後10分間は表示しない
- 前回Interstitial表示から30分以上
- スタンプ獲得後5分以上
- 対象画面を15秒以上利用
- セッション内の最大表示回数は設けない

上記時間を満たしただけでは表示しない。「画面を見終えて戻る」等のユーザー操作上の自然な区切りが必要。

## 禁止ゾーン
次のタイミングではInterstitialや新しい割り込み広告を開始しない。
- アプリ起動直後
- 起動時お知らせ表示中およびその直後
- オンボーディング
- GPS取得/判定中の重要導線
- 聖地到着直前
- スタンプ獲得処理・獲得演出
- 地図の移動/目的地操作を妨げるタイミング
- エラー/権限要求ダイアログとの連続表示

お知らせの起動モーダル内には広告を置かない。

## 広告種別間の扱い
Banner/Inline/Interstitialは役割が異なるため、BannerやInlineが表示されたことだけを理由にInterstitialの15分間隔をリセットしない。Interstitial同士の頻度はInterstitialのPolicyで制御する。

Rewarded広告とInterstitialは同時表示しない。Rewarded広告のロード後に表示条件を再確認し、Interstitialとの共有ロックを取得してから表示する。実際にRewarded広告が表示された場合はInterstitialの最短間隔を再計測し、表示失敗やキャンセルだけでは間隔をリセットしない。

## 一元管理
広告可否判断をAdPlacementPolicyへ集約する。各画面が独自に頻度や禁止条件を持たない。placement IDを定義し、将来の計測・A/BテストでもUIコードを分岐だらけにしない。

例:
- map_banner
- collection_inline
- ranking_inline
- announcements_inline
- event_explore_inline
- natural_exit_interstitial

## 計測と調整
現行実装の初期値10分/30分/5分/15秒は固定仕様ではなく、クローズドテストでUXと収益を見ながら検証する基準値とする。広告収益だけでなく、1セッション当たり表示回数、セッション継続、スタンプ獲得完了、広告直後離脱、画面滞在を確認する。

長時間利用者には条件を満たすたび3回目以降も表示可能とする。一方で短時間利用者へ無理にInterstitialを表示しない。収益増でもプレイ離脱が増える配置は採用しない。


## 本番広告ユニットIDの管理

Android本番ビルドの広告ユニットIDはソースコードへ直接記述せず、GitHub Actionsの保護された `production` Environment Variablesで管理する。

- `ADMOB_ANDROID_BANNER_AD_UNIT_ID`
- `ADMOB_ANDROID_INTERSTITIAL_AD_UNIT_ID`
- `ADMOB_ANDROID_STORY_REWARDED_AD_UNIT_ID`

本番ビルドWorkflowは3値の形式を事前検証し、Google公式のテスト広告ユニットIDが指定されている場合はビルドを停止する。値はFlutterの `--dart-define` で渡し、Releaseビルドで使用する。Debug/ProfileではGoogle公式テスト広告IDを維持し、広告表示頻度やリワード付与時間などのユーザー体験仕様とは分離して管理する。
