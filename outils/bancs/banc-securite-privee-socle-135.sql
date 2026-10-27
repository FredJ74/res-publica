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
 RAISE NOTICE 'Banc #135 : 4 assertions réussies en transaction annulée';
END $t$;
