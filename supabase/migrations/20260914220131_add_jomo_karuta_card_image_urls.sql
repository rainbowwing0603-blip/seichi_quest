-- ============================================================
-- 上毛かるた×群馬
-- 44札の画像URL設定
--
-- 注意:
-- このmigrationは、event-card-images/jomo-karuta/ に
-- 01_a.png ～ 44_wa.png が配置された後に適用する。
-- ============================================================

with image_map (
  card,
  file_name
) as (
  values
    ('あ', '01_a.png'),
    ('い', '02_i.png'),
    ('う', '03_u.png'),
    ('え', '04_e.png'),
    ('お', '05_o.png'),
    ('か', '06_ka.png'),
    ('き', '07_ki.png'),
    ('く', '08_ku.png'),
    ('け', '09_ke.png'),
    ('こ', '10_ko.png'),
    ('さ', '11_sa.png'),
    ('し', '12_shi.png'),
    ('す', '13_su.png'),
    ('せ', '14_se.png'),
    ('そ', '15_so.png'),
    ('た', '16_ta.png'),
    ('ち', '17_chi.png'),
    ('つ', '18_tsu.png'),
    ('て', '19_te.png'),
    ('と', '20_to.png'),
    ('な', '21_na.png'),
    ('に', '22_ni.png'),
    ('ぬ', '23_nu.png'),
    ('ね', '24_ne.png'),
    ('の', '25_no.png'),
    ('は', '26_ha.png'),
    ('ひ', '27_hi.png'),
    ('ふ', '28_fu.png'),
    ('へ', '29_he.png'),
    ('ほ', '30_ho.png'),
    ('ま', '31_ma.png'),
    ('み', '32_mi.png'),
    ('む', '33_mu.png'),
    ('め', '34_me.png'),
    ('も', '35_mo.png'),
    ('や', '36_ya.png'),
    ('ゆ', '37_yu.png'),
    ('よ', '38_yo.png'),
    ('ら', '39_ra.png'),
    ('り', '40_ri.png'),
    ('る', '41_ru.png'),
    ('れ', '42_re.png'),
    ('ろ', '43_ro.png'),
    ('わ', '44_wa.png')
)
update public.seichi as s
set card_image_url =
  'https://wxlvhpmolrtcwryaazfb.supabase.co/storage/v1/object/public/event-card-images/jomo-karuta/'
  || image_map.file_name
from image_map,
     public.events as e
where e.id = s.event_id
  and e.slug = 'jomo-karuta-gunma'
  and s.card = image_map.card;