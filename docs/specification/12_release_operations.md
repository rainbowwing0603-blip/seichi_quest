# リリース・運用仕様

## Android
applicationId `jp.seichiquest.app`。Releaseはupload keystoreで署名する。秘密鍵・password・key.propertiesはGitへ入れない。

## Version
Flutter `pubspec.yaml` のversionName/versionCodeを使用。versionCodeはPlayへ一度投入した値を再利用しない。

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
2. Play Consoleで投入済み最大versionCodeを確認し、それより大きい番号を設定。
3. `flutter pub get`、`flutter analyze`、`flutter test`、Release AAB build。
4. 実機/エミュレータで主要導線をスモークテスト。mock locationはdebugではテスト可能、release/profileでは拒否する。
5. Play ConsoleへAAB登録、リリースノート入力、審査/配信状態を確認。
6. commit、versionName、versionCode、AAB SHA-256、提出日時、Play状態をリリース記録へ残す。
7. Supabase `app_release_policies` のlatest/minimumを、実配布状態と矛盾しないタイミングで更新する。
