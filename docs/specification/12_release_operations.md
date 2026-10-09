# リリース・運用仕様

## Android
applicationId `jp.seichiquest.app`。Releaseはupload keystoreで署名する。秘密鍵・password・key.propertiesはGitへ入れない。

## Version
- 人が決めるのは `pubspec.yaml` の `versionName`（例: `version: 1.0.0`）だけ。正式リリースの番号は別途判断し、ここで固定しない。
- `versionCode` は手動管理しない。PlayリリースWorkflowがGoogle Playの既存App Bundleを照会し、最大値 + 1をビルド時に `--build-number` へ渡す。
- `versionName` は `--build-name` で渡す。AABのversionCodeをAPI応答と照合し、不一致なら停止する。
- リリースWorkflowはテストトラック（alpha / beta / internal）のみを許可する。Production公開は別の明示的な手順で行う。
- Play側の既存versionCodeを取得できない場合は、推測値で続行せず失敗させる。既存Bundleの最大値を基準にし、番号を再利用しない。
- `pubspec.yaml` に `+NN` を書かない。ローカルビルドでは必要に応じて明示的な `--build-number` を指定するが、Play配布用番号はWorkflowに任せる。

## 2026-09-27 現行状態
- 開発ブランチ: `fix/destination-range-and-float`
- HEAD: `3e4b1a89b52f52f09376b8c3d9a5b9e9726a2540`
- pubspec: `1.0.0+12`
- mainとの差分: 24 commits ahead / 0 behind（確認時）
- GitHub open PR: 0（確認時）
- GitHub Releases: 0（確認時）
- 直近のrelease candidate PR checksは成功実績あり。
- Supabase Android release policy: `latest_build=11`, `minimum_build=11`, `latest_version=1.0.0`。
- Play Console上で実際に配信中のbuild番号はGitHub/Supabaseだけでは断定しない。提出前後にPlay Consoleを正本として照合する。

## App update policy
`AppVersionService` は `app_release_policies` からplatform別のlatest/minimum buildを読み、更新有無と必須更新を判定する。バックエンド障害時はfail-openとし、一時障害でアプリをロックしない。

## Build
Release AABは `flutter build appbundle --release` を基本とする。提出用AABは実際のupload keystoreと本番設定で作る。CIの仮鍵AABはビルド確認専用。

## 品質ゲート
少なくとも `flutter analyze` と `flutter test` を通し、GPS/獲得、不正対策、イベント切替、同期、主要画面、クラスタ、regional progress、NEXT/ソナー、天候/太陽表現、広告禁止ゾーン、更新Policyを確認してから配布する。

## Git
リリースタグは不変。機能開発はブランチ→PR→main。仕様変更を伴う場合は `docs/specification` も同PRで更新する。main統合前に本番DBの未回収migration/Function driftを確認する。

## Play Console
AAB作成とPlay Consoleへのアップロードは別事実として記録する。ローカルビルド成功だけで「公開済み」「アップロード済み」と記録しない。

## クローズドテスト更新手順
1. 提出対象commitを固定し、Git statusがcleanであることを確認。
2. `versionName` が今回のリリース判断に合っていることを確認する。`versionCode` は手動設定せず、GitHub ActionsがPlay上の最大値 + 1を自動採番する。
3. `flutter pub get`、`flutter analyze`、`flutter test`、Release AAB build。
4. 実機/エミュレータで主要導線をスモークテスト。mock locationはdebugではテスト可能、release/profileでは拒否する。
5. Play ConsoleへAAB登録、リリースノート入力、審査/配信状態を確認。
6. commit、versionName、Workflowログに出力された自動採番versionCode、AAB SHA-256、提出日時、Play状態をリリース記録へ残す。
7. Supabase `app_release_policies` のlatest/minimumを、実配布状態と矛盾しないタイミングで更新する。

## Supabase環境の分離
- 現在のSupabaseプロジェクト `wxlvhpmolrtcwryaazfb` はクローズドテスト用として維持し、既存のテスト履歴を削除しない。
- 本番用には別のSupabaseプロジェクトを使用する。テスト用と本番用のAuthユーザーID・スタンプ履歴・イベント参加状態は自動共有・自動移行しない。
- Flutterは `APP_ENV`、`SUPABASE_URL`、`SUPABASE_PUBLISHABLE_KEY` のDart defineで接続先を切り替える。未指定時の既定値はクローズドテスト環境。
- `APP_ENV=production` のビルドでクローズドテスト用URLまたはキーが残っている場合は、起動時に停止する。
- クローズドテスト用Play Workflowは必ず `APP_ENV=closed_test` を指定する。本番用Workflowは、本番Supabase URLとpublishable keyをGitHub Environmentの保護された変数/Secretsから渡し、テスト用既定値へのフォールバックを許さない。
- 本番プロジェクトはスキーマ・RLS・RPC・Edge Functions・Storage・Auth設定を検証し、イベント/スポット等のマスターデータを反映してから接続先を有効化する。ユーザー履歴は、別途移行方針が承認されない限り移行しない。
- 本番プロジェクト作成時は東京リージョン `ap-northeast-1` を優先候補とし、作成前に費用を確認する。


## 本番切替の現況（2026-10-09）

本番Supabaseプロジェクト `npirfaoxcarfuqjlwgav`（東京リージョン）は作成済み。クリーンスキーマ25テーブル、RLS 24ポリシー、マスターデータ13テーブル10,320件を反映し、旧 `public.seichi` は存在しない。場所の地理座標、イベント/コンテンツの関連整合性、重複レジストリ、テストプロジェクトURL残存、ユーザー個人データ混入を確認し、いずれも問題なし。production `delete-account` Edge Function v2はJWT検証とPOST/OPTIONSのCORS preflightを有効にしてデプロイ済み。

2026-10-10時点の実行結果：ガード付きスクリプトで旧75件のmigration履歴を登録し、続けてレビュー済みの新規5件を本番へ適用済み。 `supabase migration list --linked` で80件すべてのLocal/Remote一致を確認した。主要マスターデータ件数とスポットの必須位置情報も再確認済み。

残る本番リリース前ゲートは次のとおり。
- Auth匿名サインイン：Supabase Dashboardで実設定を確認する。ローカルの `config.toml` だけでは本番設定の証明にならない。
- Storage：本番バケット・オブジェクトは現在0件。必要なバケット/ポリシーと素材の権利を別途確認する。上毛かるた公式画像の許諾は未確認。
- メンテナンス用Edge Functions：本番にあるのは `delete-account` v2（`verify_jwt=true`）のみ。道の駅/GPS用関数はV2 secret設定とテストを完了し、別途承認されるまで本番へデプロイしない。
- アカウント削除：使い捨てテストアカウントで認証・削除カスケードを実機確認する。
- `app_release_policies`：現在0件は初回本番リリース前の意図した状態。実際に公開するビルド番号/バージョンと公開ストアURLを確定してから登録し、クローズドテストの値を流用しない。
- 本番アプリ：本番URLとpublishable keyでビルドし、実機スモークテスト後にPlay Consoleのトラックとアップロード済みAABを別途確認する。DB移行によって本番アプリを公開したわけではない。
