-- Foret profonde de Krasnov : la creature tiree a la vue 3 est un PNJ beta, qui doit avoir un proprietaire (contrainte
-- pnj_propriete_exclusive : un PJ, ou une institution et un perimetre). Elle appartient a l'institution « faune », perimetre
-- « soviet:ville_b:foret ». Defaut revele par le banc annule de la foret avant toute rencontre en jeu. Patch en place, ancre.
BEGIN;
DO $raccord$
DECLARE d text; avant text; apres text;
BEGIN
  d := pg_get_functiondef('public.sovarka_foret_couper(uuid)'::regprocedure);
  IF position('proprietaire_institution' IN d) = 0 THEN
    avant := E'INSERT INTO public.pnj_membres (id, famille, nom, pays, ville, building_id, room_id, classe, pa, car_int, car_cha, car_vol, car_per, car_dup, car_ent)\n    VALUES (v_pnj, ''employe'', c->>''nom'', ''soviet'', ''ville_b'', ''zone-production'', ''foret_vue_3'', ''beta'', public.pnj_pa_max(),';
    apres := E'INSERT INTO public.pnj_membres (id, famille, nom, pays, ville, building_id, room_id, classe, pa, proprietaire_institution, proprietaire_perimetre, car_int, car_cha, car_vol, car_per, car_dup, car_ent)\n    VALUES (v_pnj, ''employe'', c->>''nom'', ''soviet'', ''ville_b'', ''zone-production'', ''foret_vue_3'', ''beta'', public.pnj_pa_max(), ''faune'', ''soviet:ville_b:foret'',';
    IF (length(d) - length(replace(d, avant, ''))) / length(avant) <> 1 THEN RAISE EXCEPTION 'sovarka_foret_couper : ancrage introuvable'; END IF;
    EXECUTE replace(d, avant, apres);
  END IF;
  IF position('soviet:ville_b:foret' IN pg_get_functiondef('public.sovarka_foret_couper(uuid)'::regprocedure)) = 0 THEN
    RAISE EXCEPTION 'sovarka_foret_couper : proprietaire de la creature absent';
  END IF;
END $raccord$;
COMMIT;
