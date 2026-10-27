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
INSERT INTO public.police_interceptions(personnage,rencontre,country,city,building,room,street)
VALUES ('__test_pj_135__','prive-test-135','republic','capitale','__test_bat_135__','terrain',NULL);
SET LOCAL ROLE authenticated;
DO $t$
DECLARE r jsonb; premier jsonb; pa_avant integer; pa_apres integer;
BEGIN
 premier:=public.police_combat_resoudre('prive-test-135',NULL,'__test_bat_135__','terrain',1);
 IF premier->>'ok' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'combat_prive_refuse: %',premier; END IF;
 SELECT pa INTO pa_avant FROM public.pnj_membres WHERE id='__test_135_private__';
 r:=public.police_combat_resoudre('prive-test-135',NULL,'__test_bat_135__','terrain',1);
 SELECT pa INTO pa_apres FROM public.pnj_membres WHERE id='__test_135_private__';
 IF r IS DISTINCT FROM premier OR pa_apres IS DISTINCT FROM pa_avant
 THEN RAISE EXCEPTION 'combat_idempotence_refuse: avant %, apres %, pa %/%',premier,r,pa_avant,pa_apres; END IF;
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
