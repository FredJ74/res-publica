-- PRÉPARATION NON APPLIQUÉE : rehorodatée après la coupe canonique du 31/10/2026.
-- Ancien fichier : 20261019094425_organisations_commandes_administratives.sql ; aucun changement de règle.
-- PREPARE, NON APPLIQUE. Etape additive : ne ferme PAS les anciens droits.
-- La fermeture exige la migration des autres appelants (finances, creation, elections, cron).
BEGIN;
DO $garde$
BEGIN
 IF to_regclass('public.organisation_commandes_recus') IS NOT NULL AND
 obj_description(to_regclass('public.organisation_commandes_recus'),'pg_class') IS DISTINCT FROM 'HG commandes administratives v1' THEN
 RAISE EXCEPTION 'registre_commandes_inconnu'; END IF;

 IF EXISTS(SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='public' AND p.proname='organisation_commande_administrative'
 AND (p.oid::regprocedure::text <> 'organisation_commande_administrative(text,text,text,jsonb)'
 OR md5(p.prosrc)<>'7b1e697f28ea882fde5809d152d774ca')) THEN RAISE EXCEPTION 'commande_definition_a_reexaminer'; END IF;
END;
$garde$;
CREATE TABLE IF NOT EXISTS public.organisation_commandes_recus (
 requete text PRIMARY KEY, acteur text NOT NULL, organisation text NOT NULL,
 commande jsonb NOT NULL, resultat jsonb NOT NULL, cree_le timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE public.organisation_commandes_recus IS 'HG commandes administratives v1';
ALTER TABLE public.organisation_commandes_recus ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.organisation_commandes_recus FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.organisation_commande_administrative(p_requete text,p_organisation text,p_action text,p_parametres jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='public','pg_temp' AS $f$
DECLARE acteur text; d jsonb; avant jsonb; commande jsonb; rec public.organisation_commandes_recus;
 cible text; resultat jsonb; chef boolean; jour integer; election jsonb;
BEGIN
 acteur:=public.mon_personnage();
 IF acteur IS NULL THEN RAISE EXCEPTION 'acteur_non_authentifie' USING ERRCODE='42501'; END IF;
 IF p_requete IS NULL OR p_requete !~ '^orgcmd-[A-Za-z0-9-]{6,80}$' OR p_organisation IS NULL OR
 p_action IS NULL OR p_parametres IS NULL OR jsonb_typeof(p_parametres)<>'object' THEN
 RAISE EXCEPTION 'commande_invalide'; END IF;
 -- Toujours organisation puis requete ; aucun verrou inverse dans cette fonction.
 SELECT data::jsonb INTO d FROM public.organisations WHERE id=p_organisation FOR UPDATE;
 PERFORM pg_advisory_xact_lock(hashtextextended('orgcmd:'||p_requete,0));
 commande:=jsonb_build_object('action',p_action,'parametres',p_parametres);
 SELECT * INTO rec FROM public.organisation_commandes_recus WHERE requete=p_requete;
 IF FOUND THEN
  IF rec.acteur<>acteur OR rec.organisation<>p_organisation OR rec.commande<>commande THEN
   RAISE EXCEPTION 'requete_reutilisee' USING ERRCODE='42501'; END IF;
  -- Rejeu d'un acte deja confirme, sans reexecuter apres changement de role.
  RETURN (rec.resultat-'organisation')||jsonb_build_object('rejeu',true);
 END IF;
 IF d IS NULL THEN RAISE EXCEPTION 'organisation_absente'; END IF;
 avant:=d; chef:=coalesce(d->>'chef'=acteur,false); cible:=p_parametres->>'nom';
 IF p_action='dissoudre' THEN
  IF NOT chef THEN RAISE EXCEPTION 'reserve_au_chef' USING ERRCODE='42501'; END IF;
  IF p_parametres<>'{}'::jsonb THEN RAISE EXCEPTION 'champs_interdits'; END IF;
  -- Les FK du socle collectif refusent la destruction d'un proprietaire de materiel.
  DELETE FROM public.organisations WHERE id=p_organisation;
  resultat:=jsonb_build_object('ok',true,'dissoute',p_organisation);
  INSERT INTO public.organisation_commandes_recus(requete,acteur,organisation,commande,resultat)
  VALUES(p_requete,acteur,p_organisation,commande,resultat);
  RETURN resultat;
 ELSIF p_action='informations' THEN
  IF NOT chef THEN RAISE EXCEPTION 'reserve_au_chef' USING ERRCODE='42501'; END IF;
  IF p_parametres - ARRAY['nom','devise','avatar'] <> '{}'::jsonb OR p_parametres='{}'::jsonb OR
    EXISTS(SELECT 1 FROM jsonb_each(p_parametres) e WHERE jsonb_typeof(e.value)<>'string') THEN
   RAISE EXCEPTION 'champs_interdits'; END IF;
  IF p_parametres ? 'nom' AND length(btrim(cible))<2 THEN RAISE EXCEPTION 'nom_requis'; END IF;
  d:=d||p_parametres;
 ELSIF p_action='visibilite' THEN
  IF NOT chef THEN RAISE EXCEPTION 'reserve_au_chef' USING ERRCODE='42501'; END IF;
  IF d->>'type' IS DISTINCT FROM 'criminelle' OR p_parametres-ARRAY['visible']<>'{}'::jsonb OR
   jsonb_typeof(p_parametres->'visible') IS DISTINCT FROM 'boolean' THEN RAISE EXCEPTION 'visibilite_invalide'; END IF;
  d:=jsonb_set(d,'{visible}',p_parametres->'visible');
 ELSIF p_action IN ('exclure','quitter') THEN
  IF p_parametres-ARRAY['nom']<>'{}'::jsonb OR cible IS NULL THEN RAISE EXCEPTION 'champs_interdits'; END IF;
  IF (p_action='exclure' AND NOT chef) OR (p_action='quitter' AND cible<>acteur) THEN
   RAISE EXCEPTION 'membre_non_autorise' USING ERRCODE='42501'; END IF;
  IF cible=d->>'chef' THEN RAISE EXCEPTION 'direction_a_transmettre'; END IF;
  IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(d->'membres','[]')) m WHERE m->>'nom'=cible) THEN
   RAISE EXCEPTION 'membre_absent'; END IF;
  d:=jsonb_set(d,'{membres}',coalesce((SELECT jsonb_agg(m) FROM jsonb_array_elements(d->'membres') m WHERE m->>'nom' IS DISTINCT FROM cible),'[]'));
 ELSIF p_action IN ('candidature','vote') THEN
  IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(d->'membres','[]')) m WHERE m->>'nom'=acteur) THEN
   RAISE EXCEPTION 'reserve_aux_membres' USING ERRCODE='42501'; END IF;
  SELECT coalesce(day,1) INTO jour FROM public.personnages_donnees WHERE name=acteur;
  IF jour IS NULL THEN RAISE EXCEPTION 'personnage_absent'; END IF;
  election:=d->'election';
  IF coalesce((election->>'enCours')::boolean,false) IS NOT TRUE THEN RAISE EXCEPTION 'election_inactive'; END IF;
  IF p_action='candidature' THEN
   IF p_parametres<>'{}'::jsonb THEN RAISE EXCEPTION 'champs_interdits'; END IF;
   IF election->>'phase' IS DISTINCT FROM 'candidatures' OR jour>=(election->>'dateFinCandidatures')::integer
    OR election->>'dateFinCandidatures' IS NULL THEN RAISE EXCEPTION 'candidatures_fermees'; END IF;
   IF EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(election->'candidats','[]')) m WHERE m->>'nom'=acteur) THEN
    RAISE EXCEPTION 'deja_candidat'; END IF;
   election:=jsonb_set(election,'{candidats}',coalesce(election->'candidats','[]')||jsonb_build_array(jsonb_build_object('nom',acteur)));
  ELSE
   IF p_parametres-ARRAY['nom']<>'{}'::jsonb OR cible IS NULL THEN RAISE EXCEPTION 'candidat_requis'; END IF;
   IF election->>'phase' IS DISTINCT FROM 'vote' OR jour<(election->>'dateFinCandidatures')::integer
    OR jour>=(election->>'dateFinVote')::integer OR election->>'dateFinVote' IS NULL
    OR election->>'dateFinCandidatures' IS NULL THEN RAISE EXCEPTION 'vote_ferme'; END IF;
   IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(election->'candidats','[]')) m WHERE m->>'nom'=cible) THEN
    RAISE EXCEPTION 'candidat_absent'; END IF;
   election:=jsonb_set(election,'{votes}',coalesce(election->'votes','{}')||jsonb_build_object(acteur,cible));
  END IF;
  d:=jsonb_set(d,'{election}',election);
 ELSIF p_action IN ('nommer_tresorier','revoquer_tresorier') THEN
  IF NOT chef THEN RAISE EXCEPTION 'reserve_au_chef' USING ERRCODE='42501'; END IF;
  IF p_action='nommer_tresorier' THEN
   IF p_parametres-ARRAY['nom']<>'{}'::jsonb OR coalesce(btrim(cible),'')='' THEN RAISE EXCEPTION 'tresorier_requis'; END IF;
   cible:=btrim(cible);
   IF cible=d->>'chef' THEN RAISE EXCEPTION 'chef_deja_gestionnaire'; END IF;
   IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(d->'membres','[]')) m WHERE m->>'nom'=cible) THEN RAISE EXCEPTION 'pas_membre'; END IF;
   d:=jsonb_set(d,'{tresorier}',to_jsonb(cible));
  ELSE
   IF p_parametres<>'{}'::jsonb THEN RAISE EXCEPTION 'champs_interdits'; END IF;
   IF coalesce(d->>'tresorier','')='' THEN RAISE EXCEPTION 'aucun_tresorier'; END IF;
   d:=d||jsonb_build_object('tresorierPrecedent',d->'tresorier','tresorier',NULL);
  END IF;
 ELSE RAISE EXCEPTION 'action_non_migree';
 END IF;
 -- Defense en profondeur : aucun de ces actes n'ecrit un montant ; seuls candidature/vote modifient leur election.
 IF (d-ARRAY['nom','devise','avatar','visible','membres','tresorier','tresorierPrecedent','election']) IS DISTINCT FROM
    (avant-ARRAY['nom','devise','avatar','visible','membres','tresorier','tresorierPrecedent','election']) THEN
  RAISE EXCEPTION 'etat_hors_commande'; END IF;
 UPDATE public.organisations SET data=d::text WHERE id=p_organisation;
 resultat:=jsonb_build_object('ok',true,'organisation',d);
 INSERT INTO public.organisation_commandes_recus(requete,acteur,organisation,commande,resultat)
 VALUES(p_requete,acteur,p_organisation,commande,resultat);
 RETURN resultat;
END;
$f$;
REVOKE ALL ON FUNCTION public.organisation_commande_administrative(text,text,text,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.organisation_commande_administrative(text,text,text,jsonb) TO authenticated;
COMMIT;
