-- =====================================================================================
-- « ACCÉLÉRER LE RENDEZ-VOUS (CORRUPTION) » PAR LE SERVEUR — 29/10/2026 (Claude)
--
-- L'écran calculait seul la nouvelle date du rendez-vous chez le notaire et l'envoyait en
-- patch par `terrain_compromis_acte('achat_direct_accelerer')`, qui l'enregistrait telle
-- quelle ; le paiement (2 PA + 800 FR) partait à part, avant. Un appel direct posait donc un
-- rendez-vous immédiat, sans rien payer. (Le prix, lui, est protégé : l'acte notarié relit le
-- reçu du dépôt.)
--
-- Nouvelle porte `terrain_rdv_notaire_accelerer` : une seule transaction, paiement par
-- `payer_ordre` au tarif déclaré, délai restant divisé par deux À PARTIR DE LA DATE
-- ENREGISTRÉE, tolérance de 24 h recalculée, reçu idempotent. Règle de jeu inchangée.
-- L'ancien acte reste ouvert pour l'écran en ligne ; il sera fermé après la livraison par
-- 20261029160000 (à appliquer après la livraison).
-- =====================================================================================
CREATE OR REPLACE FUNCTION public.terrain_rdv_notaire_accelerer(p_terrain text, p_requete uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE moi text := public.mon_personnage(); p record; t record; a record; e jsonb; ad jsonb; r jsonb;
  ms numeric := floor(extract(epoch FROM clock_timestamp())*1000); restant numeric; nouvelle numeric;
BEGIN
  IF moi IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie'); END IF;
  IF p_requete IS NULL OR p_terrain IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','parametres_invalides'); END IF;
  SELECT * INTO p FROM public.personnages_donnees WHERE name = moi FOR UPDATE;
  SELECT * INTO a FROM public.terrain_acquisitions_recus WHERE acteur = moi AND requete = p_requete;
  IF FOUND THEN
    IF a.terrain IS DISTINCT FROM p.country||'_'||p_terrain OR a.action <> 'rdv_accelerer' THEN
      RETURN jsonb_build_object('ok',false,'raison','requete_reutilisee'); END IF;
    SELECT data::jsonb INTO e FROM public.terrains_etat WHERE id = a.terrain;
    RETURN a.resultat || jsonb_build_object('rejeu',true,'etat',e);
  END IF;
  IF coalesce(p.hp,0) <= 0 OR EXISTS(SELECT 1 FROM public.detention_active(moi))
     OR coalesce(p.hospitalisation->>'dateFinParis','') > (statement_timestamp() AT TIME ZONE 'Europe/Paris')::date::text THEN
    RETURN jsonb_build_object('ok',false,'raison','acteur_indisponible'); END IF;
  SELECT * INTO t FROM public.terrains_etat
   WHERE id = p.country||'_'||p_terrain AND country = p.country AND building_id = p_terrain FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','terrain_introuvable'); END IF;
  e := t.data::jsonb; ad := e->'achatDirect';
  IF coalesce(e->>'succession_gel','') <> '' THEN RETURN jsonb_build_object('ok',false,'raison','terrain_gele'); END IF;
  IF jsonb_typeof(ad) IS DISTINCT FROM 'object' OR ad->>'demandeur' IS DISTINCT FROM moi THEN
    RETURN jsonb_build_object('ok',false,'raison','pas_mon_achat_direct'); END IF;
  IF p.current_building IS DISTINCT FROM p_terrain OR p.current_city IS DISTINCT FROM e->>'city' THEN
    RETURN jsonb_build_object('ok',false,'raison','pas_sur_place'); END IF;
  IF (ad->>'dateAchat') !~ '^[0-9]+(\.[0-9]+)?$' THEN RETURN jsonb_build_object('ok',false,'raison','rendez_vous_invalide'); END IF;
  restant := (ad->>'dateAchat')::numeric - ms;
  IF restant <= 0 THEN RETURN jsonb_build_object('ok',false,'raison','rendez_vous_deja_arrive'); END IF;
  -- Paiement au tarif déclaré de l'ordre ; tout échec ensuite annule aussi le paiement.
  r := public.payer_ordre(moi, 'corrompre_rdv_notaire', 2, 800);
  IF r->>'ok' IS DISTINCT FROM 'true' THEN
    RETURN jsonb_build_object('ok',false,'raison',coalesce(r->>'raison','paiement_refuse')); END IF;
  nouvelle := ms + floor(restant / 2);
  ad := ad || jsonb_build_object('dateAchat', nouvelle, 'dateLimite', nouvelle + 86400000);
  e := public.terrain_etat_fusionner_interne(t.id, jsonb_build_object('achatDirect', ad), t.country);
  r := jsonb_build_object('ok',true,'dateAchat',nouvelle,'dateLimite',nouvelle + 86400000,'paiement',r);
  INSERT INTO public.terrain_acquisitions_recus VALUES (moi, p_requete, t.id, 'rdv_accelerer', '{}'::jsonb, r);
  UPDATE public.personnages_donnees SET updated_at = clock_timestamp() WHERE name = moi;
  RETURN r || jsonb_build_object('etat', e);
END;
$function$;
REVOKE ALL ON FUNCTION public.terrain_rdv_notaire_accelerer(text,uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.terrain_rdv_notaire_accelerer(text,uuid) TO authenticated;
