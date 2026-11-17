-- Restaurant « Entre terre et mer » de Starovka (prix validés par Fred, 18/11/2026) :
--  1. menus à la carte à 15 PSK (au lieu de 6) : dotation ET commerce déjà créé ;
--  2. dîner d'affaires à 40 PSK (2 PA) : le serveur tarife désormais ce lieu (il n'y était pas,
--     l'invitation y était refusée) ; 2 menus de Starovka + 1 bière du restaurant.
-- Le tarif (diner_affaires, 2, 40) existe déjà (20261117161500). Aucune donnée de joueur touchée. Idempotente.
BEGIN;

UPDATE public.commerces_dotations
   SET parametres = jsonb_set(parametres, '{prixVente}',
         COALESCE(parametres->'prixVente','{}'::jsonb)
         || '{"starovka_menu_pecheur":15,"starovka_menu_eleveur":15,"starovka_menu_terre_mer":15}'::jsonb)
 WHERE cle = 'capitaine-sauvage|salle_principale@soviet.ville_a';

UPDATE public.entreprises e
   SET data = jsonb_set(e.data, '{parametres,prixVente}',
         COALESCE(e.data->'parametres'->'prixVente','{}'::jsonb)
         || '{"starovka_menu_pecheur":15,"starovka_menu_eleveur":15,"starovka_menu_terre_mer":15}'::jsonb),
       updated_at = now()
 WHERE e.id = 'brasserie-soviet-ville_a-capitaine-sauvage-salle_principale';

DO $diner$
DECLARE d text; b text; v_pos integer;
BEGIN
  d := pg_get_functiondef('public.diner_commerce_lieu_interne(text,text,text,text)'::regprocedure);
  IF position('brasserie-soviet-ville_a-capitaine-sauvage-salle_principale' IN d) > 0 THEN RETURN; END IF;
  -- Insertion avant le dernier « END; » (fin du CASE), quelle que soit la mise en page de la version en place.
  v_pos := length(d) - position(reverse('END;') IN reverse(d)) - 2;
  IF position('END;' IN d) = 0 OR substr(d, v_pos, 4) <> 'END;' THEN RAISE EXCEPTION 'diner_commerce_lieu_interne : ancrage introuvable'; END IF;
  b := E'\n   WHEN (p_pays,p_ville,p_bat,p_piece)=(''soviet'',''ville_a'',''capitaine-sauvage'',''salle_principale'')\n'
    || E'    THEN ''{"entreprise":"brasserie-soviet-ville_a-capitaine-sauvage-salle_principale","prix":40,"pa":2,\n'
    || E'           "menus":["starovka_menu_pecheur","starovka_menu_eleveur","starovka_menu_terre_mer"],"boisson":"biere_pression","qte_boisson":1}''::jsonb\n  ';
  EXECUTE left(d, v_pos - 1) || b || substr(d, v_pos);
END $diner$;

DO $post$
BEGIN
  IF (public.diner_commerce_lieu_interne('soviet','ville_a','capitaine-sauvage','salle_principale')->>'prix')::integer IS DISTINCT FROM 40
     OR (public.diner_commerce_lieu_interne('soviet','ville_a','hotel-mineur','hall_mineur')->>'prix')::integer IS DISTINCT FROM 40
     OR (public.diner_commerce_lieu_interne('republic','ville_a','capitaine-sauvage','salle_principale')->>'prix')::integer IS DISTINCT FROM 150
     OR NOT EXISTS (SELECT 1 FROM public.ordres_couts WHERE fn='diner_affaires' AND pa=2 AND cost=40)
     OR (SELECT (parametres->'prixVente'->>'starovka_menu_pecheur')::integer FROM public.commerces_dotations
          WHERE cle='capitaine-sauvage|salle_principale@soviet.ville_a') IS DISTINCT FROM 15
  THEN RAISE EXCEPTION 'starovka_restaurant_prix : contrôle structurel en échec'; END IF;
END $post$;

NOTIFY pgrst, 'reload schema';
COMMIT;
