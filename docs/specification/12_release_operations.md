# リリース・運用仕様

## Android
applicationId `jp.seichiquest.app`。targetSdkは36を明示。Java/Kotlin targetは17。Releaseはupload keystoreで署名する。

## Version
Flutter `pubspec.yaml` のversionName/versionCodeを使用。versionCodeはPlayへ一度投入した値を再利用しない。

## 現行基準
`v1.0.0+8` はリリース用コミット `e596314a5afff26c124c1a5317a000da56ad6a0f` を指す。後続でmainへ統合されたため、タグをmain先端へ移動しない。


## 次回クローズドテスト候補
`1.0.0+10` は既に公開済みのため再利用しない。現在のリリース候補は `1.0.0+11`。Play提出時もversionCode 11以上であることを確認する。

## Build
Release AABは `flutter build appbundle --release` を基本とする。署名設定とGoogle Maps API keyは `android/key.properties` から読む。

## 品質ゲート
少なくとも `flutter analyze` と `flutter test` を通し、GPS/獲得、イベント切替、同期、主要画面を確認してから配布する。

## Git
リリースタグは不変。機能開発はブランチ→PR→main。仕様変更を伴う場合は `docs/specification` も同PRで更新する。

## Play Console
AAB作成とPlay Consoleへのアップロードは別事実として記録する。ローカルビルド成功だけで「公開済み」「アップロード済み」と記録しない。

## クローズドテスト更新時の手順
1. PRの自動確認（`flutter analyze` / `flutter test` / 仮鍵でのRelease AABビルド）を確認し、実機でGPS獲得・同期・イベント切替・地図操作を試す。天気・季節・時間帯の表示、アニメーションを減らす設定、発熱と操作時の重さも確認する。
2. Play Consoleで既に投入した最大の`versionCode`を確認し、それより大きい番号に`pubspec.yaml`の`version: 名前+番号`を更新する。同じ番号のAABを再投入しない。
3. PCの`android/key.properties`とupload keystoreが実際の提出用設定であることを確認する。これらの秘密情報はGitへ追加しない。
4. mainへ統合した提出対象のコミットで`flutter pub get`、`flutter analyze`、`flutter test`、`flutter build appbundle --release`を実行する。AABは`build/app/outputs/bundle/release/app-release.aab`。
5. Play Consoleの同じクローズドテスト枠へAABを登録し、リリースノートを入力して審査・配信状態を確認する。提出後はコミット、versionName、versionCode、提出日時とPlay Console上の状態を記録する。

CIで生成するAABは仮の署名鍵と仮のGoogle Maps API keyを使用した**ビルド確認専用**であり、Play Consoleへの提出や実機動作確認には使わない。
