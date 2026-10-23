-- #94 PREPAREE : decision et pieces justificatives dans la meme transaction.
BEGIN;
DO $definitions$ BEGIN
 IF to_regprocedure('public.terrain_permis_decider(text,boolean,text,uuid)') IS NOT NULL AND NOT EXISTS(SELECT 1 FROM pg_proc WHERE oid=to_regprocedure('public.terrain_permis_decider(text,boolean,text,uuid)') AND md5(prosrc)='7302cab448a47675ed04baf27e4f5697') THEN RAISE EXCEPTION 'definition_non_examinee: terrain_permis_decider(text,boolean,text,uuid)';END IF;
END;$definitions$;
CREATE TABLE IF NOT EXISTS public.urbanisme_decisions_internes(transaction_id bigint PRIMARY KEY,acteur uuid NOT NULL,terrain text NOT NULL);
ALTER TABLE public.urbanisme_decisions_internes ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.urbanisme_decisions_internes FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE FUNCTION public.terrain_permis_decider(p_terrain text,p_valide boolean,p_motif text,p_requete uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $f$
DECLARE acteur text:=public.mon_personnage();uid uuid:=auth.uid();a record;poste record;t record;et jsonb;p jsonb;r jsonb;pay jsonb;doc jsonb;ref text;nature text;jour integer;legacy boolean:=false;
BEGIN
 IF acteur IS NULL OR uid IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie');END IF;
 IF p_requete IS NULL OR p_valide IS NULL OR nullif(btrim(p_terrain),'') IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','requete_invalide');END IF;
 IF NOT p_valide AND length(btrim(coalesce(p_motif,'')))<10 THEN RETURN jsonb_build_object('ok',false,'raison','motif_requis');END IF;
 SELECT * INTO a FROM public.personnages_donnees WHERE name=acteur FOR UPDATE;
 ref:='urb-decision-'||uid::text||'-'||p_requete::text;nature:=CASE WHEN p_valide THEN 'acceptation' ELSE 'refus' END;
 PERFORM pg_advisory_xact_lock(hashtextextended(ref,0));
 SELECT d.data INTO doc FROM public.dossiers_urbanisme d JOIN public.urbanisme_archives_attestees ar ON ar.archive=d.id WHERE d.id=ref AND ar.emetteur=acteur;
 IF FOUND THEN
  IF doc->>'buildingId' IS DISTINCT FROM p_terrain OR doc->>'nature' IS DISTINCT FROM nature
   OR NOT p_valide AND doc->>'motifRefus' IS DISTINCT FROM btrim(p_motif) THEN RETURN jsonb_build_object('ok',false,'raison','requete_reutilisee');END IF;
  RETURN jsonb_build_object('ok',true,'rejeu',true,'document',doc);
 END IF;
 IF coalesce(a.hp,0)<=0 OR coalesce(a.hospitalisation->>'dateFinParis','')>(statement_timestamp() AT TIME ZONE 'Europe/Paris')::date::text THEN RETURN jsonb_build_object('ok',false,'raison','acteur_incapacite');END IF;
 IF EXISTS(SELECT 1 FROM public.detention_active(acteur)) THEN RETURN jsonb_build_object('ok',false,'raison','acteur_detenu');END IF;
 SELECT * INTO poste FROM public.acteur_poste_courant();
 SELECT * INTO t FROM public.terrains_etat WHERE country=a.country AND building_id=p_terrain AND data::jsonb->>'city'=poste.poste_city FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','hors_juridiction');END IF;
 IF poste.poste_id IS DISTINCT FROM 'maire_adjoint' OR poste.pays IS DISTINCT FROM t.country THEN RETURN jsonb_build_object('ok',false,'raison','autorite_refusee');END IF;
 et:=t.data::jsonb;p:=et->'permis';
 IF coalesce(et->>'succession_gel','')<>'' THEN RETURN jsonb_build_object('ok',false,'raison','terrain_gele');END IF;
 IF coalesce(p->>'statut','') NOT IN('instruction','attente_validation') OR p IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','dossier_deja_decide');END IF;
 jour:=public.jour_de_jeu_pays(t.country);IF jour IS NULL THEN RAISE EXCEPTION 'calendrier_indisponible';END IF;
 IF p->>'statut'='attente_validation' THEN
  legacy:=true;p:=p||'{"statut":"instruction"}';
 END IF;
 INSERT INTO public.urbanisme_decisions_internes VALUES(txid_current(),uid,p_terrain);
 pay:=public.payer_ordre(acteur,'traiter_demandes_permis',1,0);
 IF pay->>'ok' IS DISTINCT FROM 'true' THEN DELETE FROM public.urbanisme_decisions_internes WHERE transaction_id=txid_current();RETURN pay;END IF;
 IF legacy THEN PERFORM public.terrain_etat_fusionner_interne(t.id,jsonb_build_object('permis',p),t.country);END IF;
 p:=p||jsonb_build_object('statut',CASE WHEN p_valide THEN 'valide' ELSE 'refuse' END,'motifRefus',CASE WHEN p_valide THEN NULL ELSE btrim(p_motif) END,'jourRefus',CASE WHEN p_valide THEN NULL ELSE jour END);
 r:=public.terrain_permis_acte(p_terrain,'permis_decider',jsonb_build_object('permis',p,'constructionAutorisee',p_valide));
 IF r->>'ok' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'decision_non_confirmee';END IF;
 INSERT INTO public.dossiers_urbanisme(id,country,city,building_id,type_evenement,data)
 VALUES(ref,t.country,et->>'city',p_terrain,nature,'{}');
 SELECT data INTO doc FROM public.dossiers_urbanisme WHERE id=ref;
 r:=public.objet_sas_deposer('document_urbanisme',p->>'demandeur','{}',ref);
 IF r->>'ok' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'document_non_confirme';END IF;
 r:=public.mail_systeme_poser_interne('Services d''urbanisme',p->>'demandeur','Decision sur votre permis',
  CASE WHEN p_valide THEN 'Votre permis a ete valide.' ELSE 'Permis refuse : '||btrim(p_motif) END,ref);
 -- L'echec du courrier est journalise par le moteur commun, sans annuler l'acte.
 DELETE FROM public.urbanisme_decisions_internes WHERE transaction_id=txid_current();
 RETURN jsonb_build_object('ok',true,'document',doc,'paiement',pay,'notification',r);
END;$f$;
REVOKE ALL ON FUNCTION public.terrain_permis_decider(text,boolean,text,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.terrain_permis_decider(text,boolean,text,uuid) TO authenticated;
COMMIT;
