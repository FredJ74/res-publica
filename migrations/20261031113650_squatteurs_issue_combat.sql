-- PRÉPARATION NON APPLIQUÉE : rehorodatée après la coupe canonique du 31/10/2026.
-- Ancien fichier : 20261029181000_squatteurs_issue_combat.sql ; aucun changement de règle.
-- RACCORDEMENT IMMOBILIER DU COMBAT CONTRE LES SQUATTEURS (29/10/2026, Claude). NON APPLIQUÉE.
-- CONTRAT (Fred, 29/10/2026) : l'ISSUE RÉELLE du combat commun remplace définitivement l'ancien
-- score final 0-100 de la règle #57-5. Issues : 'defaite' (rien ne change), 'neutralises'
-- (squatteurs hors de combat, trace DÉLIT), 'tues' (CADAVRES laissés, trace CRIME) ; la dissimulation du corps n'efface pas
-- le crime. Aucun moteur de combat ici : le moteur universel de Codex calcule le jet et applique
-- les suites de la défaite (hôpital, PA) ; il appelle ensuite cette fonction, réservée au serveur.
-- Identification et contexte : `terrain_occupation_lire` (existante) rend l'occupation
-- (squatter_cool / squatter_agr) et le terrain ; aucun ajout nécessaire.
-- QUALIFICATION PÉNALE (décision de Fred, 29/10/2026) : neutralisation = AGRESSION (délit mineur,
-- 25 % de détection, 1 jour, 500 FR, comme le hooliganisme) ; mort des squatteurs = requalification
-- en MEURTRE (crime, 25 %, 2 jours, 1 500 FR, comme l'assassinat). Le combat ne cesse que lorsqu'un
-- des deux camps tombe à 0 PA (règle de Fred, pour le moteur de Codex).
-- DÉPENDANCE : Codex — résolution d'un combat collectif PJ (+ gros bras) contre un groupe de PNJ
-- rendant son issue réelle (defaite / neutralises / tues), jusqu'à 0 PA d'un camp.
INSERT INTO public.actes_illegaux (fn, type, detect_rate, peine_jours, amende, decouvrable, maj_le) VALUES
  ('agression', 'delit_mineur', 25, 1, 500, true, now()),
  ('meurtre',   'crime',        25, 2, 1500, true, now())
ON CONFLICT (fn) DO NOTHING;
CREATE OR REPLACE FUNCTION public.terrain_squatteurs_issue_interne(
  p_terrain text, p_acteur text, p_issue text, p_requete uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE p record; t record; a record; e jsonb; occ text; issue text := p_issue; r jsonb; repere boolean := false;
BEGIN
  IF NOT public.est_appel_serveur() THEN RETURN jsonb_build_object('ok',false,'raison','reserve_au_serveur'); END IF;
  IF p_issue IS NULL OR p_issue NOT IN ('defaite','neutralises','tues') OR p_requete IS NULL THEN
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
  IF issue = 'neutralises' THEN
    -- Terrain libéré pour cette visite ; le tirage de la visite suivante reste celui du socle
    -- d'occupation (aucune réapparition après compromis ou achat).
    e := public.terrain_etat_fusionner_interne(t.id, jsonb_build_object('pnj', NULL, 'pnjData', NULL), t.country);
    PERFORM public.crime_tracer_interne(p_acteur, 'agression', p_terrain);
    repere := public.crime_detecter_interne(p_acteur, 'agression', true);
  ELSIF issue = 'tues' THEN
    -- Les cadavres restent : le parcours existant (police, enquête, dissimulation) s'applique.
    e := public.terrain_etat_fusionner_interne(t.id, jsonb_build_object('pnj', 'cadavre', 'pnjData', NULL), t.country);
    PERFORM public.crime_tracer_interne(p_acteur, 'meurtre', p_terrain);
    repere := public.crime_detecter_interne(p_acteur, 'meurtre', true);
  END IF;
  r := jsonb_build_object('ok',true,'issue',issue,'occupation',occ,'repere',repere,
         'terrainLibre', issue = 'neutralises', 'cadavres', issue = 'tues');
  INSERT INTO public.terrain_acquisitions_recus VALUES (p_acteur, p_requete, t.id, 'squatteurs_issue', jsonb_build_object('issue',p_issue), r);
  RETURN r || jsonb_build_object('etat', e);
END;
$function$;
REVOKE ALL ON FUNCTION public.terrain_squatteurs_issue_interne(text,text,text,uuid) FROM PUBLIC, anon, authenticated;
