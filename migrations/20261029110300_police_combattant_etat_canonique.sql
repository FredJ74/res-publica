-- #219 : le round policier existant ne doit pas faire combattre un PJ au coma,
-- hospitalisé ou déjà engagé ailleurs. Les reçus restent lus avant cette garde.
DO $police$
DECLARE s text;a text;b text;
BEGIN
 s:=pg_get_functiondef('public.police_combat_resoudre(text,text,text,text,integer)'::regprocedure);
 IF position('-- police_combattant_etat_canonique_v1' IN s)>0 THEN RETURN;END IF;
 a:=' IF FOUND THEN RETURN v_receipt; END IF;';
 b:=a||chr(10)||' -- police_combattant_etat_canonique_v1'
  ||chr(10)||' IF NOT EXISTS(SELECT 1 FROM public.groupe_combattants_interne(v_nom,p_rencontre) g WHERE g.est_pj AND g.identifiant=v_nom) THEN'
  ||chr(10)||' RETURN jsonb_build_object(''ok'',false,''raison'',''joueur_indisponible'');END IF;';
 IF (length(s)-length(replace(s,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'police_recu_definition_non_examinee';END IF;
 EXECUTE replace(s,a,b);
END $police$;
