-- =====================================================================
-- Juliette 30 ans : anecdotes, missions secrètes, notifications
-- À coller UNE SEULE FOIS dans Supabase > SQL Editor > New query > Run.
-- Relançable sans danger (les tables existantes sont conservées).
-- =====================================================================

-- 1) Réglages (invisibles pour les invités : aucune règle de lecture publique)
create table if not exists public.j30_config(k text primary key, v text not null);
alter table public.j30_config enable row level security;
insert into public.j30_config(k,v) values
 ('anecdotes_open','2026-12-20T16:00:00+01:00'),
 ('anecdotes_close','2026-12-26T00:00:00+01:00'),
 ('missions_reveal','2026-12-21T20:00:00+01:00'),
 ('send_key','c3c0e571256fc6adbee0ff3f21dd5951')
on conflict (k) do nothing;

create or replace function public.j30_cfg(p_k text) returns text
language sql stable security definer set search_path=public as $$ select v from public.j30_config where k=p_k $$;
revoke all on function public.j30_cfg(text) from public, anon;

-- Seules les dates d'ouverture sont lisibles publiquement (jamais la clé d'envoi)
create or replace function public.j30_when(p_k text) returns timestamptz
language sql stable security definer set search_path=public as $$
 select case when p_k in ('anecdotes_open','anecdotes_close','missions_reveal') then public.j30_cfg(p_k)::timestamptz end $$;
grant execute on function public.j30_when(text) to anon;

-- 2) Anecdotes en quad (mur partagé, ouvert dimanche 20 décembre à 16 h)
create table if not exists public.anecdotes(
 id uuid primary key default gen_random_uuid(),
 created_at timestamptz not null default now(),
 auteur text not null default '',
 titre text not null default '',
 texte text not null,
 emo jsonb not null default '{}'::jsonb);
alter table public.anecdotes enable row level security;
drop policy if exists anec_select on public.anecdotes;
drop policy if exists anec_insert on public.anecdotes;
create policy anec_select on public.anecdotes for select to anon
 using (now() >= public.j30_when('anecdotes_open'));
create policy anec_insert on public.anecdotes for insert to anon
 with check (now() >= public.j30_when('anecdotes_open')
  and now() < public.j30_when('anecdotes_close')
  and char_length(texte) between 10 and 1200 and char_length(titre) <= 80 and char_length(auteur) <= 40
  and emo = '{}'::jsonb);
grant select, insert on public.anecdotes to anon;

create or replace function public.anecdote_react(p_id uuid, p_emo text) returns jsonb
language plpgsql security definer set search_path=public as $$
declare r jsonb;
begin
 if now() < public.j30_cfg('anecdotes_open')::timestamptz then return null; end if;
 if p_emo not in ('😂','❤️','👏','🤯') then return null; end if;
 update public.anecdotes
   set emo = jsonb_set(emo, array[p_emo], to_jsonb(coalesce((emo->>p_emo)::int,0)+1))
   where id = p_id returning emo into r;
 return r;
end $$;
grant execute on function public.anecdote_react(uuid,text) to anon;

-- 3) Missions secrètes : tables sans AUCUN accès public, lecture uniquement par code personnel
create table if not exists public.j30_missions(id int primary key, titre text not null, consigne text not null, indice text not null default '');
create table if not exists public.j30_assign(
 code text primary key, guest text unique not null,
 mission_id int not null references public.j30_missions(id),
 statut text not null default 'todo' check (statut in ('todo','done','help')),
 maj timestamptz);
alter table public.j30_missions enable row level security;
alter table public.j30_assign enable row level security;

insert into public.j30_missions(id,titre,consigne,indice) values
(1,'Le comique du repas','Pendant un même repas, fais rire au moins trois personnes différentes, sans te moquer de qui que ce soit.','Une anecdote vraie, à peine exagérée, fait presque toujours son effet.'),
(2,'La pose synchronisée','Obtiens une photo de groupe où tout le monde fait spontanément la même pose, sans avoir expliqué pourquoi.','Lance la pose toi-même et laisse les autres t''imiter.'),
(3,'Le mot improbable','Fais deviner à quelqu''un un mot improbable que tu auras choisi (cornichon, trampoline, pantoufle…) au fil d''une conversation naturelle, sans jamais le prononcer.','Parle de ce que fait l''objet, de où on le trouve, de qui l''utilise.'),
(4,'Les trois expressions','Place dans de vraies conversations les trois expressions suivantes : « c''est du gâteau », « ça roule ma poule », « on n''est pas sorti de l''auberge ».','Attends que le contexte s''y prête, la magie vient du naturel.'),
(5,'Le duo inédit','Fais prendre une photo souvenir à deux personnes qui ne figurent pas encore ensemble sur une photo du voyage.','Propose la photo comme une surprise, avec leur accord.'),
(6,'Le talent caché','Fais découvrir au groupe ton talent caché ou ta spécialité : une imitation, un petit tour, une chanson, une anecdote improbable…','Choisis un moment calme, après un repas par exemple.'),
(7,'Le toast collectif','Fais participer tout le monde à un toast original (une phrase à compléter à tour de rôle, un mot imposé, une rime…).','Prépare ta première phrase à l''avance pour lancer la chaîne.'),
(8,'Le compliment sincère','Obtiens un compliment sincère d''une autre personne du groupe, sans le demander directement.','Mets quelqu''un à l''honneur, les compliments reviennent souvent.'),
(9,'La pose collective','Convaincs le groupe de réaliser une pose collective originale pour une photo (statue, vague, pyramide basse…).','Propose un thème précis plutôt que « faisons quelque chose de drôle ».'),
(10,'Le fou rire discret','Fais rire quelqu''un au moment le plus inattendu, sans interrompre une activité et sans déranger les autres.','Un regard complice suffit parfois.'),
(11,'L''historien du voyage','Fais raconter à trois personnes différentes leur souvenir de voyage préféré, en posant les bonnes questions.','Demande « et après ? » et « qu''est-ce qui t''a le plus surpris ? ».'),
(12,'Le DJ d''un soir','Récolte une chanson choisie par chacun pour la playlist du séjour et retiens-les toutes.','Demande « la chanson qui te rend heureux(se) », pas la plus sérieuse.'),
(13,'Le portraitiste','Réalise, avec leur accord, un portrait amusant de trois personnes différentes.','Cherche la lumière et laisse-les choisir leur expression.'),
(14,'Le maître du suspense','Raconte une anecdote en t''arrêtant au meilleur moment, jusqu''à ce que le groupe te supplie de continuer.','Respire, boive une gorgée de thé, regarde autour de toi.'),
(15,'L''ambassadeur','Fais dire « choukran » (merci) par trois personnes différentes, au bon moment, à des personnes qu''elles remercient vraiment.','Montre l''exemple lors d''un service rendu.'),
(16,'Le faiseur de surnoms','Invente, avec leur accord, un surnom affectueux pour trois personnes du groupe et fais-le adopter pendant le séjour.','Pars d''une anecdote partagée ou d''une qualité.')
on conflict (id) do update set titre=excluded.titre, consigne=excluded.consigne, indice=excluded.indice;

-- Attribution : une mission différente par personne, un code personnel par personne.
-- Ne relance PAS cette partie après le départ : elle ne touche pas aux attributions déjà faites.
insert into public.j30_assign(code,guest,mission_id) values
('J6K9VU','Juliette',7),
('XRCZUX','Quentin',8),
('BVFKYM','Adèle',11),
('QWG6FB','Justine',16),
('H2MTG6','Matéo',5),
('7QM6FJ','Pierre',10),
('BJAC9G','Kevin',4),
('6RZZC7','Bastien',2),
('GSMAZQ','Romain',12),
('KYG4G6','Julie',14),
('TPB4X6','Laurine',6),
('28K57V','Anthony',3)
on conflict (guest) do nothing;

create or replace function public.mission_ouvrir(p_code text) returns json
language sql security definer set search_path=public as $$
 select json_build_object('guest',a.guest,'titre',m.titre,'consigne',m.consigne,'indice',m.indice,'statut',a.statut)
 from public.j30_assign a join public.j30_missions m on m.id=a.mission_id
 where a.code=upper(btrim(p_code)) $$;

create or replace function public.mission_statut(p_code text, p_statut text) returns text
language plpgsql security definer set search_path=public as $$
declare s text;
begin
 if p_statut not in ('todo','done','help') then return null; end if;
 update public.j30_assign set statut=p_statut, maj=now() where code=upper(btrim(p_code)) returning statut into s;
 return s;
end $$;

create or replace function public.mission_revelation() returns json
language plpgsql security definer set search_path=public as $$
declare t timestamptz := public.j30_cfg('missions_reveal')::timestamptz;
begin
 if now() < t then return json_build_object('open',false,'at',t); end if;
 return json_build_object('open',true,'at',t,'liste',
  (select coalesce(json_agg(json_build_object('guest',a.guest,'titre',m.titre,'consigne',m.consigne,'statut',a.statut) order by m.id),'[]'::json)
   from public.j30_assign a join public.j30_missions m on m.id=a.mission_id));
end $$;
grant execute on function public.mission_ouvrir(text), public.mission_statut(text,text), public.mission_revelation() to anon;

-- 4) Notifications : abonnements des téléphones et journal des envois
create table if not exists public.j30_subs(endpoint text primary key, p256dh text not null, auth text not null, guest text not null default '', maj timestamptz not null default now());
create table if not exists public.j30_pushlog(slot text primary key, sent_at timestamptz not null default now());
alter table public.j30_subs enable row level security;
alter table public.j30_pushlog enable row level security;

create or replace function public.push_save(p_endpoint text, p_p256dh text, p_auth text, p_guest text) returns boolean
language plpgsql security definer set search_path=public as $$
begin
 if p_endpoint !~ '^https://' or char_length(p_endpoint) > 1000 or char_length(p_guest) > 40 then return false; end if;
 insert into public.j30_subs(endpoint,p256dh,auth,guest) values (p_endpoint,p_p256dh,p_auth,p_guest)
 on conflict (endpoint) do update set p256dh=excluded.p256dh, auth=excluded.auth, guest=excluded.guest, maj=now();
 return true;
end $$;
create or replace function public.push_remove(p_endpoint text) returns void
language sql security definer set search_path=public as $$ delete from public.j30_subs where endpoint=p_endpoint $$;
grant execute on function public.push_save(text,text,text,text), public.push_remove(text) to anon;

-- Réservé au script d'envoi (protégé par la clé d'envoi)
create or replace function public.push_state(p_key text) returns json
language plpgsql security definer set search_path=public as $$
begin
 if p_key is distinct from public.j30_cfg('send_key') then return null; end if;
 return json_build_object(
  'subs',(select coalesce(json_agg(json_build_object('endpoint',endpoint,'p256dh',p256dh,'auth',auth,'guest',guest)),'[]'::json) from public.j30_subs),
  'sent',(select coalesce(json_agg(slot),'[]'::json) from public.j30_pushlog),
  'codes',(select coalesce(json_object_agg(guest,code),'{}'::json) from public.j30_assign));
end $$;
create or replace function public.push_mark(p_key text, p_slot text) returns boolean
language plpgsql security definer set search_path=public as $$
begin
 if p_key is distinct from public.j30_cfg('send_key') then return false; end if;
 insert into public.j30_pushlog(slot) values (p_slot) on conflict do nothing; return true;
end $$;
create or replace function public.push_drop(p_key text, p_endpoint text) returns boolean
language plpgsql security definer set search_path=public as $$
begin
 if p_key is distinct from public.j30_cfg('send_key') then return false; end if;
 delete from public.j30_subs where endpoint=p_endpoint; return true;
end $$;
grant execute on function public.push_state(text), public.push_mark(text,text), public.push_drop(text,text) to anon;
