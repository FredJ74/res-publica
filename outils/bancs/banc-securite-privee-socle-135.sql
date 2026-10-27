-- Sécurité : la fonction auxiliaire est réservée aux appels internes SECURITY DEFINER.
DO $t$ BEGIN
 IF has_function_privilege('authenticated','public.securite_agents_prives_presents_interne(text,text,text,text,text,text)','EXECUTE')
    OR has_function_privilege('anon','public.securite_agents_prives_presents_interne(text,text,text,text,text,text)','EXECUTE')
 THEN RAISE EXCEPTION 'exposition_publique_des_agents'; END IF;
END $t$;
-- Banc #135, à lancer dans la MÊME transaction que la migration préparée,
-- avant ROLLBACK (aucune donnée permanente). Ne touche aucun PJ existant.
INSERT INTO public.pnj_membres (id,famille,classe,nom,pays,proprietaire_pj,statut,pa,car_per,car_vol,ville,building_id,room_id)
VALUES ('__test_135_private__','employe','beta','Test 135','republic','__test_employeur_135__','actif',12,17,19,'capitale','__test_bat_135__','terrain');
INSERT INTO public.pnj_employes_metier (pnj_id,job,role_libelle,cout_jour)
VALUES ('__test_135_private__','agent_securite','Test',0);
DO $t$
DECLARE r jsonb;
BEGIN
 r:=public.securite_agents_prives_presents_interne('republic','capitale','__test_bat_135__','terrain',NULL,'__test_cible_135__');
 IF jsonb_array_length(r)<>1 OR r->0->'stats'->>'PER'<>'17' OR r->0->>'pnj_prive_id'<>'__test_135_private__'
 THEN RAISE EXCEPTION 'agent_prive_non_detecte: %',r; END IF;
 r:=public.securite_agents_prives_presents_interne('republic','capitale','__test_bat_135__','terrain',NULL,'__test_employeur_135__');
 IF jsonb_array_length(r)<>0 THEN RAISE EXCEPTION 'agent_detecte_contre_employeur'; END IF;
 r:=public.securite_agents_prives_presents_interne('republic','capitale','__autre__','terrain',NULL,'__test_cible_135__');
 IF jsonb_array_length(r)<>0 THEN RAISE EXCEPTION 'agent_detecte_a_distance'; END IF;
 UPDATE public.pnj_membres SET statut='detenu' WHERE id='__test_135_private__';
 r:=public.securite_agents_prives_presents_interne('republic','capitale','__test_bat_135__','terrain',NULL,'__test_cible_135__');
 IF jsonb_array_length(r)<>0 THEN RAISE EXCEPTION 'agent_detenu_actif'; END IF;
 UPDATE public.pnj_membres SET statut='actif',pa=0 WHERE id='__test_135_private__';
 r:=public.securite_agents_prives_presents_interne('republic','capitale','__test_bat_135__','terrain',NULL,'__test_cible_135__');
 IF jsonb_array_length(r)<>0 THEN RAISE EXCEPTION 'agent_sans_pa_actif'; END IF;
 UPDATE public.pnj_membres SET pa=12 WHERE id='__test_135_private__';
 r:=public.securite_agents_prives_presents_interne('republic','autre_ville','__test_bat_135__','terrain',NULL,'__test_cible_135__');
 IF jsonb_array_length(r)<>0 THEN RAISE EXCEPTION 'agent_autre_ville_actif'; END IF;
 RAISE NOTICE 'Banc #135 : 6 assertions de présence réussies en transaction annulée';
END $t$;

-- Cas authentifié : avis de recherche fictif, rencontre et combat commun.
INSERT INTO auth.users(id,instance_id,aud,role)
VALUES ('c1350000-0000-4000-8000-000000000135','00000000-0000-0000-0000-000000000000','authenticated','authenticated');
SELECT set_config('request.jwt.claim.sub','c1350000-0000-4000-8000-000000000135',true);
INSERT INTO public.personnages_donnees(name,user_id,country,current_city,current_building,current_room,hp,pa,resources,stats)
VALUES ('__test_pj_135__','c1350000-0000-4000-8000-000000000135','republic','capitale','__test_bat_135__','terrain',100,12,'{"dis":0}'::jsonb,'{"PER":8,"VOL":8}'::jsonb);
-- Escorte : la position du PNJ suit celle de son chef PJ, sans affectation chantier.
INSERT INTO public.pnj_membres(id,famille,classe,nom,pays,proprietaire_pj,leader_pj,statut,pa,car_per,car_vol)
VALUES('__test_135_suiveur__','employe','beta','Escorte fictive','republic','__test_employeur_135__','__test_pj_135__','actif',12,22,19);
INSERT INTO public.pnj_employes_metier(pnj_id,job,role_libelle,cout_jour)
VALUES('__test_135_suiveur__','agent_securite','Escorte fictive',0);
DO $t$ DECLARE r jsonb; BEGIN
 r:=public.securite_agents_prives_presents_interne('republic','capitale','__test_bat_135__','terrain',NULL,'__test_cible_135__');
 IF (SELECT count(*) FROM jsonb_array_elements(r) x WHERE x->>'pnj_prive_id'='__test_135_suiveur__')<>1
 THEN RAISE EXCEPTION 'escorte_non_presente_avec_chef: %',r; END IF;
 r:=public.securite_agents_prives_presents_interne('republic','capitale','__test_bat_135__','terrain',NULL,'__test_employeur_135__');
 IF jsonb_array_length(r)<>0 THEN RAISE EXCEPTION 'escorte_hostile_employeur'; END IF;
END $t$;
-- Un PNJ vivant ne se supprime jamais : le neutraliser dans la transaction de test.
UPDATE public.pnj_membres SET statut='detenu' WHERE id='__test_135_suiveur__';
UPDATE public.pnj_membres SET statut='actif' WHERE id='__test_135_private__';
INSERT INTO public.jugements(id,country,city,accuse,motif,executee,data)
VALUES ('__test_jugement_135__','republic','capitale','__test_pj_135__','test',false,'{"motifs":[{"jours":1}]}'::jsonb);
-- La détection choisit le groupe puis mémorise uniquement les matricules retenus.
-- Le test reste isolé : il supprime ses propres rencontres fictives avant le combat existant.
DO $t$ DECLARE r jsonb; membres jsonb; i integer; trouve boolean:=false;
BEGIN
 FOR i IN 1..60 LOOP
   DELETE FROM public.police_detection_attempts WHERE personnage='__test_pj_135__';
   r:=public.police_detection_verifier('__test_bat_135__','terrain',NULL);
   IF coalesce((r->>'detecte')::boolean,false) THEN
     IF r->>'rencontre' NOT LIKE 'prive-%' OR (r->>'effectif')::integer<>1 THEN
       RAISE EXCEPTION 'categorie_de_detection_incorrecte: %',r; END IF;
     SELECT intervenants INTO membres FROM public.police_interceptions
     WHERE rencontre=r->>'rencontre' AND personnage='__test_pj_135__';
     IF membres<>jsonb_build_array('prive:__test_135_private__') THEN
       RAISE EXCEPTION 'intervenants_non_figes: %',membres; END IF;
     DELETE FROM public.police_interceptions WHERE rencontre=r->>'rencontre' AND personnage='__test_pj_135__';
     trouve:=true; EXIT;
   END IF;
 END LOOP;
 IF NOT trouve THEN RAISE EXCEPTION 'aucune_detection_privee_sur_60_tirages'; END IF;
END $t$;
-- Mixité : priorité de groupe policier et exclusion des agents privés du combat policier.
INSERT INTO public.batiments_etat(id,country,city,building_id,data)
VALUES('__test_commissariat_135__','republic','capitale','commissariat',
 jsonb_build_object('effectifsPolice',jsonb_build_object('policiers',jsonb_build_array(
 jsonb_build_object('matricule','POL-135-A','groupeId','POL-135-G','pa',12,'stats',jsonb_build_object('PER',100,'VOL',10),'buildingId','__test_bat_135__','roomId','terrain'),
 jsonb_build_object('matricule','POL-135-B','groupeId','POL-135-G','pa',12,'stats',jsonb_build_object('PER',100,'VOL',10),'buildingId','__test_bat_135__','roomId','terrain'),
 jsonb_build_object('matricule','POL-135-S','pa',12,'stats',jsonb_build_object('PER',100,'VOL',10),'buildingId','__test_bat_135__','roomId','terrain')
 ))));
DO $t$ DECLARE r jsonb; membres jsonb; i integer; trouve boolean:=false;
BEGIN
 FOR i IN 1..60 LOOP
   DELETE FROM public.police_detection_attempts WHERE personnage='__test_pj_135__';
   r:=public.police_detection_verifier('__test_bat_135__','terrain',NULL);
   IF coalesce((r->>'detecte')::boolean,false) THEN
     SELECT intervenants INTO membres FROM public.police_interceptions
       WHERE rencontre=r->>'rencontre' AND personnage='__test_pj_135__';
     IF r->>'rencontre' LIKE 'police-%' AND (r->>'effectif')::integer=2 THEN
       IF (SELECT count(*) FROM jsonb_array_elements_text(membres) x WHERE x IN ('POL-135-A','POL-135-B'))<>2
          OR jsonb_array_length(membres)<>2
       THEN RAISE EXCEPTION 'groupe_police_incorrect: %',membres; END IF;
       trouve:=true;
     END IF;
     DELETE FROM public.police_interceptions WHERE rencontre=r->>'rencontre' AND personnage='__test_pj_135__';
     IF trouve THEN EXIT; END IF;
   END IF;
 END LOOP;
 IF NOT trouve THEN RAISE EXCEPTION 'groupe_police_jamais_prioritaire_sur_60_tirages'; END IF;
END $t$;
INSERT INTO public.police_interceptions(personnage,rencontre,country,city,building,room,street)
VALUES ('__test_pj_135__','prive-test-135','republic','capitale','__test_bat_135__','terrain',NULL);
SET LOCAL ROLE authenticated;
DO $t$
DECLARE r jsonb; premier jsonb;
BEGIN
 premier:=public.police_combat_resoudre('prive-test-135',NULL,'__test_bat_135__','terrain',1);
 IF premier->>'ok' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'combat_prive_refuse: %',premier; END IF;
 r:=public.police_combat_resoudre('prive-test-135',NULL,'__test_bat_135__','terrain',1);
 IF r IS DISTINCT FROM premier THEN RAISE EXCEPTION 'combat_rejeu_verdict_different: % / %',premier,r; END IF;
END $t$;
-- Contre-épreuve : un autre personnage authentifié ne peut rejouer la rencontre.
SELECT set_config('request.jwt.claim.sub','c1350000-0000-4000-8000-000000000136',true);
DO $t$
DECLARE r jsonb;
BEGIN
 r:=public.police_combat_resoudre('prive-test-135',NULL,'__test_bat_135__','terrain',2);
 IF r->>'ok' IS DISTINCT FROM 'false' THEN RAISE EXCEPTION 'combat_access_non_autorise: %',r; END IF;
END $t$;
SELECT set_config('request.jwt.claim.sub','c1350000-0000-4000-8000-000000000135',true);
RESET ROLE;
-- Après un round valide, l'état des PA du garde reste dans le socle PNJ.
DO $t$
DECLARE v_pa integer;
BEGIN
 SELECT pa INTO v_pa FROM public.pnj_membres WHERE id='__test_135_private__';
 IF v_pa IS NULL OR v_pa NOT BETWEEN 0 AND 12 THEN RAISE EXCEPTION 'pa_garde_hors_bornes: %',v_pa; END IF;
END $t$;
-- Deux agents simultanés : le round commun arbitre l'effectif, sans tableau de vigiles de chantier.
INSERT INTO public.pnj_membres(id,famille,classe,nom,pays,proprietaire_pj,statut,pa,car_per,car_vol,ville,building_id,room_id)
VALUES('__test_135_renfort__','employe','beta','Renfort fictif','republic','__test_employeur_135__','actif',12,16,18,'capitale','__test_bat_135__','terrain');
INSERT INTO public.pnj_employes_metier(pnj_id,job,role_libelle,cout_jour)
VALUES('__test_135_renfort__','maitre_chien','Renfort fictif',0);
DO $t$ DECLARE r jsonb; BEGIN
 r:=public.securite_agents_prives_presents_interne('republic','capitale','__test_bat_135__','terrain',NULL,'__test_pj_135__');
 IF jsonb_array_length(r)<>2 THEN RAISE EXCEPTION 'effectif_multiple_manquant: %',r; END IF;
END $t$;
-- Le deuxième round avec deux agents utilise le combat commun ; il ne crée aucun état de chantier.
SET LOCAL ROLE authenticated;
DO $t$ DECLARE r jsonb; BEGIN
 r:=public.police_combat_resoudre('prive-test-135',NULL,'__test_bat_135__','terrain',2);
 IF r->>'ok' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'combat_deux_agents_refuse: %',r; END IF;
END $t$;
RESET ROLE;
-- Contre-épreuve : un agent déplacé hors de la zone ne peut poursuivre le combat.
UPDATE public.pnj_membres SET building_id='__autre__' WHERE id IN ('__test_135_private__','__test_135_renfort__');
SET LOCAL ROLE authenticated;
DO $t$ DECLARE r jsonb; BEGIN
 r:=public.police_combat_resoudre('prive-test-135',NULL,'__test_bat_135__','terrain',3);
 IF r->>'ok' IS DISTINCT FROM 'false' THEN RAISE EXCEPTION 'agent_eloigne_combat_accepte: %',r; END IF;
END $t$;
RESET ROLE;
