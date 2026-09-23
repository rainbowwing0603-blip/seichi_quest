-- 聖地クエスト
-- profiles の表示名基盤を整備する。
--
-- 表示名仕様:
-- ・1〜30文字
-- ・前後空白を除去して判定
-- ・空白だけは禁止
-- ・大文字小文字を区別せず重複禁止
--
-- 既存の profiles RLS は維持する。

alter table public.profiles
  add constraint profiles_display_name_length_check
  check (
    display_name is null
    or (
      char_length(btrim(display_name)) between 1 and 30
      and display_name = btrim(display_name)
    )
  );

create unique index profiles_display_name_unique_idx
  on public.profiles (lower(display_name))
  where display_name is not null;

comment on column public.profiles.display_name is
  '公開表示名。1〜30文字、前後空白禁止、大文字小文字を区別せず一意。';