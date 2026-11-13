-- Novomirsk : la réception diplomatique reste au Pavillon des Ambassadeurs.
-- Activer audiences/asile à l'accueil du Palais, protéger les bureaux par l'autorité serveur,
-- sans modifier les ordres de Luthécia ni les flux de voyage inter-empires.
-- Source des fonctions : pg_get_functiondef sur la production avant modification.
-- Migration idempotente ; aucune suppression de lignes de joueurs.
UPDATE public.navigation_lieux_regles SET pieces =
  '["accueil_ambassades_novomirsk","bureau_republia_novomirsk","bureau_khalija_novomirsk","bureau_estado_novomirsk"]'::jsonb
WHERE pays='soviet' AND ville='capitale' AND batiment='palais-ambassades-novomirsk';

DO $migration_check$
BEGIN
 IF EXISTS (SELECT 1 FROM public.personnages_donnees WHERE country='soviet'
   AND current_building='palais-ambassades-novomirsk' AND current_room='salle_reception') THEN
   RAISE EXCEPTION 'Joueurs dans la salle supprimée : intervention nécessaire avant migration';
 END IF;
END
$migration_check$;

-- ambassade_identite
CREATE OR REPLACE FUNCTION public.ambassade_identite(p_empire text)
 RETURNS jsonb
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT CASE p_empire
    WHEN 'republic' THEN jsonb_build_object('ambassadeur','Hubert de La Courtoisie', 'ambassade','Ambassade de Républia')
    WHEN 'soviet'  THEN jsonb_build_object('ambassadeur','Valery Antonov',      'ambassade','Ambassade de Sovarka')
    WHEN 'narco'   THEN jsonb_build_object('ambassadeur','Guillermo Vasquez',   'ambassade','Ambassade d''El Estado')
    WHEN 'khalija' THEN jsonb_build_object('ambassadeur','Mohamed Al-Mansoori', 'ambassade','Ambassade d''Al-Khalija')
  END;
$function$
;

-- ambassade_acces_bureau_interne
CREATE OR REPLACE FUNCTION public.ambassade_acces_bureau_interne(p_empire text, p_nom text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; v_expire timestamptz;
BEGIN
  v_moi := p_nom;
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  IF public.ambassade_identite(p_empire) IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'ambassade_inconnue');
  END IF;
  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;
  IF EXISTS (SELECT 1 FROM public.ambassades_ouvertes a
              WHERE a.pays_hote = v_pays AND a.empire = p_empire
                AND a.data ->> 'ambassadeur' = v_moi) THEN
    RETURN jsonb_build_object('ok', true, 'motif', 'ambassadeur');
  END IF;
  PERFORM public.ambassades_asiles_echoir(v_moi);
  IF public.ambassade_refuge_de(v_moi) = p_empire THEN
    RETURN jsonb_build_object('ok', true, 'motif', 'refugie');
  END IF;
  PERFORM public.ambassades_audiences_echoir(v_moi);
  SELECT expire_le INTO v_expire FROM public.ambassades_audiences
   WHERE demandeur = v_moi AND pays_hote = v_pays AND empire = p_empire AND statut = 'accordee' AND expire_le > now();
  IF v_expire IS NOT NULL THEN
    RETURN jsonb_build_object('ok', true, 'motif', 'audience', 'expire_le', v_expire);
  END IF;
  RETURN jsonb_build_object('ok', false, 'raison', 'sur_audience');
END; $function$
;

-- ambassade_acces_bureaux
CREATE OR REPLACE FUNCTION public.ambassade_acces_bureaux()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; v_res jsonb := '{}'::jsonb; e text; v_expire timestamptz; v_refuge text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;
  PERFORM public.ambassades_audiences_echoir(v_moi);
  PERFORM public.ambassades_asiles_echoir(v_moi);
  v_refuge := public.ambassade_refuge_de(v_moi);
  FOREACH e IN ARRAY ARRAY['khalija','soviet','narco','republic'] LOOP
    IF e = v_pays THEN CONTINUE; END IF;
    IF EXISTS (SELECT 1 FROM public.ambassades_ouvertes a
                WHERE a.pays_hote = v_pays AND a.empire = e AND a.data ->> 'ambassadeur' = v_moi) THEN
      v_res := v_res || jsonb_build_object(e, jsonb_build_object('acces', true, 'motif', 'immunite'));
      CONTINUE;
    END IF;
    IF v_refuge = e THEN
      v_res := v_res || jsonb_build_object(e, jsonb_build_object('acces', true, 'motif', 'refugie'));
      CONTINUE;
    END IF;
    SELECT expire_le INTO v_expire FROM public.ambassades_audiences
     WHERE demandeur = v_moi AND pays_hote = v_pays AND empire = e AND statut = 'accordee' AND expire_le > now();
    IF v_expire IS NOT NULL THEN
      v_res := v_res || jsonb_build_object(e, jsonb_build_object('acces', true, 'motif', 'audience', 'expire_le', v_expire));
    ELSE
      v_res := v_res || jsonb_build_object(e, jsonb_build_object('acces', false));
    END IF;
  END LOOP;
  -- Ambassadeurs joueurs en poste dans le pays (25/10/2026) : leurs PNJ deviennent secretaires.
  RETURN jsonb_build_object('ok', true, 'bureaux', v_res, 'ambassadeurs', coalesce((
    SELECT jsonb_object_agg(a.empire, a.data ->> 'ambassadeur') FROM public.ambassades_ouvertes a
     WHERE a.pays_hote = v_pays AND nullif(btrim(coalesce(a.data ->> 'ambassadeur', '')), '') IS NOT NULL), '{}'::jsonb));
END; $function$
;

-- ambassade_demander_audience
CREATE OR REPLACE FUNCTION public.ambassade_demander_audience(p_empire text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_moi text; v_pays text; v_batiment text; v_pj text; v_id uuid;
  v_paie jsonb; v_ident jsonb; v_statut text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  v_ident := public.ambassade_identite(p_empire);
  IF v_ident IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'ambassade_inconnue');
  END IF;
  SELECT country, current_building INTO v_pays, v_batiment
    FROM public.personnages_donnees WHERE name = v_moi;
  IF v_pays IS NULL OR v_pays = p_empire THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'ambassade_inconnue');
  END IF;
  IF v_batiment IS DISTINCT FROM (CASE v_pays WHEN 'republic' THEN 'quartier-ambassades' WHEN 'soviet' THEN 'palais-ambassades-novomirsk' ELSE NULL END) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place');
  END IF;

  PERFORM public.ambassades_audiences_echoir(v_moi);

  SELECT statut INTO v_statut FROM public.ambassades_audiences
   WHERE demandeur = v_moi AND empire = p_empire AND statut IN ('demandee','accordee');
  IF v_statut = 'demandee' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'demande_en_cours');
  ELSIF v_statut = 'accordee' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'audience_deja_accordee');
  END IF;

  -- L'ambassadeur joueur en poste ici, s'il y en a un (inexistant tant que les autres empires
  -- ne sont pas codes : la branche est prete, et c'est tout).
  SELECT nullif(btrim(coalesce(a.data ->> 'ambassadeur','')), '') INTO v_pj
    FROM public.ambassades_ouvertes a
   WHERE a.pays_hote = v_pays AND a.empire = p_empire;

  -- ENREGISTRER AVANT DE PAYER : l'index unique arbitre une course entre deux onglets sans
  -- prelever le perdant. Si le paiement est refuse, la ligne est retiree.
  BEGIN
    INSERT INTO public.ambassades_audiences (demandeur, pays_hote, empire, ambassadeur_pj, accord_prevu_le)
    VALUES (v_moi, v_pays, p_empire, v_pj,
            CASE WHEN v_pj IS NULL THEN now() + random() * interval '3 days' END)
    RETURNING id INTO v_id;
  EXCEPTION WHEN unique_violation THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'demande_en_cours');
  END;

  v_paie := public.payer_ordre(v_moi, 'demander_audience_ambassadeur', 1, 0);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN
    DELETE FROM public.ambassades_audiences WHERE id = v_id;
    RETURN v_paie;
  END IF;

  PERFORM public.mail_systeme_poser_interne(
    (CASE WHEN v_pays='soviet' THEN 'Palais des Ambassades' ELSE 'Quartier des Ambassades' END), v_moi, 'Demande d''audience transmise',
    'Votre demande d''audience auprès de l''<strong>' || (v_ident ->> 'ambassade') || '</strong> a bien été transmise.<br><br>'
    || 'Vous recevrez une réponse dans les plus brefs délais.<br><br>'
    || 'Le secrétariat du Quartier des Ambassades');

  IF v_pj IS NOT NULL THEN
    PERFORM public.mail_systeme_poser_interne(
      'Quartier des Ambassades', v_pj, 'Demande d''audience',
      '<strong>' || v_moi || '</strong> sollicite une audience auprès de votre ambassade.<br><br>'
      || 'Si vous l''accordez, votre bureau lui sera ouvert pendant 48 heures.'
      || '[[act:audience_accorder|' || v_id::text || ']]');
  END IF;

  -- Un delai tire a zero ou presque : l'audience est accordee sur-le-champ.
  PERFORM public.ambassades_audiences_echoir(v_moi);
  SELECT statut INTO v_statut FROM public.ambassades_audiences WHERE id = v_id;

  RETURN jsonb_build_object('ok', true, 'statut', v_statut,
                            'ambassadeur', v_ident ->> 'ambassadeur',
                            'ambassadeur_joueur', v_pj IS NOT NULL,
                            'pa', v_paie -> 'pa');
END; $function$
;

-- ambassade_demander_asile
CREATE OR REPLACE FUNCTION public.ambassade_demander_asile(p_empire text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; v_batiment text; v_id uuid; v_paie jsonb; v_ident jsonb; v_statut text; v_pj text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  v_ident := public.ambassade_identite(p_empire);
  IF v_ident IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'ambassade_inconnue'); END IF;
  SELECT country, current_building INTO v_pays, v_batiment FROM public.personnages_donnees WHERE name = v_moi;
  IF v_pays IS NULL OR v_pays = p_empire THEN RETURN jsonb_build_object('ok', false, 'raison', 'ambassade_inconnue'); END IF;
  IF v_batiment IS DISTINCT FROM (CASE v_pays WHEN 'republic' THEN 'quartier-ambassades' WHEN 'soviet' THEN 'palais-ambassades-novomirsk' ELSE NULL END) THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;
  PERFORM public.ambassades_asiles_echoir(v_moi);
  SELECT statut INTO v_statut FROM public.ambassades_asiles WHERE demandeur = v_moi AND statut IN ('demandee','accorde');
  IF v_statut = 'demandee' THEN RETURN jsonb_build_object('ok', false, 'raison', 'asile_en_cours');
  ELSIF v_statut = 'accorde' THEN RETURN jsonb_build_object('ok', false, 'raison', 'deja_refugie'); END IF;
  SELECT nullif(btrim(coalesce(a.data ->> 'ambassadeur', '')), '') INTO v_pj
    FROM public.ambassades_ouvertes a WHERE a.pays_hote = v_pays AND a.empire = p_empire;
  BEGIN
    INSERT INTO public.ambassades_asiles (demandeur, pays_hote, empire, decision_prevue_le, ambassadeur_pj)
    VALUES (v_moi, v_pays, p_empire,
            CASE WHEN v_pj IS NULL THEN now() + random() * interval '3 days' ELSE 'infinity'::timestamptz END, v_pj)
    RETURNING id INTO v_id;
  EXCEPTION WHEN unique_violation THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'asile_en_cours');
  END;
  v_paie := public.payer_ordre(v_moi, 'demander_asile_politique', 2, 0);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN
    DELETE FROM public.ambassades_asiles WHERE id = v_id;
    RETURN v_paie;
  END IF;
  PERFORM public.mail_systeme_poser_interne((CASE WHEN v_pays='soviet' THEN 'Palais des Ambassades' ELSE 'Quartier des Ambassades' END), v_moi, 'Demande d''asile transmise',
    'Votre demande d''asile politique auprès de l''<strong>' || (v_ident ->> 'ambassade')
    || '</strong> a bien été transmise.<br><br>Votre dossier sera examiné, et la réponse vous parviendra dans les plus brefs délais.<br><br>'
    || 'Le secrétariat du Quartier des Ambassades');
  IF v_pj IS NOT NULL THEN
    PERFORM public.mail_systeme_poser_interne('Quartier des Ambassades', v_pj, 'Demande d''asile politique',
      '<strong>' || v_moi || '</strong> sollicite l''asile politique auprès de votre ambassade. À vous de l''accorder ou de le refuser.<br><br>'
      || '[[act:asile_accorder|' || v_id::text || ']][[act:asile_refuser|' || v_id::text || ']]');
    RETURN jsonb_build_object('ok', true, 'statut', 'demandee', 'ambassade', v_ident ->> 'ambassade', 'pa', v_paie -> 'pa');
  END IF;
  PERFORM public.ambassades_asiles_echoir(v_moi);
  SELECT statut INTO v_statut FROM public.ambassades_asiles WHERE id = v_id;
  RETURN jsonb_build_object('ok', true, 'statut', v_statut, 'ambassade', v_ident ->> 'ambassade', 'pa', v_paie -> 'pa');
END; $function$
;

-- navigation_interieure_personnage_interne
CREATE OR REPLACE FUNCTION public.navigation_interieure_personnage_interne(p_nom text, p_batiment text, p_piece text, p_verifier boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE p public.personnages_donnees%ROWTYPE;l public.navigation_lieux_regles%ROWTYPE;r jsonb; total numeric;
BEGIN
 r:=public.navigation_disponibilite_interne(p_nom);
 IF NOT coalesce((r->>'ok')::boolean,false) THEN RETURN r; END IF;
 SELECT * INTO p FROM public.personnages_donnees WHERE name=p_nom;
 -- navigation_zone_speciale_v1
 IF p_batiment IS NULL AND p_piece IS NULL AND (p.current_city,p.current_building) IN (('caserne','caserne-militaire'),('qhs','qhs-prison')) THEN IF NOT p_verifier THEN UPDATE public.personnages_donnees SET current_building=NULL,current_room=NULL,current_street=NULL,updated_at=clock_timestamp() WHERE name=p_nom;END IF; RETURN jsonb_build_object('ok',true,'building',NULL,'room',NULL);END IF;
 SELECT * INTO l FROM public.navigation_lieux_regles WHERE pays=p.country AND ville=p.current_city AND batiment=p_batiment;
 IF NOT public.navigation_piece_referencee_interne(p.country,p.current_city,p_batiment,p_piece) THEN RETURN jsonb_build_object('ok',false,'raison','destination_inconnue'); END IF;
 IF p_batiment='quartier-ambassades' AND p_piece IN ('bureau_al_khalija','bureau_sovarka','bureau_el_estado') THEN
  r:=public.ambassade_acces_bureau_interne(CASE p_piece WHEN 'bureau_al_khalija' THEN 'khalija' WHEN 'bureau_sovarka' THEN 'soviet' ELSE 'narco' END,p_nom);
  IF NOT coalesce((r->>'ok')::boolean,false) THEN RETURN r; END IF;
 END IF;
 -- palais_ambassades_novomirsk_audience_v1 : même autorité serveur qu'à Luthécia.
 IF p.country='soviet' AND p.current_city='capitale' AND p_batiment='palais-ambassades-novomirsk'
    AND p_piece IN ('bureau_republia_novomirsk','bureau_khalija_novomirsk','bureau_estado_novomirsk') THEN
  r:=public.ambassade_acces_bureau_interne(CASE p_piece
        WHEN 'bureau_republia_novomirsk' THEN 'republic'
        WHEN 'bureau_khalija_novomirsk' THEN 'khalija'
        ELSE 'narco' END,p_nom);
  IF NOT coalesce((r->>'ok')::boolean,false) THEN RETURN r; END IF;
 END IF;
 -- palais_presidentiel_sovarka_v1 (Fred, 08/11/2026) : restaurant et appartements groupé au président, musée sur billet du jour.
 IF p.country='soviet' AND p.current_city='capitale' AND p_batiment='palais-presidentiel' AND (p.current_building IS DISTINCT FROM p_batiment OR p.current_room IS DISTINCT FROM p_piece) THEN
  r:=CASE WHEN public.sovarka_palais_acces_interne(p_nom,p_piece) IS NULL THEN NULL ELSE jsonb_build_object('ok',false,'raison',public.sovarka_palais_acces_interne(p_nom,p_piece),'membre',p_nom) END;
  IF r IS NOT NULL THEN RETURN r; END IF;
 END IF;
 -- acces_reserve_v1 (Fred, 12/11/2026) : Pavillon des Ambassadeurs et Résidence impériale de Novomirsk.
 IF p.country='soviet' AND p.current_city='capitale' AND p_batiment IN ('pavillon-ambassadeurs-novomirsk','residence-imperiale-novomirsk') THEN
  IF p.current_building IS DISTINCT FROM p_batiment AND NOT p_verifier THEN DELETE FROM public.acces_intrusions WHERE acteur=p_nom AND batiment=p_batiment; END IF;
  IF p.current_building IS DISTINCT FROM p_batiment OR p.current_room IS DISTINCT FROM p_piece THEN
   r:=CASE WHEN public.acces_reserve_raison_interne(p_nom,p_batiment,p_piece) IS NULL THEN NULL
      ELSE jsonb_build_object('ok',false,'raison',public.acces_reserve_raison_interne(p_nom,p_batiment,p_piece),'batiment',p_batiment,'piece',p_piece,'membre',p_nom) END;
   IF r IS NOT NULL THEN RETURN r; END IF;
  END IF;
 END IF;
 -- ssm_acces_sur_rendezvous_v1
 IF p.country='republic' AND p.current_city='ville_b' AND p_batiment='services-sociaux-montrouge' AND p_piece='bureau_assistante_sociale' AND NOT public.ssm_rendezvous_valide_interne(p_nom) THEN RETURN jsonb_build_object('ok',false,'raison','rendezvous_ssm_requis'); END IF;
 IF l.ferme THEN RETURN jsonb_build_object('ok',false,'raison','acces_restreint'); END IF;
 -- Les restrictions sans porte serveur pour une identité arbitraire restent
 -- fermées, jamais déduites d'un cache ou d'une attestation du navigateur.
 IF l.membership='loge' AND NOT EXISTS(
   SELECT 1 FROM public.organisations o
   WHERE o.data::jsonb->>'type'='loge' AND o.data::jsonb->>'statut'='actif'
   AND EXISTS(SELECT 1 FROM jsonb_array_elements(CASE WHEN jsonb_typeof(o.data::jsonb->'membres')='array'
       THEN o.data::jsonb->'membres' ELSE '[]'::jsonb END) m WHERE m->>'nom'=p_nom)) THEN
  RETURN jsonb_build_object('ok',false,'raison','membre_loge_requis'); END IF;
 IF p_batiment='clinique-privee' AND p_piece~'^chambre_([1-9]|10)$' AND EXISTS(
   SELECT 1 FROM public.locations_actives loc WHERE loc.country=p.country
   AND loc.data->>'buildingId'=p_batiment AND loc.data->>'roomId'=p_piece AND loc.data->>'city'='capitale'
   AND loc.data->>'locataire' IS DISTINCT FROM p_nom AND loc.data->'visitesAutorisees'='false'::jsonb) THEN
  RETURN jsonb_build_object('ok',false,'raison','visite_refusee'); END IF;
 IF (l.membership IS NOT NULL AND l.membership<>'loge') 
 /* navigation_acces_ambassade_par_membre_v1 */ THEN
  RETURN jsonb_build_object('ok',false,'raison','acces_collectif_a_raccorder'); END IF;
 -- douane_zone_par_membre_v1
 IF p_piece='zone_embarquement' AND NOT public.douane_passage_valide_interne(p_nom,'avion') THEN
 RETURN jsonb_build_object('ok',false,'raison','controle_douanier_requis');END IF;
 -- serrure_batiment_v1 (04/11/2026) : un batiment ferme a cle ne s'ouvre qu'a qui en detient une cle.
 IF p.current_building IS DISTINCT FROM p_batiment
    AND public.serrure_batiment_ferme_interne(p_nom, p.country, p.current_city, p_batiment) THEN
  RETURN jsonb_build_object('ok',false,'raison','porte_fermee_a_cle','batiment',true); END IF;
 -- serrure_porte_v1 (04/11/2026) : un lieu ferme a cle ne s'ouvre qu'a qui en detient une cle.
 IF (p.current_building IS DISTINCT FROM p_batiment OR p.current_room IS DISTINCT FROM p_piece)
    AND public.serrure_porte_fermee_interne(p_nom, p.country, p.current_city, p_batiment, p_piece) THEN
  RETURN jsonb_build_object('ok',false,'raison','porte_fermee_a_cle'); END IF;
 -- blocus_syndical_v1
 IF p_batiment IS NOT NULL AND p_piece IS DISTINCT FROM (l.pieces->>0) AND public.blocus_actif_interne(p.country,p.current_city,p_batiment) IS NOT NULL THEN
  RETURN jsonb_build_object('ok',false,'raison','blocus_syndical'); END IF;
 IF EXISTS(SELECT 1 FROM public.batiments_fermes f WHERE f.pays=p.country AND f.ville=p.current_city AND f.batiment_id=p_batiment
 AND (f.date_fin_universelle>(statement_timestamp() AT TIME ZONE 'Europe/Paris')::date
 OR (f.date_fin_universelle IS NULL AND f.jour_fin>p.day))) THEN
  RETURN jsonb_build_object('ok',false,'raison','batiment_ferme'); END IF;
 IF p.current_building IS DISTINCT FROM p_batiment THEN
  IF p.current_building IS NOT NULL OR (NOT EXISTS(SELECT 1 FROM public.rue_sorties_batiments
   WHERE country=p.country AND city=p.current_city AND building=p_batiment AND noeud=p.current_street) AND NOT (p.current_street IS NULL AND (p.current_city,p_batiment,p_piece) IN (('caserne','caserne-militaire','corps_garde'),('qhs','qhs-prison','entree_qhs')))) THEN
   RETURN jsonb_build_object('ok',false,'raison','entree_non_accessible'); END IF;
  SELECT coalesce(sum(coalesce(nullif(x->>'qty','')::numeric,nullif(x->>'encombrement','')::numeric,1)),0)
   INTO total FROM jsonb_array_elements(CASE WHEN jsonb_typeof(p.inventory)='array' THEN p.inventory ELSE '[]'::jsonb END) x;
  IF total>100 THEN RETURN jsonb_build_object('ok',false,'raison','inventaire_surcharge'); END IF;
 END IF;
 IF NOT p_verifier AND (p.current_building IS DISTINCT FROM p_batiment OR p.current_room IS DISTINCT FROM p_piece) THEN
  UPDATE public.personnages_donnees SET current_building=p_batiment,current_room=p_piece,current_street=NULL,updated_at=clock_timestamp() WHERE name=p_nom;
 END IF;
 RETURN jsonb_build_object('ok',true,'building',p_batiment,'room',p_piece);
END $function$
;
