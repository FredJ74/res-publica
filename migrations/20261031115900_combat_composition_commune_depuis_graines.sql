-- #219 PRÉPARÉE : extraire le parcours commun déjà employé par l'armée.
-- Les graines restent propres au contexte ; un seul parcours d'accompagnement.
DO $composition$
DECLARE s text;corps text;debut integer;boucle integer;
BEGIN
 IF to_regprocedure('public.combat_bataille_completer_groupes_interne(bigint,text,text,text,text)') IS NOT NULL THEN RETURN;END IF;
 SELECT prosrc INTO s FROM pg_proc WHERE oid='public.militaire_bataille_recruter(bigint,text,text,text,text)'::regprocedure;
 debut:=position('BEGIN' IN s);boucle:=position(' FOR s IN SELECT e.*,m.leader_pj,m.leader_pnj_id' IN s);
 IF debut=0 OR boucle<=debut OR position('public.groupe_combattants_interne(personne,NULL,p_bataille_id)' IN s)=0 THEN RAISE EXCEPTION 'combat_composition_corps_non_examine';END IF;
 corps:=substring(s FROM 1 FOR debut+4)||chr(10)||' PERFORM pg_advisory_xact_lock(hashtextextended(''groupe_pj:graphe'',0));'||chr(10)||substring(s FROM boucle);
 EXECUTE format('CREATE FUNCTION public.combat_bataille_completer_groupes_interne(p_bataille_id bigint,p_camp text,p_ville text,p_bat text,p_piece text) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO public,pg_temp AS %L',corps);
 corps:=substring(s FROM 1 FOR boucle-1)||' PERFORM public.combat_bataille_completer_groupes_interne(p_bataille_id,p_camp,p_ville,p_bat,p_piece);END;';
 EXECUTE format('CREATE OR REPLACE FUNCTION public.militaire_bataille_recruter(p_bataille_id bigint,p_camp text,p_ville text,p_bat text,p_piece text) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO public,pg_temp AS %L',corps);
END $composition$;
REVOKE ALL ON FUNCTION public.combat_bataille_completer_groupes_interne(bigint,text,text,text,text) FROM PUBLIC,anon,authenticated,service_role;
