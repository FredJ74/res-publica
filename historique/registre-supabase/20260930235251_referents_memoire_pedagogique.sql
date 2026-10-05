-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260930235251
-- Nom original      : referents_memoire_pedagogique
-- Categorie         : MIXTE -- MIXTE (structure ET mutation de donnees)
-- Date (deduite de la version) : 2026-09-30 23:52:51 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 6160a569addb8f6fc31266fd641c177f
--
-- ARCHIVE DOCUMENTAIRE exportee de supabase_migrations.schema_migrations.
-- Ce fichier NE FAIT PAS partie d'une chaine de reconstruction et NE DOIT
-- PAS etre rejoue, ni execute automatiquement, ni servir a installer une
-- base neuve. Voir historique/registre-supabase/README.md.
--
-- Le SQL ci-dessous est conserve INTEGRALEMENT, SANS AUCUNE MODIFICATION :
-- ni correction, ni mise en forme, ni separation des parties DDL et DML,
-- ni ajout d'idempotence. On archive ce qui s'est reellement passe.
-- ============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
create table if not exists public.pnj_referents (
  referent_id text primary key,
  domaine     text not null
);

comment on table public.pnj_referents is
  'Liste FERMEE des PNJ referents, cote serveur. Ne porte que des identifiants et un libelle de domaine : la personnalite vit dans api/_pnj-referents.js. Sert a refuser d''ouvrir une memoire pedagogique pour un PNJ qui n''en est pas un.';

insert into public.pnj_referents (referent_id, domaine) values
  ('marc_hantile',      'economie'),
  ('martial_bouterin',  'militaire — organisation, strategie, operations'),
  ('gaspard_ferriere',  'militaire — engagement, formation, troupe'),
  ('procureur_saad',    'justice — poursuites et parquet'),
  ('juge_fontaine',     'justice — proces et jugement'),
  ('president_laroche', 'institutions et Etat'),
  ('raoul_toufaud',     'police')
on conflict (referent_id) do nothing;

create table if not exists public.pnj_referents_pedagogie (
  referent_id   text        not null,
  joueur        text        not null,
  consultations integer     not null default 0,
  premiere_le   timestamptz not null default now(),
  derniere_le   timestamptz not null default now(),
  sujets        jsonb       not null default '{}'::jsonb,
  primary key (referent_id, joueur)
);

comment on table public.pnj_referents_pedagogie is
  'Memoire PEDAGOGIQUE d''un referent envers un joueur : combien de fois il lui a deja explique des choses. AUCUNE familiarite, AUCUNE confiance, AUCUN jalon -- ces notions appartiennent aux PNJ sociaux, et les melanger effacerait la difference de nature entre les deux. Une ligne par couple ; fermee au client, tout passe par les deux RPC.';

alter table public.pnj_referents           enable row level security;
alter table public.pnj_referents_pedagogie enable row level security;
revoke all on table public.pnj_referents           from public, anon, authenticated;
revoke all on table public.pnj_referents_pedagogie from public, anon, authenticated;
grant all on table public.pnj_referents           to service_role;
grant all on table public.pnj_referents_pedagogie to service_role;

create or replace function public.referent_pedagogie_noter(p_referent_id text)
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $fn$
DECLARE v_moi text; v_n integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF NOT EXISTS (SELECT 1 FROM public.pnj_referents r WHERE r.referent_id = p_referent_id) THEN
    RETURN jsonb_build_object('ok', true, 'referent', false); END IF;

  INSERT INTO public.pnj_referents_pedagogie (referent_id, joueur, consultations)
       VALUES (p_referent_id, v_moi, 1)
  ON CONFLICT (referent_id, joueur) DO UPDATE
     SET consultations = public.pnj_referents_pedagogie.consultations + 1,
         derniere_le   = now();

  SELECT consultations INTO v_n FROM public.pnj_referents_pedagogie
   WHERE referent_id = p_referent_id AND joueur = v_moi;
  RETURN jsonb_build_object('ok', true, 'referent', true, 'consultations', v_n);
END;
$fn$;

comment on function public.referent_pedagogie_noter(text) is
  'Note une consultation aboutie aupres d''un referent. Sans effet pour un PNJ qui n''est pas dans la liste fermee : aucune ligne n''est creee. Ne touche a aucune notion sociale.';

create or replace function public.referent_pedagogie_contexte(p_referent_id text)
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public', 'pg_temp'
as $fn$
DECLARE v_moi text; v_n integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT consultations INTO v_n FROM public.pnj_referents_pedagogie
   WHERE referent_id = p_referent_id AND joueur = v_moi;
  IF v_n IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucune_consultation'); END IF;
  RETURN jsonb_build_object('ok', true, 'consultations', v_n);
END;
$fn$;

comment on function public.referent_pedagogie_contexte(text) is
  'Combien de fois ce referent a deja explique des choses au joueur connecte, pour adapter son enseignement. Lecture seule, sous le jeton du joueur.';

revoke all on function public.referent_pedagogie_noter(text)    from public, anon;
revoke all on function public.referent_pedagogie_contexte(text) from public, anon;
grant execute on function public.referent_pedagogie_noter(text)    to authenticated, service_role;
grant execute on function public.referent_pedagogie_contexte(text) to authenticated, service_role;

DO $garde$
DECLARE n integer;
BEGIN
  SELECT count(*) INTO n FROM public.pnj_referents;
  IF n <> 7 THEN RAISE EXCEPTION 'liste des referents : % entrees, 7 attendues', n; END IF;
END $garde$;