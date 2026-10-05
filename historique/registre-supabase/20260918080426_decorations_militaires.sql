-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260918080426
-- Nom original      : decorations_militaires
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-18 08:04:26 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : f247434ebb0e35c6ad7e1b65d7913ada
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
-- DECORATIONS MILITAIRES (18 septembre 2026)
--
-- AUCUNE GRILLE DE MERITE, AUCUNE LISTE DE MEDAILLES. Le jeu ne decide jamais qui merite quoi :
-- il enregistre qu'une autorite a decore quelqu'un, et il dit laquelle. C'est une decision
-- humaine, pas un declenchement algorithmique -- donc pas de seuil de jours de service, pas de
-- condition de faits d'armes, pas de catalogue ferme d'intitules. L'intitule est SAISI par celui
-- qui decore.
--
-- TROIS NIVEAUX, ET LE NIVEAU N'EST PAS DECLARE : il est DEDUIT du poste atteste de l'acteur.
-- Un Commandant ne peut pas s'auto-attribuer une decoration d'Etat en cochant une case.
--   commandant -> 'compagnie'   (Commandant de la Caserne)
--   min_def    -> 'armee'       (Ministre de la Defense, dit Ministre de la Guerre)
--   president  -> 'etat'        (chef de l'Etat)
CREATE TABLE IF NOT EXISTS public.decorations_militaires (
  id            bigserial PRIMARY KEY,
  decore        text NOT NULL,
  pays          text NOT NULL,
  niveau        text NOT NULL CHECK (niveau IN ('compagnie','armee','etat')),
  intitule      text NOT NULL,
  citation      text,
  decerne_par   text NOT NULL,
  poste_decernant text NOT NULL,
  decerne_le    timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS decorations_militaires_decore_idx
  ON public.decorations_militaires (decore, decerne_le DESC);

-- Une meme autorite ne decerne pas deux fois EXACTEMENT la meme decoration a la meme personne.
-- C'est une garde anti-double-clic, pas une limite de discretion : elle n'empeche ni une seconde
-- decoration d'un autre intitule, ni la meme decoration par une autre autorite.
CREATE UNIQUE INDEX IF NOT EXISTS decorations_militaires_unicite_idx
  ON public.decorations_militaires (decore, decerne_par, intitule);

ALTER TABLE public.decorations_militaires ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS decorations_lecture_publique ON public.decorations_militaires;
-- Une decoration est un HONNEUR PUBLIC : tout le monde peut la lire, c'est le but.
CREATE POLICY decorations_lecture_publique ON public.decorations_militaires
  FOR SELECT TO authenticated USING (true);

REVOKE ALL ON public.decorations_militaires FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.decorations_militaires TO authenticated;
REVOKE ALL ON SEQUENCE public.decorations_militaires_id_seq FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.militaire_decorer(
  p_decore text, p_intitule text, p_citation text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_moi text; v_poste text; v_niveau text; v_pays_moi text; v_pays_cible text; v_id bigint;
  v_intitule text; v_citation text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  v_poste := public.acteur_poste_courant();
  v_niveau := CASE v_poste WHEN 'commandant' THEN 'compagnie'
                           WHEN 'min_def'    THEN 'armee'
                           WHEN 'president'  THEN 'etat' END;
  IF v_niveau IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante', 'poste', v_poste);
  END IF;

  v_intitule := btrim(coalesce(p_intitule, ''));
  IF length(v_intitule) < 3 OR length(v_intitule) > 120 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'intitule_invalide');
  END IF;
  v_citation := nullif(btrim(coalesce(p_citation, '')), '');
  IF length(coalesce(v_citation, '')) > 600 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'citation_trop_longue');
  END IF;

  IF btrim(coalesce(p_decore,'')) = v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'auto_decoration_refusee');
  END IF;

  SELECT country INTO v_pays_moi   FROM public.personnages_donnees WHERE name = v_moi;
  SELECT country INTO v_pays_cible FROM public.personnages_donnees WHERE name = btrim(coalesce(p_decore,''));
  IF v_pays_cible IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'decore_introuvable'); END IF;
  -- On ne decore que les siens. Decorer un etranger serait un acte diplomatique, pas militaire.
  IF v_pays_cible IS DISTINCT FROM v_pays_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'hors_juridiction');
  END IF;

  BEGIN
    INSERT INTO public.decorations_militaires (decore, pays, niveau, intitule, citation, decerne_par, poste_decernant)
    VALUES (btrim(p_decore), v_pays_cible, v_niveau, v_intitule, v_citation, v_moi, v_poste)
    RETURNING id INTO v_id;
  EXCEPTION WHEN unique_violation THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_decernee');
  END;

  RETURN jsonb_build_object('ok', true, 'id', v_id, 'decore', btrim(p_decore),
    'niveau', v_niveau, 'intitule', v_intitule, 'decerne_par', v_moi, 'poste', v_poste);
END;
$$;

REVOKE ALL ON FUNCTION public.militaire_decorer(text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.militaire_decorer(text, text, text) TO authenticated;