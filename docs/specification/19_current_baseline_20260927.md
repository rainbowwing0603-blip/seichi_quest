# 現行ベースライン 2026-09-27

この文書は、次期「しるべ / ストーリー」開発へ入る前に、現行アプリ・DB・リリース・仕様の境界を固定するためのスナップショットである。

## Git / App
- Repository: `rainbowwing0603-blip/seichi_quest`
- Working branch: `fix/destination-range-and-float`
- Release baseline anchor: `3e4b1a89b52f52f09376b8c3d9a5b9e9726a2540`（build 12へ更新した時点）
- 監査・文書整合はbaseline anchor以降の同一候補ブランチ上で継続する。差分件数は固定値として記録せず、PR #13を最新状態の確認点とする
- PR: #13 `Release baseline: map refinements, release policy, backend/spec sync`（Draft）
- `pubspec.yaml`: `1.0.0+12`
- GitHub Releases: 0（2026-09-27確認時）

## Verification
2026-09-27時点:
- GitHub Actions run #126で `flutter analyze` / `flutter test` / Android release AAB build verification が成功
- CIのrelease AABは一時署名によるビルド検証用であり、Play提出用の本番署名成果物とは区別する
- WindowsローカルでもFlutter 3.47.1 / Dart 3.13.1で `flutter analyze` 成功、167 tests passed
- Android emulator（API 37）で起動し、Supabase初期化、イベント復元、地図、位置情報、NEXT、天気、テスト広告の基本動作を確認
- 最終Play提出前にローカルのrelease signingで+12 AABを生成し、SHA-256とサイズを記録する

## Release
Supabase `app_release_policies` のAndroid値はlatest=11、minimum=11、latest_version=1.0.0。ソースは+12なので、+12は「次の提出候補」として扱い、Play Consoleで実配布状態を確認するまでは公開済みと記録しない。

## Production Supabase
2026-09-27確認:
- events 4
- places 1328
- contents 1311
- event_contents 1311
- content_blocks 292
- profiles 114
- collection_history 14
- roadside_station_registry 1234
- collection_series_places 1231
- app_release_policies 1
- legacy `seichi`: 廃止済み

本番migrationは `20260926225451_add_app_release_policy` まで照合済み。直近で不足していたPostGIS API surface hardeningとapp release policy migrationはGitへ回収済み。

## 現行機能の柱
1. 汎用イベント/コンテンツ/地点モデル
2. GPS + サーバー獲得判定 + オフライン同期
3. mock location / 不自然移動検知とserver cooldown
4. event-aware NEXT / 推奨ルート
5. zoom別 spot / cluster / regional progress
6. 距離連動ソナー、獲得範囲、heading-up
7. 天候・季節・時間帯・太陽方位連動の地図表現
8. スタンプ帳、Spot Detail、実績、ランキング、プロフィール
9. お知らせ、広告Policy、通知
10. app release policy

## 次期開発へ持ち越す確認事項
- Edge Function本番/Git一致確認とmaintenance secretの安全な外部化
- Security Advisor警告を意図別に精査
- 上毛かるたpicture-card画像実体の権利・最終素材確認
- +12の本番署名AAB生成、ハッシュ記録、Play Console照合
- PR #13を最終確認後にmainへ統合してbaselineを固定

## しるべとの境界
しるべのキャラクター表示、状態機械、ストーリー、伏線、派生キャラクター、物語進行DBはこのベースラインには含めない。次期設計では、イベント固有分岐を増殖させず既存のEvent/Content/Block基盤と接続する。
