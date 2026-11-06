-- DON D'ARGENT AUX SQUATTEURS : DECIDE PAR LE SERVEUR (04/11/2026, Claude, reste hors #379).
--
-- Avant : « Donner de l'argent » sur un terrain occupé (confirmerDonArgent, plateau-justice-economie.js)
-- tirait tout à l'écran : refus selon l'ISN, jet de départ, -10 DIS, -10 PV, et `state.arg -= montant`.
-- Depuis que `arg` est un total calculé (20261104013000), ce débit n'atteignait plus aucune poche :
-- le don ne coûtait rien, et le départ des squatteurs n'était posé que dans le cache de l'écran.
--
-- Règles existantes de l'écran, reprises sans changement :
--   * refus du PNJ : jet ≤ max(0, ISN − 50) / 2  → −10 DIS, l'argent n'est pas pris ;
--   * squatteurs agressifs : moins de 500 FR → billets jetés (rien n'est pris, le PA est engagé) ;
--     sinon réussite min(70, 15 + bonus), échec → argent pris et −10 PV ;
--   * squatteurs tranquilles : réussite min(85, CHA × 3 + bonus), échec → argent pris ;
--   * bonus = min(40, ⌊montant / 100⌋) ; ordre `donner_argent_pnj`, 1 PA.
-- Le seul autre occupant possible d'un terrain est un cadavre : on ne lui donne rien (refus nommé).
-- L'argent part des fonds ordinaires (liquide puis Banque nationale) par `argent_debiter_interne` ;
-- il quitte le jeu (les squatteurs sont des PNJ sans caisse).
-- Une requête = un seul effet (reçu dans `terrain_actions_recus`, action « don »).

DO $prevol$
BEGIN
  IF to_regprocedure('public.argent_debiter_interne(text,numeric,text)') IS NULL THEN
    RAISE EXCEPTION 'squatteurs_don : moteur argent_debiter_interne absent (20261104013000)'; END IF;
  IF to_regprocedure('public.terrain_occupation_action_preparer(text,text)') IS NULL
     OR to_regprocedure('public.terrain_etat_fusionner_interne(text,jsonb,text)') IS NULL
     OR to_regprocedure('public.terrain_negociation_jet_interne()') IS NULL
     OR to_regclass('public.terrain_actions_recus') IS NULL THEN
    RAISE EXCEPTION 'squatteurs_don : socle d''occupation absent'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.ordres_couts WHERE fn = 'donner_argent_pnj' AND pa = 1 AND cost = 0) THEN
    RAISE EXCEPTION 'squatteurs_don : coût de donner_argent_pnj non déclaré'; END IF;
END $prevol$;

CREATE OR REPLACE FUNCTION public.terrain_squatteurs_don(p_terrain text, p_montant integer, p_occupation text, p_requete uuid)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE acteur text := public.mon_personnage(); p record; r record; c jsonb; e jsonb; occ text; cle text;
  regles jsonb; isn numeric; cha numeric; dispo numeric; pris numeric; paiement jsonb;
  taux_refus numeric; jet_refus integer; taux numeric; jet integer; bonus integer;
  succes boolean := false; issue text; resultat jsonb;
BEGIN
  IF acteur IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie'); END IF;
  IF p_requete IS NULL OR nullif(p_occupation,'') IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','requete_invalide'); END IF;
  IF p_montant IS NULL OR p_montant <= 0 OR p_montant > 100000000 THEN RETURN jsonb_build_object('ok',false,'raison','montant_invalide'); END IF;
  SELECT * INTO p FROM public.personnages_donnees WHERE name = acteur FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','acteur_introuvable'); END IF;
  -- Rejeu : même requête, même effet, aucun second jet.
  SELECT a.* INTO r FROM public.terrain_actions_recus a WHERE a.acteur = p.id AND a.requete = p_requete;
  IF FOUND THEN
    IF (r.terrain, r.action, r.occupation) IS DISTINCT FROM (p.country||'_'||p_terrain, 'don', p_occupation)
       OR (r.resultat->>'montant')::integer IS DISTINCT FROM p_montant THEN
      RETURN jsonb_build_object('ok',false,'raison','requete_reutilisee'); END IF;
    SELECT data::jsonb INTO e FROM public.terrains_etat WHERE id = r.terrain;
    RETURN r.resultat || jsonb_build_object('rejeu',true,'etat',e);
  END IF;
  -- Mêmes gardes que les autres actes d'occupation (présence, disponibilité, gel, police en route).
  c := public.terrain_occupation_action_preparer(p_terrain, 'police');
  IF c->>'ok' IS DISTINCT FROM 'true' THEN RETURN c; END IF;
  IF c->>'occupation' IS DISTINCT FROM p_occupation THEN
    RETURN jsonb_build_object('ok',false,'raison','occupation_modifiee','etat',c->'etat'); END IF;
  e := c->'etat'; occ := e->>'pnj'; cle := p.country||'_'||p_terrain;
  IF occ NOT IN ('squatter_cool','squatter_agr') THEN
    RETURN jsonb_build_object('ok',false,'raison','aucun_squatteur','etat',e); END IF;
  SELECT data INTO regles FROM public.terrain_actions_regles WHERE id;
  isn := (regles->'indices'->p.country->>'ISN')::numeric;
  IF isn IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','referentiel_indisponible'); END IF;
  -- Fonds vérifiés AVANT tout paiement : ordre de verrou personnage puis compte.
  PERFORM 1 FROM public.comptes_bancaires WHERE personnage = acteur AND banque = 'nationale' FOR UPDATE;
  dispo := coalesce(p.liquide,0) + coalesce((SELECT solde FROM public.comptes_bancaires
             WHERE personnage = acteur AND banque = 'nationale' ORDER BY id LIMIT 1),0);
  IF dispo < p_montant THEN RETURN jsonb_build_object('ok',false,'raison','fonds_insuffisants','disponible',dispo); END IF;
  paiement := public.payer_ordre(acteur, 'donner_argent_pnj', 1, 0);
  IF paiement->>'ok' IS DISTINCT FROM 'true' THEN RETURN paiement; END IF;

  bonus := least(40, floor(p_montant / 100.0))::integer;
  taux_refus := greatest(0, isn - 50) / 2;
  jet_refus := public.terrain_negociation_jet_interne();
  IF jet_refus <= taux_refus THEN
    issue := 'refus'; pris := 0;
    UPDATE public.personnages_donnees SET resources = coalesce(resources,'{}')
           || jsonb_build_object('dis', greatest(0, coalesce((resources->>'dis')::numeric,50) - 10))
     WHERE id = p.id;
  ELSIF occ = 'squatter_agr' AND p_montant < 500 THEN
    issue := 'insulte'; pris := 0;   -- billets jetés : rien n'est pris
  ELSE
    pris := public.argent_debiter_interne(acteur, p_montant, 'liquide_puis_nationale');
    IF pris IS DISTINCT FROM p_montant::numeric THEN RAISE EXCEPTION 'don_non_preleve'; END IF;
    IF occ = 'squatter_cool' THEN
      -- CHA effectif du PJ, comme getStatEffective('CHA') : excommunication −2, affaiblissement par les PV.
      cha := coalesce((p.stats->>'CHA')::numeric, 8)
             - CASE WHEN p.excommunie IS NOT NULL AND p.excommunie <> 'null'::jsonb AND p.excommunie <> 'false'::jsonb THEN 2 ELSE 0 END;
      IF p.stats_affaiblies ? 'CHA' THEN cha := greatest(1, floor(cha * greatest(0, least(1, p.hp::numeric / 100)) + .5));
      ELSE cha := floor(cha + .5); END IF;
      taux := least(85, cha * 3 + bonus);
    ELSE
      taux := least(70, 15 + bonus);
    END IF;
    jet := public.terrain_negociation_jet_interne();
    succes := jet <= taux;
    issue := CASE WHEN succes THEN 'depart' ELSE 'restent' END;
    IF succes THEN
      e := public.terrain_etat_fusionner_interne(cle, jsonb_build_object('pnj', NULL, 'pnjData', NULL), p.country);
    ELSIF occ = 'squatter_agr' THEN
      UPDATE public.personnages_donnees SET hp = greatest(0, coalesce(hp,100) - 10) WHERE id = p.id;
    END IF;
  END IF;
  UPDATE public.personnages_donnees SET updated_at = clock_timestamp() WHERE id = p.id;
  SELECT * INTO p FROM public.personnages_donnees WHERE id = p.id;
  resultat := jsonb_build_object('ok',true,'action','don','issue',issue,'succes',succes,'occupation',occ,
    'montant',p_montant,'preleve',pris,'taux',taux,'jet',jet,'tauxRefus',taux_refus,'jetRefus',jet_refus,
    'pa',p.pa,'hp',p.hp,'dis',(p.resources->>'dis')::numeric,'liquide',p.liquide,'arg',p.arg,
    'solde_national',coalesce((SELECT solde FROM public.comptes_bancaires WHERE personnage = acteur AND banque = 'nationale' ORDER BY id LIMIT 1),0));
  INSERT INTO public.terrain_actions_recus VALUES (p.id, p_requete, cle, p_occupation, 'don', resultat);
  RETURN resultat || jsonb_build_object('etat', e);
END;
$function$;

REVOKE ALL ON FUNCTION public.terrain_squatteurs_don(text,integer,text,uuid) FROM PUBLIC, anon, service_role;
GRANT EXECUTE ON FUNCTION public.terrain_squatteurs_don(text,integer,text,uuid) TO authenticated;
NOTIFY pgrst, 'reload schema';
