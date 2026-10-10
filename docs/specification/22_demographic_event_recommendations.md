# 年代ベースのイベントおすすめ

## 目的

クエスト一覧に、ユーザーがまだ参加していないイベントのおすすめを表示する。リリースブランチの既存クエスト導線、イベント探索、次の目的地・収集機能は維持する。

## 推薦ロジック

- 認証済みユーザーのみがRPCを呼び出す。
- 参加済みイベントはおすすめから除外する。
- 年代が設定されている場合は同年代の参加実績を優先する。
- 年代の「回答しない」は属性として扱わず、年代別の推薦に使用しない。
- 年代別の統計対象が5人未満の場合、属性別の結果は返さず全体人気へフォールバックする。
- 性別はデータベース上の任意項目。現行のプロフィール画面は年代のみ編集する。性別入力を追加する場合は、直接テーブル更新を避け、既存の安全なプロフィール保存RPCを拡張してから実装する。
- 終了済み・非アクティブイベントは対象外とする。

## プライバシーとアクセス制御

- RPCは集計値とイベントIDのみを返し、参加者の表示名やユーザーIDを返さない。
- get_event_recommendations(integer) は SECURITY DEFINER、空の search_path、認証済みロール限定の EXECUTE 権限を維持する。
- 属性別統計は対象集団が5人以上の場合に限る。
- 年代だけを登録した利用者でも集計できるよう、NULLの性別を「性別条件なし」として扱う。

## 実装ファイル

- lib/models/event_recommendation.dart
- lib/services/event_recommendation_service.dart
- lib/widgets/recommended_events_card.dart
- lib/widgets/event_recommendation_section.dart
- lib/widgets/quest_page.dart
- lib/main.dart
- lib/widgets/profile_page.dart
- supabase/migrations/20261007211445_event_demographic_recommendations.sql
- supabase/migrations/20261010120000_fix_event_recommendation_null_gender.sql

## 検証

- Flutter analyze と全テストをCIで実行する。
- 年代未設定時は全体人気へフォールバックする。
- 年代設定時に性別がNULLでも年代別集計が成立する。
- 参加済みイベント、非アクティブイベント、終了済みイベントが推薦されない。
- 5人未満の属性集団が属性別推薦として表示されない。
- RPC応答に個人識別情報が含まれないことを確認する。
- プロフィール保存は既存の save_my_profile RPCを維持する。