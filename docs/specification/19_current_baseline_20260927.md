# 現行ベースライン 2026-09-27

この文書は、次期「しるべ / ストーリー」開発へ入る前に、現行アプリ・DB・リリース・仕様の境界を固定するためのスナップショットである。

## Git / App
- Repository: `rainbowwing0603-blip/seichi_quest`
- Working branch: `fix/destination-range-and-float`
- Release baseline anchor: `3e4b1a89b52f52f09376b8c3d9a5b9e9726a2540`（build 12へ更新した時点。監査・文書修正コミットはこの後に積む）
- 現在の候補ブランチ: main比 42 commits ahead / 0 behind（2026-09-27再確認時）
- PR: #13 `Release baseline: map refinements, release policy, backend/spec sync`（Draft、CI検証中）
- `pubspec.yaml`: `1.0.0+12`
- GitHub Releases: 0（確認時）

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

本番migrationは `20260926225451_add_app_release_policy` まで。Gitとの差分回収が残る。

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
- 本番後半migrationをGitへ回収
- Edge Function本番/Git一致確認
- Security Advisor警告を意図別に精査
- TEST IMAGE / media fallback経路確認
- +12のanalyze/testはGitHub Actionsで成功。release AABビルド検証とPlay Console照合を完了する
- PRを作りmainへ統合してbaselineを固定

## しるべとの境界
しるべのキャラクター表示、状態機械、ストーリー、伏線、派生キャラクター、物語進行DBはこのベースラインには含めない。次期設計では、イベント固有分岐を増殖させず既存のEvent/Content/Block基盤と接続する。
