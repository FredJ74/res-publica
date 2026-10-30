-- Après la relation d'adhésion PJ et #216 : raccorder les suiveurs PNJ au chef
-- existant au lieu de considérer chaque agent porté comme un groupe indépendant.
-- Ne crée aucune identité supplémentaire. Police/armée restent à raccorder.
DO $presence$
DECLARE s text; a text; b text;
BEGIN
 s:=pg_get_functiondef('public.securite_agents_prives_presents_interne(text,text,text,text,text,text)'::regprocedure);
 a:='''groupeCle'',coalesce(m.leader_pnj_id,m.id),';
 b:=$nouveau$'groupeCle',CASE WHEN m.leader_pj IS NOT NULL THEN 'pj:'||coalesce(
     (SELECT g.chef FROM public.groupes_pj_adhesions g WHERE g.membre=m.leader_pj),m.leader_pj)
    ELSE 'pnj:'||coalesce(m.leader_pnj_id,m.id) END,$nouveau$;
 IF position(b IN s)>0 THEN RETURN; END IF;
 IF (length(s)-length(replace(s,a,'')))/length(a)<>1 THEN
  RAISE EXCEPTION 'presence_privee_chef_definition_non_examinee'; END IF;
 EXECUTE replace(s,a,b);
END $presence$;
