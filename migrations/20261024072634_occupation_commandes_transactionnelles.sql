-- #135 PREPAREE : police et dissimulation, memes PA, fonds et registre judiciaire.
BEGIN;
CREATE OR REPLACE FUNCTION public.terrain_occupation_action_preparer(p_terrain text,p_action text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $f$
DECLARE acteur text:=public.mon_personnage();p record;t record;e jsonb;regles jsonb;cha numeric;dup numeric;isn numeric;indice_d numeric;bonus numeric:=0;org record;m jsonb;grade integer;v numeric;taux numeric;delai integer;cout integer;
BEGIN
 IF acteur IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie');END IF;
 IF p_action NOT IN('police','corruption_police','cadavre') OR p_action IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','action_inconnue');END IF;
 SELECT * INTO p FROM public.personnages_donnees WHERE name=acteur FOR UPDATE;
 IF NOT FOUND OR p.current_building IS DISTINCT FROM p_terrain OR p_terrain NOT LIKE 'terrain-a-batir%' THEN RETURN jsonb_build_object('ok',false,'raison','pas_sur_place');END IF;
 IF coalesce(p.hp,0)<=0 OR coalesce(p.hospitalisation->>'dateFinParis','')>(statement_timestamp() AT TIME ZONE 'Europe/Paris')::date::text OR EXISTS(SELECT 1 FROM public.detention_active(acteur)) THEN RETURN jsonb_build_object('ok',false,'raison','acteur_indisponible');END IF;
 PERFORM public.terrain_police_traiter_interne(p.country||'_'||p_terrain);
 SELECT * INTO t FROM public.terrains_etat WHERE id=p.country||'_'||p_terrain AND country=p.country AND building_id=p_terrain FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','terrain_introuvable');END IF;
 e:=public.terrain_etat_lire(t.data);
 IF e->>'city' IS DISTINCT FROM p.current_city THEN RETURN jsonb_build_object('ok',false,'raison','terrain_incoherent');END IF;
 IF coalesce(e->>'succession_gel','')<>'' THEN RETURN jsonb_build_object('ok',false,'raison','terrain_gele');END IF;
 IF coalesce(e->>'policeAppellee','')<>'' OR coalesce((e->>'enqueteJusqua')::numeric,0)>extract(epoch FROM clock_timestamp())*1000 THEN RETURN jsonb_build_object('ok',false,'raison','intervention_en_cours','etat',e);END IF;
 IF (p_action='cadavre' AND e->>'pnj' IS DISTINCT FROM 'cadavre') OR coalesce(e->>'pnj','') NOT IN('cadavre','squatter_cool','squatter_agr') THEN RETURN jsonb_build_object('ok',false,'raison','occupation_incompatible','etat',e);END IF;
 SELECT data INTO regles FROM public.terrain_actions_regles WHERE id;
 isn:=(regles->'indices'->p.country->>'ISN')::numeric;indice_d:=(regles->'indices'->p.country->>'ID')::numeric;
 IF isn IS NULL OR indice_d IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','referentiel_indisponible');END IF;
 SELECT avg(c),avg(d) INTO cha,dup FROM (
 SELECT coalesce((p.stats->>'CHA')::numeric,8) c,coalesce((p.stats->>'DUP')::numeric,8) d
 UNION ALL SELECT mb.car_cha,mb.car_dup FROM public.pnj_membres mb JOIN public.pnj_employes_metier em ON em.pnj_id=mb.id
 WHERE mb.proprietaire_pj=acteur AND mb.leader_pj=acteur AND mb.statut='actif') x;
 IF cha::text IN('NaN','Infinity','-Infinity') OR dup::text IN('NaN','Infinity','-Infinity') OR coalesce(p.resources->>'dis','50') IN('NaN','Infinity','-Infinity') THEN RETURN jsonb_build_object('ok',false,'raison','etat_personnage_invalide');END IF;
 cha:=cha-CASE WHEN p.excommunie IS NOT NULL AND p.excommunie<>'null'::jsonb THEN 2 ELSE 0 END;
 IF p.stats_affaiblies ? 'CHA' THEN cha:=greatest(1,floor(cha*greatest(0,least(1,p.hp::numeric/100))+.5));ELSE cha:=floor(cha+.5);END IF;
 IF p.stats_affaiblies ? 'DUP' THEN dup:=greatest(1,floor(dup*greatest(0,least(1,p.hp::numeric/100))+.5));ELSE dup:=floor(dup+.5);END IF;
 FOR org IN SELECT data::jsonb d FROM public.organisations LOOP
  SELECT value INTO m FROM jsonb_array_elements(coalesce(org.d->'membres','[]')) WHERE value->>'nom'=acteur LIMIT 1;
  IF m IS NULL THEN CONTINUE;END IF;grade:=coalesce((m->>'gradeIdx')::integer,0);
  SELECT max((value->>'valeur')::numeric) INTO v FROM jsonb_array_elements(coalesce(regles->'bonus'->(org.d->>'type'),'[]')) WHERE (value->>'grade')::integer<=grade;
  bonus:=bonus+coalesce(v,0);
 END LOOP;
 delai:=greatest(6,floor(96-isn*.6+.5)::integer);cout:=0;
 IF p_action='police' THEN taux:=NULL;
 ELSIF p_action='corruption_police' THEN taux:=least(80,40+floor(dup*2));cout:=floor(100+isn*3);delai:=greatest(1,floor((96-isn*.6)/4+.5)::integer);
 ELSE taux:=least(85,floor(coalesce((p.resources->>'dis')::numeric,50)/2+cha/2)-floor(isn/5)+bonus/3);END IF;
 RETURN jsonb_build_object('ok',true,'etat',e,'occupation',coalesce(e->>'dateGeneration','historique')||':'||(e->>'pnj'),
 'taux',taux,'pa',CASE WHEN p_action='cadavre' THEN 2 ELSE 1 END,'cout',cout,'delaiHeures',delai,'prescriptionJours',greatest(7,floor(indice_d*.6+.5)::integer));
END;$f$;
REVOKE ALL ON FUNCTION public.terrain_occupation_action_preparer(text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.terrain_occupation_action_preparer(text,text) TO authenticated;
CREATE OR REPLACE FUNCTION public.terrain_occupation_action(p_terrain text,p_action text,p_occupation text,p_requete uuid,p_taux numeric DEFAULT NULL,p_cout integer DEFAULT 0) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $f$
DECLARE acteur text:=public.mon_personnage();p record;r record;c jsonb;e jsonb;resultat jsonb;paiement jsonb;jet integer;succes boolean;ms numeric:=floor(extract(epoch FROM clock_timestamp())*1000);cle text;entree jsonb;
BEGIN
 IF acteur IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie');END IF;
 IF p_requete IS NULL OR nullif(p_occupation,'') IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','requete_invalide');END IF;
 SELECT * INTO p FROM public.personnages_donnees WHERE name=acteur FOR UPDATE;
 SELECT a.* INTO r FROM public.terrain_actions_recus a WHERE a.acteur=p.id AND a.requete=p_requete;
 IF FOUND THEN
  IF (r.terrain,r.action,r.occupation) IS DISTINCT FROM (p.country||'_'||p_terrain,p_action,p_occupation) THEN RETURN jsonb_build_object('ok',false,'raison','requete_reutilisee');END IF;
  IF (r.resultat->>'cout')::integer IS DISTINCT FROM p_cout THEN RETURN jsonb_build_object('ok',false,'raison','requete_reutilisee');END IF;
  IF (r.resultat->>'taux')::numeric IS DISTINCT FROM p_taux THEN RETURN jsonb_build_object('ok',false,'raison','requete_reutilisee');END IF;
  SELECT data::jsonb INTO e FROM public.terrains_etat WHERE id=r.terrain;
  RETURN r.resultat||jsonb_build_object('rejeu',true,'etat',e);
 END IF;
 c:=public.terrain_occupation_action_preparer(p_terrain,p_action);
 IF c->>'ok' IS DISTINCT FROM 'true' THEN RETURN c;END IF;
 IF c->>'occupation' IS DISTINCT FROM p_occupation THEN RETURN jsonb_build_object('ok',false,'raison','occupation_modifiee','etat',c->'etat');END IF;
 IF (c->>'taux')::numeric IS DISTINCT FROM p_taux THEN RETURN jsonb_build_object('ok',false,'raison','taux_modifie');END IF;
 IF (c->>'cout')::integer IS DISTINCT FROM p_cout THEN RETURN jsonb_build_object('ok',false,'raison','cout_modifie');END IF;
 -- Verrouiller la contrepartie bancaire avant le payeur, selon le socle financier ordinaire.
 PERFORM 1 FROM public.comptes_bancaires WHERE personnage=acteur AND banque='nationale' FOR UPDATE;
 IF (c->>'cout')::numeric>0 AND coalesce(p.liquide,0)+coalesce((SELECT solde FROM public.comptes_bancaires WHERE personnage=acteur AND banque='nationale'),0)<(c->>'cout')::numeric THEN RETURN jsonb_build_object('ok',false,'raison','fonds_insuffisants');END IF;
 paiement:=public.payer_ordre(acteur,CASE WHEN p_action='cadavre' THEN 'faire_disparaitre_cadavre' ELSE 'appeler_police_terrain' END,(c->>'pa')::integer,0);
 IF paiement->>'ok' IS DISTINCT FROM 'true' THEN RETURN paiement;END IF;
 IF (c->>'cout')::numeric>0 AND public.helvetia_debiter_fonds_ordinaires(acteur,(c->>'cout')::numeric) IS NOT TRUE THEN RAISE EXCEPTION 'paiement_non_confirme';END IF;
 IF p_action='police' THEN succes:=true;jet:=NULL;ELSE jet:=public.terrain_negociation_jet_interne();succes:=jet<=(c->>'taux')::numeric;END IF;
 e:=c->'etat';cle:=p.country||'_'||p_terrain;
 IF p_action IN('police','corruption_police') AND succes THEN
  e:=e||jsonb_build_object('policeAppellee',ms,'policeInterventionAt',ms+(c->>'delaiHeures')::numeric*3600000,
   'interventionPolice',jsonb_build_object('statut','attente','occupation',p_occupation,'echeance',ms+(c->>'delaiHeures')::numeric*3600000,'requete',p_requete));
 END IF;
 IF p_action='cadavre' THEN
  IF succes THEN
   entree:=jsonb_build_object('type','cadavre_dissimule','auteur',acteur,'date',ms,'prescriptionAt',ms+(c->>'prescriptionJours')::numeric*86400000);
   e:=e||jsonb_build_object('pnj',NULL,'pnjData',NULL,'occupationScellee',true,'cadavreDisparuAt',ms,'prescriptionAt',entree->'prescriptionAt','actesIllegaux',coalesce(e->'actesIllegaux','[]')||jsonb_build_array(entree));
  ELSE
   entree:=jsonb_build_object('id','cadavre-'||p_requete,'type','suspicion_cadavre','terrain',p_terrain,'debut',ms,'fin',ms+86400000);
   paiement:=public.recherche_inscrire(entree);
   IF paiement->>'ok' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'recherche_non_confirmee';END IF;
  END IF;
 END IF;
 IF p_action<>'police' THEN
  UPDATE public.personnages_donnees SET resources=coalesce(resources,'{}')||jsonb_build_object('dis',greatest(0,coalesce((resources->>'dis')::numeric,50)-CASE WHEN succes THEN 5 WHEN p_action='cadavre' THEN 20 ELSE 15 END)),
   hp=greatest(0,hp-CASE WHEN p_action='cadavre' AND NOT succes THEN 5 ELSE 0 END),updated_at=clock_timestamp() WHERE id=p.id;
 END IF;
 -- Meme l'appel legal change la revision : une sauvegarde anterieure ne peut republier ses PA.
 UPDATE public.personnages_donnees SET updated_at=clock_timestamp() WHERE id=p.id;
 UPDATE public.terrains_etat SET data=e::text,updated_at=now() WHERE id=cle;
 resultat:=jsonb_build_object('ok',true,'succes',succes,'action',p_action,'taux',c->'taux','jet',jet,'cout',c->'cout','pa',c->'pa','delaiHeures',c->'delaiHeures','prescriptionJours',c->'prescriptionJours');
 INSERT INTO public.terrain_actions_recus VALUES(p.id,p_requete,cle,p_occupation,p_action,resultat);
 RETURN resultat||jsonb_build_object('etat',e);
END;$f$;
REVOKE ALL ON FUNCTION public.terrain_occupation_action(text,text,text,uuid,numeric,integer) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.terrain_occupation_action(text,text,text,uuid,numeric,integer) TO authenticated;
COMMIT;
