# 聖地クエスト

実在する場所を巡り、GPS訪問によってイベントのコンテンツを集めるFlutterアプリです。

上毛かるたの聖地巡礼から始まり、地域観光、全国規模の収集シリーズ、店舗・商品・作品/IPコラボまでを、共通の Event / Content / Place モデルで扱うことを目指しています。

## Current baseline

- Android applicationId: `jp.seichiquest.app`
- Flutter/Dart: 3.47.1 / 3.13.1
- 現在のソース version: `1.0.0+17`
- Backend: Supabase
- Map: Google Maps
- Collection: GPS + server-side validation + offline retry
- Map presentation: spot / cluster / regional progress
- Features: NEXT destination, sonar, weather/season/day-phase effects, achievements, ranking, announcements, ads, local notifications
- Story preview: Rewarded Adによる1時間限定プレビューを実装
- Current specification baseline: 2026-10-08

Version 17はリリース準備済みのソース状態であり、Google Playへの配信完了とは別に扱います。実配布状態はPlay Consoleを正本として確認します。

仕様・運用・DB・リリースの正本は [docs/specification/README.md](docs/specification/README.md) を参照してください。

## Development

機能変更時はコードだけでなく、対応する `docs/specification` と traceability を更新します。DB変更はmigrationとして管理し、本番Supabaseへ先行変更した場合はGitへ回収します。

秘密鍵、Android upload keystore、service_role/secret key、本番ユーザーデータ、許諾前の権利物画像はリポジトリへ保存しません。
