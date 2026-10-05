-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260911223719
-- Nom original      : tracts_calomnieux
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-11 22:37:19 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : f4f1e0d389d46b0790375f5a47363150
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
-- TRACTS CALOMNIEUX -- MECANIQUE DE PERSUASION INDIVIDUELLE (12 septembre 2026)
-- Voir migration_tracts_calomnieux.sql dans le depot pour la doctrine complete.

-- 1. INF EN DELTA (extension du trigger de fusion POP existant)
CREATE OR REPLACE FUNCTION public.personnages_fusionner_pop()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
DECLARE
  v_base numeric;
  v_old  numeric;
BEGIN
  IF jsonb_typeof(NEW.resources) = 'object' AND NEW.resources ? 'popBase' THEN
    v_base := CASE WHEN jsonb_typeof(NEW.resources -> 'popBase') = 'number' THEN (NEW.resources ->> 'popBase')::numeric END;
    NEW.resources := NEW.resources - 'popBase';
    IF TG_OP = 'UPDATE' AND v_base IS NOT NULL AND jsonb_typeof(NEW.resources -> 'pop') = 'number' THEN
      v_old := CASE WHEN jsonb_typeof(OLD.resources -> 'pop') = 'number' THEN (OLD.resources ->> 'pop')::numeric ELSE v_base END;
      NEW.resources := jsonb_set(NEW.resources, '{pop}',
        to_jsonb(GREATEST(0, LEAST(100, v_old + ((NEW.resources ->> 'pop')::numeric - v_base)))));
    END IF;
  END IF;
  IF jsonb_typeof(NEW.resources) = 'object' AND NEW.resources ? 'infBase' THEN
    v_base := CASE WHEN jsonb_typeof(NEW.resources -> 'infBase') = 'number' THEN (NEW.resources ->> 'infBase')::numeric END;
    NEW.resources := NEW.resources - 'infBase';
    IF TG_OP = 'UPDATE' AND v_base IS NOT NULL AND jsonb_typeof(NEW.resources -> 'inf') = 'number' THEN
      v_old := CASE WHEN jsonb_typeof(OLD.resources -> 'inf') = 'number' THEN (OLD.resources ->> 'inf')::numeric ELSE v_base END;
      NEW.resources := jsonb_set(NEW.resources, '{inf}',
        to_jsonb(GREATEST(0, LEAST(100, v_old + ((NEW.resources ->> 'inf')::numeric - v_base)))));
    END IF;
  END IF;
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.personnages_fusionner_pop() FROM PUBLIC, anon, authenticated;

-- 2. REGISTRE DES ACTES
CREATE TABLE IF NOT EXISTS public.calomnies_actes (
  id             bigserial PRIMARY KEY,
  auteur         text NOT NULL,
  cible          text NOT NULL,
  pnj_cle        text NOT NULL,
  pnj_nom        text NOT NULL,
  jour_paris     date NOT NULL,
  resultat       text NOT NULL CHECK (resultat IN ('reussite', 'echec', 'echec_critique')),
  pays_faits     text,
  ville_faits    text,
  pays_competent text NOT NULL,
  jet            smallint,
  taux           smallint,
  cree_le        timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS calomnies_actes_verrou
  ON public.calomnies_actes (pnj_cle, cible, jour_paris) WHERE resultat = 'reussite';
CREATE INDEX IF NOT EXISTS calomnies_actes_cible ON public.calomnies_actes (cible, cree_le DESC);
ALTER TABLE public.calomnies_actes ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.calomnies_actes FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.calomnies_actes TO anon, authenticated;
DROP POLICY IF EXISTS calomnies_actes_lecture ON public.calomnies_actes;
CREATE POLICY calomnies_actes_lecture ON public.calomnies_actes FOR SELECT USING (true);

-- 3. EFFET POP + INF ATOMIQUE
CREATE OR REPLACE FUNCTION public.calomnie_appliquer_effet(p_cible text, p_pop integer, p_inf integer)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_res jsonb;
BEGIN
  UPDATE public.personnages
     SET resources = jsonb_set(
           jsonb_set(CASE WHEN jsonb_typeof(resources) = 'object' THEN resources ELSE '{}'::jsonb END,
                     '{pop}', to_jsonb(GREATEST(0, LEAST(100,
                       COALESCE(CASE WHEN jsonb_typeof(resources -> 'pop') = 'number' THEN (resources ->> 'pop')::numeric END, 50) + p_pop)))),
           '{inf}', to_jsonb(GREATEST(0, LEAST(100,
             COALESCE(CASE WHEN jsonb_typeof(resources -> 'inf') = 'number' THEN (resources ->> 'inf')::numeric END, 0) + p_inf))))
   WHERE name = p_cible
   RETURNING resources INTO v_res;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_introuvable');
  END IF;
  RETURN jsonb_build_object('ok', true, 'pop', v_res -> 'pop', 'inf', v_res -> 'inf');
END;
$$;

-- 4. MANDAT DANS LE PAYS COMPETENT
CREATE OR REPLACE FUNCTION public.calomnie_inscrire_mandat(p_auteur text, p_cible text, p_pays text, p_ville_faits text, p_instant timestamptz)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_entree jsonb;
BEGIN
  v_entree := jsonb_build_object(
    'id', 'rech-calomnie-' || md5(p_auteur || '|' || p_cible || '|' || p_pays || '|' || extract(epoch FROM p_instant)::text),
    'type', 'condamnation',
    'origine', 'serveur',
    'country', p_pays,
    'motifs', jsonb_build_array(jsonb_build_object(
      'type', 'Distribution de tracts calomnieux',
      'jours', 1,
      'source', 'calomnie_juridiction_victime',
      'cible', p_cible,
      'city', p_ville_faits,
      'date_evenement', to_char(p_instant AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'))),
    'issue_judiciaire', 'Mandat d''arret pour calomnie envers un resident (faits commis a l''etranger)',
    'autorite', 'Parquet',
    'jour_condamnation', null);
  UPDATE public.personnages
     SET recherche = CASE WHEN jsonb_typeof(recherche) = 'array' THEN recherche ELSE '[]'::jsonb END || v_entree
   WHERE name = p_auteur;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'auteur_introuvable');
  END IF;
  RETURN jsonb_build_object('ok', true, 'mandat', v_entree);
END;
$$;

-- 5. MOTEUR
CREATE OR REPLACE FUNCTION public.calomnie_distribuer_interne(
  p_requete text,
  p_joueur  text,
  p_cible   text,
  p_pnj_nom text,
  p_vol_pnj integer,
  p_instant timestamptz
)
RETURNS jsonb
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
DECLARE
  v_rej    jsonb;
  v_p      record;
  v_v      record;
  v_inv    jsonb;
  v_nom    text;
  v_cle    text;
  v_jour   date;
  v_pays   text;
  v_taux   integer;
  v_jet    integer;
  v_jet2   integer;
  v_effet  jsonb;
  v_mandat jsonb;
  v_res    text;
BEGIN
  v_rej := public.assemblee_requete_ouvrir(p_requete, p_joueur, 'tract_calomnieux');
  IF v_rej IS NOT NULL THEN RETURN v_rej; END IF;

  IF COALESCE(btrim(p_cible), '') = '' OR p_cible = p_joueur THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'cible_invalide'));
  END IF;

  SELECT country, current_city, stats, resources, inventory, pa INTO v_p
    FROM public.personnages WHERE name = p_joueur;
  IF NOT FOUND THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'joueur_introuvable'));
  END IF;

  SELECT country, domicile INTO v_v FROM public.personnages WHERE name = p_cible;
  IF NOT FOUND THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'cible_introuvable'));
  END IF;
  v_pays := COALESCE(NULLIF(btrim(COALESCE(v_v.domicile ->> 'country', '')), ''), v_v.country);
  IF COALESCE(btrim(v_pays), '') = '' THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'juridiction_indeterminee'));
  END IF;

  v_inv := CASE WHEN jsonb_typeof(v_p.inventory) = 'array' THEN v_p.inventory ELSE '[]'::jsonb END;
  IF NOT EXISTS (
    SELECT 1 FROM jsonb_array_elements(v_inv) i
     WHERE i ->> 'type' = 'tract_calomnieux' AND i ->> 'cible' = p_cible
       AND jsonb_typeof(i -> 'quantite') = 'number' AND (i ->> 'quantite')::numeric >= 1
  ) THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'tract_absent'));
  END IF;

  IF COALESCE(v_p.pa, 0) < 1 THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'pa_insuffisants'));
  END IF;

  v_nom := public.tracts_electoraux_nom_pnj(p_pnj_nom);
  IF v_nom = '' THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'pnj_invalide'));
  END IF;
  v_cle := COALESCE(v_p.country, '') || ':' || COALESCE(v_p.current_city, '') || ':' || v_nom;
  v_jour := (p_instant AT TIME ZONE 'Europe/Paris')::date;

  PERFORM pg_advisory_xact_lock(hashtext('calomnie|' || v_cle || '|' || p_cible || '|' || v_jour::text));
  IF EXISTS (SELECT 1 FROM public.calomnies_actes
              WHERE pnj_cle = v_cle AND cible = p_cible AND jour_paris = v_jour AND resultat = 'reussite') THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'deja_convaincu'));
  END IF;

  v_taux := public.tracts_electoraux_taux(
    public.assemblee_stat_base(v_p.stats, 'CHA'),
    CASE WHEN jsonb_typeof(v_p.resources -> 'inf') = 'number' THEN (v_p.resources ->> 'inf')::numeric ELSE 0 END,
    LEAST(30, GREATEST(0, COALESCE(p_vol_pnj, 10))));
  v_jet := floor(random() * 100)::integer + 1;

  IF v_jet <= v_taux THEN
    v_res := 'reussite';
  ELSE
    v_jet2 := floor(random() * 100)::integer + 1;
    v_res := CASE WHEN v_jet2 <= 10 THEN 'echec_critique' ELSE 'echec' END;
  END IF;

  INSERT INTO public.calomnies_actes (auteur, cible, pnj_cle, pnj_nom, jour_paris, resultat,
                                      pays_faits, ville_faits, pays_competent, jet, taux)
  VALUES (p_joueur, p_cible, v_cle, p_pnj_nom, v_jour, v_res,
          v_p.country, v_p.current_city, v_pays, v_jet, v_taux);

  IF v_res = 'reussite' THEN
    v_effet := public.calomnie_appliquer_effet(p_cible, -5, -2);
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object(
      'ok', true, 'reussi', true, 'critique', false, 'consomme', 1, 'pa', 1,
      'jet', v_jet, 'taux', v_taux, 'pop', v_effet -> 'pop', 'inf', v_effet -> 'inf',
      'juridiction', v_pays));
  END IF;

  IF v_res = 'echec' THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object(
      'ok', true, 'reussi', false, 'critique', false, 'consomme', 1, 'pa', 1,
      'jet', v_jet, 'taux', v_taux, 'juridiction', v_pays));
  END IF;

  IF v_pays IS NOT DISTINCT FROM v_p.country THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object(
      'ok', true, 'reussi', false, 'critique', true, 'consomme', 1, 'pa', 1,
      'jet', v_jet, 'taux', v_taux, 'juridiction', v_pays, 'poursuite', 'flagrant_delit'));
  END IF;
  v_mandat := public.calomnie_inscrire_mandat(p_joueur, p_cible, v_pays, v_p.current_city, p_instant);
  RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object(
    'ok', true, 'reussi', false, 'critique', true, 'consomme', 1, 'pa', 1,
    'jet', v_jet, 'taux', v_taux, 'juridiction', v_pays, 'poursuite', 'mandat',
    'mandat_inscrit', COALESCE(v_mandat -> 'ok', 'false'::jsonb)));
END;
$$;

CREATE OR REPLACE FUNCTION public.calomnie_distribuer(
  p_requete text,
  p_joueur  text,
  p_cible   text,
  p_pnj_nom text,
  p_vol_pnj integer DEFAULT 10
)
RETURNS jsonb
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT public.calomnie_distribuer_interne(p_requete, p_joueur, p_cible, p_pnj_nom, p_vol_pnj, now());
$$;

REVOKE ALL ON FUNCTION public.calomnie_appliquer_effet(text, integer, integer)                     FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.calomnie_inscrire_mandat(text, text, text, text, timestamptz)        FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.calomnie_distribuer_interne(text, text, text, text, integer, timestamptz) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.calomnie_distribuer(text, text, text, text, integer)                 FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.calomnie_appliquer_effet(text, integer, integer)                   TO service_role;
GRANT EXECUTE ON FUNCTION public.calomnie_inscrire_mandat(text, text, text, text, timestamptz)      TO service_role;
GRANT EXECUTE ON FUNCTION public.calomnie_distribuer_interne(text, text, text, text, integer, timestamptz) TO service_role;
GRANT EXECUTE ON FUNCTION public.calomnie_distribuer(text, text, text, text, integer)               TO anon, authenticated, service_role;