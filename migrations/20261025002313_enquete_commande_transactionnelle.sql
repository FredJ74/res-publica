-- L09 : hôte privé, mêmes moteurs de caisse, d'instruction et de transmission.
BEGIN;
DO $g$ BEGIN
 IF to_regclass('public.police_enquetes_recus') IS NOT NULL AND obj_description(to_regclass('public.police_enquetes_recus')) IS DISTINCT FROM 'HG police enquete atomique #135 v1' THEN RAISE EXCEPTION 'registre_enquetes_inconnu';END IF;
 IF EXISTS(SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname='police_enquete_commande' AND (p.oid IS DISTINCT FROM to_regprocedure('public.police_enquete_commande(text,uuid)') OR md5(p.prosrc)<>'a32c8051e8bed55afd755e85430a3989')) THEN RAISE EXCEPTION 'definition_non_examinee: police_enquete_commande';END IF;
 IF to_regprocedure('public.plainte_instruire_trace_interne(text,text,text,text,text,text)') IS NULL OR to_regprocedure('public.affaire_transmettre(text,text,text,jsonb)') IS NULL OR to_regclass('public.evenements_globaux') IS NULL THEN RAISE EXCEPTION 'dependance_enquete_absente';END IF;
END;$g$;
CREATE TABLE IF NOT EXISTS public.police_enquetes_recus(acteur uuid NOT NULL,requete uuid NOT NULL,cible text NOT NULL,resultat jsonb NOT NULL,traitee_at timestamptz NOT NULL DEFAULT now(),PRIMARY KEY(acteur,requete));
COMMENT ON TABLE public.police_enquetes_recus IS 'HG police enquete atomique #135 v1';
ALTER TABLE public.police_enquetes_recus ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.police_enquetes_recus FROM PUBLIC,anon,authenticated,service_role;
CREATE OR REPLACE FUNCTION public.police_enquete_commande(p_cible text,p_requete uuid) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $f$
DECLARE moi text:=public.mon_personnage();p record;site record;ancien record;trace public.actions_tracables%rowtype;
 v_cible text:=btrim(coalesce(p_cible,''));r jsonb;instruction jsonb;v_affaire jsonb;courrier jsonb;solde numeric;per_cible numeric;inf_cible numeric;
 taux numeric;bonus integer:=0;jet integer;succes boolean:=false;v_evenement bigint;v_texte text;
BEGIN
 IF moi IS NULL OR auth.uid() IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie');END IF;
 IF p_requete IS NULL OR v_cible='' OR v_cible=moi THEN RETURN jsonb_build_object('ok',false,'raison','cible_invalide');END IF;
 SELECT * INTO p FROM public.personnages_donnees WHERE name=moi FOR UPDATE;
 IF NOT FOUND OR p.user_id IS DISTINCT FROM auth.uid() THEN RETURN jsonb_build_object('ok',false,'raison','personnage_non_possede');END IF;
 IF NOT EXISTS(SELECT 1 FROM public.postes_attribues a WHERE a.country=p.country AND a.city=p.current_city AND a.poste_id='commissaire' AND a.titulaire IN(moi,'pj:'||moi)) THEN RETURN jsonb_build_object('ok',false,'raison','commissaire_hors_juridiction');END IF;
 SELECT * INTO site FROM public.ordres_jets_sites s WHERE s.pays=p.country AND s.ville=p.current_city AND s.batiment=p.current_building AND s.piece=p.current_room AND s.ordre='mener_enquete' AND s.poste='commissaire';
 IF NOT FOUND OR site.caisse IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','pas_sur_place');END IF;
 SELECT * INTO ancien FROM public.police_enquetes_recus WHERE acteur=p.id AND requete=p_requete;
 IF FOUND THEN
  IF ancien.cible IS DISTINCT FROM v_cible THEN RETURN jsonb_build_object('ok',false,'raison','requete_reutilisee');END IF;
  r:=ancien.resultat||'{"rejeu":true}';
 ELSE
  IF coalesce(p.hp,0)<=0 OR EXISTS(SELECT 1 FROM public.detention_active(moi)) OR coalesce(p.hospitalisation->>'dateFinParis','')>(statement_timestamp() AT TIME ZONE 'Europe/Paris')::date::text THEN RETURN jsonb_build_object('ok',false,'raison','acteur_indisponible');END IF;
  -- Une trace non datable ne peut être annoncée ni expirée ni absente.
  SELECT coalesce((data->>'solde')::numeric,0) INTO solde FROM public.caisses_batiments WHERE id=site.caisse FOR UPDATE;
  IF NOT FOUND OR solde<site.cout THEN RETURN jsonb_build_object('ok',false,'raison','caisse_insuffisante');END IF;
  -- Durée existante de la trace, ancrée à sa création réelle ; aucun jour personnel de l'enquêteur.
  SELECT * INTO trace FROM public.actions_tracables a WHERE a.country=p.country AND a.city=p.current_city AND a.auteur=v_cible AND a.decouvert IS NOT TRUE
   AND a.created_at<=statement_timestamp() AND a.jour_expiration>=a.jour
   AND (a.created_at AT TIME ZONE 'Europe/Paris')::date+(a.jour_expiration-a.jour)>=(statement_timestamp() AT TIME ZONE 'Europe/Paris')::date
   ORDER BY a.created_at DESC,a.id LIMIT 1 FOR UPDATE;
  IF trace.id IS NULL AND EXISTS(SELECT 1 FROM public.actions_tracables a WHERE a.country=p.country AND a.city=p.current_city AND a.auteur=v_cible AND a.decouvert IS NOT TRUE AND a.created_at IS NULL AND a.jour_expiration>=a.jour) THEN RETURN jsonb_build_object('ok',false,'raison','datation_traces_indeterminee');END IF;
  INSERT INTO public.acquisitions_transactions_internes VALUES(txid_current(),moi,p.country||'_'||p.current_building,'mener_enquete',site.pa,0);
  r:=public.payer_ordre(moi,'mener_enquete',site.pa,0);
  IF r->>'ok' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION USING ERRCODE='P0135',MESSAGE=coalesce(r->>'raison','paiement_refuse');END IF;
  IF (SELECT pa FROM public.personnages_donnees WHERE id=p.id) IS DISTINCT FROM p.pa-site.pa THEN RAISE EXCEPTION 'paiement_enquete_non_confirme';END IF;
  r:=public.caisse_client_mouvement(site.caisse,-site.cout,'mener_enquete',false);
  IF r->>'ok' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION USING ERRCODE='P0135',MESSAGE=coalesce(r->>'raison','caisse_insuffisante');END IF;
  IF (SELECT (data->>'solde')::numeric FROM public.caisses_batiments WHERE id=site.caisse) IS DISTINCT FROM solde-site.cout THEN RAISE EXCEPTION 'caisse_enquete_non_confirmee';END IF;
  IF trace.id IS NOT NULL THEN
   SELECT coalesce(nullif((d.stats->>'PER')::numeric,0),8),coalesce(d.inf,0) INTO per_cible,inf_cible FROM public.personnages_donnees d WHERE d.name=v_cible;
   taux:=35+2*(public.personnage_stat_jet_interne(moi,'PER')-coalesce(per_cible,8))+(coalesce(p.inf,0)-coalesce(inf_cible,0))*.3+(public.personnage_securite_jet_interne(moi)-45)/5;
   bonus:=public.religion_benediction_consommer_interne(p.id,'mener_enquete',p_requete);
   taux:=greatest(10,least(90,floor(taux+bonus+.5)));jet:=public.terrain_negociation_jet_interne();
   IF jet IS NULL OR jet NOT BETWEEN 1 AND 100 THEN RAISE EXCEPTION 'jet_invalide';END IF;
   succes:=jet<=taux;
   IF succes THEN
    instruction:=public.plainte_instruire_trace_interne(p.country,p.current_city,v_cible,'enquete',moi,trace.id);
    IF instruction->>'ok' IS DISTINCT FROM 'true' OR coalesce(instruction->>'decision','') NOT IN('enquete_ouverte','contre_espionnage') OR NOT EXISTS(SELECT 1 FROM public.actions_tracables a WHERE a.id=trace.id AND a.decouvert IS TRUE) THEN RAISE EXCEPTION 'instruction_enquete_non_confirmee';END IF;
    IF instruction->>'decision'='enquete_ouverte' THEN
     v_affaire:=public.affaire_transmettre(v_cible,trace.type_action,p.current_city,jsonb_build_object('victime',trace.cible,'jourFait',trace.jour,'refType','action_tracee','refId',trace.id));
     IF v_affaire->>'ok' IS DISTINCT FROM 'true' OR NOT EXISTS(SELECT 1 FROM public.plaintes_en_cours a WHERE a.id=v_affaire->>'id' AND a.country=p.country AND a.city=p.current_city AND a.data::jsonb->>'cible'=v_cible) OR NOT EXISTS(SELECT 1 FROM public.dossiers_judiciaires_actes d WHERE d.affaire=v_affaire->>'id' AND d.pays=p.country AND d.ville=p.current_city AND d.type='affaire_transmise_police' AND d.donnees->>'ref_id'=trace.id) THEN RAISE EXCEPTION 'transmission_enquete_non_confirmee';END IF;
     courrier:=public.mail_systeme_poser_interne(moi,v_cible,'Enquete de police','Une enquete a mis en evidence un acte illegal vous concernant. Vous avez ete place en garde a vue.');
     v_texte:='ENQUETE : '||v_cible||' a ete demasque(e) et place(e) en garde a vue.';
     INSERT INTO public.evenements_globaux(country,city,texte,jour) VALUES(p.country,p.current_city,v_texte,public.jour_de_jeu_pays(p.country)) RETURNING id INTO v_evenement;
     IF v_evenement IS NULL OR NOT EXISTS(SELECT 1 FROM public.evenements_globaux g WHERE g.id=v_evenement AND g.country=p.country AND g.city=p.current_city AND g.texte=v_texte) THEN RAISE EXCEPTION 'evenement_enquete_non_confirme';END IF;
    END IF;
   END IF;
  END IF;
  r:=jsonb_build_object('ok',true,'succes',succes,'jet',jet,'taux',taux,'bonus',bonus,'cible',v_cible,'cout',site.cout,'paPreleves',site.pa,
   'decision',CASE WHEN trace.id IS NULL THEN 'aucun_element' WHEN NOT succes THEN 'indices_insuffisants' ELSE instruction->>'decision' END,'trace',to_jsonb(trace),'instruction',instruction,'affaire',v_affaire,'notification',courrier,'evenementPublic',v_evenement);
  INSERT INTO public.police_enquetes_recus(acteur,requete,cible,resultat) VALUES(p.id,p_requete,v_cible,r);
  DELETE FROM public.acquisitions_transactions_internes WHERE transaction_id=txid_current() AND acteur=moi;
  UPDATE public.personnages_donnees SET updated_at=clock_timestamp() WHERE name=moi;
 END IF;
 SELECT * INTO p FROM public.personnages_donnees WHERE name=moi;
 RETURN r||jsonb_build_object('pa',p.pa,'liquide',p.liquide,'arg',p.arg,'solde_caisse',(SELECT data->'solde' FROM public.caisses_batiments WHERE id=site.caisse),'realites',public.religion_benediction_lire());
EXCEPTION WHEN SQLSTATE 'P0135' THEN RETURN jsonb_build_object('ok',false,'raison',SQLERRM);
END;$f$;
REVOKE ALL ON FUNCTION public.police_enquete_commande(text,uuid) FROM PUBLIC,anon,authenticated,service_role;
COMMIT;
