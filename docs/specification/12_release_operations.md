# リリース・運用仕様

## Android
applicationId `jp.seichiquest.app`。Releaseはupload keystoreで署名する。秘密鍵・password・key.propertiesはGitへ入れない。

## Version
Flutter `pubspec.yaml` のversionName/versionCodeを使用する。versionCodeはGoogle Playへ一度投入した値を再利用しない。

Google Play Test Release workflowは、Play上の既存versionCode最大値を取得し、アップロード対象がそれ以下の場合はtrack更新・commit前に停止する。このガードをversionCode管理の補助として使い、番号自体はリリース準備時に明示的に更新する。

## 2026-10-08 現行状態
- main HEAD: `8d1badbd75a489b8b03d478270f85f3dd21dbccb`
- ソース version: `1.0.0+17`
- Version 16はGoogle Play Alphaへ配信済みで、Rewarded Story PreviewのUIが出ない事象を確認した。
- Version 16のGitHub Actions build logでは `STORY_REWARDED_AD_UNIT_ID` が空だったため、Release AABへRewarded ad unit IDが注入されていなかった。これがボタン非表示の直接原因。
- Version 17ではworkflowを修正し、GitHub variable/secretを優先し、未設定時は正しいAndroid Rewarded ad unit IDをフォールバックとして使用する。また空値の場合はbuildを失敗させる。
- Version 17はリリース準備済みだが、現時点ではPlayへの配信完了を記録しない。帰宅後にworkflowを手動実行し、Alpha配信と実機スモークテストを行う。
- リリース元の正本は最新 `main`。
- Google Playへの公開・配信状態はPlay Console / Android Publisher APIを正本として確認する。GitHub上のversion値だけで公開済みとは判定しない。
- iOSは実機配布をまだ行わず、必要時のみCodemagicの `ios-unsigned-check` でunsigned buildを検証する。

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
5. Rewarded Story Preview用Android ad unit IDを `--dart-define` へ注入し、空値ならbuildを停止する。
6. AAB artifactを7日間保存する。
7. Workload Identity FederationでGoogle Cloudへ認証する。JSON service-account keyは使用しない。
8. Android Publisher APIへ一時editとしてAABをuploadする。
9. Play上の最大versionCodeより新しいことを確認する。
10. alpha / beta / internal の指定test trackだけを更新し、validate後にcommitする。

production trackはこのworkflowから選択できず、guardでも拒否する。

## 品質ゲート
少なくとも `flutter analyze` と `flutter test` を通し、GPS/獲得、不正対策、イベント切替、同期、主要画面、クラスタ、regional progress、NEXT/ソナー、天候/太陽表現、広告禁止ゾーン、更新Policy、Rewarded Story Previewを確認してから配布する。

Release広告は本番AdMob IDを使用するため、実機検証ではAdMob側で登録したテスト端末を使う。

## Git
リリースタグは不変。機能開発はブランチ→PR→mainを基本とする。仕様変更を伴う場合は `docs/specification` も同PRで更新する。main統合前に本番DBの未回収migration/Function driftを確認する。

## Google Play
AAB作成、Playへのupload、track更新、edit commitは別の事実として扱う。workflowのbuild成功だけで「公開済み」と記録しない。

現在の自動release権限はtest trackに限定する。production release、Play App Signing変更、管理者権限などは自動化用service accountへ付与しない。

## クローズドテスト更新手順
1. 提出対象commit/refを固定する。
2. `pubspec.yaml` のversionCodeを前回Play投入値より大きくする。
3. Google Play Test Release workflowを手動起動する。通常は `main` を使う。
4. workflow内でanalyze/test/build/signing/versionCode/Rewarded ad unit guardを通す。
5. test trackへのcommit成功をログで確認する。
6. 登録済みテスト端末で主要導線をスモークテストする。Rewarded Adは実際にボタン表示、広告表示、報酬、1時間期限を確認する。
7. commit、versionName、versionCode、提出日時、track、Play状態を記録する。
8. `app_release_policies` は実配布状態と矛盾しないタイミングで更新する。

## iOS
iOS実機配布・TestFlightはApple Developer Program導入後に行う。それまではCodemagic unsigned checkでコンパイル互換性を確認する。

Codemagicの `ios-unsigned-check` は必要時のみ起動する。unsigned checkではGoogle公式AdMob test App IDを使い、Google Maps API keyは空値でコンパイル確認する。
