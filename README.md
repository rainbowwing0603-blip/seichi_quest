# 聖地クエスト

実在する場所を巡り、GPS訪問によってイベントのコンテンツを集めるFlutterアプリです。

上毛かるたの聖地巡礼から始まり、地域観光、全国規模の収集シリーズ、店舗・商品・作品/IPコラボまでを、共通の Event / Content / Place モデルで扱うことを目指しています。

## Current baseline

- Android applicationId: `jp.seichiquest.app`
- Flutter/Dart: 3.47.1 / 3.13.1
- 現在のソース version: `1.0.0+19`
- Backend: Supabase
- Map: Google Maps
- Collection: GPS + server-side validation + offline retry
- Map presentation: spot / cluster / regional progress
- Features: NEXT destination, sonar, weather/season/day-phase effects, achievements, ranking, announcements, ads, local notifications
- Story preview: Rewarded Adによる1時間限定プレビューを実装
- Current specification baseline: 2026-10-11

Version 19はリリース準備済みのソース状態であり、Google Playへの配信完了とは別に扱います。実配布状態はPlay Consoleを正本として確認します。

仕様・運用・DB・リリースの正本は [docs/specification/README.md](docs/specification/README.md) を参照してください。

## Branch policy

- `main` is the source of truth for production Android AAB builds and production release configuration.
- The Google Play test-release workflow defaults to `feature/android-next-release`; its versionCode is assigned from Play's current maximum, so the closed-test release number is not the same as `main`'s source version `1.0.0+19`.
- Keep the production and closed-test source paths distinct. Do not wholesale merge or reset either branch: collection-card and story-preview UI changes overlap. Promote changes between branches only through narrow, tested PRs.
- Before production migration pushes, keep `supabase/migrations/` version-for-version aligned with production history and run the Supabase source guardrails.

## Development

機能変更時はコードだけでなく、対応する `docs/specification` と traceability を更新します。DB変更はmigrationとして管理し、本番Supabaseへ先行変更した場合はGitへ回収します。本番へmigrationをpushする前に、`supabase/ENVIRONMENT_SYNC_STATUS.md` のとおりソースと本番履歴の版数・内容を照合します。

秘密鍵、Android upload keystore、service_role/secret key、本番ユーザーデータ、許諾前の権利物画像はリポジトリへ保存しません。
