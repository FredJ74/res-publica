-- Image du furet renifleur (planche de Fred, 18/11/2026) : l'objet déposé à l'achat porte son image d'inventaire.
-- Aucun furet n'était encore en jeu au moment du raccord (relevé du 18/11) : pas de reprise des inventaires.
BEGIN;
DO $$
DECLARE f regprocedure := 'public.furet_acheter(uuid)'::regprocedure; d text;
  avant text := $a$'reniflesAvaries', 0, 'desc'$a$;
  apres text := $b$'reniflesAvaries', 0, 'imageUrl', 'images/objet-furet-renifleur.webp', 'desc'$b$;
BEGIN
  d := pg_get_functiondef(f);
  IF position('objet-furet-renifleur' IN d) > 0 THEN RETURN; END IF;
  IF (length(d) - length(replace(d, avant, ''))) / length(avant) <> 1 THEN RAISE EXCEPTION 'furet_acheter : ancrage'; END IF;
  EXECUTE replace(d, avant, apres);
  IF position('objet-furet-renifleur' IN pg_get_functiondef(f)) = 0 THEN RAISE EXCEPTION 'furet_acheter : raccord absent'; END IF;
END $$;
COMMIT;
