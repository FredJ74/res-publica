-- RACCORDEMENT IMMOBILIER DU COMBAT CONTRE LES SQUATTEURS (29/10/2026, Claude). NON APPLIQUÉE.
-- Règle #57-5 (décidée) : jet final <50 défaite ; 50-89 neutralisation, trace DÉLIT ;
-- 90-100 squatteurs tués, CADAVRES laissés, trace CRIME ; la dissimulation du corps n'efface pas
-- le crime. Aucun moteur de combat ici : le moteur universel de Codex calcule le jet et applique
-- les suites de la défaite (hôpital, PA) ; il appelle ensuite cette fonction, réservée au serveur.
-- Identification et contexte : `terrain_occupation_lire` (existante) rend l'occupation
-- (squatter_cool / squatter_agr) et le terrain ; aucun ajout nécessaire.
-- DÉPENDANCES : (1) Codex — résolution d'un combat collectif PJ (+ gros bras) contre un groupe
-- de PNJ rendant un score 0-100 ; (2) Fred — acte pénal du délit (voir RELAIS.md), d'où le
-- paramètre `p_acte_delit` : sans acte déclaré dans `actes_illegaux`, seule la trace est posée.
CREATE OR REPLACE FUNCTION public.terrain_squatteurs_issue_interne(
  p_terrain text, p_acteur text, p_jet integer, p_requete uuid, p_acte_delit text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE p record; t record; a record; e jsonb; occ text; issue text; r jsonb; repere boolean := false;
BEGIN
  IF NOT public.est_appel_serveur() THEN RETURN jsonb_build_object('ok',false,'raison','reserve_au_serveur'); END IF;
  IF p_jet IS NULL OR p_jet < 0 OR p_jet > 100 OR p_requete IS NULL THEN
    RETURN jsonb_build_object('ok',false,'raison','parametres_invalides'); END IF;
  SELECT * INTO a FROM public.terrain_acquisitions_recus WHERE acteur = p_acteur AND requete = p_requete;
  IF FOUND THEN RETURN a.resultat || jsonb_build_object('rejeu',true); END IF;
  SELECT * INTO p FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','acteur_introuvable'); END IF;
  SELECT * INTO t FROM public.terrains_etat
   WHERE id = p.country||'_'||p_terrain AND building_id = p_terrain FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','terrain_introuvable'); END IF;
  e := t.data::jsonb; occ := e->>'pnj';
  IF occ NOT IN ('squatter_cool','squatter_agr') THEN RETURN jsonb_build_object('ok',false,'raison','aucun_squatteur'); END IF;
  IF p.current_building IS DISTINCT FROM p_terrain OR p.current_city IS DISTINCT FROM e->>'city' THEN
    RETURN jsonb_build_object('ok',false,'raison','pas_sur_place'); END IF;
  issue := CASE WHEN p_jet < 50 THEN 'defaite' WHEN p_jet < 90 THEN 'neutralises' ELSE 'tues' END;
  IF issue = 'neutralises' THEN
    -- Terrain libéré pour cette visite ; le tirage de la visite suivante reste celui du socle
    -- d'occupation (aucune réapparition après compromis ou achat).
    e := public.terrain_etat_fusionner_interne(t.id, jsonb_build_object('pnj', NULL, 'pnjData', NULL), t.country);
    PERFORM public.crime_tracer_interne(p_acteur, 'neutralisation_squatteurs', p_terrain);
    IF p_acte_delit IS NOT NULL AND EXISTS (SELECT 1 FROM public.actes_illegaux WHERE fn = p_acte_delit) THEN
      repere := public.crime_detecter_interne(p_acteur, p_acte_delit, true);
    END IF;
  ELSIF issue = 'tues' THEN
    -- Les cadavres restent : le parcours existant (police, enquête, dissimulation) s'applique.
    e := public.terrain_etat_fusionner_interne(t.id, jsonb_build_object('pnj', 'cadavre', 'pnjData', NULL), t.country);
    PERFORM public.crime_tracer_interne(p_acteur, 'assassinat', p_terrain);
    repere := public.crime_detecter_interne(p_acteur, 'assassinat', true);
  END IF;
  r := jsonb_build_object('ok',true,'issue',issue,'jet',p_jet,'occupation',occ,'repere',repere,
         'terrainLibre', issue = 'neutralises', 'cadavres', issue = 'tues');
  INSERT INTO public.terrain_acquisitions_recus VALUES (p_acteur, p_requete, t.id, 'squatteurs_issue', jsonb_build_object('jet',p_jet), r);
  RETURN r || jsonb_build_object('etat', e);
END;
$function$;
REVOKE ALL ON FUNCTION public.terrain_squatteurs_issue_interne(text,text,integer,uuid,text) FROM PUBLIC, anon, authenticated;
