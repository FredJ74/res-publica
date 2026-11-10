-- SOVARKA : CARTES DES RESTAURANTS (decisions de Fred du 10/11/2026, 22 h 27 - 22 h 45 ; GAME-DESIGN-NOVOMIRSK.md,
-- « Cartes des restaurants de Sovarka »).
--  1. En Sovarka, plus aucun plat francais ni vin : les generiques bœuf bourguignon, saucisse-puree, plat de poisson,
--     petit-dejeuner, vin, carbonade-frites et sandwich des cheminots deviennent propres a la Republia. Biere, cafe,
--     boissons sans alcool et cacahuetes restent communs.
--  2. La Mere Volga (Novomirsk) : Menu du Proletaire, du Stakhanoviste, du Jour de Repos.
--  3. « Entre terre et mer » (Starovka) : Menu du Pecheur des Glaces, de l'Eleveur, Terre et Mer.
--  4. Bar Sever (Krasnov) : tartine de salo, solianka, petit-dejeuner du kolkhozien, verre de vodka, the au samovar.
--  5. Grand Hotel de Novomirsk : ses trois menus, plus zakouski, champagne sovietique et vodka imperiale (8 PSK fixes).
-- Prix de vente PNJ : formule commune (2 x cout de revient), a l'echelle de Sovarka (PA a 15 PSK).
-- Socle : une dotation de commerce peut desormais viser un pays ET une ville (cle « batiment|piece@pays.ville »),
-- avant la cle « @ville » (les villes ville_a/ville_b/capitale existent dans les deux empires).
-- Aucune donnee de joueur touchee. Idempotente.
BEGIN;

-- 1. Generiques francais reserves a la Republia.
UPDATE public.recettes_commerce SET pays_autorises = '["republic"]'::jsonb
 WHERE id IN ('boeuf_bourguignon','saucisse_puree','plat_de_poisson','petit_dejeuner','vin','carbonade_frites','sandwich_cheminots')
   AND pays_autorises IS NULL;

-- 2-5. Recettes locales.
INSERT INTO public.recettes_commerce (id, source, label, pa, portions, materiaux, prix_fixe, categorie, types_autorises,
                                      pays_autorises, villes_autorisees, buildings_autorises, effets) VALUES
 ('volga_menu_proletaire','alimentaire','Menu du Prolétaire — Soupe aux choux (chtchi), Kacha de sarrasin au beurre, Kissel de canneberge',1,6,'{"cereales":1,"fruits_legumes":1}',NULL,'menu','["brasserie"]','["soviet"]','["capitale"]','["capitaine-sauvage"]','{"hp":10,"moral":1,"paDiffere":3}'),
 ('volga_menu_stakhanoviste','alimentaire','Menu du Stakhanoviste — Salade vinegret de betteraves, Côtelettes Pojarski et pommes de terre, Syrniki à la crème aigre',1,6,'{"viande":1,"cereales":1,"fruits_legumes":1}',NULL,'menu','["brasserie"]','["soviet"]','["capitale"]','["capitaine-sauvage"]','{"hp":10,"moral":1,"paDiffere":3}'),
 ('volga_menu_repos','alimentaire','Menu du Jour de Repos — Hareng sous fourrure, Golubtsy (choux farcis), Blinis à la confiture',1,6,'{"poisson":1,"viande":1,"cereales":1}',NULL,'menu','["brasserie"]','["soviet"]','["capitale"]','["capitaine-sauvage"]','{"hp":10,"moral":1,"paDiffere":3}'),
 ('starovka_menu_pecheur','alimentaire','Menu du Pêcheur des Glaces — Stroganina (poisson cru gelé), Oukha (soupe de poisson), Airelles au miel',1,6,'{"poisson":2,"fruits_legumes":1}',NULL,'menu','["brasserie"]','["soviet"]','["ville_a"]','["capitaine-sauvage"]','{"hp":10,"moral":1,"paDiffere":3}'),
 ('starovka_menu_eleveur','alimentaire','Menu de l''Éleveur — Bouillon de renne, Bouzy (raviolis vapeur bouriates), Beignets boortsog',1,6,'{"viande":2,"cereales":1}',NULL,'menu','["brasserie"]','["soviet"]','["ville_a"]','["capitaine-sauvage"]','{"hp":10,"moral":1,"paDiffere":3}'),
 ('starovka_menu_terre_mer','alimentaire','Menu Terre et Mer — Salade de chou de mer, Omoul fumé et côtes de renne grillées, Crème de lait de renne au sucre',1,6,'{"poisson":1,"viande":1,"laitages":1}',NULL,'menu','["brasserie"]','["soviet"]','["ville_a"]','["capitaine-sauvage"]','{"hp":10,"moral":1,"paDiffere":3}'),
 ('sever_tartine_salo','alimentaire','Tartine de salo et cornichons',1,8,'{"viande":1,"cereales":1}',NULL,'plat','["cafe"]','["soviet"]','["ville_b"]','["cafe-tabac-cheminots-montrouge"]','{"hp":5,"moral":1}'),
 ('sever_solianka','alimentaire','Solianka — plat du jour',1,8,'{"viande":1,"fruits_legumes":1}',NULL,'plat','["cafe"]','["soviet"]','["ville_b"]','["cafe-tabac-cheminots-montrouge"]','{"hp":8,"moral":2}'),
 ('sever_petit_dejeuner','alimentaire','Petit-déjeuner du kolkhozien (kacha au lait, pain noir, thé)',1,10,'{"cereales":1}',NULL,'petit_dej','["cafe"]','["soviet"]','["ville_b"]','["cafe-tabac-cheminots-montrouge"]','{"hp":3,"moral":1}'),
 ('sever_vodka','alimentaire','Verre de vodka',1,15,'{"alcool":1}',NULL,'boisson','["cafe"]','["soviet"]','["ville_b"]','["cafe-tabac-cheminots-montrouge"]','{"moral":2}'),
 ('sever_the_samovar','alimentaire','Thé au samovar',1,15,'{"produits_exotiques":1}',NULL,'boisson','["cafe"]','["soviet"]','["ville_b"]','["cafe-tabac-cheminots-montrouge"]','{"moral":2}'),
 ('grand_hotel_zakouski','alimentaire','Zakouski (cornichons, harengs, œufs de saumon)',1,15,'{"poisson":1}',NULL,'snack','["brasserie"]','["soviet"]','["capitale"]','["hotel-republica"]','{"hp":2,"moral":1}'),
 ('grand_hotel_champagne_sovietique','alimentaire','Champagne soviétique (Sovetskoïe Shampanskoïe)',2,9,'{"fruits_legumes":2}',8,'boisson','["brasserie"]','["soviet"]','["capitale"]','["hotel-republica"]','{"moral":2}'),
 ('grand_hotel_vodka_imperiale','alimentaire','Vodka impériale glacée',2,9,'{"cereales":2}',8,'boisson','["brasserie"]','["soviet"]','["capitale"]','["hotel-republica"]','{"moral":2}')
ON CONFLICT (id) DO NOTHING;

-- Dotations par pays et ville (cartes, stocks, prix PNJ).
INSERT INTO public.commerces_dotations (cle, type, caisse, stock_matieres, cout_moyen_matieres, carte, parametres) VALUES
 ('capitaine-sauvage|salle_principale@soviet.capitale','brasserie',1000,
  '{"cereales":15,"poisson":10,"viande":10,"fruits_legumes":10}','{"cereales":1,"poisson":1,"viande":2,"fruits_legumes":1}',
  '["volga_menu_proletaire","volga_menu_stakhanoviste","volga_menu_repos","biere_pression","cafe_boisson","snack_buvette"]',
  '{"stockMax":{"volga_menu_proletaire":20,"volga_menu_stakhanoviste":20,"volga_menu_repos":20,"biere_pression":20,"cafe_boisson":20,"snack_buvette":20},
    "prixVente":{"volga_menu_proletaire":6,"volga_menu_stakhanoviste":6,"volga_menu_repos":6,"biere_pression":2,"cafe_boisson":2,"snack_buvette":2}}'),
 ('capitaine-sauvage|salle_principale@soviet.ville_a','brasserie',1000,
  '{"cereales":10,"poisson":15,"viande":15,"fruits_legumes":10,"laitages":5}','{"cereales":1,"poisson":1,"viande":2,"fruits_legumes":1,"laitages":1}',
  '["starovka_menu_pecheur","starovka_menu_eleveur","starovka_menu_terre_mer","biere_pression","cafe_boisson","snack_buvette"]',
  '{"stockMax":{"starovka_menu_pecheur":20,"starovka_menu_eleveur":20,"starovka_menu_terre_mer":20,"biere_pression":20,"cafe_boisson":20,"snack_buvette":20},
    "prixVente":{"starovka_menu_pecheur":6,"starovka_menu_eleveur":6,"starovka_menu_terre_mer":6,"biere_pression":2,"cafe_boisson":2,"snack_buvette":2}}'),
 ('cafe-tabac-cheminots-montrouge@soviet.ville_b','cafe',500,
  '{"viande":10,"cereales":10,"fruits_legumes":10,"produits_exotiques":10,"alcool":10}','{"viande":2,"cereales":1,"fruits_legumes":1,"produits_exotiques":1,"alcool":2}',
  '["sever_tartine_salo","sever_solianka","sever_petit_dejeuner","sever_vodka","sever_the_samovar","cafe_boisson","biere_pression","boisson_sans_alcool"]',
  '{"stockMax":{"sever_tartine_salo":20,"sever_solianka":20,"sever_petit_dejeuner":20,"sever_vodka":20,"sever_the_samovar":20,"cafe_boisson":20,"biere_pression":20,"boisson_sans_alcool":20},
    "prixVente":{"sever_tartine_salo":5,"sever_solianka":5,"sever_petit_dejeuner":3,"sever_vodka":2,"sever_the_samovar":2,"cafe_boisson":2,"biere_pression":2,"boisson_sans_alcool":3}}'),
 ('hotel-republica@soviet.capitale','brasserie',3000,
  '{"viande":15,"poisson":10,"cereales":25,"fruits_legumes":20,"produits_exotiques":10}','{"viande":2,"poisson":1,"cereales":1,"fruits_legumes":1,"produits_exotiques":1}',
  '["menu_sovarka_imperial","menu_sovarka_tsars","menu_sovarka_plan","grand_hotel_zakouski","grand_hotel_champagne_sovietique","grand_hotel_vodka_imperiale","cafe_boisson","biere_pression","snack_buvette"]',
  '{"stockMax":{"menu_sovarka_imperial":20,"menu_sovarka_tsars":20,"menu_sovarka_plan":20,"grand_hotel_zakouski":20,"grand_hotel_champagne_sovietique":20,"grand_hotel_vodka_imperiale":20,"cafe_boisson":20,"biere_pression":20,"snack_buvette":20},
    "prixVente":{"menu_sovarka_imperial":40,"menu_sovarka_tsars":40,"menu_sovarka_plan":40,"grand_hotel_zakouski":2,"grand_hotel_champagne_sovietique":8,"grand_hotel_vodka_imperiale":8,"cafe_boisson":7,"biere_pression":7,"snack_buvette":7}}')
ON CONFLICT (cle) DO NOTHING;

-- Socle : lecture de la dotation par pays et ville (patch ancre d'entreprise_assurer_existence, 3 points).
DO $raccord$
DECLARE d text; a1 text; b1 text; a2 text; b2 text;
BEGIN
  d := pg_get_functiondef('public.entreprise_assurer_existence(text,text,text,text,text,text)'::regprocedure);
  IF position('dotation_pays_ville_v1' IN d) > 0 THEN RETURN; END IF;
  a1 := E'    SELECT * INTO v_dot FROM public.commerces_dotations WHERE cle = v_cle || ''@'' || p_ville;\n';
  b1 := E'    -- dotation_pays_ville_v1 (10/11/2026) : la cle « @pays.ville » prime sur « @ville ».\n'
     || E'    SELECT * INTO v_dot FROM public.commerces_dotations WHERE cle = v_cle || ''@'' || p_pays || ''.'' || p_ville;\n'
     || E'    IF NOT FOUND THEN\n'
     || E'      SELECT * INTO v_dot FROM public.commerces_dotations WHERE cle = v_cle || ''@'' || p_ville;\n'
     || E'    END IF;\n';
  a2 := E'      SELECT * INTO v_dot FROM public.commerces_dotations WHERE cle = p_batiment;\n';
  b2 := E'      SELECT * INTO v_dot FROM public.commerces_dotations WHERE cle = p_batiment || ''@'' || p_pays || ''.'' || p_ville;\n'
     || E'    END IF;\n'
     || E'    IF NOT FOUND THEN\n'
     || a2;
  IF (length(d) - length(replace(d, a1, ''))) / length(a1) <> 2
     OR (length(d) - length(replace(d, a2, ''))) / length(a2) <> 1 THEN
    RAISE EXCEPTION 'entreprise_assurer_existence : ancrage introuvable';
  END IF;
  EXECUTE replace(replace(d, a1, b1), a2, b2);
END $raccord$;

-- Grand Hotel de Novomirsk deja cree : carte nettoyee (plus de vin ni de menus de Luthecia), extras ajoutes.
UPDATE public.entreprises e SET data = jsonb_set(jsonb_set(jsonb_set(jsonb_set(e.data,
   '{carte}', (SELECT d.carte FROM public.commerces_dotations d WHERE d.cle = 'hotel-republica@soviet.capitale')),
   '{stockProduits}', (COALESCE(e.data->'stockProduits','{}'::jsonb) - 'vin' - 'menu_gastronomique_1' - 'menu_gastronomique_2' - 'menu_gastronomique_3')
                      || '{"grand_hotel_zakouski":15,"grand_hotel_champagne_sovietique":9,"grand_hotel_vodka_imperiale":9}'::jsonb),
   '{parametres,stockMax}', (COALESCE(e.data->'parametres'->'stockMax','{}'::jsonb) - 'vin' - 'menu_gastronomique_1' - 'menu_gastronomique_2' - 'menu_gastronomique_3')
                      || '{"grand_hotel_zakouski":20,"grand_hotel_champagne_sovietique":20,"grand_hotel_vodka_imperiale":20}'::jsonb),
   '{parametres,prixVente}', (COALESCE(e.data->'parametres'->'prixVente','{}'::jsonb) - 'vin' - 'menu_gastronomique_1' - 'menu_gastronomique_2' - 'menu_gastronomique_3')
                      || '{"grand_hotel_zakouski":2,"grand_hotel_champagne_sovietique":8,"grand_hotel_vodka_imperiale":8}'::jsonb),
   updated_at = now()
 WHERE e.id = 'brasserie-soviet-capitale-hotel-republica' AND NOT (e.data->'carte' ? 'grand_hotel_zakouski');

-- Controles structurels.
DO $$
BEGIN
  IF (SELECT count(*) FROM public.recettes_commerce WHERE id LIKE 'volga_%' OR id LIKE 'starovka_menu_%' OR id LIKE 'sever_%' OR id LIKE 'grand_hotel_%') <> 14
     OR (SELECT count(*) FROM public.commerces_dotations WHERE cle LIKE '%@soviet.%') <> 4
     OR position('dotation_pays_ville_v1' IN pg_get_functiondef('public.entreprise_assurer_existence(text,text,text,text,text,text)'::regprocedure)) = 0
     OR EXISTS (SELECT 1 FROM public.recettes_commerce WHERE id IN ('boeuf_bourguignon','vin','saucisse_puree','plat_de_poisson','petit_dejeuner','carbonade_frites','sandwich_cheminots')
                AND pays_autorises IS DISTINCT FROM '["republic"]'::jsonb)
     OR EXISTS (SELECT 1 FROM public.entreprises WHERE id = 'brasserie-soviet-capitale-hotel-republica' AND data->'carte' ? 'vin') THEN
    RAISE EXCEPTION 'sovarka_cartes_restaurants : controle structurel en echec';
  END IF;
END $$;

COMMIT;

-- Complement (meme lot) : le diner d'affaires du Grand Hotel de Novomirsk consommait du vin, retire de Sovarka ;
-- il sert desormais une bouteille de champagne sovietique.
BEGIN;
DO $diner$
DECLARE d text; a text; b text;
BEGIN
  d := pg_get_functiondef('public.diner_commerce_lieu_interne(text,text,text,text)'::regprocedure);
  a := $a$"menus":["menu_sovarka_imperial","menu_sovarka_tsars","menu_sovarka_plan"],"boisson":"vin"$a$;
  b := $b$"menus":["menu_sovarka_imperial","menu_sovarka_tsars","menu_sovarka_plan"],"boisson":"grand_hotel_champagne_sovietique"$b$;
  IF position(b IN d) > 0 THEN RETURN; END IF;
  IF (length(d) - length(replace(d, a, ''))) / length(a) <> 1 THEN RAISE EXCEPTION 'diner_commerce_lieu_interne : ancrage introuvable'; END IF;
  EXECUTE replace(d, a, b);
END $diner$;
COMMIT;

-- Complement (meme lot) : bonus de +3 PA au prochain Dormir des menus de Sovarka (miroir pa_bonus_differes, regenere
-- par outils/generateurs/generer_pa_bonus_differes.py). Les trois menus du Grand Hotel y manquaient depuis le 06/11.
BEGIN;
INSERT INTO public.pa_bonus_differes (source, montant) VALUES
 ('volga_menu_proletaire',3),('volga_menu_stakhanoviste',3),('volga_menu_repos',3),
 ('starovka_menu_pecheur',3),('starovka_menu_eleveur',3),('starovka_menu_terre_mer',3),
 ('menu_sovarka_imperial',3),('menu_sovarka_tsars',3),('menu_sovarka_plan',3)
ON CONFLICT (source) DO NOTHING;
COMMIT;
