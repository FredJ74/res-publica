-- #94 PREPAREE : conserve le moteur et ses recus ; ne confond pas travailleur et proprietaire.
BEGIN;
DO $g$ DECLARE h text;s text;BEGIN
 SELECT md5(prosrc),pg_get_functiondef(oid) INTO h,s FROM pg_proc WHERE oid=to_regprocedure('public.chantier_commande(text,text,text,jsonb)');
 IF h='106d75cbaecc936f53bdc005acd9ab40' THEN
  s:=replace(s,$ancien$ PERFORM public.chantier_autorite_exiger_interne(etat->>'proprietaire',t.country,etat->>'city');$ancien$,$nouveau$ -- Le travail remunere est ouvert aux PJ presents ; seule la gestion exige le proprietaire.
 IF p_action<>'travailler' THEN
 PERFORM public.chantier_autorite_exiger_interne(etat->>'proprietaire',t.country,etat->>'city');
 END IF;$nouveau$);EXECUTE s;
 ELSIF h IS DISTINCT FROM 'b46c382a352401d3dd7365a7c8ea975c' THEN RAISE EXCEPTION 'definition_non_examinee: chantier_commande(text,text,text,jsonb)';END IF;
END;$g$;
COMMIT;
