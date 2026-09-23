# お知らせ仕様

## 目的
新イベント開始、イベント終了間近、アップデート、メンテナンス等をアプリ内で伝える。Push通知のON/OFFに依存せず、後から読み返せる正本を持つ。

## 起動時表示
オンボーディング完了後かつ通常画面が成立した後に、現在時刻で公開対象の「未読かつ起動時ポップアップ対象」を取得する。未読が複数でもダイアログを連続表示せず、1つのモーダル内で 1/N として切り替える。

閉じる時点で今回表示した項目を既読化する。詳しく見る場合は詳細を表示し、event_idがある項目は関連イベントへの導線を提供する。お知らせ表示直後にInterstitial広告を連続表示しない。

## 後から読む
MyPageに「お知らせ」入口を置き、公開期間内のお知らせ一覧を表示する。未読がある場合はバッジを表示する。一覧から詳細を開いた項目も既読化する。

## データモデル案
announcements:
- id uuid PK
- title text
- body text
- category text: event_start / event_ending / update / maintenance / campaign / general
- priority int
- event_id uuid nullable FK events
- publish_from timestamptz
- publish_until timestamptz nullable
- show_on_startup boolean
- is_active boolean
- created_at / updated_at

announcement_reads:
- user_id uuid
- announcement_id uuid
- read_at timestamptz
- PK(user_id, announcement_id)

公開対象は is_active=true、publish_from<=now()、publish_untilがNULLまたはnow()<publish_until。RLSでは公開対象のannouncementをauthenticatedがread可能とし、announcement_readsは本人行のみselect/insert/update可能とする。クライアントからannouncement本文を作成・変更できない。

## イベント終了間近
第一段階ではannouncementを明示登録する。将来、events.end_atから「終了7日前」等を自動生成/表示する場合も、同一Announcementモデルへ集約し、別UIを増やさない。

## 管理
アプリ更新なしで投稿できることを目標とする。管理画面対応前でもDB管理で運用可能にするが、一般ユーザーへ書込権限を与えない。

## Push通知との関係
アプリ内お知らせを正本とし、Push/ローカル通知は配送手段として分離する。通知拒否ユーザーもMyPageから確認できる。
