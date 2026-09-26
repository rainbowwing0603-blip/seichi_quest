alter table public.events add column item_label_singular text not null default 'スポット', add column item_label_plural text not null default 'スポット';
update public.events set item_label_singular='札', item_label_plural='札' where slug='jomo-karuta-gunma';
update public.events set item_label_singular='古墳', item_label_plural='古墳' where slug='kofun-kingdom-gunma';
update public.events set item_label_singular='道の駅', item_label_plural='道の駅' where slug='michinoeki-japan';;
