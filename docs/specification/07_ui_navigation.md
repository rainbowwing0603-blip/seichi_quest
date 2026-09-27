# UI・画面遷移仕様

## メイン
Material 3、Noto Sans JP、紫系seed color。起点はSeichiMapPage。

## 主な画面
MapPage、CollectionPage、QuestPage、RankingPage、MyPage、ProfilePage、AccountPage、AdventureLogPage、EventExplorePage、SyncStatusPage、NotificationSettingsPage、AppSettingsPage、OnboardingPage、LicensePage、AnnouncementsPage、EventDetailPage。

## Map
Google Map、現在地、未獲得/獲得済/NEXT、クエストHUD、エラー/位置精度案内を統合する。

ズーム表示Policy:
- zoom >= 9: 個別spot
- 6 <= zoom < 9: geographic grid cluster
- zoom < 6: regional progress

クラスタはズームに応じてセルを縮小し、拡大すると自然に個別地点へ分割する。クラスタアイコン生成中に通常ピンへ一時フォールバックしてちらつかせないことを表示上の要件とする。

NEXTには獲得範囲Circleと距離連動ソナーを利用する。ソナー反応距離は `max(1000m, stampRadius × 5)`。heading-upを利用できる。

天候・季節・時間帯を地図上の環境表現へ反映し、太陽方位/高度をローカル計算して光の方向へ利用する。reduce motion設定時は不要なアニメーションを停止する。

## Collection / Spot Detail
全件・獲得済・未獲得のフィルタを持つ。汎用ContentBlockを使って読み札・解説・画像・リンク等を描画する。画像が無い場合もUIを成立させる。内部GPS由来・検証状態・管理用メタデータはユーザー向け説明として表示しない。

## Quest / Ranking / My
Questはイベント実績の進捗と達成状態を表示する。Rankingはイベント単位のランキング、Myはプロフィール・アカウント・設定・お知らせ等への導線を提供する。

## Event Explore
複数イベントから現在のイベントを選択する入口。全国展開・コラボでもイベント種別ごとに別アプリ/別ナビゲーションを作らず共通入口を維持する。

## UX原則
画像・説明等の任意データが未設定でも空白の巨大枠や壊れたレイアウトを出さない。機能追加はイベント固有画面を増殖させず、共通rendererとmetadata/blockで吸収する。
