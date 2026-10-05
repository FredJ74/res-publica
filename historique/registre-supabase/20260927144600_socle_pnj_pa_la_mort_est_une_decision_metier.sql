-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260927144600
-- Nom original      : socle_pnj_pa_la_mort_est_une_decision_metier
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-27 14:46:00 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : f1344ba199eafa7ef1a7e662fa395544
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
-- CHECKPOINT A — LES PRIMITIVES PA DEPLACENT LE NOMBRE, ELLES NE TUENT PAS
--
-- POURQUOI CE CORRECTIF. En branchant l'entrainement et la bataille sur les primitives generiques,
-- deux regressions apparaissaient, de la meme cause : j'avais place la mort DANS l'arithmetique.
--
--   1. ENTRAINEMENT. La selection retient les soldats a `pa >= 6`. Un homme a exactement 6 PA
--      tombait donc a 0 et mourait a l'entrainement. L'ancien code ecrivait greatest(0, pa - 6)
--      sans jamais tuer personne. Le cout PA de l'entrainement doit rester un cout, pas une
--      sentence.
--   2. BATAILLE. `militaire_bataille_appliquer` fixe d'abord les PA de la cible (ligne 50) puis,
--      si elle est a 0, appelle `militaire_soldat_supprimer` (ligne 85), qui appelle `pnj_mourir`.
--      Une mort declenchee par `pnj_pa_fixer` aurait donc tue DEUX fois le meme homme : ses
--      possessions auraient ete posees au sol deux fois. C'est exactement la duplication que le
--      cycle de mort generique avait ete ecrit pour empecher.
--
-- LA REGLE, desormais explicite : atteindre 0 PA n'est pas un evenement du socle. Le socle constate
-- l'epuisement et le RAPPORTE (`epuises`) ; c'est le METIER qui decide ce que l'epuisement signifie
-- chez lui -- mort au combat, simple immobilite a l'entrainement, neutralisation ailleurs. Le seul
-- chemin de mort reste `pnj_mourir`, appele par le metier, comme la bataille le fait deja.
--
-- Aucun comportement vivant ne change : avant ce lot, aucune fonction metier n'appelait ces
-- primitives (le drapeau `soldats_blob_autoritaire` les refusait toutes pour la famille soldat).
CREATE OR REPLACE FUNCTION public.pnj_pa_debiter(p_ids text[], p_cout integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_refus jsonb; v_touches integer := 0; v_epuises integer := 0;
BEGIN
  v_refus := public.pnj_pa_garde(p_ids);
  IF v_refus IS NOT NULL THEN RETURN v_refus; END IF;
  IF p_cout IS NULL OR p_cout < 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cout_invalide'); END IF;

  WITH maj AS (
    UPDATE public.pnj_membres
       SET pa = greatest(0, pa - p_cout), maj_le = now()
     WHERE id = ANY(p_ids) AND statut = 'actif'
    RETURNING pa)
  SELECT count(*), count(*) FILTER (WHERE pa = 0) INTO v_touches, v_epuises FROM maj;

  -- `epuises` est une CONSTATATION remise au metier, pas une mort.
  RETURN jsonb_build_object('ok', true, 'touches', v_touches, 'epuises', v_epuises,
                            'cout', p_cout);
END; $$;

CREATE OR REPLACE FUNCTION public.pnj_pa_fixer(p_ids text[], p_valeur integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_refus jsonb; v_n integer := 0; v_val integer;
BEGIN
  v_refus := public.pnj_pa_garde(p_ids);
  IF v_refus IS NOT NULL THEN RETURN v_refus; END IF;
  IF p_valeur IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'valeur_invalide'); END IF;
  v_val := least(public.pnj_pa_max(), greatest(0, p_valeur));
  UPDATE public.pnj_membres SET pa = v_val, maj_le = now()
   WHERE id = ANY(p_ids) AND statut = 'actif';
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RETURN jsonb_build_object('ok', true, 'touches', v_n, 'valeur', v_val,
                            'epuises', CASE WHEN v_val = 0 THEN v_n ELSE 0 END);
END; $$;

REVOKE ALL ON FUNCTION public.pnj_pa_debiter(text[], integer) FROM authenticated, anon;
REVOKE ALL ON FUNCTION public.pnj_pa_fixer(text[], integer)   FROM authenticated, anon;
REVOKE ALL ON FUNCTION public.pnj_pa_crediter(text[], integer) FROM authenticated, anon;
REVOKE ALL ON FUNCTION public.pnj_pa_garde(text[])             FROM authenticated, anon;