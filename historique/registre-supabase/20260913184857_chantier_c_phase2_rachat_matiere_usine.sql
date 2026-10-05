-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260913184857
-- Nom original      : chantier_c_phase2_rachat_matiere_usine
-- Categorie         : MIXTE -- MIXTE (structure ET mutation de donnees)
-- Date (deduite de la version) : 2026-09-13 18:48:57 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 3c31e3aca0dbbda598f048e91122df89
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
-- ============================================================================
-- CHANTIER C / PHASE 2 — F6 : RACHAT DE MATIERE PAR UNE USINE
-- 13 septembre 2026. Le joueur vend sa matiere premiere ; l'usine le paie.
-- ============================================================================
-- CE QUI ETAIT OUVERT : le navigateur fixait le montant que l'usine lui versait,
-- retirait le lot de son propre inventaire et reecrivait la caisse de l'usine.
-- Une vente est desormais arbitree par le serveur de bout en bout.

-- Miroir des deux configurations de rachat, transcrites a l'identique :
--   USINES_RACHAT_PRIX_DETAIL : les usines qui rachetent au tarif DETAIL
--     (prix de base) plutot qu'au tarif fournisseur -- la Scierie Guy Tarembois.
--   MATIERES_HORS_CHAINE_PAR_BATIMENT : matieres qu'une usine accepte alors
--     qu'aucune de ses recettes ne les consomme encore.
CREATE TABLE IF NOT EXISTS public.usines_rachat_config (
  cle text PRIMARY KEY,            -- pays|ville|buildingId
  prix_detail boolean NOT NULL DEFAULT false,
  matieres_hors_chaine jsonb NOT NULL DEFAULT '[]'::jsonb
);
ALTER TABLE public.usines_rachat_config ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS usines_rachat_config_lecture ON public.usines_rachat_config;
CREATE POLICY usines_rachat_config_lecture ON public.usines_rachat_config
  FOR SELECT TO anon, authenticated USING (true);
TRUNCATE public.usines_rachat_config;
INSERT INTO public.usines_rachat_config VALUES
('republic|ville_a|zone-production', true, '["bois","minerai"]'::jsonb);

CREATE OR REPLACE FUNCTION public.vendre_matiere_a_usine(
  p_acteur text, p_pays text, p_ville text, p_batiment text, p_matiere text, p_qte integer)
RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = public, pg_temp AS $$
DECLARE
  v_cle text := p_pays || '|' || coalesce(p_ville,'') || '|' || p_batiment;
  v_id text := p_pays || '_' || p_ville || '_' || p_batiment;
  v_accepte boolean; v_detail boolean;
  v_etat jsonb; v_usine jsonb; v_sm jsonb; v_cmm jsonb;
  v_plafond numeric; v_stock numeric; v_place numeric;
  v_prix numeric; v_total numeric; v_caisse numeric;
  v_inv jsonb; v_detenu numeric; v_arg numeric; v_liquide numeric;
  v_cout_moyen numeric;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  IF p_qte IS NULL OR p_qte <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'quantite_invalide');
  END IF;

  -- Matiere acceptee ? Par une chaine de l'usine, ou par sa liste hors chaine.
  SELECT coalesce(prix_detail, false),
         EXISTS (SELECT 1 FROM public.chaines_production_usine c
                 WHERE c.building_id = p_batiment AND c.matiere = p_matiere)
         OR coalesce(matieres_hors_chaine, '[]'::jsonb) ? p_matiere
    INTO v_detail, v_accepte
  FROM public.usines_rachat_config WHERE cle = v_cle;
  IF v_accepte IS NULL THEN
    v_detail := false;
    SELECT EXISTS (SELECT 1 FROM public.chaines_production_usine c
                   WHERE c.building_id = p_batiment AND c.matiere = p_matiere) INTO v_accepte;
  END IF;
  IF NOT v_accepte THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'matiere_non_acceptee');
  END IF;

  SELECT coalesce(inventory,'[]'::jsonb), coalesce(arg,0), coalesce(liquide,0)
    INTO v_inv, v_arg, v_liquide
  FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  IF v_inv IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;
  v_detenu := public.inventaire_quantite(v_inv, p_matiere);
  IF v_detenu < p_qte THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'stock_personnel_insuffisant', 'detenu', v_detenu);
  END IF;

  SELECT public.batiment_etat_lire(data) INTO v_etat FROM public.batiments_etat WHERE id = v_id FOR UPDATE;
  IF v_etat IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'introuvable'); END IF;
  v_usine := coalesce(v_etat->'usine', '{}'::jsonb);
  v_sm := coalesce(v_usine->'stockMatieres', '{}'::jsonb);
  v_cmm := coalesce(v_usine->'coutMoyenMatieres', '{}'::jsonb);
  v_caisse := coalesce((v_usine->>'caisse')::numeric, 0);

  SELECT plafond, CASE WHEN v_detail THEN prix_base ELSE prix_achat_fournisseur END
    INTO v_plafond, v_prix FROM public.ressources_economie WHERE cle = p_matiere;
  IF v_prix IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'ressource_inconnue'); END IF;

  v_stock := coalesce((v_sm->>p_matiere)::numeric, 0);
  v_place := greatest(0, coalesce(v_plafond,0) - v_stock);
  IF v_place < p_qte THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'stock_plein', 'placeRestante', v_place);
  END IF;

  v_total := v_prix * p_qte;
  IF v_caisse < v_total THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caisse_insuffisante', 'caisse', v_caisse);
  END IF;

  -- Cout moyen pondere, meme calcul que crediterStockMatiereCommerce.
  v_cout_moyen := CASE WHEN v_stock + p_qte = 0 THEN 0
    ELSE round(((coalesce((v_cmm->>p_matiere)::numeric, 0) * v_stock) + (v_prix * p_qte))
               / (v_stock + p_qte), 4) END;

  UPDATE public.personnages_donnees
     SET inventory = public.inventaire_retirer(v_inv, p_matiere, p_qte),
         arg = v_arg + v_total, liquide = v_liquide + v_total
   WHERE name = p_acteur;

  v_usine := v_usine || jsonb_build_object(
    'stockMatieres', jsonb_set(v_sm, ARRAY[p_matiere], to_jsonb(v_stock + p_qte)),
    'coutMoyenMatieres', jsonb_set(v_cmm, ARRAY[p_matiere], to_jsonb(v_cout_moyen)),
    'caisse', v_caisse - v_total);
  UPDATE public.batiments_etat
     SET data = to_jsonb((v_etat || jsonb_build_object('usine', v_usine))::text), updated_at = now()
   WHERE id = v_id;

  RETURN jsonb_build_object('ok', true, 'total', v_total, 'prixUnitaire', v_prix, 'qte', p_qte,
    'arg', v_arg + v_total, 'liquide', v_liquide + v_total,
    'inventory', public.inventaire_retirer(v_inv, p_matiere, p_qte),
    'caisse_usine', v_caisse - v_total);
END; $$;
REVOKE ALL ON FUNCTION public.vendre_matiere_a_usine(text,text,text,text,text,integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.vendre_matiere_a_usine(text,text,text,text,text,integer) TO authenticated;