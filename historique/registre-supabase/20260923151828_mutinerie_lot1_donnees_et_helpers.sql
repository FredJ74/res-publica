-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260923151828
-- Nom original      : mutinerie_lot1_donnees_et_helpers
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-23 15:18:28 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : e6c8410103e54306322fe8146dda08ef
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
CREATE TABLE IF NOT EXISTS public.mutineries (
  camp         text PRIMARY KEY,
  pays         text NOT NULL,
  fondateur    text NOT NULL,
  compagnie_id text,
  section_id   text,
  statut       text NOT NULL DEFAULT 'active',
  cree_le      timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.mutineries_membres (
  camp         text NOT NULL REFERENCES public.mutineries(camp) ON DELETE CASCADE,
  personnage   text NOT NULL,
  role_origine text,
  statut       text NOT NULL DEFAULT 'actif',
  rejoint_le   timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (camp, personnage)
);

CREATE UNIQUE INDEX IF NOT EXISTS mutineries_membres_un_seul_camp
  ON public.mutineries_membres (personnage);

ALTER TABLE public.mutineries          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mutineries_membres  ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS mutineries_lecture_mon_pays ON public.mutineries;
CREATE POLICY mutineries_lecture_mon_pays ON public.mutineries
  FOR SELECT TO authenticated USING (pays = public.militaire_mon_pays());

DROP POLICY IF EXISTS mutineries_membres_lecture_mon_pays ON public.mutineries_membres;
CREATE POLICY mutineries_membres_lecture_mon_pays ON public.mutineries_membres
  FOR SELECT TO authenticated USING (EXISTS (
    SELECT 1 FROM public.mutineries m
     WHERE m.camp = mutineries_membres.camp AND m.pays = public.militaire_mon_pays()));

REVOKE ALL ON public.mutineries         FROM PUBLIC, anon, authenticated;
REVOKE ALL ON public.mutineries_membres FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.mutineries         TO authenticated;
GRANT SELECT ON public.mutineries_membres TO authenticated;

CREATE OR REPLACE FUNCTION public.mutinerie_social_national(p_pays text)
RETURNS numeric LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public' AS $function$
  SELECT CASE WHEN count(*) = 3 THEN round(avg((v.data ->> 'social')::numeric), 2) ELSE 45 END
    FROM public.indices_villes v
   WHERE v.id = ANY (ARRAY[p_pays || '_capitale', p_pays || '_ville_a', p_pays || '_ville_b'])
     AND jsonb_typeof(v.data -> 'social') = 'number';
$function$;

CREATE OR REPLACE FUNCTION public.mutinerie_camp_de(p_nom text)
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public' AS $function$
  SELECT mm.camp FROM public.mutineries_membres mm
    JOIN public.mutineries m ON m.camp = mm.camp
   WHERE mm.personnage = p_nom AND mm.statut = 'actif' AND m.statut = 'active'
   LIMIT 1;
$function$;

CREATE OR REPLACE FUNCTION public.mutinerie_est_camp(p_camp text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public' AS $function$
  SELECT EXISTS (SELECT 1 FROM public.mutineries WHERE camp = p_camp);
$function$;

CREATE OR REPLACE FUNCTION public.mutinerie_pays_du_camp(p_camp text)
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public' AS $function$
  SELECT coalesce((SELECT m.pays FROM public.mutineries m WHERE m.camp = p_camp), p_camp);
$function$;

CREATE OR REPLACE FUNCTION public.mutinerie_camps_presents(
  p_pays text, p_ville text, p_bat text, p_piece text)
RETURNS text[] LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public' AS $function$
  SELECT coalesce(array_agg(DISTINCT t.camp), '{}'::text[]) FROM (
    SELECT coalesce(sol->>'mutin', c.data->>'pays') AS camp
      FROM public.compagnies_militaires c,
           jsonb_array_elements(coalesce(c.data->'sections','[]'::jsonb)) s,
           jsonb_array_elements(coalesce(s->'soldats','[]'::jsonb)) sol
     WHERE c.data->>'pays' = p_pays
       AND NOT coalesce((sol->>'pj')::boolean, false)
       AND coalesce((sol->>'pa')::integer, 0) > 0
       AND ((sol->>'ville' = p_ville AND sol->>'buildingId' = p_bat AND sol->>'roomId' = p_piece
             AND (sol->>'leaderCourant') IS NULL)
         OR EXISTS (SELECT 1 FROM public.personnages_donnees chef
                     WHERE chef.name = sol->>'leaderCourant' AND chef.current_city = p_ville
                       AND chef.current_building = p_bat AND chef.current_room = p_piece))
    UNION ALL
    SELECT coalesce(public.mutinerie_camp_de(pd.name), pd.country)
      FROM public.personnages_donnees pd
      JOIN public.services_militaires sm ON sm.personnage = pd.name AND sm.fin_ts IS NULL
     WHERE pd.country = p_pays AND pd.current_city = p_ville
       AND pd.current_building = p_bat AND pd.current_room = p_piece
       AND coalesce(pd.pa, 0) > 0
  ) t;
$function$;