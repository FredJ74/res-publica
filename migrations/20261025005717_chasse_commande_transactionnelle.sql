-- L09 : coût et jet réunis à l'exécution judiciaire existante, hôte privé.
BEGIN;
DO $g$ BEGIN
 IF to_regclass('public.police_chasses_recus') IS NOT NULL AND obj_description(to_regclass('public.police_chasses_recus')) IS DISTINCT FROM 'HG police chasse atomique #135 v1' THEN RAISE EXCEPTION 'registre_chasses_inconnu';END IF;
 IF EXISTS(SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname='police_chasse_commande' AND (p.oid IS DISTINCT FROM to_regprocedure('public.police_chasse_commande(text,uuid)') OR md5(p.prosrc)<>'1fa3b8fade0878bff0c6a482fd6506c4')) THEN RAISE EXCEPTION 'definition_non_examinee: police_chasse_commande';END IF;
 IF to_regprocedure('public.justice_executer_condamnation(text,text)') IS NULL OR to_regprocedure('public.justice_recherches(text)') IS NULL OR to_regclass('public.evenements_globaux') IS NULL THEN RAISE EXCEPTION 'dependance_chasse_absente';END IF;
END;$g$;
CREATE TABLE IF NOT EXISTS public.police_chasses_recus(acteur uuid NOT NULL,requete uuid NOT NULL,cible text NOT NULL,resultat jsonb NOT NULL,traitee_at timestamptz NOT NULL DEFAULT now(),PRIMARY KEY(acteur,requete));
COMMENT ON TABLE public.police_chasses_recus IS 'HG police chasse atomique #135 v1';
ALTER TABLE public.police_chasses_recus ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.police_chasses_recus FROM PUBLIC,anon,authenticated,service_role;
CREATE OR REPLACE FUNCTION public.police_chasse_commande(p_cible text,p_requete uuid) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $f$
DECLARE moi text:=public.mon_personnage();p record;site record;ancien record;j record;v_jugement text;v_cible text:=btrim(coalesce(p_cible,''));
 r jsonb;execution jsonb;courrier jsonb;solde numeric;taux numeric;per_cible numeric;inf_cible numeric;bonus integer;jet integer;succes boolean;v_evenement bigint;v_texte text;
BEGIN
 IF moi IS NULL OR auth.uid() IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie');END IF;
 IF p_requete IS NULL OR v_cible='' THEN RETURN jsonb_build_object('ok',false,'raison','cible_invalide');END IF;
 SELECT * INTO p FROM public.personnages_donnees WHERE name=moi FOR UPDATE;
 IF NOT FOUND OR p.user_id IS DISTINCT FROM auth.uid() THEN RETURN jsonb_build_object('ok',false,'raison','personnage_non_possede');END IF;
 IF NOT EXISTS(SELECT 1 FROM public.postes_attribues a WHERE a.country=p.country AND a.city=p.current_city AND a.poste_id='commissaire' AND a.titulaire IN(moi,'pj:'||moi)) THEN RETURN jsonb_build_object('ok',false,'raison','commissaire_hors_juridiction');END IF;
 SELECT * INTO site FROM public.ordres_jets_sites s WHERE s.pays=p.country AND s.ville=p.current_city AND s.batiment=p.current_building AND s.piece=p.current_room AND s.ordre='organiser_chasse_homme' AND s.poste='commissaire';
 IF NOT FOUND OR site.caisse IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','pas_sur_place');END IF;
 SELECT * INTO ancien FROM public.police_chasses_recus WHERE acteur=p.id AND requete=p_requete;
 IF FOUND THEN
  IF ancien.cible IS DISTINCT FROM v_cible THEN RETURN jsonb_build_object('ok',false,'raison','requete_reutilisee');END IF;
  r:=ancien.resultat||'{"rejeu":true}';
 ELSE
  IF coalesce(p.hp,0)<=0 OR EXISTS(SELECT 1 FROM public.detention_active(moi)) OR coalesce(p.hospitalisation->>'dateFinParis','')>(statement_timestamp() AT TIME ZONE 'Europe/Paris')::date::text THEN RETURN jsonb_build_object('ok',false,'raison','acteur_indisponible');END IF;
  SELECT id INTO v_jugement FROM public.justice_recherches(v_cible) a WHERE nullif(a.country,'') IS NULL OR a.country=p.country LIMIT 1;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','cible_non_recherchee');END IF;
  SELECT * INTO j FROM public.jugements WHERE id=v_jugement FOR UPDATE;
  IF NOT FOUND OR j.executee IS DISTINCT FROM false OR j.accuse IS DISTINCT FROM v_cible OR nullif(j.country,'') IS NOT NULL AND j.country<>p.country THEN RETURN jsonb_build_object('ok',false,'raison','condamnation_obsolete');END IF;
  IF EXISTS(SELECT 1 FROM public.detention_active(v_cible)) THEN RETURN jsonb_build_object('ok',false,'raison','cible_deja_detenue');END IF;
  -- Ce moteur personnel est utilisé par l'interception existante ; jamais recréé ici.
  IF v_cible=moi AND to_regprocedure('public.justice_executer_condamnation_soi(text)') IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','moteur_execution_personnelle_indisponible');END IF;
  SELECT coalesce((data->>'solde')::numeric,0) INTO solde FROM public.caisses_batiments WHERE id=site.caisse FOR UPDATE;
  IF NOT FOUND OR solde<site.cout THEN RETURN jsonb_build_object('ok',false,'raison','caisse_insuffisante');END IF;
  SELECT coalesce(nullif((d.stats->>'PER')::numeric,0),8),coalesce(d.inf,0) INTO per_cible,inf_cible FROM public.personnages_donnees d WHERE d.name=v_cible;
  taux:=45+2*(public.personnage_stat_jet_interne(moi,'PER')-coalesce(per_cible,8))+(coalesce(p.inf,0)-coalesce(inf_cible,0))*.3+(public.personnage_securite_jet_interne(moi)-45)/5;
  INSERT INTO public.acquisitions_transactions_internes VALUES(txid_current(),moi,p.country||'_'||p.current_building,'organiser_chasse_homme',site.pa,0);
  r:=public.payer_ordre(moi,'organiser_chasse_homme',site.pa,0);
  IF r->>'ok' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION USING ERRCODE='P0135',MESSAGE=coalesce(r->>'raison','paiement_refuse');END IF;
  IF (SELECT pa FROM public.personnages_donnees WHERE id=p.id) IS DISTINCT FROM p.pa-site.pa THEN RAISE EXCEPTION 'paiement_chasse_non_confirme';END IF;
  r:=public.caisse_client_mouvement(site.caisse,-site.cout,'organiser_chasse_homme',false);
  IF r->>'ok' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION USING ERRCODE='P0135',MESSAGE=coalesce(r->>'raison','caisse_insuffisante');END IF;
  IF (SELECT (data->>'solde')::numeric FROM public.caisses_batiments WHERE id=site.caisse) IS DISTINCT FROM solde-site.cout THEN RAISE EXCEPTION 'caisse_chasse_non_confirmee';END IF;
  bonus:=public.religion_benediction_consommer_interne(p.id,'organiser_chasse_homme',p_requete);taux:=greatest(10,least(90,floor(taux+bonus+.5)));jet:=public.terrain_negociation_jet_interne();
  IF jet IS NULL OR jet NOT BETWEEN 1 AND 100 THEN RAISE EXCEPTION 'jet_invalide';END IF;succes:=jet<=taux;
  IF succes THEN
   IF v_cible=moi THEN execution:=public.justice_executer_condamnation_soi(v_jugement);
   ELSE execution:=public.justice_executer_condamnation(v_jugement,p.current_city);END IF;
   IF execution->>'ok' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION USING ERRCODE='P0135',MESSAGE=coalesce(execution->>'raison','execution_refusee');END IF;
   IF nullif(execution->>'detention_id','') IS NULL
    OR NOT EXISTS(SELECT 1 FROM public.jugements d WHERE d.id=v_jugement AND d.executee IS TRUE)
    OR NOT EXISTS(SELECT 1 FROM public.detention_active(v_cible) d WHERE d.id=execution->>'detention_id' AND d.city=p.current_city AND d.country IS NOT DISTINCT FROM j.country)
    OR NOT EXISTS(SELECT 1 FROM public.personnages_donnees d WHERE d.name=v_cible AND d.est_emprisonne->>'detentionId'=execution->>'detention_id') THEN RAISE EXCEPTION 'arrestation_chasse_non_confirmee';END IF;
   courrier:=public.mail_systeme_poser_interne(moi,v_cible,'Arrestation','Vous avez ete localise(e) et arrete(e) suite a un avis de recherche.');
   v_texte:='CHASSE A L HOMME : '||v_cible||' a ete localise(e) et arrete(e).';
   INSERT INTO public.evenements_globaux(country,city,texte,jour) VALUES(p.country,p.current_city,v_texte,public.jour_de_jeu_pays(p.country)) RETURNING id INTO v_evenement;
   IF v_evenement IS NULL OR NOT EXISTS(SELECT 1 FROM public.evenements_globaux g WHERE g.id=v_evenement AND g.country=p.country AND g.city=p.current_city AND g.texte=v_texte) THEN RAISE EXCEPTION 'evenement_chasse_non_confirme';END IF;
  END IF;
  r:=jsonb_build_object('ok',true,'succes',succes,'jet',jet,'taux',taux,'bonus',bonus,'cible',v_cible,'jugement',v_jugement,'execution',execution,'notification',courrier,'evenementPublic',v_evenement,'cout',site.cout,'paPreleves',site.pa);
  INSERT INTO public.police_chasses_recus(acteur,requete,cible,resultat) VALUES(p.id,p_requete,v_cible,r);
  DELETE FROM public.acquisitions_transactions_internes WHERE transaction_id=txid_current() AND acteur=moi;
  UPDATE public.personnages_donnees SET updated_at=clock_timestamp() WHERE name=moi;
 END IF;
 SELECT * INTO p FROM public.personnages_donnees WHERE name=moi;
 RETURN r||jsonb_build_object('pa',p.pa,'liquide',p.liquide,'arg',p.arg,'solde_caisse',(SELECT data->'solde' FROM public.caisses_batiments WHERE id=site.caisse),'realites',public.religion_benediction_lire());
EXCEPTION WHEN SQLSTATE 'P0135' THEN RETURN jsonb_build_object('ok',false,'raison',SQLERRM);
END;$f$;
REVOKE ALL ON FUNCTION public.police_chasse_commande(text,uuid) FROM PUBLIC,anon,authenticated,service_role;
COMMIT;
