-- Banc indépendant des inventaires. À exécuter APRÈS la migration, dans BEGIN/ROLLBACK.
-- Les données sont exclusivement fictives. Les savepoints isolent chaque issue.
INSERT INTO auth.users(id,instance_id,aud,role)
VALUES('c1350000-0000-4000-8000-000000000235','00000000-0000-0000-0000-000000000000','authenticated','authenticated');
SELECT set_config('request.jwt.claim.sub','c1350000-0000-4000-8000-000000000235',true);
INSERT INTO public.personnages_donnees(name,user_id,country,current_city,current_building,current_room,hp,pa,resources,stats)
VALUES('__test_pj_135_issues__','c1350000-0000-4000-8000-000000000235','republic','capitale','__test_bat_135_issues__','terrain',100,12,'{"dis":0}'::jsonb,'{"PER":8,"VOL":8}'::jsonb);
INSERT INTO public.pnj_membres(id,famille,classe,nom,pays,proprietaire_pj,statut,pa,car_per,car_vol,ville,building_id,room_id)
VALUES('__test_garde_135_issues__','employe','beta','Garde fictif','republic','__test_employeur_135_issues__','actif',12,100,19,'capitale','__test_bat_135_issues__','terrain');
INSERT INTO public.pnj_employes_metier(pnj_id,job,role_libelle,cout_jour)
VALUES('__test_garde_135_issues__','agent_securite','Garde fictif',0);
INSERT INTO public.jugements(id,country,city,accuse,motif,executee,data)
VALUES('__test_jugement_135_issues__','republic','capitale','__test_pj_135_issues__','test',false,'{"motifs":[{"jours":1}]}'::jsonb);
SAVEPOINT avant_reddition;
INSERT INTO public.police_interceptions(personnage,rencontre,country,city,building,room,street)
VALUES('__test_pj_135_issues__','prive-reddition-135','republic','capitale','__test_bat_135_issues__','terrain',NULL);
SET LOCAL ROLE authenticated;
DO $t$ DECLARE r jsonb; BEGIN
 r:=public.police_reddition_resoudre('prive-reddition-135');
 IF r->>'ok' IS DISTINCT FROM 'true' OR r->>'detention_id' IS NULL THEN
   RAISE EXCEPTION 'reddition_privee_sans_detention: %',r;
 END IF;
END $t$;
RESET ROLE;
ROLLBACK TO SAVEPOINT avant_reddition;
SAVEPOINT avant_fuite;
INSERT INTO public.police_interceptions(personnage,rencontre,country,city,building,room,street)
VALUES('__test_pj_135_issues__','prive-fuite-135','republic','capitale','__test_bat_135_issues__','terrain',NULL);
SET LOCAL ROLE authenticated;
DO $t$ DECLARE r jsonb; BEGIN
 BEGIN
   r:=public.police_fuite_resoudre('prive-fuite-135');
   IF r->>'ok' IS DISTINCT FROM 'true' THEN
     RAISE EXCEPTION 'fuite_privee_non_resolue: %',r;
   END IF;
 EXCEPTION WHEN raise_exception THEN
   -- Une fuite réussie doit trouver une sortie de bâtiment réelle.
   -- Le décor __test_bat_135_issues__ n'en a volontairement pas.
   IF SQLERRM IS DISTINCT FROM 'sortie_batiment_inconnue' THEN RAISE; END IF;
 END;
END $t$;
RESET ROLE;
ROLLBACK TO SAVEPOINT avant_fuite;
-- Les contrôles sans policiers utilisent la même fuite et la même détention judiciaire.
