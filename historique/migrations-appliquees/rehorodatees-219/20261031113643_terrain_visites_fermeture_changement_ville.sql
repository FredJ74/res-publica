-- PRÉPARATION NON APPLIQUÉE : rehorodatée après la coupe canonique du 31/10/2026.
-- Ancien fichier : 20261027104800_terrain_visites_fermeture_changement_ville.sql ; aucun changement de règle.
-- Une visite appartient a un terrain dans sa ville, pas seulement a un identifiant
-- de batiment partageable entre plusieurs villes. Aucun changement de donnees.
CREATE OR REPLACE FUNCTION public.terrain_visites_clore_interne() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $f$
DECLARE v record;
BEGIN
  -- Un rafraichissement ou une sauvegarde au meme endroit conserve la visite.
  IF (NEW.country,NEW.current_city,NEW.current_building) IS NOT DISTINCT FROM
     (OLD.country,OLD.current_city,OLD.current_building) THEN RETURN NEW; END IF;
  FOR v IN SELECT t.id
    FROM public.terrain_visites_actives a
    JOIN public.terrains_etat t ON t.id=a.terrain_id
    WHERE a.personnage_id=OLD.id
      AND (t.country IS DISTINCT FROM NEW.country
           OR t.building_id IS DISTINCT FROM NEW.current_building
           OR (t.data::jsonb->>'city') IS DISTINCT FROM NEW.current_city)
    ORDER BY t.id FOR UPDATE OF t LOOP
    DELETE FROM public.terrain_visites_actives
     WHERE personnage_id=OLD.id AND terrain_id=v.id;
  END LOOP;
  RETURN NEW;
END;$f$;
REVOKE ALL ON FUNCTION public.terrain_visites_clore_interne() FROM PUBLIC,anon,authenticated;
