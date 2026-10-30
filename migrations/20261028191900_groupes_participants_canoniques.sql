-- #219 : lecture commune de l'appartenance, jamais d'effectifs fournis par l'écran.
-- Identités PJ/PNJ explicitement séparées ; le matricule métier n'est pas une clé.
CREATE OR REPLACE FUNCTION public.groupe_participants_interne(p_nom text)
RETURNS TABLE(cle text,est_pj boolean,identifiant text,nom text,pays text,ville text,
 batiment text,piece text,rue text,chef text,statut text)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $g$
 WITH racine AS (
  SELECT coalesce((SELECT g.chef FROM public.groupes_pj_adhesions g WHERE g.membre=p_nom),p_nom) AS chef
 ), membres AS (
  SELECT r.chef AS nom,r.chef FROM racine r
  UNION SELECT g.membre,r.chef FROM racine r JOIN public.groupes_pj_adhesions g ON g.chef=r.chef
 )
 SELECT 'pj:'||d.name,true,d.name,d.name,d.country,d.current_city,d.current_building,d.current_room,d.current_street,g.chef,'actif'::text
 FROM membres g JOIN public.personnages_donnees d ON d.name=g.nom
 UNION ALL
 SELECT 'pnj:'||m.id,false,m.id,m.nom,p.pays,p.ville,p.building_id,p.room_id,p.rue_noeud_id,g.chef,m.statut
 FROM membres g JOIN public.pnj_membres m ON m.leader_pj=g.nom
 CROSS JOIN LATERAL public.pnj_position_effective(m.id) p;
$g$;
REVOKE ALL ON FUNCTION public.groupe_participants_interne(text) FROM PUBLIC,anon,authenticated,service_role;
-- Le même lecteur alimente la composition du moteur de navigation ; pas de liste parallèle.
DO $participants$
DECLARE s text;a text;b text;
BEGIN
 s:=pg_get_functiondef('public.navigation_commander_interne(text,text,text)'::regprocedure);
 a:='SELECT coalesce(array_agg(id ORDER BY id),''{}''::text[]) INTO pnjs'
 ||chr(10)||'  FROM public.pnj_membres WHERE leader_pj=ANY(ids);';
 b:='SELECT coalesce(array_agg(identifiant ORDER BY identifiant),''{}''::text[]) INTO pnjs'
 ||chr(10)||'  FROM public.groupe_participants_interne(moi) WHERE NOT est_pj;';
 IF position(b IN s)>0 THEN RETURN; END IF;
 IF (length(s)-length(replace(s,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'navigation_composition_non_examinee'; END IF;
 EXECUTE replace(s,a,b);
END $participants$;
