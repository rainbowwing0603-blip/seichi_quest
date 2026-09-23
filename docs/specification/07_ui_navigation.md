# UI・画面遷移仕様

## メイン
Material 3、Noto Sans JP、紫系seed color。起点はSeichiMapPage。

## 主な画面
MapPage、CollectionPage、QuestPage、RankingPage、MyPage、ProfilePage、AccountPage、AdventureLogPage、EventExplorePage、SyncStatusPage、NotificationSettingsPage、AppSettingsPage、OnboardingPage、LicensePage。

## Map
Google Map、現在地、未獲得/獲得済/NEXTの専用マーカー、クエストHUD、エラー/位置精度案内を統合する。マーカー画像は遅延ロードし、準備前はdefault markerへフォールバックする。

## Collection
全件・獲得済・未獲得のフィルタを持つ。コンテンツ画像が無い場合もUIを成立させる。

## Quest
イベント実績の進捗と達成状態を表示する。

## Ranking / My
イベント単位のランキングと自分の順位、プロフィール・アカウント・設定等への導線を提供する。

## Event Explore
複数イベントから現在のイベントを選択する入口。今後の全国展開・コラボでもイベント種別ごとに別アプリ/別ナビゲーションを作らず共通入口を維持する。

## UX原則
画像・説明等の任意データが未設定でも空白の巨大枠や壊れたレイアウトを出さない。機能追加はイベント固有画面を増殖させず、共通rendererとmetadata/blockで吸収する。
