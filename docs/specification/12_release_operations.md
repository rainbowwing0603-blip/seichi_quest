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

## 2026-09-27時点の履歴スナップショット（現行状態ではない）
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

## Git / ブランチ運用
- リリース検証の正本は `feature/android-next-release`。本番ビルドworkflowもこのブランチ以外からの実行を拒否する。
- 2026-10-11のGitHub比較では `main` とリリースブランチが分岐し、リリースブランチは85コミット先行・111コミット遅れ。これは単純なfast-forwardではなく、機能・設定・履歴を含む統合作業が必要な状態。
- **分岐解消までは `main` をリリースブランチへ一括マージせず、リリースブランチを勝手に切り替えない。** `main` への統合は、変更ファイル・ワークフロー・DB migration・アセットを比較し、段階的な専用PRとCIで行う。
- リリースタグは不変。機能開発はブランチ→PR→レビュー。仕様変更を伴う場合は `docs/specification` も同じPRで更新する。main統合前に本番DBの未回収migration/Function driftを確認する。

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
- Storage：本番バケット・オブジェクトは現在0件。必要なバケット/ポリシーと素材の権利を別途確認する。上毛かるた画像の使用許諾は2026-10-08に取得済み。素材の登録・公開状態は別途確認する。
- メンテナンス用Edge Functions：本番にあるのは `delete-account` v2（`verify_jwt=true`）のみ。道の駅/GPS用関数はV2 secret設定とテストを完了し、別途承認されるまで本番へデプロイしない。
- アカウント削除：使い捨てテストアカウントで認証・削除カスケードを実機確認する。
- `app_release_policies`：現在0件は初回本番リリース前の意図した状態。実際に公開するビルド番号/バージョンと公開ストアURLを確定してから登録し、クローズドテストの値を流用しない。
- 本番アプリ：本番URLとpublishable keyでビルドし、実機スモークテスト後にPlay Consoleのトラックとアップロード済みAABを別途確認する。DB移行によって本番アプリを公開したわけではない。


## 2026-10-11 本番AABワークフローのキー疎通チェック

- 本番Android成果物ワークフローは、GitHub Environment `production` から `SUPABASE_PUBLISHABLE_KEY` を受け取り、本番プロジェクト `npirfaoxcarfuqjlwgav` に対する接続先確認を行う。
- PostgREST の `/rest/v1/` ルートを単純に呼び出す確認方法は、本番ビルド前のキー検証として不適切なため、Auth の公開設定エンドポイント `/auth/v1/settings` による疎通確認を使用する。
- 本チェックの失敗時に認証確認を無効化してビルドを続行しない。環境URL、publishable key、応答ステータスを切り分け、認証検証が成功してからAAB生成を許可する。
- このワークフローはAABとSHA-256を成果物として保存するのみで、Google Playへのアップロードや公開を実行しない。

## 2026-10-11 現在の本番準備状況

- Production Supabase migration履歴は94件、`feature/android-next-release` のSQL migrationファイルも94件。2026-10-11のversion-set比較では、source-only / production-only version IDは0件。今後の本番migration push前にも `supabase migration list --linked` を実行し、件数だけでなくversion IDの差分がゼロであることを確認する。
- `.github/workflows/production-android-build.yml` は署名付き本番AABを成果物として作るだけで、Playへのアップロード・公開や `app_release_policies` の更新は行わない。
- 1時間の物語プレビュー解放はクライアント実装が存在する（`story_rewarded_ad_service.dart`, `story_preview_unlock_service.dart`, `story_preview_section.dart`）。解放期限の判定にはSupabaseサーバー時刻を使う。コード/単体テストの存在は、実機での広告視聴・失敗時の挙動・再起動後の解放状態まで含むE2E合格を意味しない。
- リリース前に残る実地確認は、本番のGitHub Environment設定と署名鍵、Maps/AdMobの本番値、Play Consoleの未使用versionCode、本番Auth匿名サインイン、10月8日に使用許諾を取得した上毛かるた画像の素材・公開状態の最終確認、アカウント削除、スタンプ獲得・物語広告解放の実機E2E。これらはGitHubソースだけから成功と断定しない。
