-- Hôtel des Voyageurs de Starovka (décisions de Fred, 17/11/2026, GAME-DESIGN-NOVOMIRSK.md « Tour de Starovka ») :
-- 1. Cinq pièces : salle commune (hall_mineur, réception + restaurant + bar) et quatre chambres
--    (chambre_mineur, chambre_mineur_2 à 4), à Starovka seulement (Montrouge et Krasnov inchangés).
-- 2. Le bonus de nuit d'hôtel vaut dans les quatre chambres (hotel_nuitee_consommation_interne).
-- 3. Carte propre (commerce cafe-soviet-ville_a-hotel-mineur) : Menu du Voyageur, Menu du Cheminot,
--    petit-déjeuner du voyageur, thé au beurre, tarassoun, vodka, plus café, bière et boissons sans alcool.
--    Prix PNJ : 2 × coût de revient à l'échelle de Sovarka (menus 6 PSK, petit-déjeuner 3, boissons 2 à 3).
-- 4. Dîner d'affaires 40 PSK (2 menus + 1 tarassoun), même contrat serveur commerce_v1 que le Grand Hôtel.
-- 5. « Écouter le barman » : 90 %, source Aldar Zhamsuev, comme le bar de La Républia.
-- Aucune donnée de joueur touchée. Idempotente.
BEGIN;

DO $pre$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.navigation_lieux_regles
                  WHERE pays='soviet' AND ville='ville_a' AND batiment='hotel-mineur'
                    AND pieces @> '["hall_mineur","chambre_mineur"]'::jsonb)
  THEN RAISE EXCEPTION 'hotel_voyageurs : pièces canoniques absentes'; END IF;
END $pre$;

-- 1. Navigation : cinq pièces, dans l'ordre de data.js (roomOrder).
UPDATE public.navigation_lieux_regles
   SET pieces='["hall_mineur","chambre_mineur","chambre_mineur_2","chambre_mineur_3","chambre_mineur_4"]'::jsonb
 WHERE pays='soviet' AND ville='ville_a' AND batiment='hotel-mineur'
   AND pieces IS DISTINCT FROM '["hall_mineur","chambre_mineur","chambre_mineur_2","chambre_mineur_3","chambre_mineur_4"]'::jsonb;

-- 2. Nuit d'hôtel dans les quatre chambres (patch ancré, une seule occurrence).
DO $nuitee$
DECLARE d text; a text; b text;
BEGIN
  d := pg_get_functiondef('public.hotel_nuitee_consommation_interne(text)'::regprocedure);
  IF position('chambre_mineur_4' IN d) > 0 THEN RETURN; END IF;
  a := $a$(p.current_building='hotel-mineur' AND p.current_room='chambre_mineur')$a$;
  b := $b$(p.current_building='hotel-mineur' AND p.current_room IN ('chambre_mineur','chambre_mineur_2','chambre_mineur_3','chambre_mineur_4'))$b$;
  IF (length(d) - length(replace(d, a, ''))) / length(a) <> 1 THEN RAISE EXCEPTION 'hotel_nuitee_consommation_interne : ancrage introuvable'; END IF;
  EXECUTE replace(d, a, b);
END $nuitee$;

-- 3. Carte de l'Hôtel des Voyageurs.
INSERT INTO public.recettes_commerce (id, source, label, pa, portions, materiaux, prix_fixe, categorie, types_autorises,
                                      pays_autorises, villes_autorisees, buildings_autorises, effets) VALUES
 ('voyageurs_petit_dejeuner','alimentaire','Petit-déjeuner du voyageur (bouillie d''avoine au lait de renne, pain et confiture, thé)',1,10,'{"cereales":1}',NULL,'petit_dej','["cafe"]','["soviet"]','["ville_a"]','["hotel-mineur"]','{"hp":3,"moral":1}'),
 ('voyageurs_the_beurre','alimentaire','Thé au beurre bouriate',1,15,'{"produits_exotiques":1}',NULL,'boisson','["cafe"]','["soviet"]','["ville_a"]','["hotel-mineur"]','{"moral":2}'),
 ('voyageurs_tarassoun','alimentaire','Tarassoun (eau-de-vie de lait bouriate)',1,15,'{"laitages":1}',NULL,'boisson','["cafe"]','["soviet"]','["ville_a"]','["hotel-mineur"]','{"moral":2}'),
 ('voyageurs_vodka','alimentaire','Verre de vodka',1,15,'{"alcool":1}',NULL,'boisson','["cafe"]','["soviet"]','["ville_a"]','["hotel-mineur"]','{"moral":2}'),
 ('voyageurs_menu_voyageur','alimentaire','Menu du Voyageur — Soupe de nouilles au mouton, Khouchour (chaussons frits au renne), Compote d''airelles',1,6,'{"viande":1,"cereales":1,"fruits_legumes":1}',NULL,'menu','["cafe"]','["soviet"]','["ville_a"]','["hotel-mineur"]','{"hp":10,"moral":1,"paDiffere":3}'),
 ('voyageurs_menu_cheminot','alimentaire','Menu du Cheminot — Pelmeni en bouillon, Pain noir, Kissel de canneberge',1,6,'{"viande":1,"cereales":1,"fruits_legumes":1}',NULL,'menu','["cafe"]','["soviet"]','["ville_a"]','["hotel-mineur"]','{"hp":10,"moral":1,"paDiffere":3}')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.commerces_dotations (cle, type, caisse, stock_matieres, cout_moyen_matieres, carte, parametres) VALUES
 ('hotel-mineur@soviet.ville_a','cafe',500,
  '{"viande":10,"cereales":15,"fruits_legumes":10,"produits_exotiques":10,"laitages":10,"alcool":10}',
  '{"viande":2,"cereales":1,"fruits_legumes":1,"produits_exotiques":1,"laitages":1,"alcool":2}',
  '["voyageurs_menu_voyageur","voyageurs_menu_cheminot","voyageurs_petit_dejeuner","voyageurs_the_beurre","voyageurs_tarassoun","voyageurs_vodka","cafe_boisson","biere_pression","boisson_sans_alcool"]',
  '{"stockMax":{"voyageurs_menu_voyageur":20,"voyageurs_menu_cheminot":20,"voyageurs_petit_dejeuner":20,"voyageurs_the_beurre":20,"voyageurs_tarassoun":20,"voyageurs_vodka":20,"cafe_boisson":20,"biere_pression":20,"boisson_sans_alcool":20},
    "prixVente":{"voyageurs_menu_voyageur":6,"voyageurs_menu_cheminot":6,"voyageurs_petit_dejeuner":3,"voyageurs_the_beurre":2,"voyageurs_tarassoun":2,"voyageurs_vodka":2,"cafe_boisson":2,"biere_pression":2,"boisson_sans_alcool":3}}')
ON CONFLICT (cle) DO NOTHING;

-- +3 PA au prochain Dormir des deux menus (miroir pa_bonus_differes, généré par generer_pa_bonus_differes.py).
INSERT INTO public.pa_bonus_differes (source, montant) VALUES
 ('voyageurs_menu_voyageur',3),('voyageurs_menu_cheminot',3)
ON CONFLICT (source) DO NOTHING;

-- 4. Dîner d'affaires de la salle commune, 40 PSK.
DO $diner$
DECLARE d text; a text; b text;
BEGIN
  d := pg_get_functiondef('public.diner_commerce_lieu_interne(text,text,text,text)'::regprocedure);
  IF position('cafe-soviet-ville_a-hotel-mineur' IN d) > 0 THEN RETURN; END IF;
  a := E'\n  END;\n';
  b := E'\n   WHEN (p_pays,p_ville,p_bat,p_piece)=(''soviet'',''ville_a'',''hotel-mineur'',''hall_mineur'')\n'
    || E'    THEN ''{"entreprise":"cafe-soviet-ville_a-hotel-mineur","prix":40,"pa":2,\n'
    || E'           "menus":["voyageurs_menu_voyageur","voyageurs_menu_cheminot"],"boisson":"voyageurs_tarassoun","qte_boisson":1}''::jsonb\n'
    || E'  END;\n';
  IF (length(d) - length(replace(d, a, ''))) / length(a) <> 1 THEN RAISE EXCEPTION 'diner_commerce_lieu_interne : ancrage introuvable'; END IF;
  EXECUTE replace(d, a, b);
END $diner$;

-- 5. Rumeurs : le barman de la salle commune.
DO $rumeur$
DECLARE d text; a text; b text;
BEGIN
  d := pg_get_functiondef('public.rumeur_ecoute_jauges_interne(text)'::regprocedure);
  IF position('Aldar Zhamsuev' IN d) > 0 THEN RETURN; END IF;
  a := $a$ ELSE RETURN jsonb_build_object('ok',false,'raison','pas_sur_place');END IF;$a$;
  b := $b$ ELSIF a.country='soviet'AND a.current_city='ville_a'AND a.current_building='hotel-mineur'AND a.current_room='hall_mineur'THEN taux:=90;cout_pa:=0;source:='Aldar Zhamsuev';
 ELSE RETURN jsonb_build_object('ok',false,'raison','pas_sur_place');END IF;$b$;
  IF (length(d) - length(replace(d, a, ''))) / length(a) <> 1 THEN RAISE EXCEPTION 'rumeur_ecoute_jauges_interne : ancrage introuvable'; END IF;
  EXECUTE replace(d, a, b);
END $rumeur$;

DO $post$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.navigation_lieux_regles WHERE pays='soviet' AND ville='ville_a' AND batiment='hotel-mineur'
                   AND pieces='["hall_mineur","chambre_mineur","chambre_mineur_2","chambre_mineur_3","chambre_mineur_4"]'::jsonb)
     OR NOT EXISTS (SELECT 1 FROM public.navigation_lieux_regles WHERE pays='republic' AND ville='ville_b' AND batiment='hotel-mineur'
                   AND pieces='["hall_mineur","chambre_mineur"]'::jsonb)
     OR position('chambre_mineur_4' IN pg_get_functiondef('public.hotel_nuitee_consommation_interne(text)'::regprocedure)) = 0
     OR (SELECT count(*) FROM public.recettes_commerce WHERE id LIKE 'voyageurs\_%') <> 6
     OR NOT EXISTS (SELECT 1 FROM public.commerces_dotations WHERE cle='hotel-mineur@soviet.ville_a')
     OR (SELECT count(*) FROM public.pa_bonus_differes WHERE source IN ('voyageurs_menu_voyageur','voyageurs_menu_cheminot')) <> 2
     OR (public.diner_commerce_lieu_interne('soviet','ville_a','hotel-mineur','hall_mineur')->>'prix')::integer IS DISTINCT FROM 40
     OR public.diner_commerce_lieu_interne('soviet','capitale','hotel-republica','restaurant') IS NULL
     OR public.diner_commerce_lieu_interne('soviet','ville_b','hotel-mineur','hall_mineur') IS NOT NULL
     OR position('Aldar Zhamsuev' IN pg_get_functiondef('public.rumeur_ecoute_jauges_interne(text)'::regprocedure)) = 0
  THEN RAISE EXCEPTION 'hotel_voyageurs : contrôle structurel en échec'; END IF;
END $post$;

COMMIT;
