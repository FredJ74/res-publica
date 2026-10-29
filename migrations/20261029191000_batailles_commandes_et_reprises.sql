-- #219. Reçus dans le magasin technique existant, pas de nouvelle bataille.
DO $internes$
DECLARE r record;s text;
BEGIN
 FOR r IN SELECT * FROM (VALUES
 ('militaire_bataille_engager()','militaire_bataille_engager_interne','CREATE OR REPLACE FUNCTION public.militaire_bataille_engager_interne('),
 ('militaire_bataille_poursuivre(bigint)','militaire_bataille_poursuivre_interne','CREATE OR REPLACE FUNCTION public.militaire_bataille_poursuivre_interne('),
 ('militaire_bataille_decider(bigint,text)','militaire_bataille_decider_interne','CREATE OR REPLACE FUNCTION public.militaire_bataille_decider_interne(')) x(signature,prive,declaration) LOOP
  IF NOT EXISTS(SELECT 1 FROM pg_proc WHERE pronamespace='public'::regnamespace AND proname=r.prive) THEN
   s:=pg_get_functiondef(('public.'||r.signature)::regprocedure);
   IF position('-- bataille_graphe_avant_lignes_v1' IN s)=0 THEN RAISE EXCEPTION 'bataille_commande_precondition: %',r.signature;END IF;
   EXECUTE replace(s,'CREATE OR REPLACE FUNCTION public.'||split_part(r.signature,'(',1)||'(',r.declaration);
  END IF;
 END LOOP;
END $internes$;
REVOKE ALL ON FUNCTION public.militaire_bataille_engager_interne(),public.militaire_bataille_poursuivre_interne(bigint),public.militaire_bataille_decider_interne(bigint,text) FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION public.militaire_bataille_commande_interne(p_bataille bigint,p_action text,p_round integer,p_requete uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $g$
DECLARE moi text;args jsonb;v jsonb;b public.batailles%ROWTYPE;detail_erreur text;
BEGIN
 moi:=public.mon_personnage();
 IF moi IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie');END IF;
 IF p_requete IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','requete_requise');END IF;
 IF p_action IS NULL OR p_action NOT IN ('engager','continuer','tenir','replier') THEN RETURN jsonb_build_object('ok',false,'raison','action_invalide');END IF;
 args:=jsonb_build_object('operation','bataille','bataille',p_bataille,'action',p_action,'round',p_round);
 PERFORM pg_advisory_xact_lock(hashtextextended('groupe_pj:graphe',0));
 SELECT verdict INTO v FROM public.navigation_requetes WHERE acteur=moi AND requete=p_requete AND arguments=args;
 IF FOUND THEN RETURN v;END IF;
 IF EXISTS(SELECT 1 FROM public.navigation_requetes WHERE acteur=moi AND requete=p_requete) THEN RETURN jsonb_build_object('ok',false,'raison','requete_reutilisee');END IF;
 IF p_action='engager' THEN
  IF p_bataille IS NOT NULL OR p_round IS NOT NULL THEN RETURN jsonb_build_object('ok',false,'raison','parametres_invalides');END IF;
  v:=public.navigation_disponibilite_interne(moi);
  IF NOT coalesce((v->>'ok')::boolean,false) THEN RETURN v;END IF;
 ELSE
  SELECT * INTO b FROM public.batailles WHERE id=p_bataille FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','bataille_introuvable');END IF;
  IF p_round IS NULL OR p_round<>b.round_courant THEN RETURN jsonb_build_object('ok',false,'raison','round_obsolete','round',b.round_courant);END IF;
  IF b.statut<>'en_cours' THEN RETURN jsonb_build_object('ok',false,'raison','bataille_terminee');END IF;
  IF NOT EXISTS(SELECT 1 FROM public.batailles_engagements e WHERE e.bataille_id=p_bataille AND e.personnage=moi) THEN RETURN jsonb_build_object('ok',false,'raison','non_engage');END IF;
  -- Avancer le monde reste permis à tout participant, même déjà évacué,
  -- comme l'ancienne porte. Cela ne le recrute pas comme combattant.
  -- Donner un ordre au groupe, en revanche, exige un chef disponible sur place.
  IF p_action<>'continuer' AND NOT EXISTS(SELECT 1 FROM public.groupe_combattants_interne(moi,NULL,p_bataille) g WHERE g.est_pj AND g.identifiant=moi) THEN RETURN jsonb_build_object('ok',false,'raison','acteur_indisponible');END IF;
  IF p_action<>'continuer' AND NOT EXISTS(SELECT 1 FROM public.personnages_donnees d WHERE d.name=moi
    AND (d.country,d.current_city,d.current_building,d.current_room) IS NOT DISTINCT FROM (b.pays,b.ville,b.batiment,b.piece)) THEN RETURN jsonb_build_object('ok',false,'raison','pas_sur_place');END IF;
 END IF;
 BEGIN
  v:=CASE WHEN p_action='engager' THEN public.militaire_bataille_engager_interne()
      WHEN p_action='continuer' THEN public.militaire_bataille_poursuivre_interne(p_bataille)
      ELSE public.militaire_bataille_decider_interne(p_bataille,p_action) END;
 EXCEPTION WHEN SQLSTATE 'P2194' THEN
  GET STACKED DIAGNOSTICS detail_erreur=PG_EXCEPTION_DETAIL;
  RETURN jsonb_build_object('ok',false,'raison','repli_refuse','refus',detail_erreur::jsonb);
 END;
 IF coalesce((v->>'ok')::boolean,false) THEN
  INSERT INTO public.navigation_requetes(acteur,requete,arguments,verdict) VALUES(moi,p_requete,args,v);
 END IF;
 RETURN v;
END $g$;
REVOKE ALL ON FUNCTION public.militaire_bataille_commande_interne(bigint,text,integer,uuid) FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION public.militaire_bataille_engager(p_requete uuid)
RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $g$
 SELECT public.militaire_bataille_commande_interne(NULL,'engager',NULL,p_requete);
$g$;
CREATE OR REPLACE FUNCTION public.militaire_bataille_poursuivre(p_bataille_id bigint,p_round_attendu integer,p_requete uuid)
RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $g$
 SELECT public.militaire_bataille_commande_interne(p_bataille_id,'continuer',p_round_attendu,p_requete);
$g$;
CREATE OR REPLACE FUNCTION public.militaire_bataille_decider(p_bataille_id bigint,p_decision text,p_round_attendu integer,p_requete uuid)
RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $g$
 SELECT public.militaire_bataille_commande_interne(p_bataille_id,p_decision,p_round_attendu,p_requete);
$g$;
REVOKE ALL ON FUNCTION public.militaire_bataille_engager(uuid),public.militaire_bataille_poursuivre(bigint,integer,uuid),public.militaire_bataille_decider(bigint,text,integer,uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.militaire_bataille_engager(uuid),public.militaire_bataille_poursuivre(bigint,integer,uuid),public.militaire_bataille_decider(bigint,text,integer,uuid) TO authenticated;

-- Les navigateurs antérieurs ne peuvent répéter un round sans reçu.
CREATE OR REPLACE FUNCTION public.militaire_bataille_engager()
RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $g$ SELECT jsonb_build_object('ok',false,'raison','requete_requise'); $g$;
CREATE OR REPLACE FUNCTION public.militaire_bataille_poursuivre(p_bataille_id bigint)
RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $g$ SELECT jsonb_build_object('ok',false,'raison','requete_requise'); $g$;
CREATE OR REPLACE FUNCTION public.militaire_bataille_decider(p_bataille_id bigint,p_decision text)
RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $g$ SELECT jsonb_build_object('ok',false,'raison','requete_requise'); $g$;
