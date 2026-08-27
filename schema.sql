-- ============================================================
-- KayPam — Schéma de base de données (Supabase / PostgreSQL)
-- ============================================================
-- Comment utiliser ce fichier :
-- 1. Ouvrez votre projet sur https://supabase.com
-- 2. Allez dans "SQL Editor" (menu de gauche)
-- 3. Collez TOUT le contenu de ce fichier et cliquez "Run"
-- 4. Créez ensuite un bucket de stockage nommé "listing-media"
--    dans "Storage" (voir SETUP.md pour les détails)
-- 5. IMPORTANT : ajoutez votre compte admin existant dans la table
--    "admins" — zionmaket@gmail.com deja ajoute
-- ============================================================

create extension if not exists "pgcrypto";

-- ---------- TABLES DE BASE ----------

create table if not exists owners (
  id uuid primary key default gen_random_uuid(),
  auth_user_id uuid unique references auth.users(id) on delete cascade,
  username text,
  name text not null,
  phone text not null,
  whatsapp text,
  created_at timestamptz not null default now()
);

-- Ajoute les nouvelles colonnes si la table existait déjà (ancienne version
-- basée sur le téléphone seul, sans compte).
alter table owners add column if not exists auth_user_id uuid references auth.users(id) on delete cascade;
alter table owners add column if not exists username text;
alter table owners add column if not exists whatsapp text;

-- Numéro WhatsApp non renseigné pour d'anciens comptes : on retombe sur le
-- téléphone général en attendant que le propriétaire renseigne un numéro dédié.
update owners set whatsapp = phone where whatsapp is null;

-- Le téléphone n'a plus besoin d'être unique : c'est maintenant le username
-- (donc le compte) qui identifie un propriétaire de façon unique.
alter table owners drop constraint if exists owners_phone_key;

drop index if exists owners_username_unique_idx;
create unique index owners_username_unique_idx on owners (lower(username)) where username is not null;

drop index if exists owners_auth_user_id_unique_idx;
create unique index owners_auth_user_id_unique_idx on owners (auth_user_id) where auth_user_id is not null;

-- ID court et lisible par compte (ex. KP-00001), généré automatiquement,
-- pour distinguer facilement deux propriétaires portant le même nom.
create sequence if not exists owners_owner_number_seq;
alter table owners add column if not exists owner_number bigint;
alter table owners alter column owner_number set default nextval('owners_owner_number_seq');
update owners set owner_number = nextval('owners_owner_number_seq') where owner_number is null;
alter sequence owners_owner_number_seq owned by owners.owner_number;
drop index if exists owners_owner_number_unique_idx;
create unique index owners_owner_number_unique_idx on owners(owner_number);

create table if not exists listings (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references owners(id) on delete cascade,
  title text not null,
  city text not null,
  commune text,
  zone text,
  departement text,
  transaction text not null check (transaction in ('Vente','Location')),
  type text not null,
  price numeric not null check (price >= 0),
  currency text not null check (currency in ('USD','HTG')),
  period text check (period in ('mois','an') or period is null),
  description text,
  status text not null default 'en_attente_verification'
    check (status in ('en_attente_verification','valide','refuse')),
  available boolean not null default true,
  created_at timestamptz not null default now(),
  reviewed_at timestamptz
);

-- Ajoute les nouvelles colonnes si la table existait déjà
alter table listings add column if not exists available boolean not null default true;
alter table listings add column if not exists commune text;
alter table listings add column if not exists zone text;
alter table listings add column if not exists departement text;

-- Endèks pou rechèch rapid
create index if not exists idx_listings_available on listings(available);
create index if not exists idx_listings_status on listings(status);
create index if not exists idx_listings_city on listings(city);
create index if not exists idx_listings_commune on listings(commune);
create index if not exists idx_listings_zone on listings(zone);
create index if not exists idx_listings_departement on listings(departement);
create index if not exists idx_listings_location on listings(departement, city, commune, zone);

create table if not exists listing_media (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references listings(id) on delete cascade,
  media_type text not null check (media_type in ('photo','video')),
  url text not null,
  created_at timestamptz not null default now()
);

create index if not exists idx_listing_media_listing_id on listing_media(listing_id);

-- ---------- TABLE ADMINS ----------
-- Distingue "l'équipe KayPam qui vérifie les annonces" de "n'importe quel
-- propriétaire connecté". Sans cette table, un propriétaire connecté serait
-- traité comme "authenticated" au même titre qu'un admin, et verrait TOUTES
-- les annonces (y compris en attente) et tous les propriétaires — une faille
-- de sécurité importante. Un utilisateur ne peut PAS s'ajouter lui-même ici :
-- seul vous, depuis le Table Editor ou le SQL Editor de Supabase, le pouvez.
create table if not exists admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

alter table admins enable row level security;
drop policy if exists "admins_self_select" on admins;
create policy "admins_self_select" on admins
  for select to authenticated using (user_id = auth.uid());
-- Aucune policy insert/update/delete : seul le SQL Editor (avec vos propres
-- droits de propriétaire de projet) peut modifier cette table.

-- ---------- TABLE VISITS (STATISTIQUES DE VISITES) ----------
-- Table pour enregistrer toutes les visites du site
create table if not exists visits (
  id uuid primary key default gen_random_uuid(),
  visitor_id text,
  page text,
  referrer text,
  user_agent text,
  visited_at timestamptz default now()
);

-- Endèks pour les visites
create index if not exists idx_visits_visited_at on visits(visited_at);
create index if not exists idx_visits_visitor_id on visits(visitor_id);
create index if not exists idx_visits_page on visits(page);

-- ---------- SÉCURITÉ (Row Level Security) ----------

alter table owners enable row level security;
alter table listings enable row level security;
alter table listing_media enable row level security;
alter table visits enable row level security;

-- OWNERS : personne ne lit cette table directement, même pas un propriétaire
-- connecté qui consulte ses propres infos (il passe par des fonctions dédiées
-- ci-dessous), SAUF l'équipe admin (table admins) pour l'appel de courtoisie.
-- Exception volontaire et étroite : le nom/téléphone d'un propriétaire
-- redevient visible publiquement UNIQUEMENT s'il a au moins une annonce
-- validée et disponible — c'est ce qui permet le bouton WhatsApp sur les
-- fiches d'annonces publiques, sans exposer les propriétaires dont aucune
-- annonce n'est encore (ou plus) publique.
drop policy if exists "owners_public_select" on owners;
drop policy if exists "owners_public_insert" on owners;
drop policy if exists "owners_admin_select" on owners;
drop policy if exists "owners_public_select_for_live_listings" on owners;
create policy "owners_admin_select" on owners
  for select to authenticated
  using (exists (select 1 from admins a where a.user_id = auth.uid()));
create policy "owners_public_select_for_live_listings" on owners
  for select to anon, authenticated
  using (exists (
    select 1 from listings l
    where l.owner_id = owners.id and l.status = 'valide' and l.available = true
  ));

-- LISTINGS : le public ne voit QUE les annonces validées et disponibles.
-- L'équipe admin (présente dans la table admins) voit tout.
-- La création d'annonce passe uniquement par create_listing() ci-dessous.
drop policy if exists "listings_public_select_validated" on listings;
drop policy if exists "listings_admin_select_all" on listings;
drop policy if exists "listings_admin_update" on listings;
create policy "listings_public_select_validated" on listings
  for select to anon, authenticated using (status = 'valide' and available = true);
create policy "listings_admin_select_all" on listings
  for select to authenticated
  using (exists (select 1 from admins a where a.user_id = auth.uid()));
create policy "listings_admin_update" on listings
  for update to authenticated
  using (exists (select 1 from admins a where a.user_id = auth.uid()))
  with check (exists (select 1 from admins a where a.user_id = auth.uid()));

-- LISTING_MEDIA : lecture publique (nécessaire pour afficher les photos),
-- écriture réservée aux propriétaires connectés (ils ajoutent leurs photos/
-- vidéos juste après avoir créé leur annonce, dans la même session).
drop policy if exists "media_public_select" on listing_media;
drop policy if exists "media_public_insert" on listing_media;
create policy "media_public_select" on listing_media
  for select to anon, authenticated using (true);
-- Un propriétaire connecté ne peut attacher une photo/vidéo qu'à une annonce
-- qui lui appartient réellement (vérifié via owners.auth_user_id) — empêche
-- un compte de "vandaliser" l'annonce d'un autre propriétaire.
create policy "media_public_insert" on listing_media
  for insert to authenticated
  with check (
    exists (
      select 1 from listings l
      join owners o on o.id = l.owner_id
      where l.id = listing_media.listing_id
        and o.auth_user_id = auth.uid()
    )
  );

-- VISITS : tout le monde peut insérer (pour le tracking), seul l'admin peut lire
drop policy if exists "visits_insert" on visits;
drop policy if exists "visits_admin_select" on visits;
create policy "visits_insert" on visits
  for insert to anon, authenticated
  with check (true);
create policy "visits_admin_select" on visits
  for select to authenticated
  using (exists (select 1 from admins a where a.user_id = auth.uid()));

-- ---------- FONCTIONS DE BASE ----------

-- Crée le profil propriétaire lié au compte qui vient de s'inscrire
-- (auth.uid()). Le username est déjà garanti unique par Supabase Auth
-- (l'inscription utilise un email synthétique "username@kaypam.local" —
-- si le username existe déjà, l'inscription elle-même échoue avant d'arriver
-- ici). L'index unique sur owners.username est une deuxième sécurité.

-- Efase tout vèsyon ki egziste
drop function if exists public.link_owner_account();
drop function if exists public.link_owner_account(text);
drop function if exists public.link_owner_account(text, text);
drop function if exists public.link_owner_account(text, text, text);
drop function if exists public.link_owner_account(text, text, text, text);
drop function if exists public.link_owner_account(text, text, text, text, text);
drop function if exists public.link_owner_account(uuid);
drop function if exists public.link_owner_account(uuid, text);
drop function if exists public.link_owner_account(uuid, text, text);
drop function if exists public.link_owner_account(uuid, text, text, text);
drop function if exists public.link_owner_account(uuid, text, text, text, text);

-- Rekreye fonksyon an ak 4 paramèt
create or replace function public.link_owner_account(
  p_username text,
  p_name text,
  p_phone text,
  p_whatsapp text
) returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Vous devez être connecté pour créer un profil propriétaire';
  end if;

  insert into owners (auth_user_id, username, name, phone, whatsapp)
  values (auth.uid(), p_username, p_name, p_phone, coalesce(p_whatsapp, p_phone))
  returning id into v_id;

  return v_id;
end;
$$;

grant execute on function public.link_owner_account(text, text, text, text) to authenticated;

-- Retourne le profil propriétaire lié au compte actuellement connecté
-- (ou aucune ligne si l'inscription n'a jamais été finalisée), y compris
-- l'ID court lisible (ex. KP-00001) qui distingue deux propriétaires
-- portant le même nom.
drop function if exists public.get_my_owner_profile();
create or replace function public.get_my_owner_profile()
returns table(id uuid, username text, name text, phone text, whatsapp text, account_code text)
language sql
security definer
set search_path = public
as $$
  select id, username, name, phone, whatsapp,
    'KP-' || lpad(owner_number::text, 5, '0')
  from owners where auth_user_id = auth.uid();
$$;

grant execute on function public.get_my_owner_profile to authenticated;

-- Crée une annonce en statut "en_attente_verification" pour le propriétaire
-- actuellement connecté. L'owner_id n'est JAMAIS fourni par le client : il
-- est déduit du compte connecté (auth.uid()), ce qui empêche quiconque
-- d'attribuer une annonce à un autre propriétaire.
-- Cette fonction prend désormais en charge les champs commune, zone et departement.
drop function if exists public.create_listing(uuid, text, text, text, text, numeric, text, text, text);
drop function if exists public.create_listing(text, text, text, text, numeric, text, text, text);
drop function if exists public.create_listing(text, text, text, text, text, text, numeric, text, text, text);
create or replace function public.create_listing(
  p_title text,
  p_city text,
  p_commune text,
  p_zone text,
  p_departement text,
  p_transaction text,
  p_type text,
  p_price numeric,
  p_currency text,
  p_period text,
  p_description text
) returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_owner_id uuid;
  new_id uuid;
begin
  select id into v_owner_id from owners where auth_user_id = auth.uid();
  if v_owner_id is null then
    raise exception 'Aucun profil propriétaire trouvé pour ce compte. Terminez votre inscription.';
  end if;

  insert into listings (owner_id, title, city, commune, zone, departement, transaction, type, price, currency, period, description, status)
  values (v_owner_id, p_title, p_city, p_commune, p_zone, p_departement, p_transaction, p_type, p_price, p_currency, p_period, p_description, 'en_attente_verification')
  returning id into new_id;

  return new_id;
end;
$$;

grant execute on function public.create_listing to authenticated;

-- Retourne des compteurs globaux (propriétaires / annonces) sans exposer le détail
-- des annonces en attente à un visiteur non connecté.
create or replace function public.kaypam_stats()
returns json
language sql
security definer
set search_path = public
as $$
  select json_build_object(
    'owners', (select count(*) from owners),
    'listings', (select count(*) from listings)
  );
$$;

grant execute on function public.kaypam_stats to anon, authenticated;

-- ============================================================
-- STOCKAGE — à exécuter APRÈS avoir créé le bucket "listing-media"
-- dans l'onglet "Storage" de Supabase (cochez "Public bucket").
-- ============================================================

drop policy if exists "media_bucket_public_read" on storage.objects;
drop policy if exists "media_bucket_public_upload" on storage.objects;
create policy "media_bucket_public_read" on storage.objects
  for select to anon, authenticated using (bucket_id = 'listing-media');

create policy "media_bucket_public_upload" on storage.objects
  for insert to authenticated with check (bucket_id = 'listing-media');

-- ============================================================
-- SYSTÈME DE BOOST (mise en avant payante des annonces)
-- ============================================================

create table if not exists boost_plans (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  duration_days int not null check (duration_days > 0),
  price_usd numeric not null check (price_usd >= 0),
  active boolean not null default true,
  sort_order int not null default 0
);

create table if not exists boosts (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references listings(id) on delete cascade,
  plan_id uuid references boost_plans(id),
  plan_name text not null,
  duration_days int not null,
  price_usd numeric not null,
  payment_reference text,
  status text not null default 'en_attente_paiement'
    check (status in ('en_attente_paiement','actif','expire','refuse')),
  requested_at timestamptz not null default now(),
  activated_at timestamptz,
  starts_at timestamptz,
  ends_at timestamptz
);

create index if not exists idx_boosts_listing_id on boosts(listing_id);
create index if not exists idx_boosts_status on boosts(status);
create index if not exists idx_boosts_ends_at on boosts(ends_at);

alter table boost_plans enable row level security;
alter table boosts enable row level security;

-- BOOST_PLANS : lecture publique des formules actives ; l'admin gère tout
drop policy if exists "boost_plans_public_select" on boost_plans;
drop policy if exists "boost_plans_admin_write" on boost_plans;
create policy "boost_plans_public_select" on boost_plans
  for select to anon, authenticated using (active = true);
create policy "boost_plans_admin_write" on boost_plans
  for all to authenticated
  using (exists (select 1 from admins a where a.user_id = auth.uid()))
  with check (exists (select 1 from admins a where a.user_id = auth.uid()));

-- BOOSTS : le public ne voit QUE les boosts réellement actifs ET dans leur
-- fenêtre de temps en cours. C'est cette règle, à elle seule, qui fait que
-- les boosts expirés disparaissent automatiquement du roulement.
drop policy if exists "boosts_public_select_active" on boosts;
drop policy if exists "boosts_admin_select_all" on boosts;
drop policy if exists "boosts_admin_update" on boosts;
create policy "boosts_public_select_active" on boosts
  for select to anon, authenticated
  using (status = 'actif' and now() between starts_at and ends_at);
create policy "boosts_admin_select_all" on boosts
  for select to authenticated
  using (exists (select 1 from admins a where a.user_id = auth.uid()));
create policy "boosts_admin_update" on boosts
  for update to authenticated
  using (exists (select 1 from admins a where a.user_id = auth.uid()))
  with check (exists (select 1 from admins a where a.user_id = auth.uid()));

-- Le propriétaire connecté demande à booster une de SES annonces déjà
-- validée (vérifié via auth.uid(), pas via un numéro fourni par le client).
drop function if exists public.request_boost(uuid, text, uuid, text);
create or replace function public.request_boost(
  p_listing_id uuid,
  p_plan_id uuid,
  p_reference text
) returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_owner_auth_id uuid;
  v_plan boost_plans%rowtype;
  new_id uuid;
begin
  select o.auth_user_id into v_owner_auth_id
  from listings l join owners o on o.id = l.owner_id
  where l.id = p_listing_id and l.status = 'valide';

  if v_owner_auth_id is null then
    raise exception 'Annonce introuvable ou non encore validée';
  end if;

  if v_owner_auth_id <> auth.uid() then
    raise exception 'Cette annonce ne vous appartient pas';
  end if;

  if exists (
    select 1 from boosts
    where listing_id = p_listing_id
      and (status = 'en_attente_paiement' or (status = 'actif' and ends_at > now()))
  ) then
    raise exception 'Cette annonce a déjà un boost actif ou en attente de confirmation';
  end if;

  select * into v_plan from boost_plans where id = p_plan_id and active = true;
  if not found then
    raise exception 'Formule de boost introuvable';
  end if;

  insert into boosts (listing_id, plan_id, plan_name, duration_days, price_usd, payment_reference, status)
  values (p_listing_id, v_plan.id, v_plan.name, v_plan.duration_days, v_plan.price_usd, p_reference, 'en_attente_paiement')
  returning id into new_id;

  return new_id;
end;
$$;

grant execute on function public.request_boost to authenticated;

-- L'admin confirme un paiement MonCash reçu et active le boost pour sa durée.
create or replace function public.activate_boost(p_boost_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_duration int;
begin
  select duration_days into v_duration from boosts where id = p_boost_id;
  if v_duration is null then
    raise exception 'Boost introuvable';
  end if;
  update boosts
    set status = 'actif',
        starts_at = now(),
        ends_at = now() + (v_duration || ' days')::interval,
        activated_at = now()
  where id = p_boost_id;
end;
$$;

grant execute on function public.activate_boost to authenticated;

-- Retourne TOUTES les annonces du propriétaire connecté (auth.uid()), quel
-- que soit leur statut (en attente, validée, refusée), leur disponibilité,
-- et le statut de boost le plus récent de chacune. Le front-end décide
-- comment afficher chaque statut (le boost/retrait ne s'applique qu'aux
-- annonces validées).
-- Cette fonction retourne désormais également commune, zone et departement.
drop function if exists public.get_owner_boosts(text);
drop function if exists public.get_owner_boosts();
create or replace function public.get_owner_boosts()
returns table(
  listing_id uuid,
  listing_title text,
  listing_city text,
  listing_commune text,
  listing_zone text,
  listing_departement text,
  listing_transaction text,
  listing_price numeric,
  listing_currency text,
  listing_available boolean,
  listing_status text,
  boost_id uuid,
  boost_status text,
  plan_name text,
  ends_at timestamptz
)
language sql
security definer
set search_path = public
as $$
  select
    l.id, l.title, l.city, l.commune, l.zone, l.departement, l.transaction, l.price, l.currency, l.available, l.status,
    b.id,
    case when b.status = 'actif' and b.ends_at < now() then 'expire' else b.status end,
    b.plan_name, b.ends_at
  from listings l
  join owners o on o.id = l.owner_id
  left join lateral (
    select * from boosts bb
    where bb.listing_id = l.id
    order by bb.requested_at desc
    limit 1
  ) b on true
  where o.auth_user_id = auth.uid()
  order by l.created_at desc;
$$;

grant execute on function public.get_owner_boosts to authenticated;

-- Permet au propriétaire connecté de retirer sa propre annonce du site
-- public (bien loué/vendu) ou de la remettre disponible, sans repasser par
-- une validation admin. Désactive aussi tout boost actif au moment du retrait.
drop function if exists public.set_listing_availability(uuid, text, boolean);
create or replace function public.set_listing_availability(
  p_listing_id uuid,
  p_available boolean
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_owner_auth_id uuid;
begin
  select o.auth_user_id into v_owner_auth_id
  from listings l join owners o on o.id = l.owner_id
  where l.id = p_listing_id;

  if v_owner_auth_id is null then
    raise exception 'Annonce introuvable';
  end if;

  if v_owner_auth_id <> auth.uid() then
    raise exception 'Cette annonce ne vous appartient pas';
  end if;

  update listings set available = p_available where id = p_listing_id;

  if p_available = false then
    update boosts
      set status = 'expire', ends_at = now()
      where listing_id = p_listing_id and status = 'actif';
  end if;
end;
$$;

grant execute on function public.set_listing_availability to authenticated;

-- ============================================================
-- FONCTIONS POUR STATISTIQUES DE VISITES
-- ============================================================

-- Fonction pour obtenir le nombre de visites sur une période
create or replace function public.get_visits_count(
  p_start_date timestamptz,
  p_end_date timestamptz default now()
)
returns bigint
language sql
security definer
set search_path = public
as $$
  select count(*) from visits 
  where visited_at between p_start_date and p_end_date;
$$;

grant execute on function public.get_visits_count to authenticated;

-- Fonction pour obtenir le nombre de visiteurs uniques sur une période
create or replace function public.get_unique_visitors(
  p_start_date timestamptz,
  p_end_date timestamptz default now()
)
returns bigint
language sql
security definer
set search_path = public
as $$
  select count(distinct visitor_id) from visits 
  where visited_at between p_start_date and p_end_date;
$$;

grant execute on function public.get_visits_count to authenticated;

-- Fonction pour obtenir les statistiques complètes de visites (aujourd'hui, semaine, mois)
create or replace function public.get_visits_stats()
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_today timestamptz;
  v_week_ago timestamptz;
  v_month_ago timestamptz;
  v_result json;
begin
  v_today := date_trunc('day', now());
  v_week_ago := v_today - interval '7 days';
  v_month_ago := v_today - interval '30 days';
  
  select json_build_object(
    'today', (select count(*) from visits where visited_at >= v_today),
    'today_unique', (select count(distinct visitor_id) from visits where visited_at >= v_today),
    'week', (select count(*) from visits where visited_at >= v_week_ago),
    'week_unique', (select count(distinct visitor_id) from visits where visited_at >= v_week_ago),
    'month', (select count(*) from visits where visited_at >= v_month_ago),
    'month_unique', (select count(distinct visitor_id) from visits where visited_at >= v_month_ago)
  ) into v_result;
  
  return v_result;
end;
$$;

grant execute on function public.get_visits_stats to authenticated;

-- ============================================================
-- FONCTION POUR RECHERCHER LES VILLES PAR DÉPARTEMENT
-- ============================================================

-- Fonction pour obtenir les villes d'un département
create or replace function public.get_cities_by_departement(p_departement text)
returns table(city text)
language sql
security definer
set search_path = public
as $$
  select distinct city 
  from listings 
  where departement = p_departement 
    and status = 'valide' 
    and available = true
  order by city;
$$;

grant execute on function public.get_cities_by_departement to anon, authenticated;

-- Fonction pour obtenir les communes d'une ville
create or replace function public.get_communes_by_city(p_city text)
returns table(commune text)
language sql
security definer
set search_path = public
as $$
  select distinct commune 
  from listings 
  where city = p_city 
    and status = 'valide' 
    and available = true
  order by commune;
$$;

grant execute on function public.get_communes_by_city to anon, authenticated;

-- Fonction pour obtenir les zones d'une commune
create or replace function public.get_zones_by_commune(p_commune text)
returns table(zone text)
language sql
security definer
set search_path = public
as $$
  select distinct zone 
  from listings 
  where commune = p_commune 
    and status = 'valide' 
    and available = true
  order by zone;
$$;

grant execute on function public.get_zones_by_commune to anon, authenticated;

-- ============================================================
-- FONCTION POUR RECHERCHER LES ANNONCES AVEC FILTRES
-- ============================================================

-- Fonction de recherche avancée avec pagination
create or replace function public.search_listings(
  p_departement text default null,
  p_city text default null,
  p_commune text default null,
  p_zone text default null,
  p_transaction text default null,
  p_type text default null,
  p_min_price numeric default null,
  p_max_price numeric default null,
  p_limit int default 20,
  p_offset int default 0
)
returns table(
  id uuid,
  title text,
  city text,
  commune text,
  zone text,
  departement text,
  transaction text,
  type text,
  price numeric,
  currency text,
  period text,
  description text,
  photo_url text,
  owner_phone text,
  owner_whatsapp text,
  has_boost boolean,
  boost_ends_at timestamptz
)
language sql
security definer
set search_path = public
as $$
  select
    l.id,
    l.title,
    l.city,
    l.commune,
    l.zone,
    l.departement,
    l.transaction,
    l.type,
    l.price,
    l.currency,
    l.period,
    l.description,
    (select url from listing_media where listing_id = l.id and media_type = 'photo' limit 1) as photo_url,
    o.phone as owner_phone,
    o.whatsapp as owner_whatsapp,
    exists (
      select 1 from boosts b 
      where b.listing_id = l.id 
        and b.status = 'actif' 
        and b.ends_at > now()
    ) as has_boost,
    (select ends_at from boosts b 
     where b.listing_id = l.id 
       and b.status = 'actif' 
       and b.ends_at > now() 
     limit 1) as boost_ends_at
  from listings l
  join owners o on o.id = l.owner_id
  where l.status = 'valide'
    and l.available = true
    and (p_departement is null or l.departement = p_departement)
    and (p_city is null or l.city = p_city)
    and (p_commune is null or l.commune = p_commune)
    and (p_zone is null or l.zone = p_zone)
    and (p_transaction is null or l.transaction = p_transaction)
    and (p_type is null or l.type = p_type)
    and (p_min_price is null or l.price >= p_min_price)
    and (p_max_price is null or l.price <= p_max_price)
  order by 
    has_boost desc,
    l.created_at desc
  limit p_limit
  offset p_offset;
$$;

grant execute on function public.search_listings to anon, authenticated;

-- ============================================================
-- TAB VISITS_SUMMARY POUR STATISTIQUES MENSUELLES/ANNUELLES
-- ============================================================

-- Tab pou anrejistre rezime chak jou
create table if not exists visits_summary (
  id uuid primary key default gen_random_uuid(),
  date date not null unique,
  total_visits int not null default 0,
  unique_visitors int not null default 0,
  created_at timestamptz default now()
);

-- Endèks
create index if not exists idx_visits_summary_date on visits_summary(date);

-- Fonksyon pou ajoute rezime vizit chak jou
create or replace function public.add_daily_visits_summary()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_date date;
  v_total int;
  v_unique int;
begin
  -- Jwenn dènye dat ki gen rezime
  select max(date) into v_date from visits_summary;
  
  -- Si pa gen rezime, kòmanse depi 30 jou avan
  if v_date is null then
    v_date := date_trunc('day', now()) - interval '30 days';
  else
    v_date := v_date + interval '1 day';
  end if;
  
  -- Pou chak jou ki poko gen rezime
  while v_date <= date_trunc('day', now())::date loop
    -- Konte vizit pou jou sa a
    select count(*) into v_total
    from visits
    where date_trunc('day', visited_at) = v_date;
    
    -- Konte vizitè inik pou jou sa a
    select count(distinct visitor_id) into v_unique
    from visits
    where date_trunc('day', visited_at) = v_date;
    
    -- Enrejistre rezime a
    insert into visits_summary (date, total_visits, unique_visitors)
    values (v_date, v_total, v_unique)
    on conflict (date) do update
    set 
      total_visits = excluded.total_visits,
      unique_visitors = excluded.unique_visitors;
    
    v_date := v_date + interval '1 day';
  end loop;
end;
$$;

grant execute on function public.add_daily_visits_summary to authenticated;

-- Fonksyon pou jwenn rezime vizit pa peryòd
create or replace function public.get_visits_summary(
  p_start_date date,
  p_end_date date
)
returns table(
  period text,
  total_visits bigint,
  unique_visitors bigint
)
language sql
security definer
set search_path = public
as $$
  select 
    to_char(date, 'YYYY-MM') as period,
    sum(total_visits) as total_visits,
    sum(unique_visitors) as unique_visitors
  from visits_summary
  where date between p_start_date and p_end_date
  group by to_char(date, 'YYYY-MM')
  order by period;
$$;

grant execute on function public.get_visits_summary to authenticated;

-- Fonksyon pou rezime pa jou
create or replace function public.get_visits_daily(
  p_start_date date,
  p_end_date date
)
returns table(
  jour date,
  total_visits bigint,
  unique_visitors bigint
)
language sql
security definer
set search_path = public
as $$
  select 
    date,
    total_visits,
    unique_visitors
  from visits_summary
  where date between p_start_date and p_end_date
  order by date;
$$;

grant execute on function public.get_visits_daily to authenticated;

-- Rezime mwa a (mwa aktyèl la)
create or replace function public.get_current_month_summary()
returns table(
  month text,
  total_visits bigint,
  unique_visitors bigint
)
language sql
security definer
set search_path = public
as $$
  select 
    to_char(date_trunc('month', now()), 'YYYY-MM') as month,
    sum(total_visits) as total_visits,
    sum(unique_visitors) as unique_visitors
  from visits_summary
  where date >= date_trunc('month', now())
    and date <= now()::date;
$$;

grant execute on function public.get_current_month_summary to authenticated;

-- Rezime ane a (ane aktyèl la)
create or replace function public.get_current_year_summary()
returns table(
  year text,
  total_visits bigint,
  unique_visitors bigint
)
language sql
security definer
set search_path = public
as $$
  select 
    to_char(date_trunc('year', now()), 'YYYY') as year,
    sum(total_visits) as total_visits,
    sum(unique_visitors) as unique_visitors
  from visits_summary
  where date >= date_trunc('year', now())
    and date <= now()::date;
$$;

grant execute on function public.get_current_year_summary to authenticated;

-- ============================================================
-- PRIVILÈGES DE BASE — obligatoires en plus de RLS
-- ============================================================
-- Sans ces GRANT, PostgreSQL refuse l'accès à une table AVANT même de
-- vérifier les règles RLS ("permission denied for table ..."). RLS reste
-- la vraie barrière de sécurité : ces GRANT ouvrent seulement la porte
-- d'entrée générale ; RLS décide ensuite, ligne par ligne, ce que chaque
-- rôle (anon / authenticated) a le droit de voir ou modifier.
grant usage on schema public to anon, authenticated;
grant all on all tables in schema public to anon, authenticated;
grant all on all sequences in schema public to anon, authenticated;
grant insert on visits to anon, authenticated;
grant select on visits to authenticated;
alter default privileges in schema public grant all on tables to anon, authenticated;
alter default privileges in schema public grant all on sequences to anon, authenticated;

-- ============================================================
-- ÉTAPE FINALE OBLIGATOIRE — ajoutez votre compte admin existant
-- ============================================================
-- Admin email: zionmaket@gmail.com
insert into admins (user_id)
select id from auth.users where email = 'zionmaket@gmail.com'
on conflict (user_id) do nothing;

-- ============================================================
-- VERIFICATION FINALE
-- ============================================================

-- Verifye policies pou listing_media
select 
  schemaname, 
  tablename, 
  policyname, 
  permissive, 
  roles, 
  cmd, 
  qual, 
  with_check
from pg_policies 
where tablename = 'listing_media';

-- Verifye fonksyon link_owner_account
select 
  proname as function_name,
  pg_get_function_identity_arguments(oid) as arguments
from pg_proc 
where proname = 'link_owner_account' 
  and pronamespace = 'public'::regnamespace;

-- Verifye fonksyon create_listing
select 
  proname as function_name,
  pg_get_function_identity_arguments(oid) as arguments
from pg_proc 
where proname = 'create_listing' 
  and pronamespace = 'public'::regnamespace;




  -- ============================================================
-- KOREKSYON POLICIES STORAGE
-- ============================================================

-- Efase ansyen policies yo
drop policy if exists "media_bucket_public_read" on storage.objects;
drop policy if exists "media_bucket_public_upload" on storage.objects;

-- Rekreye policies ak bon non bucket la
create policy "media_bucket_public_read" on storage.objects
  for select to anon, authenticated 
  using (bucket_id = 'listing-media');

create policy "media_bucket_public_upload" on storage.objects
  for insert to authenticated 
  with check (bucket_id = 'listing-media');


  -- 1. Ajoute kolòn imaj yo anndan tab listings la
ALTER TABLE public.listings 
ADD COLUMN IF NOT EXISTS image_url text,
ADD COLUMN IF NOT EXISTS images text[];

-- 2. Asire w RLS Policy pèmèt tout moun li anons yo
DROP POLICY IF EXISTS "listings_public_read" ON public.listings;
CREATE POLICY "listings_public_read" ON public.listings
  FOR SELECT TO anon, authenticated USING (true);