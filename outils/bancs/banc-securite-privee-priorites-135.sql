-- Priorité #135 : un groupe constitué n'est pas une co-présence dans la même salle.
-- Aucun test ne nécessite de créer des policiers réels ou des affectations.
DO $t$
DECLARE agents jsonb; groupes jsonb; g jsonb; n integer;
BEGIN
 agents:=jsonb_build_array(
  jsonb_build_object('matricule','pol-solo-1','pa',12,'stats',jsonb_build_object('PER',12),'buildingId','test','roomId','salle'),
  jsonb_build_object('matricule','pol-solo-2','pa',12,'stats',jsonb_build_object('PER',12),'buildingId','test','roomId','salle'),
  jsonb_build_object('matricule','pol-g1','groupeId','pol-grp','pa',12,'stats',jsonb_build_object('PER',14),'buildingId','test','roomId','salle'),
  jsonb_build_object('matricule','pol-g2','groupeId','pol-grp','pa',12,'stats',jsonb_build_object('PER',16),'buildingId','test','roomId','salle'),
  jsonb_build_object('matricule','prive:a','pnj_prive_id','a','groupeCle','a','pa',12,'stats',jsonb_build_object('PER',20),'buildingId','test','roomId','salle'),
  jsonb_build_object('matricule','prive:b','pnj_prive_id','b','groupeCle','a','pa',12,'stats',jsonb_build_object('PER',20),'buildingId','test','roomId','salle'),
  jsonb_build_object('matricule','prive:c','pnj_prive_id','c','groupeCle','a','pa',12,'stats',jsonb_build_object('PER',20),'buildingId','test','roomId','salle')
 );
 groupes:=public.securite_ordre_detection_interne(agents,'test','salle',NULL);
 IF jsonb_array_length(groupes)<>4 THEN RAISE EXCEPTION 'quatre_groupes_attendus: %',groupes; END IF;
 IF groupes->0->>'groupe'<>'police:pol-grp' OR groupes->0->>'effectif'<>'2'
 THEN RAISE EXCEPTION 'police_groupe_pas_prioritaire: %',groupes; END IF;
 IF (groupes->1->>'categorie')::integer<>0 OR (groupes->2->>'categorie')::integer<>0
 THEN RAISE EXCEPTION 'police_isoles_pas_prioritaires: %',groupes; END IF;
 IF (groupes->3->>'categorie')::integer<>1 OR (groupes->3->>'effectif')::integer<>3
 THEN RAISE EXCEPTION 'privés_apres_police: %',groupes; END IF;
 IF (groupes->0->>'perception')::numeric<>16 THEN RAISE EXCEPTION 'bonus_PER_groupe_incorrect: %',groupes; END IF;
 -- L'ordre des deux isolés n'est pas figé : le tirage tranche à chaque appel.
 FOR n IN 1..20 LOOP
   g:=public.securite_ordre_detection_interne(agents,'test','salle',NULL);
   IF g->0->>'groupe'<>'police:pol-grp' OR (g->3->>'categorie')::integer<>1
   THEN RAISE EXCEPTION 'priorite_instable: %',g; END IF;
 END LOOP;
 -- Hors zone ou sans PA : une unité entière doit être écartée.
 agents:=jsonb_set(agents,'{2,pa}','0'::jsonb);
 agents:=jsonb_set(agents,'{3,pa}','0'::jsonb);
 groupes:=public.securite_ordre_detection_interne(agents,'test','salle',NULL);
 IF jsonb_array_length(groupes)<>3 OR (groupes->0->>'categorie')::integer<>0 OR (groupes->0->>'effectif')::integer<>1
 THEN RAISE EXCEPTION 'groupes_inactifs_pris_en_compte: %',groupes; END IF;
END $t$;
