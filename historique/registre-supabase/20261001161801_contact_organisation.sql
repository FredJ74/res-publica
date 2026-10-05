-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20261001161801
-- Nom original      : contact_organisation
-- Categorie         : MIXTE -- MIXTE (structure ET mutation de donnees)
-- Date (deduite de la version) : 2026-10-01 16:18:01 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 531a4f83dfc64c0ca6b63755ec19d2d6
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
-- METTRE EN RELATION, SANS RIEN SAVOIR (1er octobre 2026)
-- Version appliquee de migration_20261001_contact_organisation.sql.
-- La garantie centrale : contact_organisation_demander() N'A PAS DE PARAMETRE
-- pour le projet du joueur. Le texte ne quitte pas le navigateur parce qu'aucune
-- porte ne s'ouvre pour lui.

create table if not exists public.contacts_organisations_passeurs (
  passeur           text not null,
  type_organisation text not null,
  pays              text not null,
  expediteur        text not null,
  primary key (passeur, type_organisation)
);

comment on table public.contacts_organisations_passeurs is
  'Liste FERMEE des PNJ capables de mettre un joueur en relation avec une organisation, et avec quel type. Un passeur appartient a un empire : la regle de socle interdit de partager un personnage entre plusieurs empires.';

insert into public.contacts_organisations_passeurs (passeur, type_organisation, pays, expediteur) values
  ('pat_hounette', 'criminelle', 'republic', 'Pat Hounette')
on conflict (passeur, type_organisation) do nothing;

create table if not exists public.contacts_organisations (
  joueur                   text        not null,
  passeur                  text        not null,
  type_organisation        text        not null,
  derniere_demande         timestamptz not null default now(),
  organisations_contactees jsonb       not null default '[]'::jsonb,
  primary key (joueur, passeur, type_organisation)
);

comment on table public.contacts_organisations is
  'Etat d''une mise en relation : date de la derniere demande (porte le refus de trois jours) et organisations deja sollicitees (porte l''escalade vers la suivante). Ne contient AUCUNE donnee sur le projet du joueur -- la RPC qui ecrit ici n''a aucun parametre pour en recevoir.';

alter table public.contacts_organisations_passeurs enable row level security;
alter table public.contacts_organisations          enable row level security;
revoke all on table public.contacts_organisations_passeurs from public, anon, authenticated;
revoke all on table public.contacts_organisations          from public, anon, authenticated;
grant all on table public.contacts_organisations_passeurs to service_role;
grant all on table public.contacts_organisations          to service_role;

-- Cast tolerant : `organisations.data` est du texte produit par JSON.stringify cote
-- client. Un data::jsonb direct ferait tomber la mise en relation POUR TOUT LE
-- MONDE sur une seule ligne malformee.
create or replace function public.jsonb_ou_null(p_texte text)
returns jsonb
language plpgsql
immutable
as $fn$
BEGIN
  RETURN p_texte::jsonb;
EXCEPTION WHEN others THEN
  RETURN NULL;
END;
$fn$;

comment on function public.jsonb_ou_null(text) is
  'Cast tolerant texte -> jsonb : rend NULL au lieu de lever si le texte n''est pas du JSON. Pour lire un blob ecrit par un navigateur sans qu''une seule ligne malformee fasse tomber toute une mecanique.';

revoke all on function public.jsonb_ou_null(text) from public, anon;
grant execute on function public.jsonb_ou_null(text) to authenticated, service_role;

-- Lue AU CLIC, avant que le passeur ne pose ses questions : le game design veut
-- qu'il refuse tout de suite pendant les trois jours. N'autorise rien.
create or replace function public.contact_organisation_etat(
  p_passeur text, p_type_organisation text)
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public', 'pg_temp'
as $fn$
DECLARE v_moi text; v_e record; v_restant integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  IF NOT EXISTS (SELECT 1 FROM public.contacts_organisations_passeurs p
                  WHERE p.passeur = p_passeur AND p.type_organisation = p_type_organisation) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'passeur_inconnu'); END IF;

  SELECT * INTO v_e FROM public.contacts_organisations c
   WHERE c.joueur = v_moi AND c.passeur = p_passeur
     AND c.type_organisation = p_type_organisation;

  IF v_e IS NULL THEN
    RETURN jsonb_build_object('ok', true, 'peut_demander', true,
                              'jours_restants', 0, 'deja_contactees', 0); END IF;

  v_restant := greatest(0, ceil(extract(epoch from
                 (v_e.derniere_demande + interval '3 days') - now()) / 86400.0)::integer);

  RETURN jsonb_build_object(
    'ok', true,
    'peut_demander', (now() >= v_e.derniere_demande + interval '3 days'),
    'jours_restants', v_restant,
    'deja_contactees', jsonb_array_length(v_e.organisations_contactees));
END;
$fn$;

comment on function public.contact_organisation_etat(text, text) is
  'Ce passeur accepte-t-il une nouvelle demande de ce joueur, et depuis combien de temps ? Lecture seule, sous le jeton du joueur. N''autorise rien : le delai est retranche pour de vrai dans contact_organisation_demander().';

-- AUCUN FILTRAGE : tout joueur peut demander, le passeur ne juge personne. Aucune
-- caracteristique requise, aucune reputation, aucune quete, aucun cout.
create or replace function public.contact_organisation_demander(
  p_passeur text, p_type_organisation text)
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $fn$
DECLARE
  v_moi     text;
  v_passeur record;
  v_e       record;
  v_orga    record;
  v_nom     text;
  v_corps   text;
  v_id      text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT * INTO v_passeur FROM public.contacts_organisations_passeurs p
   WHERE p.passeur = p_passeur AND p.type_organisation = p_type_organisation;
  IF v_passeur IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'passeur_inconnu'); END IF;

  -- Verrou sur la ligne d'etat : deux clics simultanes ne doivent pas solliciter
  -- deux organisations d'un coup, ni deux fois la meme.
  SELECT * INTO v_e FROM public.contacts_organisations c
   WHERE c.joueur = v_moi AND c.passeur = p_passeur
     AND c.type_organisation = p_type_organisation
     FOR UPDATE;

  IF v_e IS NOT NULL AND now() < v_e.derniere_demande + interval '3 days' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'delai_non_ecoule',
             'jours_restants', greatest(1, ceil(extract(epoch from
               (v_e.derniere_demande + interval '3 days') - now()) / 86400.0)::integer)); END IF;

  -- La plus nombreuse, jamais encore sollicitee pour ce joueur. A nombre egal,
  -- l'identifiant tranche : ce n'est pas un critere de jeu, c'est la seule facon
  -- de rendre le resultat reproductible.
  SELECT o.id,
         coalesce(d->>'nom', 'une organisation') AS nom,
         d->>'chef'                              AS chef,
         coalesce((d->>'chefEstPnj')::boolean, false) AS chef_est_pnj,
         jsonb_array_length(coalesce(d->'membres', '[]'::jsonb)) AS membres
    INTO v_orga
    FROM public.organisations o
    CROSS JOIN LATERAL (SELECT public.jsonb_ou_null(o.data) AS d) j
   WHERE d IS NOT NULL
     AND d->>'type' = p_type_organisation
     AND coalesce(d->>'chef', '') <> ''
     AND NOT (coalesce(v_e.organisations_contactees, '[]'::jsonb) ? o.id)
   ORDER BY jsonb_array_length(coalesce(d->'membres', '[]'::jsonb)) DESC, o.id ASC
   LIMIT 1;

  IF v_orga IS NULL THEN
    -- Le delai de trois jours N'EST PAS consomme : aucun message n'est parti, le
    -- passeur n'a aucune raison de faire attendre.
    RETURN jsonb_build_object('ok', false, 'raison',
             CASE WHEN v_e IS NULL OR jsonb_array_length(v_e.organisations_contactees) = 0
                  THEN 'aucune_organisation' ELSE 'toutes_contactees' END); END IF;

  -- Le bouton ne voyage pas dans le HTML : marqueur textuel inerte, meme format
  -- que marqueurActionMail() cote navigateur, reconstruit par forum.js depuis sa
  -- table blanche ACTIONS_MAIL.
  v_nom   := regexp_replace(v_moi, '[|\[\]]', '', 'g');
  v_corps := 'J''ai rencontré quelqu''un qui cherche un service. Contacte '
          || v_nom || ' de ma part.' || chr(10) || chr(10)
          || '[[act:ecrire_a|' || v_nom || ']]';

  v_id := 'co-' || (extract(epoch from clock_timestamp()) * 1000)::bigint
               || '-' || substr(md5(random()::text), 1, 6);
  INSERT INTO public.mails (id, from_player, to_player, subject, body, time, read)
  VALUES (v_id, v_passeur.expediteur, v_orga.chef, 'Quelqu''un à contacter', v_corps,
          to_char(now() AT TIME ZONE 'Europe/Paris', 'DD/MM/YYYY HH24:MI'), false);

  INSERT INTO public.contacts_organisations
         (joueur, passeur, type_organisation, derniere_demande, organisations_contactees)
  VALUES (v_moi, p_passeur, p_type_organisation, now(), jsonb_build_array(v_orga.id))
  ON CONFLICT (joueur, passeur, type_organisation) DO UPDATE
     SET derniere_demande = now(),
         organisations_contactees =
           public.contacts_organisations.organisations_contactees || jsonb_build_array(v_orga.id);

  -- Ne nomme PAS l'organisation : le passeur ne transmet aucun detail, dans les
  -- deux sens.
  RETURN jsonb_build_object('ok', true, 'rang',
           coalesce(jsonb_array_length(v_e.organisations_contactees), 0) + 1);
END;
$fn$;

comment on function public.contact_organisation_demander(text, text) is
  'Un passeur envoie un message a l''organisation du type demande comptant le plus de membres, jamais encore sollicitee pour ce joueur. Aucun filtrage : tout joueur peut demander. N''A AUCUN PARAMETRE pour le projet du joueur, et c''est la garantie que rien n''en est conserve. Ne nomme pas l''organisation dans sa reponse.';

revoke all on function public.contact_organisation_etat(text, text)      from public, anon;
revoke all on function public.contact_organisation_demander(text, text)  from public, anon;
grant execute on function public.contact_organisation_etat(text, text)     to authenticated, service_role;
grant execute on function public.contact_organisation_demander(text, text) to authenticated, service_role;

DO $garde$
DECLARE n integer;
BEGIN
  SELECT count(*) INTO n FROM public.contacts_organisations_passeurs;
  IF n < 1 THEN RAISE EXCEPTION 'aucun passeur declare'; END IF;
  SELECT count(*) INTO n FROM public.contacts_organisations_passeurs WHERE pays IS NULL;
  IF n <> 0 THEN RAISE EXCEPTION '% passeur(s) sans empire', n; END IF;
  SELECT count(*) INTO n FROM pg_proc p
    JOIN pg_namespace ns ON ns.oid = p.pronamespace
   WHERE ns.nspname = 'public'
     AND p.proname IN ('contact_organisation_etat', 'contact_organisation_demander')
     AND has_function_privilege('anon', p.oid, 'execute');
  IF n <> 0 THEN RAISE EXCEPTION '% RPC de mise en relation encore ouverte(s) a anon', n; END IF;
END $garde$;