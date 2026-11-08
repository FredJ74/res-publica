-- BASE JETABLE EXCLUSIVEMENT. Aucun compte ni solde réel. Annulation intégrale.
-- Installer la migration préparée dans la base jetable avant ce banc.
BEGIN;
DO $g$ BEGIN
 IF current_setting('hg.banc_jetable',true) IS DISTINCT FROM 'tirages_dons' THEN
  RAISE EXCEPTION 'Ce banc exige le PostgreSQL jetable dédié, jamais la production';END IF;
END $g$;
CREATE TEMP TABLE bilan(cas text,ok boolean) ON COMMIT DROP;
GRANT SELECT,INSERT ON bilan TO authenticated;
INSERT INTO public.personnages_donnees(name,user_id,country,current_city,current_building,current_room,pa,hp,moral,arg,liquide,stats,resources,inventory)
 VALUES('HG-Tirages-Fixture','00000000-0000-4000-9000-000000008001','republic','capitale','banc-tirages','salle',30,100,75,1000,1000,'{"DUP":8}','{"pop":50,"inf":50,"dis":50}','[]');
INSERT INTO public.pnj_lieux_metiers(pays,ville,building_id,room_id,nom,job,rel)
 SELECT pays,'capitale','banc-tirages','salle','HG-'||j,j,'neutral'
 FROM unnest(ARRAY['commissaire','policier','inspecteur','juge','banquier','serveur'])j
 CROSS JOIN unnest(ARRAY['republic','khalija'])pays;
INSERT INTO public.pnj_membres(id,famille,classe,nom,pays,proprietaire_pj,statut,car_dup)
 VALUES('hg-tirages-groupe','employe','beta','HG-Accompagnant','republic','HG-Tirages-Fixture','actif',5);
INSERT INTO public.pnj_employes_metier(pnj_id,job,role_libelle) VALUES('hg-tirages-groupe','barman','Fixture');
CREATE FUNCTION pg_temp.groupe_tirage(p_suit boolean) RETURNS void LANGUAGE sql SECURITY DEFINER AS $f$
 UPDATE public.pnj_membres SET leader_pj=CASE WHEN p_suit THEN 'HG-Tirages-Fixture' END WHERE id='hg-tirages-groupe'
$f$;
-- Lecteur de preuve borné au seul acteur fictif ; les commandes ci-dessous restent authenticated.
CREATE FUNCTION pg_temp.etat_tirage() RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path=public,pg_temp AS $f$
 SELECT jsonb_build_object('fiche',to_jsonb(d),'recus',(SELECT count(*)FROM public.jauges_actions_recus WHERE acteur=d.name),
  'debits',(SELECT count(*)FROM public.fonds_debits WHERE acteur=d.name)) FROM public.personnages_donnees d WHERE name='HG-Tirages-Fixture'
$f$;
CREATE FUNCTION pg_temp.reinitialiser_tirage(p_dis integer DEFAULT 50,p_stats jsonb DEFAULT '{"DUP":8}',p_employes jsonb DEFAULT '[]',p_pays text DEFAULT 'republic')
 RETURNS void LANGUAGE sql SECURITY DEFINER SET search_path=public,pg_temp AS $f$
 UPDATE public.personnages_donnees SET country=p_pays,resources=jsonb_build_object('dis',p_dis,'pop',50,'inf',50),stats=p_stats,employes=p_employes,
  effets_actifs='[]',stats_affaiblies='{}',hp=100,pa=30,arg=1000,liquide=1000 WHERE name='HG-Tirages-Fixture';
 UPDATE public.pnj_membres SET leader_pj=NULL WHERE id='hg-tirages-groupe'
$f$;
SELECT set_config('role','authenticated',true),set_config('request.path','/rpc/jauges_ordre_executer',true),
 set_config('request.jwt.claim.sub','00000000-0000-4000-9000-000000008001',true);
DO $b$
DECLARE avant jsonb;apres jsonb;v jsonb;v2 jsonb;j text;t integer;jet integer;perte integer;i integer:=0;
 succes boolean:=false;echec boolean:=false;cle uuid;refuse boolean:=false;
BEGIN
 avant:=pg_temp.etat_tirage();
 v:=public.jauges_ordre_executer('don_argent_pnj',md5('ancien')::uuid,'{"nom":"HG-commissaire","montant":10}');
 INSERT INTO bilan VALUES('ancien_ecran_refuse_avant_debit',v->>'raison'='contexte_invalide' AND avant=pg_temp.etat_tirage());
 v:=public.jauges_ordre_executer('don_argent_pnj',md5('injecte')::uuid,'{"nom":"HG-commissaire","montant":10,"contrat_dis":1,"DUP":99}');
 INSERT INTO bilan VALUES('stat_proposee_refusee',v->>'raison'='contexte_invalide' AND avant=pg_temp.etat_tirage());
 v:=public.jauges_ordre_executer('don_argent_pnj',md5('absent')::uuid,'{"nom":"Absent","montant":10,"contrat_dis":1}');
 INSERT INTO bilan VALUES('pnj_absent_sans_mutation',v->>'raison'='pnj_non_present' AND avant=pg_temp.etat_tirage());
 FOR j IN SELECT unnest(ARRAY['commissaire','policier','inspecteur','juge']) LOOP
  FOR k IN 1..10 LOOP
   i:=i+1;PERFORM pg_temp.reinitialiser_tirage();
   PERFORM setseed(k::double precision/11);jet:=floor(random()*100)::integer+1;
   PERFORM setseed(k::double precision/11);
   t:=least(CASE j WHEN 'commissaire' THEN 70 WHEN 'policier' THEN 65 WHEN 'inspecteur' THEN 70 ELSE 55 END,
     CASE j WHEN 'commissaire' THEN 30 WHEN 'policier' THEN 25 WHEN 'inspecteur' THEN 35 ELSE 20 END+16);
   perte:=CASE WHEN jet<=t THEN CASE j WHEN 'commissaire' THEN 5 WHEN 'policier' THEN 3 WHEN 'inspecteur' THEN 5 ELSE 8 END
    ELSE CASE j WHEN 'commissaire' THEN 20 WHEN 'policier' THEN 15 WHEN 'inspecteur' THEN 15 ELSE 25 END END;
   succes:=succes OR jet<=t;echec:=echec OR jet>t;cle:=md5('jet'||i)::uuid;
   v:=public.jauges_ordre_executer('don_argent_pnj',cle,jsonb_build_object('nom','HG-'||j,'montant',10,'contrat_dis',1));
   INSERT INTO bilan VALUES('formule_'||j||'_'||k,(v->>'ok')::boolean AND (v->>'contrat_dis')::int=1
     AND (v->>'dis_jet')::int=jet AND (v->>'dis_taux')::int=t AND (v->>'dis')::int=50-perte AND (v->>'liquide')::int=990);
   avant:=pg_temp.etat_tirage();
   v2:=public.jauges_ordre_executer('don_argent_pnj',cle,jsonb_build_object('nom','HG-'||j,'montant',10,'contrat_dis',1));
   INSERT INTO bilan VALUES('rejeu_'||j||'_'||k,(v2->>'rejeu')::boolean AND v2->'dis_jet'=v->'dis_jet' AND avant=pg_temp.etat_tirage());
  END LOOP;
 END LOOP;
 INSERT INTO bilan VALUES('succes_et_echec_reellement_couverts',succes AND echec);
 PERFORM pg_temp.reinitialiser_tirage(7);
 avant:=pg_temp.etat_tirage();
 v:=public.jauges_ordre_executer('don_argent_pnj',cle,jsonb_build_object('nom','HG-juge','montant',10,'contrat_dis',1));
 INSERT INTO bilan VALUES('rejeu_relit_dis_plus_recente',(v->>'dis')::int=7 AND (v->>'rejeu')::boolean AND avant=pg_temp.etat_tirage());
 v:=public.jauges_ordre_executer('don_argent_pnj',cle,jsonb_build_object('nom','HG-juge','montant',11,'contrat_dis',1));
 INSERT INTO bilan VALUES('cle_reutilisee_refusee',v->>'raison'='requete_reutilisee' AND avant=pg_temp.etat_tirage());
 -- Groupe : même moyenne/arrondi que getStatEffective, mais composition et stats vérifiées au socle.
 PERFORM pg_temp.reinitialiser_tirage(50,'{"DUP":8}','[{"pnjId":"hg-tirages-groupe","job":"barman","inGroupe":true,"stats":{"DUP":5}}]');
 PERFORM pg_temp.groupe_tirage(true);
 v:=public.jauges_ordre_executer('don_argent_pnj',md5('groupe-valide')::uuid,'{"nom":"HG-commissaire","montant":10,"contrat_dis":1}');
 INSERT INTO bilan VALUES('groupe_moyenne_arrondie_identique',(v->>'dis_taux')::int=44);
 PERFORM pg_temp.reinitialiser_tirage(50,'{"DUP":8}','[{"pnjId":"hg-tirages-groupe","job":"barman","inGroupe":true,"stats":{"DUP":99}}]');
 PERFORM pg_temp.groupe_tirage(true);avant:=pg_temp.etat_tirage();
 BEGIN
  PERFORM public.jauges_ordre_executer('don_argent_pnj',md5('groupe-falsifie')::uuid,'{"nom":"HG-commissaire","montant":10,"contrat_dis":1}');
  INSERT INTO bilan VALUES('groupe_stats_injectees_refusees',false);
 EXCEPTION WHEN raise_exception THEN
  INSERT INTO bilan VALUES('groupe_stats_injectees_refusees',SQLERRM='don_caracteristique_historique_non_reconciliee' AND avant=pg_temp.etat_tirage());
 END;
 PERFORM pg_temp.reinitialiser_tirage();PERFORM pg_temp.groupe_tirage(true);avant:=pg_temp.etat_tirage();
 BEGIN
  PERFORM public.jauges_ordre_executer('don_argent_pnj',md5('groupe-omis')::uuid,'{"nom":"HG-commissaire","montant":10,"contrat_dis":1}');
  INSERT INTO bilan VALUES('groupe_omis_refuse_sans_debit',false);
 EXCEPTION WHEN raise_exception THEN
  INSERT INTO bilan VALUES('groupe_omis_refuse_sans_debit',SQLERRM='don_groupe_historique_non_reconcilie' AND avant=pg_temp.etat_tirage());
 END;
 PERFORM pg_temp.reinitialiser_tirage(0);
 v:=public.jauges_ordre_executer('don_argent_pnj',md5('banquier-zero')::uuid,'{"nom":"HG-banquier","montant":10,"contrat_dis":1}');
 INSERT INTO bilan VALUES('zero_semantique_historique_preservee',(v->>'dis')::int=55 AND v->'dis_jet'='null'::jsonb);
 PERFORM pg_temp.reinitialiser_tirage(99);
 v:=public.jauges_ordre_executer('don_argent_pnj',md5('banquier-cap')::uuid,'{"nom":"HG-banquier","montant":10,"contrat_dis":1}');
 INSERT INTO bilan VALUES('banquier_plafond_100',(v->>'dis')::int=100);
 PERFORM pg_temp.reinitialiser_tirage();
 v:=public.jauges_ordre_executer('don_argent_pnj',md5('pauvre')::uuid,'{"nom":"HG-commissaire","montant":10000,"contrat_dis":1}');
 INSERT INTO bilan VALUES('fonds_insuffisants_pas_de_jet_ni_debit',v->>'raison'='fonds_insuffisants' AND (pg_temp.etat_tirage()->'fiche'->>'liquide')::int=1000);
 -- Refus préalable existant à 15 % pour cette fixture d'un autre empire, sans toucher Sovarka.
 PERFORM pg_temp.reinitialiser_tirage(50,'{"DUP":8}','[]','khalija');
 FOR k IN 1..100 LOOP
  PERFORM setseed(k::double precision/101);jet:=floor(random()*100)::int+1;
  IF jet<=15 THEN
   PERFORM setseed(k::double precision/101);
   v:=public.jauges_ordre_executer('don_argent_pnj',md5('refus')::uuid,'{"nom":"HG-commissaire","montant":10,"contrat_dis":1}');
   refuse:=(v->>'refuse')::boolean AND (v->>'dis')::int=35 AND (v->>'liquide')::int=1000;EXIT;
  END IF;
 END LOOP;
 INSERT INTO bilan VALUES('refus_prealable_sans_debit',refuse);
END $b$;
SELECT * FROM bilan ORDER BY cas;
DO $b$ BEGIN IF EXISTS(SELECT 1 FROM bilan WHERE ok IS NOT TRUE)THEN RAISE EXCEPTION 'tirages_dons_banc_echec';END IF;RAISE NOTICE 'BILAN_TIRAGES_DONS %',(SELECT jsonb_build_object('cas',count(*),'ok',count(*) FILTER(WHERE ok))FROM bilan);END $b$;
ROLLBACK;
