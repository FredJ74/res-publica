-- #219 PRÉPARÉE. Fred, 30/10, commentaire 6518723961. END = car_ent / ENT existant.
INSERT INTO public.pnj_metiers_profils(metier,car_int,car_cha,car_vol,car_per,car_dup,car_ent,classe,recrutable,note)
VALUES('squatter_cool',10,10,10,10,10,10,'beta',false,'PNJ unique squatteurs, arbitrage Fred 30/10'),
 ('squatter_agr',10,10,13,10,10,10,'beta',false,'PNJ unique squatteurs, arbitrage Fred 30/10')
ON CONFLICT(metier) DO NOTHING;
DO $profil$
BEGIN
 IF EXISTS(SELECT 1 FROM public.pnj_metiers_profils WHERE metier IN ('squatter_cool','squatter_agr')
 AND (car_int,car_cha,car_vol,car_per,car_dup,car_ent,classe,recrutable)
 IS DISTINCT FROM (10,10,CASE WHEN metier='squatter_agr' THEN 13 ELSE 10 END,10,10,10,'beta'::text,false)) THEN
 RAISE EXCEPTION 'profil_squatteurs_deja_different';END IF;
END $profil$;
CREATE OR REPLACE FUNCTION public.combat_occupant_terrain_interne(p_terrain text,p_acteur text)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path TO public,pg_temp AS $g$
DECLARE p public.personnages_donnees%ROWTYPE;t public.terrains_etat%ROWTYPE;e jsonb;profil public.pnj_metiers_profils%ROWTYPE;ident text;
BEGIN
 SELECT * INTO p FROM public.personnages_donnees WHERE name=p_acteur;
 SELECT * INTO t FROM public.terrains_etat WHERE id=p.country||'_'||p_terrain AND building_id=p_terrain FOR UPDATE;
 IF NOT FOUND THEN RETURN NULL;END IF;e:=t.data::jsonb;
 IF p.current_building IS DISTINCT FROM p_terrain OR p.current_city IS DISTINCT FROM e->>'city' OR e->>'pnj' NOT IN ('squatter_cool','squatter_agr') THEN RETURN NULL;END IF;
 SELECT * INTO profil FROM public.pnj_metiers_profils WHERE metier=e->>'pnj';
 ident:='occupation:'||t.id||':'||coalesce(e->>'dateGeneration','historique')||':'||profil.metier;
 IF e->>'pnjSocleId' IS DISTINCT FROM ident THEN
  UPDATE public.pnj_membres SET statut='disparu',maj_le=now() WHERE id=e->>'pnjSocleId'
   AND id LIKE 'occupation:%' AND statut='actif' AND leader_pj IS NULL AND leader_pnj_id IS NULL
   AND NOT EXISTS(SELECT 1 FROM public.batailles_engagements x JOIN public.batailles b ON b.id=x.bataille_id WHERE x.pnj_id=pnj_membres.id AND b.statut='en_cours');
 END IF;
 -- Famille technique générique employe, sans emploi/salaire/contrat ni propriétaire :
 -- aucune ligne pnj_employes_metier ni pouvoir de recrutement n'est créée.
 INSERT INTO public.pnj_membres(id,famille,nom,pays,ville,building_id,room_id,classe,pa,car_int,car_cha,car_vol,car_per,car_dup,car_ent)
 VALUES(ident,'employe','squatteurs',p.country,p.current_city,p_terrain,p.current_room,'beta',public.pnj_pa_max(),profil.car_int,profil.car_cha,profil.car_vol,profil.car_per,profil.car_dup,profil.car_ent)
 ON CONFLICT(id) DO NOTHING;
 PERFORM public.terrain_etat_fusionner_interne(t.id,jsonb_build_object('pnjSocleId',ident),t.country);
 RETURN ident;
END $g$;
REVOKE ALL ON FUNCTION public.combat_occupant_terrain_interne(text,text) FROM PUBLIC,anon,authenticated,service_role;
-- Extraire uniquement conditions et paiement du contrat vivant ; aucun jet ni conséquence.
DO $paiement$
DECLARE s text;fin integer;
BEGIN
 IF to_regprocedure('public.combat_agression_preparer_interne(text,text,integer)') IS NOT NULL THEN RETURN;END IF;
 SELECT prosrc INTO s FROM pg_proc WHERE oid='public.crime_neutraliser(text,text,integer)'::regprocedure;
 fin:=position('  v_taux := greatest(' IN s);
 IF fin=0 OR position('public.payer_ordre(v_moi, ''neutraliser_'' || p_mode, v_pa, 0)' IN s)=0 THEN RAISE EXCEPTION 'neutraliser_conditions_non_examinees';END IF;
 s:=substring(s FROM 1 FOR fin-1)||' RETURN jsonb_build_object(''ok'',true,''paie'',v_paie,''dis'',v_dis);END;';
 EXECUTE format('CREATE FUNCTION public.combat_agression_preparer_interne(p_cible text,p_mode text,p_per_pnj integer DEFAULT 10) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO public,pg_temp AS %L',s);
END $paiement$;
REVOKE ALL ON FUNCTION public.combat_agression_preparer_interne(text,text,integer) FROM PUBLIC,anon,authenticated,service_role;
