-- Santé — consommation : alcool, sommeil, repas, soins (Fred, 22/11/2026, après-midi : GAME-DESIGN-SANTE-20261122.md,
-- points 7, 8, 9, 10, 11). Le point 6 (escort_intimite) est traité par la migration des maladies.
-- Requiert le socle 20261122230000_sante_socle (sante_param, sante_gagner_interne, sante_reveil_interne).
-- Tous les gains passent par sante_gagner_interne (modulés par le Moral, point 11) ; une perte (3e verre) ne l'est jamais.
-- Toutes les valeurs viennent de sante_parametres (réglables par un MJ) ; aucune Santé actuelle n'est modifiée (point 16).
--
-- POINT 7 — ALCOOL. Le compteur est celui de la gueule de bois : verres_du_jour (nom, jour de Paris), incrémenté par
--   maladie_verre_interne, seule porte de toutes les boissons alcoolisées : bar et restaurant d'un commerce de joueur
--   (consommer_sur_place_commerce), inventaire (inventaire_consommer : minibar de la Résidence, bouteilles de distillerie,
--   verre offert déposé), tournée (tournee_cloturer_boire), dîner d'affaires (champagne, boisson du lieu), service d'étage
--   du Grand Hôtel, « trinquer » chez l'habitant (sovarka_maison_agir) et, NOUVEAU, le comptoir des commerces PNJ
--   (commerce_vendre_produit, mode comptoir : bière, vin, vodka du bar… qui n'étaient pas comptés jusqu'ici).
--   Après l'incrément : 1er verre alcoolisé du jour +1, 2e 0, 3e et suivants −2 (sante_alcool_verre_interne).
--   Le +5 de tournee_cloturer_boire est supprimé. « boire_verre » n'a plus de chemin serveur (son +5 était une
--   configuration morte du navigateur, plateau-pnj.js, retirée). La buvette du stade (consommer_buvette de
--   jauges_ordre_executer) n'est proposée par aucun lieu : non touchée.
--
-- POINT 8 — SOMMEIL. Branché sur l'appel serveur existant du Dormir, pa_repos_nocturne (jamais rejoué : garde du jour) :
--   juste avant ses deux RETURN de réussite (repos ordinaire et repos hospitalier), sante_sommeil_interne(nom)
--   détermine le lieu À PARTIR DE LA POSITION EN BASE (personnages_donnees), crédite le gain une seule fois par jour de
--   Paris (table sante_sommeils, clé nom + jour), appelle sante_reveil_interne(nom) et renvoie
--   « sante_sommeil » (gain, avant, après, lieu) et « evenements_reveil ». Lieu, dans cet ordre :
--     1. dehors   : aucun bâtiment (current_building vide : rue) ;
--     2. chambre  : son propre logement (logement_sommeil_interne non nul : titulaire, conjoint, colocataire, chambre
--                   premium) ;
--     3. table sante_sommeil_lieux (pays et ville facultatifs, motifs sur bâtiment et pièce, par priorité) :
--          clinique : clinique-privee, pièces chambre_1 à chambre_10 (client d'une nuitée ou patient) ;
--          hôpital  : tout bâtiment dispensaire-public* (salle d'attente, EHPAD, chambre d'hôpital) ;
--          chambre  : chambres d'hôtel (hotel-republica chambres et suites, hotel-port chambre_port, hotel-mineur
--                     chambre_mineur*), chambre chez l'habitant (maison-* piece_maison), appartements de la Résidence
--                     impériale, suites du Pavillon des ambassadeurs, appartements du président (palais) ;
--          dehors   : vues en plein air (PIECES_PLEIN_AIR de plateau-climat.js : forêt et camp de bûcherons de Krasnov,
--                     zone de récolte de Starovka, champ de pétrole, cour des fermes, terrains à bâtir, pelouse du stade,
--                     Parc botanique, quais des ports) ;
--     4. bâtiment : tout autre lieu (hall d'hôtel, accueil de la clinique, bureau, prison, caserne…).
--   Gains : sommeil_chambre 5, sommeil_batiment 3, sommeil_dehors 2, sommeil_hopital 5, sommeil_clinique 7.
--   La nuitée de clinique (déclencheur clinique_nuitee_marquer_repos et clinique_nuitee_consommer) ne donne plus de
--   Santé à part : elle passe par le même crédit unique (sommeil_clinique, +7 au lieu de +10). Le navigateur ne calcule
--   plus rien (fin du +12, du +10 de régénération et du bonus Santé du logement).
--
-- POINT 9 — REPAS. Barème Santé / PA différés (bonus_pa_differe, plafond 30), Moral inchangé :
--   sante_repas_appliquer_interne(nom, catégorie, source). Catégories : menu, plat, sandwich, petitdej, snack, boisson
--   (0), joueur_p5, joueur_p10, aucun. Table sante_repas_categories (clé = recette, type ou pile d'objet), repli sur
--   recettes_commerce.categorie. Produit créé par un joueur (référence d'un commerce de joueur) : palier selon son
--   prix de vente (5 à 9,99 → joueur_p5 ; 10 et plus → joueur_p10, comme le dernier palier du navigateur ; moins de 5 :
--   rien). Branché sur : comptoir des commerces PNJ (commerce_vendre_produit : la Santé et le Moral des plats servis au
--   comptoir étaient appliqués par le navigateur), repas gastronomique (vente « service », plat réellement servi),
--   consommation sur place d'un commerce de joueur, aliment mangé depuis l'inventaire (le +1 PA immédiat devient le
--   barème), dîner d'affaires (les deux contrats : plat servi à chacun, menu à défaut), service d'étage du Grand Hôtel
--   (plat commandé) et des hôtels de Républia (plat du jour, aucun plat identifié), marché de Krasnov (pain noir,
--   goulash, fruits et légumes), nouvel ordre serveur « Se nourrir » (sante_se_nourrir : sandwich à défaut de plat).
--
-- POINT 10 — SOINS. recevoir_soin : public +8 Santé +1 PA (une fois par jour, inchangé), clinique +15 +2 PA ;
--   ordre_generique_executer : soins accélérés (soins_urgence) +25, soins sans trace (soins_discrets) +15, mêmes jets.
--
-- Fonctions communes modifiées par remplacement contrôlé (texte de production du 22/11/2026, nombre d'ancrages vérifié,
-- marque unique « sante_conso_* ») : maladie_verre_interne, tournee_cloturer_boire, commerce_vendre_produit,
-- consommer_sur_place_commerce, inventaire_consommer, restaurant_diner_servir, diner_commerce_servir_interne,
-- service_etage_commander, hotel_service_etage_commander, marche_krasnov_manger, pa_repos_nocturne,
-- clinique_nuitee_consommer, clinique_nuitee_marquer_repos, recevoir_soin, ordre_generique_executer.
-- Rejouable. Rien du goulag.
BEGIN;

CREATE OR REPLACE FUNCTION pg_temp.rp_remplacer(p_fn regprocedure, p_avant text, p_apres text, p_n integer, p_marque text)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE d text := pg_get_functiondef(p_fn); n integer;
BEGIN
  IF position(p_marque IN d) > 0 THEN RETURN; END IF;
  n := (length(d) - length(replace(d, p_avant, ''))) / length(p_avant);
  IF n <> p_n THEN RAISE EXCEPTION '% : % occurrence(s) au lieu de % (%)', p_fn, n, p_n, left(p_avant, 60); END IF;
  EXECUTE replace(d, p_avant, p_apres);
  IF position(p_marque IN pg_get_functiondef(p_fn)) = 0 THEN RAISE EXCEPTION '% : marque absente', p_fn; END IF;
END $$;

-- ---------------------------------------------------------------------------------------------------------------
-- 0. Paramètres nouveaux (les gains eux-mêmes sont semés par le socle)
-- ---------------------------------------------------------------------------------------------------------------
INSERT INTO public.sante_parametres (cle, valeur, groupe, libelle) VALUES
  ('repas_joueur_p5_prix_min', 5, 'repas', 'Produit de joueur : prix de vente à partir duquel le palier 5 s''applique'),
  ('repas_joueur_p10_prix_min', 10, 'repas', 'Produit de joueur : prix de vente à partir duquel le palier 10 s''applique'),
  ('repas_pa_differe_plafond', 30, 'repas', 'Plafond de la réserve de PA différés (prochain Dormir)')
ON CONFLICT (cle) DO NOTHING;

-- ---------------------------------------------------------------------------------------------------------------
-- 1. Alcool (point 7)
-- ---------------------------------------------------------------------------------------------------------------
-- p_n = rang du verre alcoolisé dans la journée de Paris (compteur verres_du_jour déjà incrémenté).
CREATE OR REPLACE FUNCTION public.sante_alcool_verre_interne(p_nom text, p_n integer)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_g integer;
BEGIN
  IF p_nom IS NULL OR coalesce(p_n, 0) < 1 THEN RETURN NULL; END IF;
  v_g := CASE WHEN p_n = 1 THEN public.sante_param('alcool_verre_1', 1)
              WHEN p_n = 2 THEN public.sante_param('alcool_verre_2', 0)
              ELSE public.sante_param('alcool_verre_3_et_plus', -2) END::integer;
  IF v_g = 0 THEN RETURN jsonb_build_object('ok', true, 'source', 'alcool', 'verre', p_n, 'gain', 0); END IF;
  RETURN public.sante_gagner_interne(p_nom, v_g, 'alcool', jsonb_build_object('verre', p_n)); /* sante_conso_v1 */
END $function$;

SELECT pg_temp.rp_remplacer('public.maladie_verre_interne(text)'::regprocedure,
  'RETURNING n INTO v_n;',
  'RETURNING n INTO v_n;
  PERFORM public.sante_alcool_verre_interne(p_nom, v_n); /* sante_conso_alcool */', 1, 'sante_conso_alcool');

SELECT pg_temp.rp_remplacer('public.tournee_cloturer_boire(text)'::regprocedure,
  'SET hp=least(100,coalesce(hp,100)+5),',
  'SET /* sante_conso_tournee : plus de +5 Santé */', 1, 'sante_conso_tournee');

-- ---------------------------------------------------------------------------------------------------------------
-- 2. Repas (point 9)
-- ---------------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.sante_repas_categories (
  cle text PRIMARY KEY,
  categorie text NOT NULL CHECK (categorie IN ('menu','plat','sandwich','petitdej','snack','boisson','joueur_p5','joueur_p10','aucun')),
  libelle text NOT NULL DEFAULT ''
);
ALTER TABLE public.sante_repas_categories ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.sante_repas_categories FROM PUBLIC, anon, authenticated;

INSERT INTO public.sante_repas_categories (cle, categorie, libelle) VALUES
  -- Menus gastronomiques
  ('menu_gastronomique_1','menu','Menu 1 (Le Republica)'), ('menu_gastronomique_2','menu','Menu 2 (Le Republica)'),
  ('menu_gastronomique_3','menu','Menu 3 (Le Republica)'), ('menu_psm_1','menu','Menu 1 (PSM)'), ('menu_psm_2','menu','Menu 2 (PSM)'),
  ('menu_psm_3','menu','Menu 3 (PSM)'), ('menu_sovarka_imperial','menu','Menu Impérial'), ('menu_sovarka_plan','menu','Menu du Plan'),
  ('menu_sovarka_tsars','menu','Menu des Tsars'), ('starovka_menu_eleveur','menu','Menu de l''Éleveur'),
  ('starovka_menu_pecheur','menu','Menu du Pêcheur des Glaces'), ('starovka_menu_terre_mer','menu','Menu Terre et Mer'),
  ('volga_menu_proletaire','menu','Menu du Prolétaire'), ('volga_menu_repos','menu','Menu du Jour de Repos'),
  ('volga_menu_stakhanoviste','menu','Menu du Stakhanoviste'), ('voyageurs_menu_cheminot','menu','Menu du Cheminot'),
  ('voyageurs_menu_voyageur','menu','Menu du Voyageur'),
  -- Plats du jour
  ('boeuf_bourguignon','plat','Bœuf bourguignon'), ('carbonade_frites','plat','Carbonade-frites'), ('plat_de_poisson','plat','Plat de poisson'),
  ('saucisse_puree','plat','Saucisse-purée'), ('sever_solianka','plat','Solianka'),
  ('carbonade_frites_marche','plat','Barquette de carbonade-frites (marché)'), ('goulash_krasnov','plat','Portion de goulash (recette)'),
  ('krasnov_goulash','plat','Goulash du marché de Krasnov (plat chaud, servi en portion)'),
  -- Sandwichs, tartine de salo et casse-croûte
  ('sandwich','sandwich','Sandwich'), ('sandwich_cheminots','sandwich','Sandwich jambon-beurre-cornichon'),
  ('sever_tartine_salo','sandwich','Tartine de salo et cornichons'), ('casse_croute_cheminot','sandwich','Casse-croûte du Cheminot (marché)'),
  ('croque_monsieur_luthecia','sandwich','Croque-Monsieur du Marché'), ('cornet_friture_psm','sandwich','Cornet de friture de poissons (casse-croûte de rue)'),
  ('krasnov_pain_noir','sandwich','Pain noir du marché de Krasnov (un repas de pain, comme une tartine)'),
  -- Petits-déjeuners
  ('petit_dejeuner','petitdej','Petit-déjeuner'), ('sever_petit_dejeuner','petitdej','Petit-déjeuner du kolkhozien'),
  ('voyageurs_petit_dejeuner','petitdej','Petit-déjeuner du voyageur'),
  -- Snacks
  ('amuse_bouche_luthecia','snack','Amuse-bouche'), ('grand_hotel_zakouski','snack','Zakouski'), ('pirojki_sovarka','snack','Pirojki'),
  ('snack_buvette','snack','Cacahuètes salées'), ('chocolat_generique','snack','Chocolat'), ('chocolat_chaud_generique','snack','Chocolat chaud (encas)'),
  ('fruits_legumes','snack','Fruits et légumes crus (marché de Krasnov)'), ('krasnov_fruits_legumes','snack','Fruits et légumes crus (marché de Krasnov)'),
  -- Boissons : 0
  ('biere_pression','boisson','Bière'), ('boisson_sans_alcool','boisson','Boisson sans alcool'), ('cafe_boisson','boisson','Café'),
  ('champagne_luthecia','boisson','Champagne'), ('chocolat_chaud_sovarka','boisson','Chocolat chaud'), ('cocktail_luthecia','boisson','Cocktail'),
  ('grand_hotel_champagne_sovietique','boisson','Champagne soviétique'), ('grand_hotel_vodka_imperiale','boisson','Vodka impériale'),
  ('jus_de_fruits','boisson','Jus de fruits'), ('samogon_distillerie','boisson','Samogon'), ('sever_the_samovar','boisson','Thé au samovar'),
  ('sever_vodka','boisson','Verre de vodka'), ('slivovitz_distillerie','boisson','Slivovitz'), ('the_chaud_sovarka','boisson','Thé chaud'),
  ('vin','boisson','Vin'), ('vin_chaud_sovarka','boisson','Vin chaud'), ('vodka_distillerie','boisson','Vodka'),
  ('voyageurs_tarassoun','boisson','Tarassoun'), ('voyageurs_the_beurre','boisson','Thé au beurre bouriate'), ('voyageurs_vodka','boisson','Verre de vodka')
ON CONFLICT (cle) DO NOTHING;

-- Catégorie d'une recette, d'un type ou d'une pile d'objet : table, puis recettes_commerce (catégorie, boisson, générique).
CREATE OR REPLACE FUNCTION public.sante_repas_categorie_interne(p_cle text)
 RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT coalesce(
    (SELECT categorie FROM public.sante_repas_categories WHERE cle = p_cle),
    (SELECT CASE WHEN r.boisson IS NOT NULL THEN 'boisson'
                 WHEN r.categorie = 'menu' THEN 'menu' WHEN r.categorie = 'plat' THEN 'plat'
                 WHEN r.categorie = 'petit_dej' THEN 'petitdej' WHEN r.categorie IN ('snack', 'encas') THEN 'snack'
                 WHEN r.categorie = 'boisson' THEN 'boisson'
                 WHEN r.generique_id = 'menu-gastronomique' THEN 'menu'
                 WHEN r.generique_id IN ('plat-simple', 'plat-elabore', 'aliment-prepare') THEN 'plat'
                 WHEN r.generique_id IN ('encas', 'encas-a-emporter') THEN 'snack'
                 WHEN r.generique_id IN ('boisson', 'alcool-de-distillerie') THEN 'boisson' END
       FROM public.recettes_commerce r WHERE r.id = p_cle)) /* sante_conso_v1 */
$function$;

-- Produit créé par un joueur : palier selon le prix de vente.
CREATE OR REPLACE FUNCTION public.sante_repas_joueur_categorie_interne(p_prix numeric)
 RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT CASE WHEN coalesce(p_prix, 0) >= public.sante_param('repas_joueur_p10_prix_min', 10) THEN 'joueur_p10'
              WHEN coalesce(p_prix, 0) >= public.sante_param('repas_joueur_p5_prix_min', 5) THEN 'joueur_p5'
              ELSE 'aucun' END /* sante_conso_v1 */
$function$;

-- Référence d'un commerce de joueur (nom, prixVente, recette_id, generique_id) : boisson ou palier de prix.
CREATE OR REPLACE FUNCTION public.sante_repas_reference_categorie_interne(p_ref jsonb)
 RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT CASE WHEN p_ref IS NULL THEN NULL
              WHEN coalesce(p_ref->>'generique_id', '') IN ('boisson', 'alcool-de-distillerie')
                OR public.sante_repas_categorie_interne(p_ref->>'recette_id') = 'boisson' THEN 'boisson'
              ELSE public.sante_repas_joueur_categorie_interne(
                     CASE WHEN p_ref->>'prixVente' ~ '^[0-9]+(\.[0-9]+)?$' THEN (p_ref->>'prixVente')::numeric END) END /* sante_conso_v1 */
$function$;

-- Objet d'inventaire mangé : produit de joueur (provenance d'un commerce de joueur) ou recette, type, pile connus.
CREATE OR REPLACE FUNCTION public.sante_repas_objet_categorie_interne(p_item jsonb)
 RETURNS text LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_ref jsonb;
BEGIN
  IF coalesce(p_item #>> '{provenance,referenceId}', '') <> '' AND coalesce(p_item #>> '{provenance,fondsId}', '') <> '' THEN
    SELECT CASE WHEN jsonb_typeof(data->'references'->(p_item #>> '{provenance,referenceId}')) = 'object'
                THEN data->'references'->(p_item #>> '{provenance,referenceId}') END
      INTO v_ref FROM public.entreprises WHERE id = p_item #>> '{provenance,fondsId}';
    IF v_ref IS NOT NULL THEN
      RETURN public.sante_repas_reference_categorie_interne(
        v_ref || jsonb_build_object('generique_id', coalesce(v_ref->>'generique_id', p_item->>'generique_id')));
    END IF;
  END IF;
  RETURN coalesce(public.sante_repas_categorie_interne(nullif(p_item->>'recette_id', '')),
                  public.sante_repas_categorie_interne(nullif(p_item->>'type', '')),
                  public.sante_repas_categorie_interne(nullif(p_item->>'stackKey', '')), 'aucun'); /* sante_conso_v1 */
END $function$;

-- Catégorie du p_rang-ième plat (0 = premier) d'une liste d'articles [{produit, qte}], boissons exclues ; p_defaut sinon.
CREATE OR REPLACE FUNCTION public.sante_repas_plat_servi_interne(p_articles jsonb, p_rang integer, p_defaut text)
 RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT coalesce((
    SELECT public.sante_repas_categorie_interne(a.e->>'produit')
      FROM jsonb_array_elements(CASE WHEN jsonb_typeof(p_articles) = 'array' THEN p_articles ELSE '[]'::jsonb END) WITH ORDINALITY a(e, o)
      CROSS JOIN LATERAL generate_series(1, greatest(1, coalesce(CASE WHEN a.e->>'qte' ~ '^[0-9]+$' THEN (a.e->>'qte')::integer END, 1))) s(k)
     WHERE public.sante_repas_categorie_interne(a.e->>'produit') IS DISTINCT FROM 'boisson'
     ORDER BY a.o, s.k OFFSET greatest(0, coalesce(p_rang, 0)) LIMIT 1), p_defaut) /* sante_conso_v1 */
$function$;

-- Effet d'un repas : Santé (modulée par le Moral) et PA différés au prochain Dormir. Moral : jamais touché ici.
CREATE OR REPLACE FUNCTION public.sante_repas_appliquer_interne(p_nom text, p_categorie text, p_source text, p_details jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_s integer; v_pa integer; v_r jsonb; v_b integer;
BEGIN
  IF p_nom IS NULL THEN RETURN NULL; END IF;
  IF p_categorie IS NULL OR p_categorie IN ('boisson', 'aucun') THEN
    RETURN jsonb_build_object('ok', true, 'source', p_source, 'categorie', p_categorie, 'gain', 0, 'pa_differe', 0)
      || (SELECT jsonb_build_object('apres', hp, 'avant', hp, 'bonus_pa_differe', coalesce(bonus_pa_differe, 0))
            FROM public.personnages_donnees WHERE name = p_nom);
  END IF;
  v_s := public.sante_param('repas_' || p_categorie || '_sante', 0)::integer;
  v_pa := public.sante_param('repas_' || p_categorie || '_pa', 0)::integer;
  v_r := public.sante_gagner_interne(p_nom, v_s, p_source, coalesce(p_details, '{}'::jsonb) || jsonb_build_object('categorie', p_categorie));
  IF v_pa > 0 THEN
    UPDATE public.personnages_donnees
       SET bonus_pa_differe = least(public.sante_param('repas_pa_differe_plafond', 30)::integer, coalesce(bonus_pa_differe, 0) + v_pa)
     WHERE name = p_nom RETURNING bonus_pa_differe INTO v_b;
  ELSE
    SELECT coalesce(bonus_pa_differe, 0) INTO v_b FROM public.personnages_donnees WHERE name = p_nom;
  END IF;
  RETURN coalesce(v_r, '{}'::jsonb) || jsonb_build_object('categorie', p_categorie, 'pa_differe', v_pa, 'bonus_pa_differe', v_b); /* sante_conso_v1 */
END $function$;

-- Une ligne servie au comptoir d'un commerce PNJ (consommée sur-le-champ) : repas, Moral de la recette, verre compté.
CREATE OR REPLACE FUNCTION public.sante_comptoir_ligne_interne(p_nom text, p_produit text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_r jsonb; v_moral integer;
BEGIN
  v_r := public.sante_repas_appliquer_interne(p_nom, public.sante_repas_categorie_interne(p_produit), 'comptoir', jsonb_build_object('produit', p_produit));
  SELECT greatest(0, coalesce(CASE WHEN effets->>'moral' ~ '^-?[0-9]+$' THEN (effets->>'moral')::integer END, 0))
    INTO v_moral FROM public.recettes_commerce WHERE id = p_produit;
  IF coalesce(v_moral, 0) > 0 THEN
    UPDATE public.personnages_donnees SET moral = least(100, coalesce(moral, 0) + v_moral) WHERE name = p_nom;
  END IF;
  IF public.boisson_alcoolisee_interne(p_produit) THEN PERFORM public.maladie_verre_interne(p_nom); END IF;
  PERFORM public.boisson_bue_recette_interne(p_nom, p_produit);
  PERFORM set_config('hg.sante_comptoir_pa', (coalesce(nullif(current_setting('hg.sante_comptoir_pa', true), ''), '0')::integer
    + coalesce((v_r->>'pa_differe')::integer, 0))::text, true); -- total de la vente, pour l'affichage
  RETURN jsonb_build_object('ok', coalesce((v_r->>'pa_differe')::integer, 0) > 0, 'bonus_differe', (v_r->>'bonus_pa_differe')::integer,
    'sante', v_r); /* sante_conso_v1 */
END $function$;

-- Fin de commerce_vendre_produit : repas gastronomique (vente « service ») et état du personnage servi au comptoir.
CREATE OR REPLACE FUNCTION public.sante_vente_conclure_interne(p_nom text, p_mode text, p_ordre text, p_produits jsonb, p_v jsonb)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v jsonb := p_v;
BEGIN
  IF coalesce((v->>'ok')::boolean, false) IS NOT TRUE THEN RETURN v; END IF;
  IF p_mode = 'service' AND p_ordre = 'repas_gastronomique' THEN
    v := v || jsonb_build_object('sante', public.sante_repas_appliquer_interne(p_nom,
      public.sante_repas_plat_servi_interne(p_produits, 0, 'menu'), 'repas_gastronomique',
      jsonb_build_object('produit', p_produits->0->>'produit')));
  END IF;
  IF p_mode IN ('comptoir', 'service') THEN
    v := v || coalesce((SELECT jsonb_build_object('hp', hp, 'moral', moral, 'bonus_pa_differe_total', coalesce(bonus_pa_differe, 0))
                          FROM public.personnages_donnees WHERE name = p_nom), '{}'::jsonb)
           || jsonb_build_object('pa_differe_servi', coalesce(nullif(current_setting('hg.sante_comptoir_pa', true), ''), '0')::integer);
    PERFORM set_config('hg.sante_comptoir_pa', '', true);
  END IF;
  RETURN v; /* sante_conso_v1 */
END $function$;

SELECT pg_temp.rp_remplacer('public.commerce_vendre_produit(text,text,jsonb,text,text,integer,integer,text)'::regprocedure,
  'IF coalesce((l->''effets''->>''paDiffere'')::numeric, 0) > 0 THEN',
  'IF NOT (coalesce(l->''effets'' ? ''matiere'', false) OR coalesce((l->''effets''->>''objetSimple'')::boolean, false)) THEN /* sante_conso_cvp_a */',
  1, 'sante_conso_cvp_a');
SELECT pg_temp.rp_remplacer('public.commerce_vendre_produit(text,text,jsonb,text,text,integer,integer,text)'::regprocedure,
  'c := public.pa_bonus_differe_crediter(p_acteur, l->>''produit'');',
  'c := public.sante_comptoir_ligne_interne(p_acteur, l->>''produit''); /* sante_conso_cvp_b */', 1, 'sante_conso_cvp_b');
SELECT pg_temp.rp_remplacer('public.commerce_vendre_produit(text,text,jsonb,text,text,integer,integer,text)'::regprocedure,
  'RETURN v;',
  'v := public.sante_vente_conclure_interne(p_acteur, p_mode, p_ordre, p_produits, v); /* sante_conso_cvp_c */
  RETURN v;', 1, 'sante_conso_cvp_c');

-- Consommation sur place d'un commerce de joueur : produit de joueur, palier de prix.
SELECT pg_temp.rp_remplacer('public.consommer_sur_place_commerce(text,text,text,text)'::regprocedure,
  'v_hp:=greatest(0,least(100,coalesce((v_effets->>''hp'')::integer,0)));',
  'v_hp:=0; /* sante_conso_sp_a */', 1, 'sante_conso_sp_a');
SELECT pg_temp.rp_remplacer('public.consommer_sur_place_commerce(text,text,text,text)'::regprocedure,
  'IF NOT FOUND THEN RAISE EXCEPTION ''Personnage introuvable: annulation transaction''; END IF;',
  'IF NOT FOUND THEN RAISE EXCEPTION ''Personnage introuvable: annulation transaction''; END IF;
 v_effets:=public.sante_repas_appliquer_interne(v_nom, public.sante_repas_reference_categorie_interne(v_ref), ''sur_place'', jsonb_build_object(''reference'', p_reference_id));
 v_hp:=coalesce((v_effets->>''gain'')::integer,0); /* sante_conso_sp_b */', 1, 'sante_conso_sp_b');
SELECT pg_temp.rp_remplacer('public.consommer_sur_place_commerce(text,text,text,text)'::regprocedure,
  '''effets'',jsonb_build_object(''hp'',v_hp,''moral'',v_moral));',
  '''effets'',jsonb_build_object(''hp'',v_hp,''moral'',v_moral),''sante'',v_effets,''hp'',(v_effets->>''apres'')::integer); /* sante_conso_sp_c */',
  1, 'sante_conso_sp_c');

-- Aliment mangé depuis l'inventaire : le barème remplace le +1 PA immédiat.
SELECT pg_temp.rp_remplacer('public.inventaire_consommer(text,integer,jsonb)'::regprocedure,
  'v_delta:=1;', 'v_delta:=0; /* sante_conso_inv_a */', 1, 'sante_conso_inv_a');
SELECT pg_temp.rp_remplacer('public.inventaire_consommer(text,integer,jsonb)'::regprocedure,
  'v_r:=v_r||jsonb_build_object(''pa'',v_pa,''aliment_frais'',true,',
  'v_r:=v_r||jsonb_build_object(''sante'',public.sante_repas_appliquer_interne(p_acteur,public.sante_repas_objet_categorie_interne(v_item),''inventaire'',jsonb_build_object(''objet'',v_item->>''name''))) /* sante_conso_inv_b */
     ||jsonb_build_object(''pa'',v_pa,''aliment_frais'',true,', 1, 'sante_conso_inv_b');

-- Dîner d'affaires, contrat Le Republica : plat servi à chacun (menu à défaut).
SELECT pg_temp.rp_remplacer('public.restaurant_diner_servir(bigint)'::regprocedure,
  'IF bonus IS DISTINCT FROM 3 THEN RAISE EXCEPTION ''bonus_diner_incompatible''; END IF;',
  'NULL; /* sante_conso_rd_a */', 1, 'sante_conso_rd_a');
SELECT pg_temp.rp_remplacer('public.restaurant_diner_servir(bigint)'::regprocedure,
  'SET hp=least(100,coalesce(hp,100)+10),moral=', 'SET /* sante_conso_rd_b */ moral=', 1, 'sante_conso_rd_b');
SELECT pg_temp.rp_remplacer('public.restaurant_diner_servir(bigint)'::regprocedure,
  'bonus_pa_differe=least(30,coalesce(bonus_pa_differe,0)+bonus),updated_at=now()',
  'updated_at=now() /* sante_conso_rd_c */', 1, 'sante_conso_rd_c');
SELECT pg_temp.rp_remplacer('public.restaurant_diner_servir(bigint)'::regprocedure,
  'WHERE name=moi OR (NOT i.invite_pnj AND name=i.invite);',
  'WHERE name=moi OR (NOT i.invite_pnj AND name=i.invite);
    PERFORM public.sante_repas_appliquer_interne(moi, public.sante_repas_plat_servi_interne(articles, 0, ''menu''), ''diner_affaires'', ''{}''::jsonb);
    IF NOT i.invite_pnj THEN PERFORM public.sante_repas_appliquer_interne(i.invite, public.sante_repas_plat_servi_interne(articles, 1, ''menu''), ''diner_affaires'', ''{}''::jsonb); END IF; /* sante_conso_rd_d */',
  1, 'sante_conso_rd_d');

-- Dîner d'affaires, contrat des commerces (commerce_v1).
SELECT pg_temp.rp_remplacer('public.diner_commerce_servir_interne(text,bigint)'::regprocedure,
  'IF bonus IS DISTINCT FROM 3 THEN RAISE EXCEPTION ''bonus_diner_incompatible''; END IF;',
  'NULL; /* sante_conso_dc_a */', 1, 'sante_conso_dc_a');
SELECT pg_temp.rp_remplacer('public.diner_commerce_servir_interne(text,bigint)'::regprocedure,
  'SET hp=least(100,coalesce(hp,100)+10),moral=', 'SET /* sante_conso_dc_b */ moral=', 1, 'sante_conso_dc_b');
SELECT pg_temp.rp_remplacer('public.diner_commerce_servir_interne(text,bigint)'::regprocedure,
  'bonus_pa_differe=least(30,coalesce(bonus_pa_differe,0)+bonus),updated_at=now()',
  'updated_at=now() /* sante_conso_dc_c */', 1, 'sante_conso_dc_c');
SELECT pg_temp.rp_remplacer('public.diner_commerce_servir_interne(text,bigint)'::regprocedure,
  'WHERE name=moi OR (NOT i.invite_pnj AND name=i.invite);',
  'WHERE name=moi OR (NOT i.invite_pnj AND name=i.invite);
    PERFORM public.sante_repas_appliquer_interne(moi, public.sante_repas_plat_servi_interne(articles, 0, ''menu''), ''diner_affaires'', ''{}''::jsonb);
    IF NOT i.invite_pnj THEN PERFORM public.sante_repas_appliquer_interne(i.invite, public.sante_repas_plat_servi_interne(articles, 1, ''menu''), ''diner_affaires'', ''{}''::jsonb); END IF; /* sante_conso_dc_d */',
  1, 'sante_conso_dc_d');

-- Service d'étage du Grand Hôtel (Sovarka) : le plat commandé (plat du jour si la carte ne le classe pas).
SELECT pg_temp.rp_remplacer('public.service_etage_commander(uuid,text)'::regprocedure,
  'hp = least(100, coalesce(hp, 0) + greatest(0, coalesce((v_eff->>''hp'')::integer, 0))),',
  '/* sante_conso_se_a */', 1, 'sante_conso_se_a');
SELECT pg_temp.rp_remplacer('public.service_etage_commander(uuid,text)'::regprocedure,
  'IF coalesce((v_eff->>''paDiffere'')::integer, 0) > 0 THEN PERFORM public.pa_bonus_differe_crediter(moi, p_produit); END IF;',
  'v_ancien := public.sante_repas_appliquer_interne(moi, coalesce(public.sante_repas_categorie_interne(p_produit), ''plat''), ''service_etage'', jsonb_build_object(''produit'', p_produit)); /* sante_conso_se_b */',
  1, 'sante_conso_se_b');
SELECT pg_temp.rp_remplacer('public.service_etage_commander(uuid,text)'::regprocedure,
  '''effets'', v_eff, ''hp'', hp,', '''effets'', v_eff, ''sante'', v_ancien, ''hp'', hp, /* sante_conso_se_c */', 1, 'sante_conso_se_c');

-- Service d'étage des hôtels de Républia : aucun plat identifié, plat du jour.
SELECT pg_temp.rp_remplacer('public.hotel_service_etage_commander()'::regprocedure,
  'SET hp = LEAST(100, coalesce(hp, 0) + 10), moral =', 'SET /* sante_conso_hse_a */ moral =', 1, 'sante_conso_hse_a');
SELECT pg_temp.rp_remplacer('public.hotel_service_etage_commander()'::regprocedure,
  'v_bonus := public.pa_bonus_differe_crediter(moi, ''service_etage_hotel'');',
  'v_bonus := public.sante_repas_appliquer_interne(moi, ''plat'', ''service_etage'', ''{}''::jsonb); /* sante_conso_hse_b */',
  1, 'sante_conso_hse_b');
SELECT pg_temp.rp_remplacer('public.hotel_service_etage_commander()'::regprocedure,
  '''bonus_pa'', coalesce((v_bonus->>''montant'')::integer, 0));',
  '''bonus_pa'', coalesce((v_bonus->>''pa_differe'')::integer, 0), ''sante'', v_bonus); /* sante_conso_hse_c */',
  1, 'sante_conso_hse_c');

-- Marché de Krasnov : la place du « repas brut » de la nuit est gardée (pain noir, fruits et légumes), sans PA propre.
CREATE OR REPLACE FUNCTION public.sante_repas_brut_marquer_interne(p_nom text)
 RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_nuit text; v_b integer;
BEGIN
  SELECT coalesce(pa_repos_le::text, 'jamais'), coalesce(bonus_pa_differe, 0) INTO v_nuit, v_b
    FROM public.personnages_donnees WHERE name = p_nom FOR UPDATE;
  INSERT INTO public.repas_differes_nuits (nom, cle, nuit) VALUES (p_nom, 'repas_brut', v_nuit)
  ON CONFLICT (nom, cle) DO UPDATE SET nuit = excluded.nuit, pris_le = now();
  RETURN v_b; /* sante_conso_v1 */
END $function$;

SELECT pg_temp.rp_remplacer('public.marche_krasnov_manger(uuid,text)'::regprocedure,
  'greatest(0, coalesce(pa, 0) + 2))', 'greatest(0, coalesce(pa, 0) + 0)) /* sante_conso_mk_a */', 1, 'sante_conso_mk_a');
SELECT pg_temp.rp_remplacer('public.marche_krasnov_manger(uuid,text)'::regprocedure,
  'v_b := public.repas_differe_crediter_interne(a, ''repas_brut'', ''repas_brut'');',
  'v_b := public.sante_repas_brut_marquer_interne(a); /* sante_conso_mk_b */', 1, 'sante_conso_mk_b');
SELECT pg_temp.rp_remplacer('public.marche_krasnov_manger(uuid,text)'::regprocedure,
  'IF v_avarie THEN',
  'v_pile := public.sante_repas_appliquer_interne(a, public.sante_repas_categorie_interne(''krasnov_'' || p_cle), ''marche_krasnov'', jsonb_build_object(''cle'', p_cle)); /* sante_conso_mk_c */
  IF v_avarie THEN', 1, 'sante_conso_mk_c');
SELECT pg_temp.rp_remplacer('public.marche_krasnov_manger(uuid,text)'::regprocedure,
  '''gain_pa'', CASE WHEN p_cle = ''goulash'' THEN 2 END,',
  '''gain_pa'', NULL, ''sante'', v_pile, ''gain_sante'', (v_pile->>''gain'')::integer, ''pa_differe'', (v_pile->>''pa_differe'')::integer, /* sante_conso_mk_d */',
  1, 'sante_conso_mk_d');
SELECT pg_temp.rp_remplacer('public.marche_krasnov_manger(uuid,text)'::regprocedure,
  '''bonus_differe'', CASE WHEN p_cle <> ''goulash'' THEN 1 END, ''bonus_pa_differe'', v_b,',
  '''bonus_differe'', (v_pile->>''pa_differe'')::integer, ''bonus_pa_differe'', coalesce((v_pile->>''bonus_pa_differe'')::integer, v_b), /* sante_conso_mk_e */',
  1, 'sante_conso_mk_e');
UPDATE public.marche_krasnov_produits SET effet = CASE cle
    WHEN 'fruits_legumes' THEN 'Se mangent crus : un en-cas (Santé, selon le barème des repas ; un seul repas brut par nuit).'
    WHEN 'pain_noir' THEN 'Un repas de pain : Santé et PA au prochain Dormir, comme une tartine (pas en plus d''un repas brut).'
    WHEN 'goulash' THEN 'Un plat chaud : Santé et PA au prochain Dormir, comme un plat du jour.' END
 WHERE cle IN ('fruits_legumes', 'pain_noir', 'goulash') AND effet NOT LIKE '%Santé%';

-- « Se nourrir » (marché central de Luthécia) : ordre serveur, payé au tarif du miroir, effet d'un sandwich.
CREATE OR REPLACE FUNCTION public.sante_se_nourrir(p_pa integer DEFAULT 0, p_cost integer DEFAULT 0)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE moi text := public.mon_personnage(); d record; v_pay jsonb; v_s jsonb;
BEGIN
  IF moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country, current_building INTO d FROM public.personnages_donnees WHERE name = moi FOR UPDATE;
  IF coalesce(d.current_building, '') <> 'marche' THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;
  v_pay := public.payer_ordre_interne(moi, 'se_nourrir', coalesce(p_pa, 0), coalesce(p_cost, 0));
  IF coalesce((v_pay->>'ok')::boolean, false) IS NOT TRUE THEN RETURN v_pay; END IF;
  v_s := public.sante_repas_appliquer_interne(moi, 'sandwich', 'se_nourrir', '{}'::jsonb);
  -- Moral inchangé : celui de la recette du sandwich, comme au comptoir.
  UPDATE public.personnages_donnees SET moral = least(100, coalesce(moral, 0) + greatest(0, coalesce(
      (SELECT CASE WHEN effets->>'moral' ~ '^[0-9]+$' THEN (effets->>'moral')::integer END FROM public.recettes_commerce WHERE id = 'sandwich'), 0)))
   WHERE name = moi;
  RETURN jsonb_build_object('ok', true, 'sante', v_s, 'paiement', v_pay)
    || (SELECT jsonb_build_object('hp', hp, 'moral', moral, 'pa', pa, 'liquide', liquide, 'arg', arg, 'bonus_pa_differe', bonus_pa_differe)
          FROM public.personnages_donnees WHERE name = moi); /* sante_conso_v1 */
END $function$;

-- ---------------------------------------------------------------------------------------------------------------
-- 3. Sommeil (point 8)
-- ---------------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.sante_sommeil_lieux (
  cle text PRIMARY KEY,
  priorite integer NOT NULL DEFAULT 100,
  categorie text NOT NULL CHECK (categorie IN ('chambre','batiment','dehors','hopital','clinique')),
  pays text,
  ville text,
  batiment text NOT NULL,
  piece text NOT NULL DEFAULT '.*',
  libelle text NOT NULL DEFAULT ''
);
ALTER TABLE public.sante_sommeil_lieux ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.sante_sommeil_lieux FROM PUBLIC, anon, authenticated;

INSERT INTO public.sante_sommeil_lieux (cle, priorite, categorie, pays, ville, batiment, piece, libelle) VALUES
  ('clinique_chambres', 10, 'clinique', NULL, NULL, '^clinique-privee$', '^chambre_([1-9]|10)$', 'Chambres de la clinique privée'),
  ('hopital_public', 20, 'hopital', NULL, NULL, '^dispensaire-public', '.*', 'Hôpitaux publics et dispensaires (toutes pièces)'),
  ('hotel_republica', 30, 'chambre', NULL, NULL, '^hotel-republica$', '^(chambres|suite_privee|suite_presidentielle)$', 'Chambres et suites de l''hôtel Republica / Grand Hôtel'),
  ('hotel_port', 30, 'chambre', NULL, NULL, '^hotel-port$', '^chambre_port$', 'Chambre de l''Hôtel du Port'),
  ('hotel_mineur', 30, 'chambre', NULL, NULL, '^hotel-mineur$', '^chambre_mineur(_[0-9]+)?$', 'Chambres de l''Hôtel des Mineurs'),
  ('maison_habitant', 30, 'chambre', 'soviet', NULL, '^maison-', '^piece_maison$', 'Chambre chez l''habitant (Sovarka)'),
  ('residence_imperiale', 30, 'chambre', NULL, NULL, '^residence-imperiale-novomirsk$', '^(appartement_[0-9]+|grand_appartement)$', 'Appartements de la Résidence impériale'),
  ('pavillon_suites', 30, 'chambre', NULL, NULL, '^pavillon-ambassadeurs-novomirsk$', '^suite_', 'Suites du Pavillon des ambassadeurs'),
  ('palais_appartements', 30, 'chambre', NULL, NULL, '^palais-presidentiel$', '^appartements_president$', 'Appartements du président'),
  ('foret_krasnov', 40, 'dehors', 'soviet', 'ville_b', '^zone-production$', '^(zone_recolte|foret_clairiere|foret_vue_[1-4])$', 'Forêt et camp de bûcherons de Krasnov'),
  ('recolte_starovka', 40, 'dehors', 'soviet', 'ville_a', '^zone-production$', '^zone_recolte$', 'Zone de récolte de Starovka'),
  ('champ_petrole', 40, 'dehors', NULL, NULL, '^champ-petrole-starovka$', '^zone_recolte$', 'Champ de pétrole'),
  ('cour_ferme', 40, 'dehors', NULL, NULL, '^ferme-', '^cour_ferme$', 'Cour des fermes et kolkhozes'),
  ('terrains', 40, 'dehors', NULL, NULL, '^terrain-a-batir', '^terrain', 'Terrains à bâtir et chantiers'),
  ('stade_pelouse', 40, 'dehors', NULL, NULL, '^stade$', '^terrain$', 'Pelouse du stade'),
  ('parc_botanique', 40, 'dehors', NULL, NULL, '^parc-botanique-national$', '.*', 'Parc botanique'),
  ('quais', 40, 'dehors', NULL, NULL, '^port-', '^quai_', 'Quais des ports')
ON CONFLICT (cle) DO NOTHING;

CREATE TABLE IF NOT EXISTS public.sante_sommeils (
  nom text NOT NULL,
  jour date NOT NULL,
  lieu text NOT NULL,
  resultat jsonb,
  cree_le timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (nom, jour)
);
ALTER TABLE public.sante_sommeils ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.sante_sommeils FROM PUBLIC, anon, authenticated;

-- Lieu du sommeil d'après la position en base (voir l'en-tête pour l'ordre des règles).
CREATE OR REPLACE FUNCTION public.sante_sommeil_lieu_interne(p_nom text)
 RETURNS text LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE d record; v text;
BEGIN
  SELECT country, current_city, current_building, current_room INTO d FROM public.personnages_donnees WHERE name = p_nom;
  IF NOT FOUND THEN RETURN NULL; END IF;
  IF coalesce(d.current_building, '') = '' THEN RETURN 'dehors'; END IF;
  IF to_regprocedure('public.logement_sommeil_interne(text)') IS NOT NULL AND public.logement_sommeil_interne(p_nom) IS NOT NULL THEN
    RETURN 'chambre';
  END IF;
  SELECT l.categorie INTO v FROM public.sante_sommeil_lieux l
   WHERE (l.pays IS NULL OR l.pays = d.country) AND (l.ville IS NULL OR l.ville = d.current_city)
     AND d.current_building ~ l.batiment AND coalesce(d.current_room, '') ~ l.piece
   ORDER BY l.priorite, l.cle LIMIT 1;
  RETURN coalesce(v, 'batiment'); /* sante_conso_v1 */
END $function$;

-- Crédit unique du sommeil de la journée de Paris (nuitée de clinique et Dormir partagent ce crédit).
CREATE OR REPLACE FUNCTION public.sante_sommeil_crediter_interne(p_nom text, p_lieu text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_jour date := (now() AT TIME ZONE 'Europe/Paris')::date; n integer; r jsonb;
BEGIN
  IF p_nom IS NULL OR p_lieu IS NULL THEN RETURN NULL; END IF;
  INSERT INTO public.sante_sommeils (nom, jour, lieu) VALUES (p_nom, v_jour, p_lieu) ON CONFLICT (nom, jour) DO NOTHING;
  GET DIAGNOSTICS n = ROW_COUNT;
  IF n = 0 THEN
    RETURN coalesce((SELECT resultat || jsonb_build_object('lieu', lieu) FROM public.sante_sommeils WHERE nom = p_nom AND jour = v_jour), '{}'::jsonb)
      || jsonb_build_object('deja_credite', true);
  END IF;
  r := public.sante_gagner_interne(p_nom, public.sante_param('sommeil_' || p_lieu, 0)::integer, 'sommeil', jsonb_build_object('lieu', p_lieu));
  UPDATE public.sante_sommeils SET resultat = r WHERE nom = p_nom AND jour = v_jour;
  RETURN r || jsonb_build_object('lieu', p_lieu); /* sante_conso_v1 */
END $function$;

-- Appelé par pa_repos_nocturne juste avant son RETURN de réussite.
CREATE OR REPLACE FUNCTION public.sante_sommeil_interne(p_nom text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_r jsonb; v_ev jsonb;
BEGIN
  v_r := public.sante_sommeil_crediter_interne(p_nom, public.sante_sommeil_lieu_interne(p_nom));
  v_ev := public.sante_reveil_interne(p_nom);
  RETURN jsonb_build_object('sante_sommeil', v_r,
    'evenements_reveil', CASE WHEN jsonb_typeof(v_ev) = 'array' THEN v_ev ELSE '[]'::jsonb END); /* sante_conso_v1 */
END $function$;

SELECT pg_temp.rp_remplacer('public.pa_repos_nocturne(text)'::regprocedure,
  'v_detenu jsonb; v_prison boolean := false;',
  'v_detenu jsonb; v_prison boolean := false; v_sante_nuit jsonb; /* sante_conso_nuit_a */', 1, 'sante_conso_nuit_a');
SELECT pg_temp.rp_remplacer('public.pa_repos_nocturne(text)'::regprocedure,
  'RETURN jsonb_build_object(''ok'', true, ''pa'', v_nouveau, ''bonus_consomme'', v_bonus,',
  'v_sante_nuit := public.sante_sommeil_interne(p_acteur); /* sante_conso_nuit_b */
    RETURN v_sante_nuit || jsonb_build_object(''ok'', true, ''pa'', v_nouveau, ''bonus_consomme'', v_bonus,', 2, 'sante_conso_nuit_b');

SELECT pg_temp.rp_remplacer('public.clinique_nuitee_marquer_repos()'::regprocedure,
  'hp=LEAST(100,GREATEST(0,COALESCE(hp,0)+10)),', '/* sante_conso_clin_t1 */', 1, 'sante_conso_clin_t1');
SELECT pg_temp.rp_remplacer('public.clinique_nuitee_marquer_repos()'::regprocedure,
  'WHERE name=NEW.name;',
  'WHERE name=NEW.name;
   PERFORM public.sante_sommeil_crediter_interne(NEW.name, ''clinique''); /* sante_conso_clin_t2 */', 1, 'sante_conso_clin_t2');

SELECT pg_temp.rp_remplacer('public.clinique_nuitee_consommer()'::regprocedure,
  'hp=LEAST(100,GREATEST(0,COALESCE(hp,0)+10)),', '/* sante_conso_clin_c1 */', 1, 'sante_conso_clin_c1');
SELECT pg_temp.rp_remplacer('public.clinique_nuitee_consommer()'::regprocedure,
  'UPDATE public.clinique_nuitees SET consommee_le=v_jour WHERE id=n.id;',
  'UPDATE public.clinique_nuitees SET consommee_le=v_jour WHERE id=n.id;
 PERFORM public.sante_sommeil_crediter_interne(v_nom, ''clinique'');
 SELECT hp INTO v_hp FROM public.personnages_donnees WHERE name=v_nom; /* sante_conso_clin_c2 */', 1, 'sante_conso_clin_c2');
SELECT pg_temp.rp_remplacer('public.clinique_nuitee_consommer()'::regprocedure,
  '''bonus_hp'',10',
  '''bonus_hp'',coalesce((SELECT (resultat->>''gain'')::integer FROM public.sante_sommeils WHERE nom=v_nom AND jour=(now() AT TIME ZONE ''Europe/Paris'')::date),0) /* sante_conso_clin_c3 */',
  1, 'sante_conso_clin_c3');

-- ---------------------------------------------------------------------------------------------------------------
-- 4. Soins (point 10)
-- ---------------------------------------------------------------------------------------------------------------
SELECT pg_temp.rp_remplacer('public.recevoir_soin(text,text,text,text,text,integer)'::regprocedure,
  'v_taxe jsonb; v_net numeric; v_gain_hp int; v_gain_pa int;',
  'v_taxe jsonb; v_net numeric; v_gain_hp int; v_gain_pa int; v_soin jsonb; /* sante_conso_soin_a */', 1, 'sante_conso_soin_a');
SELECT pg_temp.rp_remplacer('public.recevoir_soin(text,text,text,text,text,integer)'::regprocedure,
  'v_gain_hp := 10; v_gain_pa := 1;',
  'v_gain_hp := public.sante_param(''soin_public_sante'', 8)::int; v_gain_pa := public.sante_param(''soin_public_pa'', 1)::int; /* sante_conso_soin_b */',
  1, 'sante_conso_soin_b');
SELECT pg_temp.rp_remplacer('public.recevoir_soin(text,text,text,text,text,integer)'::regprocedure,
  'v_gain_hp := 30; v_gain_pa := 2;',
  'v_gain_hp := public.sante_param(''soin_clinique_sante'', 15)::int; v_gain_pa := public.sante_param(''soin_clinique_pa'', 2)::int; /* sante_conso_soin_c */',
  1, 'sante_conso_soin_c');
SELECT pg_temp.rp_remplacer('public.recevoir_soin(text,text,text,text,text,integer)'::regprocedure,
  'hp = least(100, v_hp + v_gain_hp), pa = least(30, v_pa + v_gain_pa),',
  'pa = least(30, v_pa + v_gain_pa), /* sante_conso_soin_d */', 1, 'sante_conso_soin_d');
SELECT pg_temp.rp_remplacer('public.recevoir_soin(text,text,text,text,text,integer)'::regprocedure,
  'IF v_pris_national > 0 AND v_compte_id IS NOT NULL THEN',
  'v_soin := public.sante_gagner_interne(p_acteur, v_gain_hp, ''soin_'' || p_type, ''{}''::jsonb); /* sante_conso_soin_e */
  IF v_pris_national > 0 AND v_compte_id IS NOT NULL THEN', 1, 'sante_conso_soin_e');
SELECT pg_temp.rp_remplacer('public.recevoir_soin(text,text,text,text,text,integer)'::regprocedure,
  '''ok'', true, ''hp'', least(100, v_hp + v_gain_hp),',
  '''ok'', true, ''hp'', (v_soin->>''apres'')::integer, ''sante'', v_soin, /* sante_conso_soin_f */', 1, 'sante_conso_soin_f');
SELECT pg_temp.rp_remplacer('public.recevoir_soin(text,text,text,text,text,integer)'::regprocedure,
  '''gain_hp'', v_gain_hp,', '''gain_hp'', (v_soin->>''gain'')::integer, /* sante_conso_soin_g */', 1, 'sante_conso_soin_g');

SELECT pg_temp.rp_remplacer('public.ordre_generique_executer(text,integer,integer)'::regprocedure,
  'e_hp := coalesce((o.effets ->> ''hp'')::numeric, 0);',
  'e_hp := CASE p_fn WHEN ''soins_urgence'' THEN public.sante_param(''soin_urgence_sante'', 25)
                     WHEN ''soins_discrets'' THEN public.sante_param(''soin_sans_trace_sante'', 15)
                     ELSE coalesce((o.effets ->> ''hp'')::numeric, 0) END; /* sante_conso_og_a */', 1, 'sante_conso_og_a');
SELECT pg_temp.rp_remplacer('public.ordre_generique_executer(text,integer,integer)'::regprocedure,
  'IF e_hp <> 0 THEN v_hp := least(100, greatest(0, v_hp + round(e_hp * v_mult)::integer)); END IF;',
  '/* sante_conso_og_b : Santé appliquée après l''écriture, par sante_gagner_interne */', 1, 'sante_conso_og_b');
SELECT pg_temp.rp_remplacer('public.ordre_generique_executer(text,integer,integer)'::regprocedure,
  'IF v_res IN (''partial'', ''success'', ''crit'') AND EXISTS',
  'IF p_fn IN (''soins_urgence'', ''soins_discrets'') THEN v_mult := least(v_mult, 1); END IF; -- soin au barème : pas de majoration critique
  IF e_hp <> 0 AND round(e_hp * v_mult) <> 0 THEN
    v_hp := (public.sante_gagner_interne(v_moi, round(e_hp * v_mult)::integer, ''ordre_'' || p_fn, ''{}''::jsonb) ->> ''apres'')::integer;
  END IF; /* sante_conso_og_c */
  IF v_res IN (''partial'', ''success'', ''crit'') AND EXISTS', 1, 'sante_conso_og_c');

-- ---------------------------------------------------------------------------------------------------------------
-- 5. Droits
-- ---------------------------------------------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.sante_alcool_verre_interne(text, integer) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.sante_repas_categorie_interne(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.sante_repas_joueur_categorie_interne(numeric) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.sante_repas_reference_categorie_interne(jsonb) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.sante_repas_objet_categorie_interne(jsonb) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.sante_repas_plat_servi_interne(jsonb, integer, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.sante_repas_appliquer_interne(text, text, text, jsonb) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.sante_comptoir_ligne_interne(text, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.sante_vente_conclure_interne(text, text, text, jsonb, jsonb) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.sante_repas_brut_marquer_interne(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.sante_sommeil_lieu_interne(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.sante_sommeil_crediter_interne(text, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.sante_sommeil_interne(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.sante_se_nourrir(integer, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.sante_se_nourrir(integer, integer) TO authenticated;

COMMIT;
