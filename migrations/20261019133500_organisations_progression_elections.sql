-- PREPARE : progression et depouillement generiques, aucune creation d'election payante.
-- Depend de 20261019130213 ; aucun droit historique ferme.
BEGIN;
DO $garde$
BEGIN
 IF to_regprocedure('public.organisation_commande_membres(text,text,text,jsonb)') IS NULL OR
 EXISTS(SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='public' AND p.proname='organisation_commande_membres' AND md5(p.prosrc) NOT IN ('a0e36e3ff683225c12a38e6bb2e7df0b','28286d902e7a89f9f3c47b98664ce885')) THEN
 RAISE EXCEPTION 'election_definition_a_reexaminer'; END IF;
END;
$garde$;
CREATE OR REPLACE FUNCTION public.organisation_commande_membres(p_requete text,p_organisation text,p_action text,p_parametres jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $f$
DECLARE acteur text; d jsonb; avant jsonb; cible text; jour integer; pays text;
 regles jsonb; grades jsonb; idx integer; membre jsonb; liste text; decision jsonb;
 commande jsonb; rec public.organisation_commandes_recus; resultat jsonb; election jsonb; vainqueur text;
BEGIN
 acteur:=public.mon_personnage();
 IF acteur IS NULL THEN RAISE EXCEPTION 'acteur_non_authentifie' USING ERRCODE='42501'; END IF;
 IF p_requete IS NULL OR p_requete !~ '^orgcmd-[A-Za-z0-9-]{6,80}$' OR p_organisation IS NULL OR
 p_parametres IS NULL OR jsonb_typeof(p_parametres)<>'object' THEN RAISE EXCEPTION 'commande_invalide'; END IF;
 SELECT data::jsonb INTO d FROM public.organisations WHERE id=p_organisation FOR UPDATE;
 PERFORM pg_advisory_xact_lock(hashtextextended('orgcmd:'||p_requete,0));
 commande:=jsonb_build_object('action',p_action,'parametres',p_parametres);
 SELECT * INTO rec FROM public.organisation_commandes_recus WHERE requete=p_requete;
 IF FOUND THEN
  IF rec.acteur<>acteur OR rec.organisation<>p_organisation OR rec.commande<>commande THEN RAISE EXCEPTION 'requete_reutilisee' USING ERRCODE='42501'; END IF;
  RETURN (rec.resultat-'organisation')||jsonb_build_object('rejeu',true);
 END IF;
 IF d IS NULL THEN RAISE EXCEPTION 'organisation_absente'; END IF;
 avant:=d;pays:=coalesce(d->>'country_origine',d->>'country');
 regles:=public.organisation_regles_membres()->(d->>'type');
 IF regles IS NULL THEN RAISE EXCEPTION 'type_non_reconnu'; END IF;
 grades:=regles->'grades'->pays;
 IF grades IS NULL THEN RAISE EXCEPTION 'grades_non_definis'; END IF;
 SELECT coalesce(day,1) INTO jour FROM public.personnages_donnees WHERE name=acteur;
 IF jour IS NULL THEN RAISE EXCEPTION 'personnage_absent'; END IF;
 cible:=p_parametres->>'nom';
 IF p_action IN ('demander','accepter_invitation','refuser_invitation','avancer_election') THEN
  IF p_parametres<>'{}' THEN RAISE EXCEPTION 'champs_interdits'; END IF;cible:=acteur;
 ELSE
  IF p_parametres-ARRAY['nom']<>'{}' OR cible IS NULL THEN RAISE EXCEPTION 'cible_requise'; END IF;
  IF d->>'chef' IS DISTINCT FROM acteur THEN RAISE EXCEPTION 'reserve_au_chef' USING ERRCODE='42501'; END IF;
 END IF;
 IF p_action IN ('demander','admettre','accepter_invitation') THEN
  -- Serialiser les admissions concurrentes du meme personnage, meme entre organisations.
  PERFORM pg_advisory_xact_lock(hashtextextended('orgmembre:'||cible,0));
  IF EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(d->'membres','[]')) m WHERE m->>'nom'=cible) THEN RAISE EXCEPTION 'deja_membre'; END IF;
  IF (SELECT count(*) FROM public.organisations o WHERE coalesce(o.data::jsonb->>'country_origine',o.data::jsonb->>'country')=pays
    AND o.data::jsonb->>'type'=d->>'type' AND EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(o.data::jsonb->'membres','[]')) m WHERE m->>'nom'=cible)) >= (regles->>'maxAdhesion')::integer THEN
   RAISE EXCEPTION 'limite_adhesion'; END IF;
 END IF;
 IF p_action='avancer_election' THEN
  election:=d->'election';
  IF coalesce((election->>'enCours')::boolean,false) THEN
   IF election->>'phase'='candidatures' AND jour>=(election->>'dateFinCandidatures')::integer THEN
    election:=jsonb_set(election,'{phase}','"vote"');
    d:=jsonb_set(d,'{election}',election);
    -- La garde de direction existante doit observer la phase vote avant le depouillement.
    -- Cette etape et la suivante restent dans la meme transaction, sans etat definitif partiel.
    UPDATE public.organisations SET data=d::text WHERE id=p_organisation;
   END IF;
   IF election->>'phase'='vote' AND jour>=(election->>'dateFinVote')::integer THEN
    SELECT x->>'nom' INTO vainqueur FROM jsonb_array_elements(coalesce(election->'candidats','[]')) WITH ORDINALITY candidats(x,ordre)
    ORDER BY (SELECT count(*) FROM jsonb_each_text(coalesce(election->'votes','{}')) v WHERE v.value=x->>'nom') DESC,ordre LIMIT 1;
    IF vainqueur IS NOT NULL THEN
     d:=d||jsonb_build_object('chef',vainqueur,'chefEstPnj',false);
     d:=jsonb_set(d,'{membres}',coalesce((SELECT jsonb_agg(CASE WHEN m->>'nom'=vainqueur THEN
      m||jsonb_build_object('gradeIdx',jsonb_array_length(grades)-1,'grade',grades->>(jsonb_array_length(grades)-1)) ELSE m END ORDER BY ordre)
      FROM jsonb_array_elements(coalesce(d->'membres','[]')) WITH ORDINALITY membres(m,ordre)),'[]'));
    END IF;
    d:=jsonb_set(d,'{election}',jsonb_build_object('enCours',false,'phase',NULL,'derniereElection',jour,'candidats','[]'::jsonb,'votes','{}'::jsonb));
   END IF;
  END IF;
 ELSIF p_action='demander' THEN
  IF coalesce((d->>'visible')::boolean,false) IS NOT TRUE THEN RAISE EXCEPTION 'invitation_requise'; END IF;
  IF EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(d->'demandesAdhesion','[]')) m WHERE m->>'nom'=acteur) THEN RAISE EXCEPTION 'demande_en_cours'; END IF;
  d:=jsonb_set(d,'{demandesAdhesion}',coalesce(d->'demandesAdhesion','[]')||jsonb_build_array(jsonb_build_object('nom',acteur,'date',jour)));
 ELSIF p_action IN ('admettre','refuser_demande','accepter_invitation','refuser_invitation') THEN
  liste:=CASE WHEN p_action IN ('admettre','refuser_demande') THEN 'demandesAdhesion' ELSE 'invitationsEnvoyees' END;
  IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(d->liste,'[]')) m WHERE m->>'nom'=cible) THEN RAISE EXCEPTION 'demande_ou_invitation_absente'; END IF;
  d:=jsonb_set(d,ARRAY[liste],coalesce((SELECT jsonb_agg(m) FROM jsonb_array_elements(d->liste) m WHERE m->>'nom' IS DISTINCT FROM cible),'[]'));
  IF p_action IN ('admettre','accepter_invitation') THEN
   membre:=jsonb_build_object('nom',cible,'grade',grades->>0,'gradeIdx',0,'rejointLe',jour);
   d:=jsonb_set(d,'{membres}',coalesce(d->'membres','[]')||jsonb_build_array(membre));
  END IF;
 ELSIF p_action IN ('promouvoir','retrograder') THEN
  SELECT m INTO membre FROM jsonb_array_elements(coalesce(d->'membres','[]')) m WHERE m->>'nom'=cible;
  IF membre IS NULL THEN RAISE EXCEPTION 'membre_absent'; END IF;
  idx:=(membre->>'gradeIdx')::integer+CASE WHEN p_action='promouvoir' THEN 1 ELSE -1 END;
  IF idx IS NULL OR idx<0 OR idx>=jsonb_array_length(grades) THEN RAISE EXCEPTION 'grade_limite'; END IF;
  membre:=membre||jsonb_build_object('gradeIdx',idx,'grade',grades->>idx);
  d:=jsonb_set(d,'{membres}',(SELECT jsonb_agg(CASE WHEN m->>'nom'=cible THEN membre ELSE m END ORDER BY ord)
    FROM jsonb_array_elements(d->'membres') WITH ORDINALITY e(m,ord)));
 ELSE RAISE EXCEPTION 'action_non_migree'; END IF;
 IF d-ARRAY['membres','demandesAdhesion','invitationsEnvoyees','chef','chefEstPnj','election'] IS DISTINCT FROM avant-ARRAY['membres','demandesAdhesion','invitationsEnvoyees','chef','chefEstPnj','election'] THEN RAISE EXCEPTION 'etat_hors_commande'; END IF;
 UPDATE public.organisations SET data=d::text WHERE id=p_organisation;
 resultat:=jsonb_build_object('ok',true,'organisation',d);
 INSERT INTO public.organisation_commandes_recus(requete,acteur,organisation,commande,resultat) VALUES(p_requete,acteur,p_organisation,commande,resultat);
 RETURN resultat;
END;
$f$;
REVOKE ALL ON FUNCTION public.organisation_commande_membres(text,text,text,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.organisation_commande_membres(text,text,text,jsonb) TO authenticated;
COMMIT;
