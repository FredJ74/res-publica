-- APPLICATION ATTESTÉE par le registre canonique du 31/10/2026 : version 20261023231127.
-- Archivage documentaire seulement ; ne pas rejouer.
-- Negociation des squatteurs : verdict, PA, paiement et depart dans une seule transaction.
-- Une offre refusee ne verse pas d'argent. Une tentative valide coute toujours 1 PA.
BEGIN;
CREATE TABLE IF NOT EXISTS public.terrain_negociations_refus (
 acteur uuid NOT NULL, terrain text NOT NULL, occupation text NOT NULL, montant integer NOT NULL CHECK(montant>0),
 PRIMARY KEY(acteur,terrain,occupation)
);
CREATE TABLE IF NOT EXISTS public.terrain_negociations_recus (
 acteur uuid NOT NULL, requete uuid NOT NULL, terrain text NOT NULL, occupation text NOT NULL,
 montant integer NOT NULL CHECK(montant>0), resultat jsonb NOT NULL, cree_le timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(acteur,requete)
);
ALTER TABLE public.terrain_negociations_refus ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.terrain_negociations_recus ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.terrain_negociations_refus,public.terrain_negociations_recus FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.terrain_negociation_jet_interne() RETURNS integer
LANGUAGE sql VOLATILE SET search_path=public,pg_temp AS $$ SELECT 1+floor(random()*100)::integer $$;
REVOKE ALL ON FUNCTION public.terrain_negociation_jet_interne() FROM PUBLIC,anon,authenticated;

-- Contexte releve au serveur, jamais des caracteristiques ni un taux proposes par le client.
CREATE OR REPLACE FUNCTION public.terrain_negociation_preparer(p_terrain text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $f$
DECLARE acteur text:=public.mon_personnage();p record;t record;e jsonb;revision text;dernier integer;
 cha numeric;social numeric;bonus integer;org record;m jsonb;grade integer;
BEGIN
 IF acteur IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie'); END IF;
 SELECT * INTO p FROM public.personnages_donnees WHERE name=acteur FOR UPDATE;
 IF NOT FOUND OR p.current_building IS DISTINCT FROM p_terrain OR p_terrain NOT LIKE 'terrain-a-batir%' THEN
  RETURN jsonb_build_object('ok',false,'raison','pas_sur_place'); END IF;
 SELECT * INTO t FROM public.terrains_etat WHERE id=p.country||'_'||p_terrain
  AND country=p.country AND building_id=p_terrain FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','terrain_introuvable'); END IF;
 e:=public.terrain_etat_lire(t.data);
 IF e IS NULL OR e->>'city' IS DISTINCT FROM p.current_city THEN RETURN jsonb_build_object('ok',false,'raison','terrain_incoherent'); END IF;
 IF coalesce(e->>'succession_gel','')<>'' THEN RETURN jsonb_build_object('ok',false,'raison','terrain_gele','etat',e); END IF;
 IF coalesce(e->>'policeAppellee','')<>'' OR coalesce((e->>'enqueteJusqua')::numeric,0)>extract(epoch FROM clock_timestamp())*1000 THEN
  RETURN jsonb_build_object('ok',false,'raison','intervention_en_cours','etat',e); END IF;
 IF coalesce(e->>'pnj','') NOT IN ('squatter_cool','squatter_agr') THEN
  RETURN jsonb_build_object('ok',false,'raison','aucun_squatteur','etat',e); END IF;
 revision:=coalesce(e->>'dateGeneration','historique')||':'||(e->>'pnj');
 SELECT n.montant INTO dernier FROM public.terrain_negociations_refus n WHERE n.acteur=p.id AND n.terrain=t.id AND n.occupation=revision;
 SELECT avg(v) INTO cha FROM (
  SELECT coalesce((p.stats->>'CHA')::numeric,8) v
  UNION ALL SELECT mb.car_cha::numeric
   FROM public.pnj_membres mb JOIN public.pnj_employes_metier em ON em.pnj_id=mb.id
   WHERE mb.proprietaire_pj=acteur AND mb.leader_pj=acteur AND mb.statut='actif'
 ) valeurs;
 cha:=cha-CASE WHEN p.excommunie IS NOT NULL AND p.excommunie<>'null'::jsonb THEN 2 ELSE 0 END;
 IF p.stats_affaiblies ? 'CHA' THEN cha:=greatest(1,floor(cha*greatest(0,least(1,coalesce(p.hp,0)::numeric/100))+.5));
 ELSE cha:=floor(cha+.5); END IF;
 IF p.country='republic' THEN
  SELECT (data->>'social')::numeric INTO social FROM public.indices_villes WHERE id=p.country||'_'||p.current_city;
  social:=coalesce(social,45);
 ELSE social:=CASE p.country WHEN 'narco' THEN 25 WHEN 'soviet' THEN 35 WHEN 'khalija' THEN 40 ELSE 45 END; END IF;
 bonus:=0;
 FOR org IN SELECT data::jsonb d FROM public.organisations LOOP
  SELECT v INTO m FROM jsonb_array_elements(coalesce(org.d->'membres','[]'::jsonb)) v WHERE v->>'nom'=acteur LIMIT 1;
  IF m IS NULL THEN CONTINUE; END IF;
  grade:=coalesce((m->>'gradeIdx')::integer,0);
  bonus:=bonus+CASE org.d->>'type'
   WHEN 'economique' THEN CASE WHEN grade>=3 THEN 30 WHEN grade>=2 THEN 20 WHEN grade>=1 THEN 10 ELSE 0 END
   WHEN 'syndicale' THEN CASE WHEN grade>=2 THEN 25 WHEN grade>=1 THEN 15 ELSE 0 END ELSE 0 END;
 END LOOP;
 RETURN jsonb_build_object('ok',true,'etat',e,'occupation',revision,'dernierRefus',dernier,
  'minimum',greatest(CASE WHEN e->>'pnj'='squatter_agr' THEN 500 ELSE 1 END,coalesce(dernier::numeric+1,1)),
  'baseTaux',50+2*(cha-13)+(social-50)/5+bonus);
END;$f$;
REVOKE ALL ON FUNCTION public.terrain_negociation_preparer(text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.terrain_negociation_preparer(text) TO authenticated;

CREATE OR REPLACE FUNCTION public.terrain_negociation_conclure(p_terrain text,p_occupation text,p_montant integer,p_requete uuid) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $f$
DECLARE acteur text:=public.mon_personnage();p record;r record;c jsonb;e jsonb;cle text;solde numeric;
 paiement jsonb;resultat jsonb;taux integer;jet integer;accepte boolean;bonus integer:=0;argent integer;
BEGIN
 IF acteur IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie'); END IF;
 IF p_requete IS NULL OR p_montant IS NULL OR p_montant<1 OR nullif(p_occupation,'') IS NULL THEN
  RETURN jsonb_build_object('ok',false,'raison','requete_invalide'); END IF;
 SELECT * INTO p FROM public.personnages_donnees WHERE name=acteur FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','personnage_introuvable'); END IF;
 SELECT n.* INTO r FROM public.terrain_negociations_recus n WHERE n.acteur=p.id AND n.requete=p_requete;
 IF FOUND THEN
  IF r.terrain IS DISTINCT FROM p.country||'_'||p_terrain OR r.occupation IS DISTINCT FROM p_occupation OR r.montant<>p_montant THEN
   RETURN jsonb_build_object('ok',false,'raison','requete_reutilisee'); END IF;
  resultat:=r.resultat||jsonb_build_object('rejeu',true);
  SELECT public.terrain_etat_lire(data) INTO e FROM public.terrains_etat WHERE id=r.terrain;
 ELSE
  c:=public.terrain_negociation_preparer(p_terrain);
  IF c->>'ok' IS DISTINCT FROM 'true' THEN RETURN c; END IF;
  IF c->>'occupation' IS DISTINCT FROM p_occupation THEN RETURN jsonb_build_object('ok',false,'raison','occupation_modifiee','etat',c->'etat'); END IF;
  IF p_montant<(c->>'minimum')::numeric THEN RETURN jsonb_build_object('ok',false,'raison','offre_trop_faible','minimum',c->'minimum','dernierRefus',c->'dernierRefus'); END IF;
  SELECT coalesce(cb.solde,0) INTO solde FROM public.comptes_bancaires cb WHERE cb.personnage=acteur AND cb.banque='nationale' FOR UPDATE;
  IF coalesce(p.liquide,0)+coalesce(solde,0)<p_montant THEN RETURN jsonb_build_object('ok',false,'raison','fonds_insuffisants'); END IF;
  paiement:=public.payer_ordre(acteur,'negocier_squatteurs',1,0);
  IF paiement->>'ok' IS DISTINCT FROM 'true' THEN RETURN paiement; END IF;
  argent:=CASE WHEN p_montant>=4000 THEN 20 WHEN p_montant>=1000 THEN floor(8+(p_montant-1000)::numeric*4/1000)
   WHEN p_montant>=500 THEN floor(5+(p_montant-500)::numeric*3/500) ELSE floor(p_montant::numeric/100) END;
  taux:=greatest(5,least(90,floor((c->>'baseTaux')::numeric+argent+.5)::integer));
  jet:=public.terrain_negociation_jet_interne();accepte:=jet<=taux;e:=c->'etat';cle:=p.country||'_'||p_terrain;
  IF accepte THEN
   IF public.helvetia_debiter_fonds_ordinaires(acteur,p_montant) IS NOT TRUE THEN RAISE EXCEPTION 'paiement_non_confirme'; END IF;
   IF e->>'pnj'='squatter_cool' THEN
    UPDATE public.personnages_donnees SET moral=least(100,coalesce(moral,50)+1) WHERE id=p.id RETURNING moral-coalesce(p.moral,50) INTO bonus;
   END IF;
   e:=public.terrain_etat_fusionner_interne(cle,'{"pnj":null,"pnjData":null,"occupationScellee":true}'::jsonb,p.country);
  ELSE
   INSERT INTO public.terrain_negociations_refus VALUES(p.id,cle,p_occupation,p_montant)
    ON CONFLICT ON CONSTRAINT terrain_negociations_refus_pkey DO UPDATE SET montant=excluded.montant;
  END IF;
  resultat:=jsonb_build_object('ok',true,'accepte',accepte,'pnj',c->'etat'->>'pnj','montant',p_montant,'taux',taux,'jet',jet,'bonusMoral',bonus);
  INSERT INTO public.terrain_negociations_recus(acteur,requete,terrain,occupation,montant,resultat) VALUES(p.id,p_requete,cle,p_occupation,p_montant,resultat);
 END IF;
 SELECT jsonb_build_object('pa',d.pa,'arg',d.arg,'liquide',d.liquide,'moral',d.moral,
  'solde_national',coalesce((SELECT cb.solde FROM public.comptes_bancaires cb WHERE cb.personnage=acteur AND cb.banque='nationale'),0))
  INTO paiement FROM public.personnages_donnees d WHERE id=p.id;
 RETURN resultat||jsonb_build_object('etat',e,'paiement',paiement);
END;$f$;
REVOKE ALL ON FUNCTION public.terrain_negociation_conclure(text,text,integer,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.terrain_negociation_conclure(text,text,integer,uuid) TO authenticated;
COMMIT;
