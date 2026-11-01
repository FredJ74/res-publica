-- APPLICATION ATTESTÉE par le registre canonique du 31/10/2026 : version 20261027192719.
-- Archivage documentaire seulement ; ne pas rejouer.
-- APPLIQUEE le 27/10/2026 par Claude via MCP apply_migration -- registre Supabase 20261027192719. Eprouvee au role authenticated.
-- ============================================================================
-- INVENTAIRE, LOT 3 : LES TRACTS IMPRIMES SONT DEPOSES PAR LE SERVEUR (27 octobre 2026)
-- ============================================================================
-- imprimerie_produire_tracts encaissait la production (PA, prix, bois, salaire) mais l'ecran
-- ajoutait lui-meme les tracts a l'inventaire. tracts_imprimer produit ET depose, avec les memes
-- regles d'empilement que l'ecran :
--   * tracts electoraux : meme cible et meme sens (POUR / CONTRE), hors lots epingles a un scrutin
--     et hors tracts de quete ;
--   * tracts calomnieux : un lot de 10, seulement a la Tribune ou a l'imprimerie-librairie,
--     empiles par cible ; la detection (imprimer_tracts_calomnieux) est tiree par le serveur.
-- Idempotente. Aucun acte de joueur.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.tracts_imprimer(p_pays text, p_ville text, p_batiment text, p_lots integer,
                                                 p_cible text, p_sens text, p_calomnieux boolean DEFAULT false)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_r jsonb; v_inv jsonb; v_qte integer; v_sens text; v_trouve boolean := false; v_repere boolean := false;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF coalesce(btrim(p_cible), '') = '' THEN RETURN jsonb_build_object('ok', false, 'raison', 'cible_requise'); END IF;
  IF p_calomnieux AND p_batiment NOT IN ('la-tribune', 'imprimerie-librairie') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'atelier_introuvable'); END IF;
  v_r := public.imprimerie_produire_tracts(v_moi, p_pays, p_ville, p_batiment, CASE WHEN p_calomnieux THEN 1 ELSE p_lots END);
  IF coalesce((v_r ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_r; END IF;
  v_qte := 10 * CASE WHEN p_calomnieux THEN 1 ELSE greatest(1, p_lots) END;
  v_sens := CASE WHEN p_sens = 'contre' THEN 'contre' ELSE 'pour' END;

  SELECT CASE WHEN jsonb_typeof(inventory) = 'array' THEN inventory ELSE '[]'::jsonb END INTO v_inv
    FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  SELECT coalesce(jsonb_agg(CASE WHEN NOT v_trouve_ligne THEN e ELSE e || jsonb_build_object('quantite', coalesce((e ->> 'quantite')::numeric, 0) + v_qte) END ORDER BY o),
                  '[]'::jsonb), bool_or(v_trouve_ligne)
    INTO v_inv, v_trouve
    FROM (SELECT e, o, coalesce(o = (SELECT min(o2) FROM jsonb_array_elements(v_inv) WITH ORDINALITY y(e2, o2)
                             WHERE CASE WHEN p_calomnieux
                                        THEN e2 ->> 'type' = 'tract_calomnieux' AND e2 ->> 'cible' = p_cible
                                        ELSE e2 ->> 'type' = 'tract' AND e2 ->> 'cible' = p_cible
                                             AND coalesce(e2 ->> 'tractType', 'pour') = v_sens
                                             AND coalesce(e2 ->> 'electionPosteId', '') = '' AND coalesce(e2 ->> 'origineQuete', '') = '' END), false) AS v_trouve_ligne
            FROM jsonb_array_elements(v_inv) WITH ORDINALITY x(e, o)) z;
  IF NOT coalesce(v_trouve, false) THEN
    v_inv := v_inv || jsonb_build_array(CASE WHEN p_calomnieux
      THEN jsonb_build_object('type', 'tract_calomnieux', 'name', 'Tracts calomnieux contre ' || p_cible, 'icon', 'ti-alert-triangle',
                              'cible', p_cible, 'quantite', v_qte, 'legal', false)
      ELSE jsonb_build_object('type', 'tract', 'name', 'Tracts ' || CASE WHEN v_sens = 'contre' THEN 'CONTRE ' ELSE 'POUR ' END || p_cible,
                              'icon', 'ti-file-description', 'tractType', v_sens, 'cible', p_cible, 'quantite', v_qte, 'legal', true) END);
  END IF;
  UPDATE public.personnages_donnees SET inventory = v_inv WHERE name = v_moi;
  IF p_calomnieux THEN v_repere := public.crime_detecter_interne(v_moi, 'imprimer_tracts_calomnieux', true); END IF;
  RETURN v_r || jsonb_build_object('quantite', v_qte, 'repere', v_repere)
    || (SELECT jsonb_build_object('inventory', inventory, 'revision', inventory_revision, 'recherche', recherche, 'dis', resources -> 'dis')
          FROM public.personnages_donnees WHERE name = v_moi);
END; $function$;

REVOKE ALL ON FUNCTION public.tracts_imprimer(text, text, text, integer, text, text, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.tracts_imprimer(text, text, text, integer, text, text, boolean) TO authenticated;
