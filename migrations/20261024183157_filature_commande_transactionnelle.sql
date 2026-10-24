-- L09 prototype privé : coût, jet, bénédiction et rapport dans une transaction.
BEGIN;
DO $g$ BEGIN IF EXISTS(SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname='personnage_stat_jet_interne' AND (p.oid IS DISTINCT FROM to_regprocedure('public.personnage_stat_jet_interne(text,text)') OR md5(p.prosrc)<>'7b64506b0ba5338f93d0d2959de4e67a')) THEN RAISE EXCEPTION 'definition_non_examinee: personnage_stat_jet_interne';END IF;END;$g$;
DO $g$ BEGIN IF EXISTS(SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname='personnage_securite_jet_interne' AND (p.oid IS DISTINCT FROM to_regprocedure('public.personnage_securite_jet_interne(text)') OR md5(p.prosrc)<>'106d27dfe6006c5b738d600ed99d2a07')) THEN RAISE EXCEPTION 'definition_non_examinee: personnage_securite_jet_interne';END IF;END;$g$;
DO $g$ BEGIN IF EXISTS(SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname='police_filature_commande' AND (p.oid IS DISTINCT FROM to_regprocedure('public.police_filature_commande(text,uuid)') OR md5(p.prosrc)<>'b9fb18b681d2f59a9d0cadfb74da364c')) THEN RAISE EXCEPTION 'definition_non_examinee: police_filature_commande';END IF;END;$g$;
CREATE TABLE IF NOT EXISTS public.police_filatures_recus(acteur uuid NOT NULL,requete uuid NOT NULL,cible text NOT NULL,resultat jsonb NOT NULL,traitee_at timestamptz NOT NULL,PRIMARY KEY(acteur,requete));
ALTER TABLE public.police_filatures_recus ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.police_filatures_recus FROM PUBLIC,anon,authenticated,service_role;

-- Projection des trois caractéristiques utilisées par ces actes, mêmes règles que getStatEffective.
CREATE OR REPLACE FUNCTION public.personnage_stat_jet_interne(p_nom text,p_cle text) RETURNS numeric
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $f$
DECLARE p record;valeur numeric;
BEGIN
 IF p_cle NOT IN('CHA','DUP','PER') OR p_cle IS NULL THEN RAISE EXCEPTION 'caracteristique_jet_non_supportee';END IF;
 SELECT * INTO p FROM public.personnages_donnees WHERE name=p_nom;
 IF NOT FOUND THEN RAISE EXCEPTION 'acteur_jet_absent';END IF;
 SELECT avg(v) INTO valeur FROM(
  SELECT (p.stats->>p_cle)::numeric v
  UNION ALL SELECT (to_jsonb(m)->>('car_'||lower(p_cle)))::numeric FROM public.pnj_membres m JOIN public.pnj_employes_metier em ON em.pnj_id=m.id
  WHERE m.proprietaire_pj=p_nom AND m.leader_pj=p_nom AND m.statut='actif'
 ) valeurs;
 valeur:=coalesce(valeur,(p.stats->>p_cle)::numeric,8);
 IF p_cle='CHA' AND p.excommunie IS NOT NULL AND p.excommunie<>'null'::jsonb THEN valeur:=valeur-2;END IF;
 IF p.stats_affaiblies ? p_cle THEN RETURN greatest(1,floor(valeur*greatest(0,least(1,coalesce(p.hp,0)::numeric/100))+.5));END IF;
 RETURN floor(valeur+.5);
END;$f$;
REVOKE ALL ON FUNCTION public.personnage_stat_jet_interne(text,text) FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION public.personnage_securite_jet_interne(p_nom text) RETURNS numeric
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $f$
DECLARE p record;v numeric;
BEGIN
 SELECT * INTO p FROM public.personnages_donnees WHERE name=p_nom;
 IF NOT FOUND THEN RAISE EXCEPTION 'acteur_jet_absent';END IF;
 IF p.country='republic' THEN SELECT (data->>'isn')::numeric INTO v FROM public.indices_villes WHERE id=p.country||'_'||p.current_city;
 ELSE SELECT (data->'indices'->p.country->>'ISN')::numeric INTO v FROM public.terrain_actions_regles WHERE id;END IF;
 RETURN coalesce(v,30);
END;$f$;
REVOKE ALL ON FUNCTION public.personnage_securite_jet_interne(text) FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION public.police_filature_commande(p_cible text,p_requete uuid) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $f$
DECLARE moi text:=public.mon_personnage();p record;site record;ancien record;r jsonb;rapport jsonb;bonus integer;jet integer;taux numeric;per_cible numeric;inf_cible numeric;cible text:=btrim(coalesce(p_cible,''));
BEGIN
 IF moi IS NULL OR auth.uid() IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie');END IF;
 IF p_requete IS NULL OR cible='' THEN RETURN jsonb_build_object('ok',false,'raison','parametres_invalides');END IF;
 SELECT * INTO p FROM public.personnages_donnees WHERE name=moi FOR UPDATE;
 -- Le registre du poste décide, pas son badge de présentation.
 IF NOT EXISTS(SELECT 1 FROM public.postes_attribues a WHERE a.country=p.country AND a.poste_id='commissaire' AND a.city=p.current_city AND a.titulaire IN(moi,'pj:'||moi)) THEN RETURN jsonb_build_object('ok',false,'raison','commissaire_hors_juridiction');END IF;
 SELECT * INTO site FROM public.ordres_jets_sites s WHERE s.pays=p.country AND s.ville=p.current_city AND s.batiment=p.current_building AND s.piece=p.current_room AND s.ordre='organiser_filature' AND s.poste='commissaire';
 IF NOT FOUND OR site.caisse IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','pas_sur_place');END IF;
 SELECT * INTO ancien FROM public.police_filatures_recus WHERE acteur=p.id AND requete=p_requete;
 IF FOUND THEN
  IF ancien.cible IS DISTINCT FROM cible THEN RETURN jsonb_build_object('ok',false,'raison','requete_reutilisee');END IF;
  r:=ancien.resultat||'{"rejeu":true}';
 ELSE
  IF coalesce(p.hp,0)<=0 OR EXISTS(SELECT 1 FROM public.detention_active(moi)) OR coalesce(p.hospitalisation->>'dateFinParis','')>(statement_timestamp() AT TIME ZONE 'Europe/Paris')::date::text THEN RETURN jsonb_build_object('ok',false,'raison','acteur_indisponible');END IF;
  SELECT coalesce(nullif((d.stats->>'PER')::numeric,0),8),coalesce(d.inf,0) INTO per_cible,inf_cible FROM public.personnages_donnees d WHERE d.name=cible;
  -- Formule actuelle de filature : aucune caractéristique ni chance envoyée par le navigateur.
  taux:=50+2*(public.personnage_stat_jet_interne(moi,'PER')-13)-(coalesce(per_cible,8)-13)
    +(public.personnage_securite_jet_interne(moi)-50)/5+(coalesce(p.inf,0)-coalesce(inf_cible,0))*.3;
  INSERT INTO public.acquisitions_transactions_internes VALUES(txid_current(),moi,p.country||'_'||p.current_building,'organiser_filature',site.pa,0);
  r:=public.payer_ordre(moi,'organiser_filature',site.pa,0);
  IF r->>'ok' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION USING ERRCODE='P0135',MESSAGE=coalesce(r->>'raison','paiement_refuse');END IF;
  r:=public.caisse_client_mouvement(site.caisse,-site.cout,'organiser_filature',false);
  IF r->>'ok' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION USING ERRCODE='P0135',MESSAGE=coalesce(r->>'raison','caisse_insuffisante');END IF;
  bonus:=public.religion_benediction_consommer_interne(p.id,'organiser_filature',p_requete);
  taux:=greatest(10,least(90,floor(taux+bonus+.5)));jet:=public.terrain_negociation_jet_interne();
  IF jet IS NULL OR jet NOT BETWEEN 1 AND 100 THEN RAISE EXCEPTION 'jet_invalide';END IF;
  IF jet<=taux THEN
   rapport:=public.filature_deplacements(cible);
   IF rapport->>'ok' IS DISTINCT FROM 'true' OR jsonb_typeof(rapport->'deplacements') IS DISTINCT FROM 'array' THEN RAISE EXCEPTION 'rapport_filature_non_confirme';END IF;
  END IF;
  r:=jsonb_build_object('ok',true,'succes',jet<=taux,'jet',jet,'taux',taux,'bonus',bonus,'cible',cible,'cout',site.cout,'paPreleves',site.pa,
   'rapportA',clock_timestamp(),'deplacements',rapport->'deplacements','horodatagesInconnus',CASE WHEN jet<=taux THEN(SELECT count(*) FROM public.historique_deplacements h WHERE h.name=cible AND h.created_at IS NULL) ELSE 0 END);
  INSERT INTO public.police_filatures_recus VALUES(p.id,p_requete,cible,r,clock_timestamp());
  DELETE FROM public.acquisitions_transactions_internes WHERE transaction_id=txid_current() AND acteur=moi;
  UPDATE public.personnages_donnees SET updated_at=clock_timestamp() WHERE name=moi;
 END IF;
 SELECT * INTO p FROM public.personnages_donnees WHERE name=moi;
 RETURN r||jsonb_build_object('pa',p.pa,'liquide',p.liquide,'arg',p.arg,'solde_caisse',(SELECT data->'solde' FROM public.caisses_batiments WHERE id=site.caisse),'realites',public.religion_benediction_lire());
EXCEPTION WHEN SQLSTATE 'P0135' THEN RETURN jsonb_build_object('ok',false,'raison',SQLERRM);
END;$f$;
-- Pas d'exposition client avant le raccordement et l'activation de l'ensemble L09.
REVOKE ALL ON FUNCTION public.police_filature_commande(text,uuid) FROM PUBLIC,anon,authenticated,service_role;

COMMIT;
