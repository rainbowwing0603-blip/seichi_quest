# 広告配置Policy

## 最優先原則
収益機会を増やしつつ、ゲーム体験を損なわないことを最優先とする。広告はプレイの途中へ割り込ませず、画面特性に応じて「常設バナー」「インライン」「自然な区切りのInterstitial」「ユーザー任意のRewarded」を使い分ける。

## 3+1層構成

### 1. Banner
地図など、広告を常設しても主要操作を妨げない画面ではバナーを継続表示してよい。表示時間だけを目的に画面を塞がず、UIを圧迫する場所には置かない。

現行BannerAdWidgetはAdaptive Bannerへ移行し、即採用する。ただし現行の `AdSize.banner` の高さ50dpをUX上限とし、横幅を端末に合わせるために縦方向が現行より大きくなることは許可しない。利用可能幅からanchored adaptive banner sizeを取得し、返された高さが50dp以下の場合のみ採用する。50dpを超える場合またはサイズ取得に失敗した場合は、現行50dpバナーへフォールバックする。広告未ロード時は不要な空白を残さない。

### 2. Inline
スクロール閲覧系画面ではコンテンツ間へ自然に配置する。候補はスタンプ帳、ランキング、お知らせ一覧、イベント探索。

一覧の先頭や主要CTA直前へ機械的に置かず、一定量のコンテンツを閲覧した位置に挿入する。広告ロード失敗時は空白枠を残さない。

### 3. Interstitial
全画面広告は自然な区切りだけで表示候補とする。

Release初期値:
- 起動後3分間は表示しない
- 前回Interstitial表示から15分以上
- スタンプ獲得後2分以上
- 対象画面を10秒以上利用
- セッション内の最大表示回数は設けない

上記時間を満たしただけでは表示しない。「画面を見終えて戻る」等のユーザー操作上の自然な区切りが必要。

### 4. Rewarded Story Preview
Rewardedは自動表示せず、未獲得地点の対象物語を読みたいユーザーが明示的に選択した場合だけ表示する。

- 報酬: 対象物語を1時間閲覧
- スタンプ獲得: 発生しない
- 対象: description / history / field_guide / story の対象ContentBlock
- 有効期限: 1時間
- server clockで期限判定
- 対象コンテンツ以外の獲得状態を変更しない
- Rewarded IDが利用できないReleaseではボタンを表示しない
- Rewarded視聴後は通常のInterstitialを即座に重ねず、通常の頻度制御へ戻す

## 禁止ゾーン
Interstitialや新しい割り込み広告を次のタイミングでは開始しない。
- アプリ起動直後
- 起動時お知らせ表示中およびその直後
- オンボーディング
- GPS取得/判定中の重要導線
- 聖地到着直前
- スタンプ獲得処理・獲得演出
- 地図の移動/目的地操作を妨げるタイミング
- エラー/権限要求ダイアログとの連続表示

Rewardedはユーザーが明示的にCTAを押した場合のみ例外的に開始する。

## 広告種別間の扱い
Banner/Inline/Interstitial/Rewardedは役割が異なる。BannerやInlineが表示されたことだけを理由にInterstitialの15分間隔をリセットしない。Rewarded表示後は全画面広告の重複表示を避け、通常のInterstitial Policyへ戻す。

## 一元管理
広告可否判断をAdPlacementPolicyへ集約する。各画面が独自に頻度や禁止条件を持たない。placement IDを定義し、将来の計測・A/BテストでもUIコードを分岐だらけにしない。

例:
- map_banner
- collection_inline
- ranking_inline
- announcements_inline
- event_explore_inline
- natural_exit_interstitial
- story_rewarded_preview

## 計測と調整
初期値の3分/15分/2分/10秒は固定仕様ではなくクローズドテストの基準値とする。広告収益だけでなく、1セッション当たり表示回数、セッション継続、スタンプ獲得完了、広告直後離脱、画面滞在、Rewarded利用率を確認する。

長時間利用者にはInterstitial条件を満たすたび3回目以降も表示可能とする。一方で短時間利用者へ無理にInterstitialを表示しない。Rewardedはユーザー価値が明確な場合のみ利用される構造を維持する。
