# リリース・運用仕様

## Android
applicationId `jp.seichiquest.app`。Releaseはupload keystoreで署名する。秘密鍵・password・key.propertiesはGitへ入れない。

## Version
Flutter `pubspec.yaml` のversionName/versionCodeを使用する。versionCodeはGoogle Playへ一度投入した値を再利用しない。

Google Play Test Release workflowは、Play上の既存versionCode最大値を取得し、アップロード対象がそれ以下の場合はtrack更新・commit前に停止する。このガードをversionCode管理の補助として使い、番号自体はリリース準備時に明示的に更新する。

## 2026-10-03 現行状態
- Google Play クローズドテスト Alpha: `1.0.0+14`（versionCode 14）を2026-10-03にAPI経由でcommit済み、status=`completed`。
- 次回Android提出候補: `1.0.0+15`。versionCode 14以下は再利用しない。
- リリース元の正本は最新 `main` とし、Google Play Test Release workflowの既定checkoutも `main` とする。
- 旧 `feature/android-next-release` / PR #17 は、mainから分岐後にCI・Play自動化がmain側で進んだためリリース元として使用しない。
- Google Playへの公開・配信状態はPlay Console / Android Publisher APIを正本として確認する。GitHub上のversion値だけで公開済みとは判定しない。
- iOSは実機配布をまだ行わず、必要時のみCodemagicの `ios-unsigned-check` をAPI起動してunsigned buildを検証する。自動起動で無料枠を消費しない。

## App update policy
`AppVersionService` は `app_release_policies` からplatform別のlatest/minimum buildを読み、更新有無と必須更新を判定する。バックエンド障害時はfail-openとし、一時障害でアプリをロックしない。

Supabaseのrelease policyは実際の配布状態と一致させる。Playへ投入しただけのbuildを、利用者へ配信済みであるかのように先行更新しない。

## Build
Release AABは `flutter build appbundle --release` を基本とする。提出用AABは実際のupload keystoreと本番設定で作る。

GitHub Actionsの `Google Play Test Release` は以下を一連で行う。
1. test track以外を拒否する。
2. 指定refをcheckoutする。既定は `main`。
3. GitHub Secretsからrelease signingを復元する。
4. `flutter pub get`、`flutter analyze`、`flutter test`、Release AAB buildを実行する。
5. AAB artifactを7日間保存する。
6. Workload Identity FederationでGoogle Cloudへ認証する。JSON service-account keyは使用しない。
7. Android Publisher APIへ一時editとしてAABをuploadする。
8. Play上の最大versionCodeより新しいことを確認する。
9. alpha / beta / internal の指定test trackだけを更新し、validate後にcommitする。

production trackはこのworkflowから選択できず、guardでも拒否する。

## 品質ゲート
少なくとも `flutter analyze` と `flutter test` を通し、GPS/獲得、不正対策、イベント切替、同期、主要画面、クラスタ、regional progress、NEXT/ソナー、天候/太陽表現、広告禁止ゾーン、更新Policyを確認してから配布する。

広告はDebug/ProfileでGoogle公式test IDを使用する。Releaseは本番AdMob IDを使用するため、実機検証ではAdMob側で登録したテスト端末を使い、広告にテスト表示が確認できるまで本番広告を操作しない。

## Git
リリースタグは不変。機能開発はブランチ→PR→mainを基本とする。仕様変更を伴う場合は `docs/specification` も同PRで更新する。main統合前に本番DBの未回収migration/Function driftを確認する。

古いrelease branchを長期間リリース元として固定しない。mainから大きくbehindした場合は、古いPRを無理にmergeせず最新mainから新しいrelease preparation branchを切り直す。

## Google Play
AAB作成、Playへのupload、track更新、edit commitは別の事実として扱う。workflowのbuild成功だけで「公開済み」と記録しない。

現在の自動release権限はtest trackに限定する。production release、Play App Signing変更、管理者権限などは自動化用service accountへ付与しない。

## クローズドテスト更新手順
1. 提出対象commit/refを固定する。
2. `pubspec.yaml` のversionCodeを前回Play投入値より大きくする。
3. Google Play Test Release workflowを手動起動する。通常は既定の `main` を使う。
4. workflow内でanalyze/test/build/signing/versionCode guardを通す。
5. test trackへのcommit成功をログで確認する。
6. P710など登録済みテスト端末で主要導線をスモークテストする。エミュレータではGoogle公式test広告を使う。
7. commit、versionName、versionCode、提出日時、track、Play状態を記録する。
8. `app_release_policies` は実配布状態と矛盾しないタイミングで更新する。

## iOS
iOS実機配布・TestFlightはApple Developer Program導入後に行う。それまではCodemagic unsigned checkでコンパイル互換性を確認する。

Codemagicの `ios-unsigned-check` はAPIから必要時のみ起動する。通常のGit push / PRを理由に自動起動しない。unsigned checkではGoogle公式AdMob test App IDを使い、Google Maps API keyは空値でコンパイル確認する。
