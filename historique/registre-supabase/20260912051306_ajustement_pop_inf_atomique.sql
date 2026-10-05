-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260912051306
-- Nom original      : ajustement_pop_inf_atomique
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-12 05:13:06 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : e74f4e0236dfe8dd83d8032c4ee2eddd
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
-- AJUSTEMENT ATOMIQUE DE LA POPULARITE / INFLUENCE D'UN AUTRE PERSONNAGE (12 septembre 2026)
-- sbAjusterPopJoueur et sbAjusterPopularite lisaient resources puis reecrivaient le blob ENTIER
-- ({inf, pop, dis}) depuis une valeur perimee : la cible perdait les gains d'INF ou de DIS obtenus
-- entre la lecture et l'ecriture. Meme remede que pour les tracts : un seul UPDATE, sous le verrou
-- de ligne, qui ne touche que les cles demandees. p_inf NULL = l'influence n'est pas modifiee.
CREATE OR REPLACE FUNCTION public.personnage_ajuster_pop_inf(p_cible text, p_pop integer, p_inf integer DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_res jsonb;
BEGIN
  IF COALESCE(btrim(p_cible), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_invalide');
  END IF;
  IF COALESCE(abs(p_pop), 0) > 100 OR COALESCE(abs(p_inf), 0) > 100 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'delta_invalide');
  END IF;
  UPDATE public.personnages
     SET resources = (
           CASE WHEN p_inf IS NULL THEN r.base
                ELSE jsonb_set(r.base, '{inf}', to_jsonb(GREATEST(0, LEAST(100,
                  COALESCE(CASE WHEN jsonb_typeof(r.base -> 'inf') = 'number' THEN (r.base ->> 'inf')::numeric END, 0) + p_inf))))
           END)
    FROM (SELECT jsonb_set(
            CASE WHEN jsonb_typeof(pp.resources) = 'object' THEN pp.resources ELSE '{}'::jsonb END,
            '{pop}', to_jsonb(GREATEST(0, LEAST(100,
              COALESCE(CASE WHEN jsonb_typeof(pp.resources -> 'pop') = 'number' THEN (pp.resources ->> 'pop')::numeric END, 50)
              + COALESCE(p_pop, 0))))) AS base
            FROM public.personnages pp WHERE pp.name = p_cible) r
   WHERE public.personnages.name = p_cible
   RETURNING public.personnages.resources INTO v_res;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_introuvable');
  END IF;
  RETURN jsonb_build_object('ok', true, 'pop', v_res -> 'pop', 'inf', v_res -> 'inf');
END;
$$;
REVOKE ALL ON FUNCTION public.personnage_ajuster_pop_inf(text, integer, integer) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.personnage_ajuster_pop_inf(text, integer, integer) TO anon, authenticated, service_role;