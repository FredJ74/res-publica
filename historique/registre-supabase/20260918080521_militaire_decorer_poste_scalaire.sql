-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260918080521
-- Nom original      : militaire_decorer_poste_scalaire
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-18 08:05:21 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 938074558865158ce506cc8617d36b21
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
-- CORRECTIF : acteur_poste_courant() renvoie une TABLE(nom, poste_id, poste_city, pays), pas un
-- texte. L'affecter a une variable text donnait la representation du RECORD entier --
-- "(zztestCmdt,,,republic)" -- et AUCUN poste ne correspondait donc jamais. Le refus etait
-- systematique : la faille etait un faux negatif, pas un faux positif, mais la fonction etait
-- integralement morte. Attrape au banc parce que le motif rapporte contenait le record.
CREATE OR REPLACE FUNCTION public.militaire_decorer(
  p_decore text, p_intitule text, p_citation text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_moi text; v_poste text; v_niveau text; v_pays_moi text; v_pays_cible text; v_id bigint;
  v_intitule text; v_citation text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT a.poste_id INTO v_poste FROM public.acteur_poste_courant() a;
  v_niveau := CASE v_poste WHEN 'commandant' THEN 'compagnie'
                           WHEN 'min_def'    THEN 'armee'
                           WHEN 'president'  THEN 'etat' END;
  IF v_niveau IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante',
      'poste', coalesce(v_poste, '(aucun)'));
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