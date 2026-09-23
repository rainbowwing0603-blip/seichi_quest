# リリース・運用仕様

## Android
applicationId `jp.seichiquest.app`。targetSdkは36を明示。Java/Kotlin targetは17。Releaseはupload keystoreで署名する。

## Version
Flutter `pubspec.yaml` のversionName/versionCodeを使用。versionCodeはPlayへ一度投入した値を再利用しない。

## 現行基準
`v1.0.0+8` はリリース用コミット `e596314a5afff26c124c1a5317a000da56ad6a0f` を指す。後続でmainへ統合されたため、タグをmain先端へ移動しない。

## Build
Release AABは `flutter build appbundle --release` を基本とする。署名設定とGoogle Maps API keyは `android/key.properties` から読む。

## 品質ゲート
少なくとも `flutter analyze` と `flutter test` を通し、GPS/獲得、イベント切替、同期、主要画面を確認してから配布する。

## Git
リリースタグは不変。機能開発はブランチ→PR→main。仕様変更を伴う場合は `docs/specification` も同PRで更新する。

## Play Console
AAB作成とPlay Consoleへのアップロードは別事実として記録する。ローカルビルド成功だけで「公開済み」「アップロード済み」と記録しない。
