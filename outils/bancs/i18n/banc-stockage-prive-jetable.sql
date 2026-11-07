-- Banc SQL I18N : base PostgreSQL jetable exclusivement.
-- Aucun accès Supabase, aucun jeton PJ, aucune écriture en production.
\set ON_ERROR_STOP on
CREATE ROLE anon NOLOGIN;
CREATE ROLE authenticated NOLOGIN;
CREATE ROLE service_role NOLOGIN;

\ir ../../livraison/I18N-STOCKAGE-PRIVE-BROUILLON-NON-APPLIQUER.sql

DO $test$
BEGIN
 IF (SELECT enabled FROM public.rp_i18n_configuration WHERE singleton=1) IS DISTINCT FROM false THEN
  RAISE EXCEPTION 'configuration non désactivée par défaut';
 END IF;
 IF has_table_privilege('anon','public.rp_i18n_cache','SELECT')
    OR has_table_privilege('authenticated','public.rp_i18n_cache','SELECT')
    OR has_table_privilege('anon','public.rp_i18n_usage','SELECT')
    OR has_table_privilege('authenticated','public.rp_i18n_usage','SELECT')
    OR has_table_privilege('anon','public.rp_i18n_configuration','UPDATE')
    OR has_table_privilege('authenticated','public.rp_i18n_reservations','INSERT') THEN
  RAISE EXCEPTION 'droit de table exposé aux joueurs';
 END IF;
 IF has_function_privilege('anon','public.rp_i18n_budget_reserver(uuid,text,integer)','EXECUTE')
    OR has_function_privilege('authenticated','public.rp_i18n_budget_reserver(uuid,text,integer)','EXECUTE')
    OR has_function_privilege('anon','public.rp_i18n_cache_lire(text)','EXECUTE')
    OR has_function_privilege('authenticated','public.rp_i18n_cache_ecrire(text,text)','EXECUTE') THEN
  RAISE EXCEPTION 'RPC privée exécutable par un joueur';
 END IF;
 IF NOT (SELECT relrowsecurity FROM pg_class WHERE oid='public.rp_i18n_usage'::regclass) THEN
  RAISE EXCEPTION 'RLS non activée';
 END IF;
END
$test$;

SET ROLE service_role;
DO $test$
DECLARE
 u uuid := '11111111-1111-4111-8111-111111111111';
 key1 text := repeat('a',64);
 key2 text := repeat('b',64);
 key3 text := repeat('c',64);
BEGIN
 IF public.rp_i18n_budget_reserver(u,key1,6) IS DISTINCT FROM false THEN
  RAISE EXCEPTION 'quota ouvert alors que désactivé';
 END IF;
 IF public.rp_i18n_cache_lire(key1) IS NOT NULL THEN
  RAISE EXCEPTION 'cache non vide avant insertion';
 END IF;
 IF public.rp_i18n_cache_ecrire(key1,'Hallo') IS DISTINCT FROM true THEN
  RAISE EXCEPTION 'écriture cache refusée';
 END IF;
 IF public.rp_i18n_cache_lire(key1) IS DISTINCT FROM 'Hallo' THEN
  RAISE EXCEPTION 'lecture cache incorrecte';
 END IF;
 IF public.rp_i18n_cache_ecrire('mauvaise cle','Bonjour') IS DISTINCT FROM false THEN
  RAISE EXCEPTION 'clé cache invalide acceptée';
 END IF;
 IF public.rp_i18n_cache_ecrire(key1,' ') IS DISTINCT FROM false THEN
  RAISE EXCEPTION 'traduction vide acceptée';
 END IF;
END
$test$;
RESET ROLE;

UPDATE public.rp_i18n_configuration
 SET enabled=true,daily_requests=2,daily_characters=12 WHERE singleton=1;

SET ROLE service_role;
DO $test$
DECLARE
 u uuid := '11111111-1111-4111-8111-111111111111';
 v uuid := '22222222-2222-4222-8222-222222222222';
 k1 text := repeat('a',64);
 k2 text := repeat('b',64);
 k3 text := repeat('c',64);
 n integer;
 c bigint;
BEGIN
 IF public.rp_i18n_budget_reserver(u,k1,6) IS DISTINCT FROM true THEN
  RAISE EXCEPTION 'première réservation impossible';
 END IF;
 IF public.rp_i18n_budget_reserver(u,k1,6) IS DISTINCT FROM false THEN
  RAISE EXCEPTION 'double réservation même clé acceptée';
 END IF;
 IF public.rp_i18n_budget_reserver(u,k2,6) IS DISTINCT FROM true THEN
  RAISE EXCEPTION 'seconde réservation impossible';
 END IF;
 IF public.rp_i18n_budget_reserver(u,k3,1) IS DISTINCT FROM false THEN
  RAISE EXCEPTION 'plafond de demandes contourné';
 END IF;
 SELECT request_count,character_count INTO n,c
 FROM public.rp_i18n_usage WHERE uid=u AND usage_day=(clock_timestamp() AT TIME ZONE 'UTC')::date;
 IF n<>2 OR c<>12 THEN
  RAISE EXCEPTION 'compteurs inattendus: % demandes, % caractères',n,c;
 END IF;
 IF public.rp_i18n_budget_reserver(v,k1,13) IS DISTINCT FROM false THEN
  RAISE EXCEPTION 'plafond de caractères contourné';
 END IF;
 IF public.rp_i18n_budget_reserver(v,k1,12) IS DISTINCT FROM true THEN
  RAISE EXCEPTION 'plafond exact non accepté';
 END IF;
END
$test$;
RESET ROLE;

SELECT 'I18N SQL : ACL, RLS, désactivation, cache, réservation, anti-rejeu, plafonds OK' AS resultat;
