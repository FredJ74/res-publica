-- « CORROMPRE UN FONCTIONNAIRE (ACCÉLÉRER) » PAR LE SERVEUR — 29/10/2026 (Claude).
-- Défaut reproduit au rôle authenticated : `terrain_permis_acte('permis_accelerer')` fusionnait le
-- permis envoyé par l'écran. Un demandeur posait lui-même `statut: valide` ou une durée d'un jour,
-- sans rien payer ; la découverte (25 %) et la division de la durée étaient tirées par l'écran.
-- Nouvelle porte : paiement au tarif déclaré (2 PA + 800 FR), découverte 25 % tirée par le serveur
-- (détection certaine par le socle pénal commun), sinon durée restante divisée par deux. Règle
-- inchangée. L'ancien acte est fermé après la livraison par 20261029160000.
CREATE OR REPLACE FUNCTION public.terrain_permis_corrompre(p_terrain text, p_requete uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE moi text := public.mon_personnage(); p record; t record; a record; e jsonb; pm jsonb; r jsonb;
  d integer; decouvert boolean; repere boolean := false;
BEGIN
  IF moi IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie'); END IF;
  IF p_requete IS NULL OR p_terrain IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','parametres_invalides'); END IF;
  SELECT * INTO p FROM public.personnages_donnees WHERE name = moi FOR UPDATE;
  SELECT * INTO a FROM public.terrain_acquisitions_recus WHERE acteur = moi AND requete = p_requete;
  IF FOUND THEN
    IF a.action <> 'permis_corrompre' OR a.terrain IS DISTINCT FROM p.country||'_'||p_terrain THEN
      RETURN jsonb_build_object('ok',false,'raison','requete_reutilisee'); END IF;
    RETURN a.resultat || jsonb_build_object('rejeu',true) || public.crime_etat_acteur_interne(moi);
  END IF;
  SELECT * INTO t FROM public.terrains_etat
   WHERE id = p.country||'_'||p_terrain AND country = p.country AND building_id = p_terrain FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','terrain_introuvable'); END IF;
  e := t.data::jsonb; pm := e->'permis';
  IF coalesce(e->>'succession_gel','') <> '' THEN RETURN jsonb_build_object('ok',false,'raison','terrain_gele'); END IF;
  IF p.current_building IS DISTINCT FROM p_terrain OR p.current_city IS DISTINCT FROM e->>'city' THEN
    RETURN jsonb_build_object('ok',false,'raison','pas_sur_place'); END IF;
  IF jsonb_typeof(pm) IS DISTINCT FROM 'object' OR pm->>'statut' IS DISTINCT FROM 'instruction' THEN
    RETURN jsonb_build_object('ok',false,'raison','aucune_instruction'); END IF;
  r := public.payer_ordre(moi, 'corrompre_fonctionnaire_permis', 2, 800);
  IF r->>'ok' IS DISTINCT FROM 'true' THEN
    RETURN jsonb_build_object('ok',false,'raison',coalesce(r->>'raison','paiement_refuse')); END IF;
  decouvert := random() < 0.25;
  IF decouvert THEN
    repere := public.crime_detecter_interne(moi, 'corruption_fonctionnaire', false);
    r := jsonb_build_object('ok',true,'decouvert',true,'repere',repere);
  ELSE
    d := greatest(1, floor(coalesce((pm->>'dureeInstruction')::numeric, 1) / 2)::integer);
    pm := pm || jsonb_build_object('dureeInstruction', d,
            'dateInstructionTerminee', coalesce((pm->>'dateDepot')::integer, 0) + d);
    e := public.terrain_etat_fusionner_interne(t.id, jsonb_build_object('permis', pm), t.country);
    r := jsonb_build_object('ok',true,'decouvert',false,'dureeInstruction',d,
            'joursRestants', greatest(0, d - coalesce((pm->>'joursInstructionFaits')::integer,0)));
  END IF;
  INSERT INTO public.terrain_acquisitions_recus VALUES (moi, p_requete, t.id, 'permis_corrompre', '{}'::jsonb, r);
  RETURN r || jsonb_build_object('etat', e) || public.crime_etat_acteur_interne(moi);
END;
$function$;
REVOKE ALL ON FUNCTION public.terrain_permis_corrompre(text,uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.terrain_permis_corrompre(text,uuid) TO authenticated;
