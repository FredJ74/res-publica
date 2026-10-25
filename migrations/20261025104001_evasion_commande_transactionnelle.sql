-- L09 privé. Aucune sortie sans clôture, recherche et reçu dans la même transaction.
BEGIN;
DO $g$ BEGIN IF EXISTS(SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname='evasion_commande' AND (p.oid IS DISTINCT FROM to_regprocedure('public.evasion_commande(uuid)') OR md5(p.prosrc)<>'9158a52aad7b8f6f683f3f81de531728')) THEN RAISE EXCEPTION 'definition_non_examinee: evasion_commande';END IF;END;$g$;
DO $g$ BEGIN IF to_regclass('public.evasions_recus') IS NOT NULL AND obj_description(to_regclass('public.evasions_recus')) IS DISTINCT FROM 'HG evasion atomique #135 v1 evasions_recus' THEN RAISE EXCEPTION 'registre_evasion_inconnu: evasions_recus';END IF;END;$g$;
DO $g$ BEGIN IF to_regclass('public.evasions_jours') IS NOT NULL AND obj_description(to_regclass('public.evasions_jours')) IS DISTINCT FROM 'HG evasion atomique #135 v1 evasions_jours' THEN RAISE EXCEPTION 'registre_evasion_inconnu: evasions_jours';END IF;END;$g$;
CREATE TABLE IF NOT EXISTS public.evasions_recus(acteur uuid NOT NULL,requete uuid NOT NULL,resultat jsonb NOT NULL,traitee_at timestamptz NOT NULL DEFAULT now(),PRIMARY KEY(acteur,requete));
CREATE TABLE IF NOT EXISTS public.evasions_jours(acteur uuid NOT NULL,jour date NOT NULL,requete uuid NOT NULL,PRIMARY KEY(acteur,jour));
COMMENT ON TABLE public.evasions_recus IS 'HG evasion atomique #135 v1 evasions_recus';
ALTER TABLE public.evasions_recus ENABLE ROW LEVEL SECURITY;
COMMENT ON TABLE public.evasions_jours IS 'HG evasion atomique #135 v1 evasions_jours';
ALTER TABLE public.evasions_jours ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.evasions_recus,public.evasions_jours FROM PUBLIC,anon,authenticated,service_role;
CREATE OR REPLACE FUNCTION public.evasion_commande(p_requete uuid) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $f$
DECLARE moi text:=public.mon_personnage();p record;d record;site record;ancien record;r jsonb;cloture jsonb;entree jsonb;req jsonb;motifs jsonb;
 bonus integer;jet integer;taux numeric;succes boolean;v_jour date:=(statement_timestamp() AT TIME ZONE 'Europe/Paris')::date;v_ident text;monde integer;solde numeric;fonds numeric;amende numeric:=0;reliquat integer;
BEGIN
 IF moi IS NULL OR auth.uid() IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie');END IF;
 IF p_requete IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','requete_manquante');END IF;
 SELECT * INTO p FROM public.personnages_donnees WHERE name=moi FOR UPDATE;
 IF NOT FOUND OR p.user_id IS DISTINCT FROM auth.uid() THEN RETURN jsonb_build_object('ok',false,'raison','personnage_non_possede');END IF;
 SELECT * INTO ancien FROM public.evasions_recus WHERE acteur=p.id AND requete=p_requete;
 IF FOUND THEN r:=ancien.resultat||'{"rejeu":true}';
 ELSE
  IF coalesce(p.hp,0)<=0 OR coalesce(p.hospitalisation->>'dateFinParis','')>v_jour::text THEN RETURN jsonb_build_object('ok',false,'raison','acteur_indisponible');END IF;
  SELECT * INTO site FROM public.ordres_jets_sites s WHERE s.pays=p.country AND s.ville=p.current_city AND s.batiment=p.current_building AND s.piece=p.current_room AND s.ordre='tentative_evasion';
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','pas_sur_place');END IF;
  SELECT x.* INTO d FROM public.detentions x JOIN public.detention_active(moi) a ON a.id=x.id FOR UPDATE OF x;
  IF NOT FOUND OR p.est_emprisonne IS NULL OR p.est_emprisonne->>'detentionId' IS DISTINCT FROM d.id THEN RETURN jsonb_build_object('ok',false,'raison','detention_non_confirmee');END IF;
  req:=p.requisition;
  IF jsonb_typeof(req)='string' THEN BEGIN req:=(req#>>'{}')::jsonb;EXCEPTION WHEN others THEN RETURN jsonb_build_object('ok',false,'raison','requisition_non_interpretable');END;END IF;
  IF req IS NOT NULL AND jsonb_typeof(req)<>'object' THEN RETURN jsonb_build_object('ok',false,'raison','requisition_non_interpretable');END IF;
  -- Le compteur historique vit seulement dans state.char, pas dans les sauvegardes examinées.
  -- Il n'est ni remis à zéro ni remplacé par une valeur fournie par le navigateur.
  IF req->>'statut'='deserteur' THEN RETURN jsonb_build_object('ok',false,'raison','historique_bonus_deserteur_a_verifier');END IF;
  IF p.est_emprisonne->>'dernierJourEvasion'=v_jour::text OR EXISTS(SELECT 1 FROM public.evasions_jours j WHERE j.acteur=p.id AND j.jour=v_jour) THEN RETURN jsonb_build_object('ok',false,'raison','tentative_quotidienne_deja_effectuee');END IF;
  INSERT INTO public.acquisitions_transactions_internes VALUES(txid_current(),moi,p.country||'_'||p.current_building,'tentative_evasion',site.pa,site.cout);
  r:=public.payer_ordre(moi,'tentative_evasion',site.pa,site.cout);IF r->>'ok' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION USING ERRCODE='P0135',MESSAGE=coalesce(r->>'raison','paiement_refuse');END IF;
  IF (SELECT pa FROM public.personnages_donnees WHERE name=moi) IS DISTINCT FROM p.pa-site.pa THEN RAISE EXCEPTION 'paiement_evasion_non_confirme';END IF;
  bonus:=public.religion_benediction_consommer_interne(p.id,'tentative_evasion',p_requete);
  taux:=greatest(2,least(40,floor(10+(public.personnage_stat_jet_interne(moi,'DUP')-10)*2-(public.personnage_securite_jet_interne(moi)-45)/3+bonus+.5)));
  jet:=public.terrain_negociation_jet_interne();IF jet IS NULL OR jet NOT BETWEEN 1 AND 100 THEN RAISE EXCEPTION 'jet_invalide';END IF;succes:=jet<=taux;v_ident:='evasion-'||p_requete::text;monde:=public.jour_de_jeu_pays(p.country);
  IF succes THEN
   cloture:=public.detention_clore_evasion();
   IF cloture->>'ok' IS DISTINCT FROM 'true' OR cloture->>'detention_id' IS DISTINCT FROM d.id OR EXISTS(SELECT 1 FROM public.detention_active(moi)) OR EXISTS(SELECT 1 FROM public.personnages_donnees WHERE name=moi AND est_emprisonne IS NOT NULL) OR NOT EXISTS(SELECT 1 FROM public.detentions x WHERE x.id=d.id AND x.mode_fin='evasion' AND x.jour_fin=d.jour_fin AND x.date_fin_effective IS NOT NULL) THEN RAISE EXCEPTION 'cloture_evasion_non_confirmee';END IF;
   reliquat:=(cloture->>'reliquat_jours')::integer;
   motifs:=coalesce(cloture->'motifs','[]')||jsonb_build_array(jsonb_build_object('type','Évasion','jour_fait',monde,'city',p.current_city,'jours',2,'source','evasion','date_evenement',statement_timestamp()));
   entree:=jsonb_build_object('id',v_ident,'type','condamnation','country',coalesce(cloture->>'country',p.country),'motifs',motifs,'detention_precedente_id',d.id,'reliquat_jours',reliquat,'jour_condamnation',monde,'jour_affaire',monde,'ville_condamnation',coalesce(d.ville_condamnation,d.city));
   r:=public.justice_condamnation_poser_interne(moi,entree,coalesce(cloture->>'country',p.country),coalesce(d.ville_condamnation,d.city),'Évasion constatée');
   IF r->>'ok' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'recherche_evasion_non_confirmee';END IF;
   r:=public.recherche_inscrire(entree);
   IF r->>'ok' IS DISTINCT FROM 'true' OR NOT EXISTS(SELECT 1 FROM public.personnages_donnees WHERE name=moi AND recherche @> jsonb_build_array(jsonb_build_object('id',v_ident))) THEN RAISE EXCEPTION 'recherche_evasion_non_confirmee';END IF;
  ELSE
   motifs:=jsonb_build_array(jsonb_build_object('type','Tentative d’évasion échouée','jours',1,'source','tentative_evasion','date_evenement',statement_timestamp()));
   r:=public.detention_prolonger_interne(moi,motifs,false);
   IF r->>'ok' IS DISTINCT FROM 'true' OR NOT EXISTS(SELECT 1 FROM public.detentions x WHERE x.id=d.id AND x.jour_fin=d.jour_fin+1) OR NOT EXISTS(SELECT 1 FROM public.personnages_donnees WHERE name=moi AND (est_emprisonne->>'jourFin')::integer=d.jour_fin+1) THEN RAISE EXCEPTION 'prolongation_evasion_non_confirmee';END IF;
   SELECT coalesce(b.solde,0) INTO solde FROM public.comptes_bancaires b WHERE b.personnage=moi AND b.banque='nationale' FOR UPDATE;fonds:=coalesce(p.liquide,0)+coalesce(solde,0);amende:=least(500,fonds);
   IF amende>0 AND NOT public.helvetia_debiter_fonds_ordinaires(moi,amende) THEN RAISE EXCEPTION 'amende_evasion_refusee';END IF;
   IF (SELECT coalesce(liquide,0) FROM public.personnages_donnees WHERE name=moi)+coalesce((SELECT b.solde FROM public.comptes_bancaires b WHERE b.personnage=moi AND b.banque='nationale'),0) IS DISTINCT FROM fonds-amende THEN RAISE EXCEPTION 'amende_evasion_non_confirmee';END IF;
  END IF;
  INSERT INTO public.evasions_jours VALUES(p.id,v_jour,p_requete);
  r:=jsonb_build_object('ok',true,'succes',succes,'jet',jet,'taux',taux,'bonus',bonus,'amende',amende,'reliquat',reliquat,'cloture',cloture,'avis',entree,'paPreleves',site.pa);
  INSERT INTO public.evasions_recus(acteur,requete,resultat) VALUES(p.id,p_requete,r);
  IF NOT EXISTS(SELECT 1 FROM public.evasions_recus x WHERE x.acteur=p.id AND x.requete=p_requete AND x.resultat=r) THEN RAISE EXCEPTION 'recu_evasion_non_confirme';END IF;
  DELETE FROM public.acquisitions_transactions_internes WHERE transaction_id=txid_current() AND acteur=moi;
  UPDATE public.personnages_donnees SET updated_at=clock_timestamp() WHERE name=moi;
 END IF;
 SELECT * INTO p FROM public.personnages_donnees WHERE name=moi;
 RETURN r||jsonb_build_object('pa',p.pa,'liquide',p.liquide,'arg',p.arg,'estEmprisonne',p.est_emprisonne,'detentionQhs',p.detention_qhs,'recherche',p.recherche,'realites',public.religion_benediction_lire());
EXCEPTION WHEN SQLSTATE 'P0135' THEN RETURN jsonb_build_object('ok',false,'raison',SQLERRM);
END;$f$;
REVOKE ALL ON FUNCTION public.evasion_commande(uuid) FROM PUBLIC,anon,authenticated,service_role;
COMMIT;
