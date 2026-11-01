-- #219 — circuits résiduels de déplacement (Claude, 01/11/2026).
-- À INTÉGRER par l'intégrateur APRÈS les 95 migrations de #219 (dépend de
-- groupes_pj_adhesions, navigation_lieux_regles, groupe_pj_quitter et du garde
-- navigation_positions_garder). Fichier volontairement hors de migrations/ pour ne
-- pas modifier le lot certifié de Codex. Patch en place (doctrine WORKFLOW-SUPABASE :
-- fragments exacts, échec bruyant si le corps diffère), aucune donnée de joueur.
--
-- Défauts corrigés (preuves : banc-circuits-residuels-219.sh) :
--  1. assemblee_protester / assemblee_revenir déplaçaient le seul acteur : un député
--     membre ou chef d'un groupe laissait les autres PJ dans l'autre pièce, et tout
--     déplacement suivant du groupe échouait en « groupe_disperse ». Même règle que la
--     porte existante groupe_pj_quitter : l'acteur quitte son groupe, la position réelle
--     des autres PJ ne change pas ; ses PNJ accompagnants le suivent.
--  2. Libération d'une peine purgée au QHS avec lieu de retour : l'écran téléportait le
--     PJ dans sa ville de retour, le serveur le laissait en cellule (le garde de
--     sauvegarde l'ignore). Le serveur le dépose au terminal de la ville, même règle
--     d'arrivée que transport_effectuer.
--  3. Incorporation d'un déserteur détenu : l'écran le conduisait au corps de garde de la
--     caserne, le serveur le laissait aux geôles. Le serveur le dépose au corps de garde.
--  4. Hospitalisation (agression, empoisonnement) et transfert en clinique privée :
--     l'écran naviguait seul vers le dispensaire ou la clinique, refusé par le serveur
--     (« acteur_incapacite », « entree_non_accessible ») ; le transfert était payé avant
--     ce refus. Porte unique hospitalisation_lieu_rejoindre : lieu lu dans la
--     référence de navigation, paiement par payer_ordre_interne dans la même
--     transaction, sortie du groupe comme en 1.

-- 1. Assemblée : l'acteur quitte son groupe avant son déplacement individuel.
DO $assemblee$
DECLARE f text; s text; a text; b text;
BEGIN
 FOREACH f IN ARRAY ARRAY['assemblee_protester','assemblee_revenir'] LOOP
  s := pg_get_functiondef(('public.'||f||'()')::regprocedure);
  IF position('-- assemblee_groupe_quitter_v1' IN s) > 0 THEN CONTINUE; END IF;
  a := CASE f WHEN 'assemblee_protester'
    THEN '  UPDATE public.personnages_donnees SET current_room = ''accueil_assemblee'' WHERE name = v_moi;'
    ELSE '  UPDATE public.personnages_donnees SET current_room = ''hemicycle'' WHERE name = v_moi;' END;
  IF (length(s)-length(replace(s,a,'')))/length(a) <> 1 THEN
   RAISE EXCEPTION 'assemblee_deplacement_non_examine: %', f; END IF;
  b := '  -- assemblee_groupe_quitter_v1 : même porte que groupe_pj_quitter (acteur = mon_personnage)'
    ||chr(10)||'  PERFORM public.groupe_pj_quitter();'||chr(10)||a;
  s := replace(s, a, b);
  -- Verrou du graphe AVANT le verrou de la fiche, même ordre que la navigation commune.
  s := overlay(s placing E'BEGIN\n  PERFORM pg_advisory_xact_lock(hashtextextended(''groupe_pj:graphe'',0));'
       FROM position('BEGIN' IN s) FOR 5);
  EXECUTE s;
 END LOOP;
END $assemblee$;

-- 2. Libération purgée au QHS : dépôt au terminal de la ville de retour.
DO $liberation$
DECLARE s text; a text; b text;
BEGIN
 s := pg_get_functiondef('public.detention_clore_interne(text,text,integer)'::regprocedure);
 IF position('-- liberation_qhs_retour_serveur_v1' IN s) > 0 THEN RETURN; END IF;
 a := 'DECLARE v_jour integer; v_peine jsonb; v_det record; v_qhs boolean;';
 IF (length(s)-length(replace(s,a,'')))/length(a) <> 1 THEN RAISE EXCEPTION 'liberation_declarations_non_examinees'; END IF;
 s := replace(s, a, a||' v_bat text; v_piece text;');
 a := '  -- 4. Le registre du QHS, sans quoi le Ministere voit un detenu libre.';
 IF (length(s)-length(replace(s,a,'')))/length(a) <> 1 THEN RAISE EXCEPTION 'liberation_ancre_non_examinee'; END IF;
 b := '  -- liberation_qhs_retour_serveur_v1 : arrivée identique à transport_effectuer.'||chr(10)
  ||'  IF v_qhs AND p_mode = ''purgee'' AND nullif(v_peine->>''retourVille'','''') IS NOT NULL THEN'||chr(10)
  ||'    SELECT n.batiment, n.pieces->>0 INTO v_bat, v_piece FROM public.navigation_lieux_regles n'||chr(10)
  ||'     JOIN public.personnages_donnees d ON d.name = p_nom AND n.pays = d.country'||chr(10)
  ||'     WHERE n.ville = v_peine->>''retourVille'' AND n.batiment LIKE ''centre-multinodal-%'''||chr(10)
  ||'       AND NOT EXISTS(SELECT 1 FROM public.navigation_lieux_regles autre WHERE autre.pays = n.pays'||chr(10)
  ||'           AND autre.ville <> n.ville AND autre.batiment = n.batiment)'||chr(10)
  ||'     ORDER BY n.batiment LIMIT 1;'||chr(10)
  ||'    IF v_bat IS NULL THEN RAISE EXCEPTION ''liberation_retour_non_reference: %'', v_peine->>''retourVille''; END IF;'||chr(10)
  ||'    UPDATE public.personnages_donnees SET current_city = v_peine->>''retourVille'', current_building = v_bat,'||chr(10)
  ||'           current_room = v_piece, current_street = NULL, updated_at = clock_timestamp() WHERE name = p_nom;'||chr(10)
  ||'  END IF;'||chr(10)||a;
 EXECUTE replace(s, a, b);
END $liberation$;

-- 3. Incorporation : dépôt au corps de garde de la caserne.
DO $incorporation$
DECLARE s text; a text; b text;
BEGIN
 s := pg_get_functiondef('public.detention_clore_motif_eteint(text)'::regprocedure);
 IF position('-- incorporation_caserne_serveur_v1' IN s) > 0 THEN RETURN; END IF;
 a := '  v_r := public.detention_clore_interne(v_moi, p_mode);';
 IF (length(s)-length(replace(s,a,'')))/length(a) <> 1 THEN RAISE EXCEPTION 'incorporation_ancre_non_examinee'; END IF;
 b := a||chr(10)||'  -- incorporation_caserne_serveur_v1 : la caserne est une zone déclarée de la navigation.'||chr(10)
  ||'  IF p_mode = ''incorporation'' THEN'||chr(10)
  ||'    IF NOT EXISTS(SELECT 1 FROM public.navigation_lieux_regles n JOIN public.personnages_donnees d'||chr(10)
  ||'        ON d.name = v_moi AND n.pays = d.country WHERE n.ville = ''caserne'''||chr(10)
  ||'        AND n.batiment = ''caserne-militaire'' AND n.pieces ? ''corps_garde'') THEN'||chr(10)
  ||'      RAISE EXCEPTION ''caserne_non_referencee''; END IF;'||chr(10)
  ||'    UPDATE public.personnages_donnees SET current_city = ''caserne'', current_building = ''caserne-militaire'','||chr(10)
  ||'           current_room = ''corps_garde'', current_street = NULL, updated_at = clock_timestamp() WHERE name = v_moi;'||chr(10)
  ||'  END IF;';
 EXECUTE replace(s, a, b);
END $incorporation$;

-- 4. Hospitalisation : rejoindre son lieu de soins (dispensaire de la ville, ou
--    chambre attribuée de la clinique privée de la capitale, transfert payé ici).
CREATE OR REPLACE FUNCTION public.hospitalisation_lieu_rejoindre(
 p_lieu text, p_chambre text DEFAULT NULL, p_verifier boolean DEFAULT false)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $h$
DECLARE moi text; p public.personnages_donnees%ROWTYPE; dispo jsonb; v_ville text; v_bat text;
 v_piece text; paiement jsonb; aujourdhui text; v_pa integer; v_cost integer;
BEGIN
 IF p_lieu IS NULL OR p_lieu NOT IN ('dispensaire','clinique') THEN
  RETURN jsonb_build_object('ok',false,'raison','lieu_invalide'); END IF;
 moi := public.mon_personnage();
 IF moi IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','non_authentifie'); END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('groupe_pj:graphe',0));
 -- Mêmes interdits que la navigation commune, sauf l'hospitalisation elle-même.
 dispo := public.navigation_disponibilite_interne(moi);
 IF NOT coalesce((dispo->>'ok')::boolean,false) AND dispo->>'raison' IS DISTINCT FROM 'acteur_incapacite' THEN
  RETURN dispo; END IF;
 SELECT * INTO p FROM public.personnages_donnees WHERE name = moi;
 aujourdhui := (statement_timestamp() AT TIME ZONE 'Europe/Paris')::date::text;
 IF p.hospitalisation IS NULL OR jsonb_typeof(p.hospitalisation) <> 'object'
 OR coalesce(p.hospitalisation->>'dateFinParis','') <= aujourdhui THEN
  RETURN jsonb_build_object('ok',false,'raison','non_hospitalise'); END IF;
 IF p_lieu = 'dispensaire' AND p.hospitalisation->>'lieu' IS DISTINCT FROM 'dispensaire' THEN
  RETURN jsonb_build_object('ok',false,'raison','lieu_non_prescrit'); END IF;
 IF p_lieu = 'clinique' THEN
  v_ville := 'capitale'; v_bat := 'clinique-privee';
  v_piece := coalesce(p_chambre, 'reception_clinique');
  IF p_chambre IS NOT NULL AND NOT (p_chambre ~ '^chambre_([1-9]|10)$' AND EXISTS(
     SELECT 1 FROM public.locations_actives loc WHERE loc.country = p.country
      AND loc.data->>'buildingId' = 'clinique-privee' AND loc.data->>'roomId' = p_chambre
      AND loc.data->>'city' = 'capitale' AND loc.data->>'locataire' = moi)) THEN
   RETURN jsonb_build_object('ok',false,'raison','chambre_non_attribuee'); END IF;
  IF NOT EXISTS(SELECT 1 FROM public.navigation_lieux_regles WHERE pays = p.country AND ville = v_ville
     AND batiment = v_bat AND pieces ? v_piece) THEN
   RETURN jsonb_build_object('ok',false,'raison','lieu_non_reference'); END IF;
 ELSE
  v_ville := p.current_city;
  SELECT batiment, pieces->>0 INTO v_bat, v_piece FROM public.navigation_lieux_regles
   WHERE pays = p.country AND ville = v_ville AND batiment LIKE 'dispensaire-public%'
   ORDER BY batiment LIMIT 1;
  IF v_bat IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','lieu_non_reference'); END IF;
 END IF;
 IF p_verifier THEN
  RETURN jsonb_build_object('ok',true,'verifie',true,'country',p.country,'city',v_ville,'building',v_bat,'room',v_piece);
 END IF;
 -- Le transfert en clinique est payé dans la même transaction que le déplacement.
 IF p_lieu = 'clinique' AND p.hospitalisation->>'lieu' IS DISTINCT FROM 'clinique' THEN
  -- Tarif lu au miroir des coûts (data.js), jamais reçu du navigateur.
  SELECT pa, cost INTO v_pa, v_cost FROM public.ordres_couts WHERE fn = 'transfert_clinique_privee'
   ORDER BY cost DESC LIMIT 1;
  paiement := public.payer_ordre_interne(moi, 'transfert_clinique_privee', coalesce(v_pa,0), coalesce(v_cost,0));
  IF NOT coalesce((paiement->>'ok')::boolean,false) THEN RETURN paiement; END IF;
 END IF;
 -- Le patient quitte son groupe (même règle que groupe_pj_quitter) ; ses PNJ le suivent.
 DELETE FROM public.groupes_pj_adhesions WHERE membre = moi OR chef = moi;
 UPDATE public.personnages_donnees SET current_city = v_ville, current_building = v_bat,
        current_room = v_piece, current_street = NULL,
        hospitalisation = jsonb_set(hospitalisation, '{lieu}', to_jsonb(p_lieu)),
        updated_at = clock_timestamp()
  WHERE name = moi;
 RETURN jsonb_build_object('ok',true,'country',p.country,'city',v_ville,'building',v_bat,'room',v_piece,
   'paiement', paiement);
END $h$;
REVOKE ALL ON FUNCTION public.hospitalisation_lieu_rejoindre(text,text,boolean) FROM PUBLIC, anon, service_role;
GRANT EXECUTE ON FUNCTION public.hospitalisation_lieu_rejoindre(text,text,boolean) TO authenticated;

DO $verification$
BEGIN
 IF position('-- assemblee_groupe_quitter_v1' IN pg_get_functiondef('public.assemblee_protester()'::regprocedure)) = 0
 OR position('-- assemblee_groupe_quitter_v1' IN pg_get_functiondef('public.assemblee_revenir()'::regprocedure)) = 0
 OR position('-- liberation_qhs_retour_serveur_v1' IN pg_get_functiondef('public.detention_clore_interne(text,text,integer)'::regprocedure)) = 0
 OR position('-- incorporation_caserne_serveur_v1' IN pg_get_functiondef('public.detention_clore_motif_eteint(text)'::regprocedure)) = 0 THEN
  RAISE EXCEPTION 'circuits_residuels_incomplets'; END IF;
END $verification$;
