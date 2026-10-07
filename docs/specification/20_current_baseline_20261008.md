# 現行ベースライン 2026-10-08

この文書は、2026-10-08時点の聖地クエストについて、実装済み機能、Version 17リリース準備状態、Rewarded Story Preview、主要な運用判断を固定する現行スナップショットである。

## Git / App

- Repository: `rainbowwing0603-blip/seichi_quest`
- 実装コードのVersion 17 anchor: `8d1badbd75a489b8b03d478270f85f3dd21dbccb`
- 現在の `pubspec.yaml`: `1.0.0+17`
- Flutter: 3.47.1
- Dart: 3.13.1
- Android applicationId: `jp.seichiquest.app`
- Supabase project ref: `wxlvhpmolrtcwryaazfb`

仕様書更新はこのanchor以降のmainへ反映されている。Version 17のコード、workflow修正、仕様書はmainに統合済み。

## Verification

Version 17準備時点で確認済み:
- `flutter pub get` 成功
- `flutter analyze` 成功
- `flutter test`: 175 tests passed
- Android emulatorへのbuild/install成功
- 実機/エミュレータでアプリ起動と主要動作を確認済み
- CodemagicのiOS unsigned build checkは過去に成功済み

Version 17のGoogle Play配信後には、Release AAB上でRewarded Story Previewの実表示確認が必要。

## Rewarded Story Preview

### 仕様
未獲得地点に対象ContentBlockがある場合、ユーザーが「広告を見て物語を1時間読む」を選択してRewarded Adを視聴すると、対象物語を1時間だけ閲覧できる。

- 対象: after_collection の description / history / field_guide / story
- スタンプ獲得は発生しない
- 実績、カード、その他の獲得状態は変更しない
- 有効期限: 1時間
- Supabase server clockを基準に期限判定
- reopen / resume / 毎分で期限を再確認
- 通信失敗時はプレビュー終了
- entitlementはアカウント/コンテンツ単位の端末内保存

### 実装対応
- `lib/services/story_rewarded_ad_service.dart`
- `lib/services/story_preview_service.dart`
- `lib/widgets/quest_item_content_section.dart`

### Release Ad ID
Android Releaseでは `ADMOB_ANDROID_STORY_REWARDED_AD_UNIT_ID` を `--dart-define` で注入する。

Release buildでRewarded IDが利用できない場合、CTAは非表示となり、通常の未獲得コンテンツ表示へフォールバックする。

## Version 16 incident

Version 16はGoogle Play Alphaへ配信済み。

Version 16では「広告を見て物語を1時間読む」ボタンが表示されなかった。原因はUI側の条件不備ではなく、GitHub ActionsのRelease build logで `STORY_REWARDED_AD_UNIT_ID` が空だったため、AABへRewarded Android Ad Unit IDが注入されなかったこと。

この構造ではRelease IDが無い場合にCTAを隠す実装になっているため、Version 16のボタン非表示はコード仕様どおりのフォールバックだった。

## Version 17 prevention

Google Play Test Release workflowを修正し、Rewarded Android Ad Unit IDについて以下を行う。

1. GitHub Actions variable / secretを優先して取得
2. repository側の設定が無い場合は現在のAndroid Rewarded unitをフォールバックとして利用
3. 最終値が空ならbuildを失敗させる
4. build logに `Rewarded story ad unit configured.` を出す
5. AABへ `--dart-define` で注入する

これにより、Version 16のように「ビルド成功したがRewarded機能だけ静かに無効化される」状態を早期検出する。

## Version 17 release status

- ソース versionCode: 17
- リリース元: `main`
- 対象track: Google Play closed test Alpha
- Version 17: **未配信、リリース待ち**
- Version 16: **Alpha配信済み**
- Version 17のworkflow実行とPlay配信は帰宅後に実施予定

Play Consoleの配信状態とSupabase `app_release_policies` は別事実として扱い、Version 17を実際に配信するまで「最新版配信済み」と記録しない。

## Release workflow

`.github/workflows/google-play-test-release.yml` の `Google Play Test Release` を手動起動する。

基本手順:
1. branch = `main`
2. track = `alpha`
3. release_status = `completed`
4. analyze / test / build / signing / versionCode guardを通過
5. Rewarded ID injectionを確認
6. Alphaへのcommitを確認
7. 登録テスト端末をVersion 17へ更新
8. 対象未獲得spotでCTA表示を確認
9. Rewarded Ad表示を確認
10. 報酬後1時間プレビューを確認

## Remaining checks

Version 17配信後に以下を確認する。

- CTAが表示されること
- Rewarded Adが実際に表示されること
- 報酬コールバックでプレビューが開くこと
- スタンプが増えないこと
- 1時間経過後にロックされること
- アプリ再開後もserver clock基準で期限が維持されること
- Rewarded直後にInterstitialが重複表示されないこと

## Historical baseline

`19_current_baseline_20260927.md` は2026-09-27時点の履歴資料として保持する。現在の正本は本ファイルである。

## Long-term boundary

「しるべ」のキャラクター状態、長期ストーリー状態機械、伏線・派生キャラクター・物語進行DBなどは未実装。現行のRewarded Story Previewは既存ContentBlockを一時閲覧する機能であり、長期ストーリーシステムとは分離する。
