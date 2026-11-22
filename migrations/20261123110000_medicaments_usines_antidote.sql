-- Médicaments, usines d'État et antidote (Fred, 22/11/2026, soir : GAME-DESIGN-SANTE-20261122.md, section « Suites »,
-- point 8 a à d, et règle générale du point 5 — tous les paiements en liquide — pour ce que ce lot touche).
-- Écrite à partir des définitions de PRODUCTION du 22/11/2026 (pg_get_functiondef, md5 vérifiés par le banc
-- outils/bancs/banc-medicaments-usines-pglite-20261123.cjs). Suppose 20261122230000_sante_socle et
-- 20261122233000_sante_maladies_medicaments appliquées. Rejouable, sans BEGIN/COMMIT. Rien du goulag.
-- Toutes les valeurs chiffrées sont des lignes de sante_parametres (page MJ « Santé — paramètres », groupes
-- « Médicaments » et « Usines d'État ») : posées une seule fois, jamais écrasées par un rejeu.
--
-- 8a — La ressource générique « Médicaments » (ressources_economie 'medicaments', produite par la chaîne plantes →
--   médicaments des usines) est la matière première des trousses de premiers secours. Seul lieu de fabrication en
--   production : l'infirmerie de la caserne (militaire_trousse_retirer, stock commun budgets_nationaux.caserneMatieres),
--   qui consommait déjà 1 Médicaments + 1 textile + 1 désinfectant en dur. Recette de la règle commune, désormais
--   réglable : trousse_medicaments 1, trousse_textile 1, trousse_desinfectant 1 (remplacement contrôlé, marques
--   medicaments_usines_v1_trousse_*). La trousse reste gratuite pour le soldat (aucun prix : pas d'ordre payant).
-- 8b — La dotation gratuite (stock_journalier, 20 boîtes / jour / médicament, réparties entre points de vente) devient
--   une production des PNJ de l'usine, chaque nuit : par médicament, jusqu'à stock_journalier boîtes (antidote :
--   antidote_pnj_boites_nuit), au même ratio que produire_medicament (medicament_matiere_par_pa plantes pour
--   medicament_produits_par_pa boîtes ; antidote × antidote_recette_coef), plafonnée par medicament_pnj_stock_max,
--   prise sur usine.stockMatieres comme celle des joueurs : sans matière, aucune boîte ; matière insuffisante =
--   partage au prorata. Aucun salaire versé aux PNJ (la dotation était gratuite). Stock PNJ distinct
--   (medicaments_stocks.quantite_pnj) : les boîtes des joueurs (quantite) sont toujours vendues en premier.
--   Appel : usines_etat_nuit(), une ligne dans api/cron-minuit.js (tâche quotidienne « usines_etat_nuit »).
-- 8c — Tout l'argent des ventes de médicaments va à la caisse de l'usine (usine_medicaments_crediter_interne),
--   y compris ce qui allait aux points de vente (Novomirsk : entreprise ; entrepôts de Républia : caisses
--   municipales) ou était perdu (comptoir de l'usine de Luthécia). Usines d'État (directeurs_usine pour la Républia,
--   directeurs_usine_pays pour Sovarka — six usines) : mécanisme des entrepôts municipaux (entrepot_reverser) :
--   fonds de roulement usine_fonds_roulement = 5 000 dans la monnaie du pays ; chaque nuit l'excédent est reversé à la
--   caisse du ministère de tutelle = le ministère qui nomme le directeur (postes_nommes_regles.nomme_par : min_fin
--   dans les deux pays, « Économie collective » en Sovarka), caisse « <pays>_gouvernement-<ministère> » ; journal
--   usines_reversements (anti-rejeu : un reversement automatique par usine et par jour). Virement volontaire du
--   directeur : l'ordre existant virement_usine_ministere (1 PA, inchangé côté coûts), réécrit pour passer par le
--   même mécanisme (tutelle, journal) ; nouvelle lecture usine_tutelle_etat() pour sa fenêtre.
-- 8d — Antidote, sixième médicament (catalogue medicaments_catalogue_interne : les cinq médicaments des maladies +
--   l'antidote, qui ne soigne aucune maladie) : produit à l'usine (produire_medicament) avec antidote_recette_coef
--   fois plus de matière ; prix par la règle commune (2 × coût de revient) appliquée à la recette plus riche :
--   round(2 × prix_base(medicaments) × antidote_recette_coef) = 132 FR avec 22 et 3 (44 pour les autres). Pris
--   (medicament_prendre, remplacement contrôlé), il marque poison_actif.antidote ; au réveil suivant,
--   sante_reveil_interne (réécrite : texte de production intégral pour la MST, bloc antidote ajouté AVANT) annule
--   l'empoisonnement — avant crim_poison_nuit_interne dans pa_repos_nocturne, donc le poison ne frappe plus cette nuit.
--   Centre antipoison (centre_anti_poison_traiter, réécrite) : consomme antipoison_antidotes_par_soin antidote(s) du
--   stock propre du centre (batiments_etat.<centre>.sante.antidotes) à chaque tentative ; sans stock, refus
--   « Plus d'antidote, réapprovisionnement en attente. » (raison plus_d_antidote). Proposition retenue : le centre
--   achète ses antidotes comme les autres acheteurs (boîtes des joueurs d'abord, recette à l'usine), chaque nuit,
--   jusqu'à antipoison_stock_cible, payés par la caisse de la structure (structures_medicales.financement :
--   clinique « propre » = sante.caisse ; dispensaire « institution » = caisse <pays>_dispensaire_<ville>, comme
--   vendre_ressource_medicale) ; le prix du soin payé par le patient (60 / 150, inchangé) est versé à cette même caisse.
-- Point 5 — liquide seulement : pharmacie_acheter_interne (n'entame plus le compte en banque) et le centre antipoison
--   (refus fonds_insuffisants si le liquide ne couvre pas le soin, avant tout prélèvement).
--
-- Nouvelles : medicaments_catalogue_interne, medicament_prix_pays_interne, medicament_matiere_lot_interne,
--   medicament_vendre_stock_interne, medicaments_pnj_produire_interne, usines_etat_liste_interne,
--   usine_reverser_interne, usines_reverser_excedent_interne, usine_tutelle_etat, antipoison_centres_interne,
--   antipoison_stock_interne, antipoison_stock_ajuster_interne, antipoison_caisse_lire_interne,
--   antipoison_caisse_mouvement_interne, antipoison_reapprovisionner_interne, antidote_prendre_interne, usines_etat_nuit.
-- Réécrites (texte de production + changements) : produire_medicament, usine_medicaments_etat, pharmacie_etat,
--   pharmacie_acheter_interne, sante_reveil_interne, centre_anti_poison_traiter, usine_virer_vers_ministere.
-- Remplacements contrôlés : militaire_trousse_retirer (medicaments_usines_v1_trousse_*), medicament_prendre
--   (medicaments_usines_v1_antidote).
-- Données : aucune donnée de joueur modifiée. Colonne medicaments_stocks.quantite_pnj ajoutée à 0 (aucune boîte PNJ
--   offerte : la première nuit produit selon la matière présente). Tables nouvelles vides.

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
-- 1. Paramètres (réglables par le MJ, jamais écrasés par un rejeu)
-- ---------------------------------------------------------------------------------------------------------------
INSERT INTO public.sante_parametres (cle, valeur, groupe, libelle) VALUES
  ('trousse_medicaments', 1, 'medicaments', 'Trousse de premiers secours : Médicaments (ressource) consommés'),
  ('trousse_textile', 1, 'medicaments', 'Trousse de premiers secours : textile consommé'),
  ('trousse_desinfectant', 1, 'medicaments', 'Trousse de premiers secours : désinfectant consommé'),
  ('medicament_pnj_stock_max', 50, 'medicaments', 'Usine : plafond du stock des boîtes produites par les PNJ, par médicament'),
  ('antidote_actif', 1, 'medicaments', 'Antidote en vente et en production (1 = oui, 0 = non)'),
  ('antidote_recette_coef', 3, 'medicaments', 'Antidote : matière première par boîte, en multiple des autres médicaments (le prix suit)'),
  ('antidote_pnj_boites_nuit', 10, 'medicaments', 'Antidote : boîtes produites par les PNJ chaque nuit (les autres : stock journalier de la maladie)'),
  ('antipoison_antidotes_par_soin', 1, 'medicaments', 'Centre antipoison : antidotes consommés par tentative de soin'),
  ('antipoison_stock_cible', 5, 'medicaments', 'Centre antipoison : stock d''antidotes racheté chaque nuit (jusqu''à)'),
  ('usine_fonds_roulement', 5000, 'usines', 'Usines d''État : fonds de roulement (monnaie du pays), excédent reversé chaque nuit à la tutelle')
ON CONFLICT (cle) DO NOTHING;

-- ---------------------------------------------------------------------------------------------------------------
-- 2. Tables
-- ---------------------------------------------------------------------------------------------------------------
ALTER TABLE public.medicaments_stocks ADD COLUMN IF NOT EXISTS quantite_pnj integer NOT NULL DEFAULT 0;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'medicaments_stocks_quantite_pnj_check') THEN
    ALTER TABLE public.medicaments_stocks ADD CONSTRAINT medicaments_stocks_quantite_pnj_check CHECK (quantite_pnj >= 0);
  END IF;
END $$;

-- Une passe PNJ par pays et par jour (anti-rejeu) ; le détail de ce qui a été produit.
CREATE TABLE IF NOT EXISTS public.medicaments_pnj_passes (
  pays text NOT NULL,
  jour date NOT NULL,
  detail jsonb NOT NULL DEFAULT '{}'::jsonb,
  cree_le timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (pays, jour)
);
ALTER TABLE public.medicaments_pnj_passes ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.medicaments_pnj_passes FROM PUBLIC, anon, authenticated;

-- Reversements des usines d'État à leur tutelle (automatiques : clé usine:jour ; volontaires : horodatés).
CREATE TABLE IF NOT EXISTS public.usines_reversements (
  id text PRIMARY KEY,
  pays text NOT NULL,
  usine_id text NOT NULL,
  tutelle text NOT NULL,
  jour date NOT NULL,
  montant numeric NOT NULL CHECK (montant > 0),
  mode text NOT NULL CHECK (mode IN ('automatique', 'volontaire')),
  acteur text,
  cree_le timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.usines_reversements ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.usines_reversements FROM PUBLIC, anon, authenticated;

-- Rachats nocturnes d'antidotes par les centres antipoison (un par centre et par jour).
CREATE TABLE IF NOT EXISTS public.antipoison_reapprovisionnements (
  centre_id text NOT NULL,
  jour date NOT NULL,
  quantite integer NOT NULL DEFAULT 0,
  montant numeric NOT NULL DEFAULT 0,
  raison text,
  cree_le timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (centre_id, jour)
);
ALTER TABLE public.antipoison_reapprovisionnements ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.antipoison_reapprovisionnements FROM PUBLIC, anon, authenticated;

-- ---------------------------------------------------------------------------------------------------------------
-- 3. Catalogue, prix et recette des médicaments (8d)
-- ---------------------------------------------------------------------------------------------------------------
-- Les cinq médicaments des maladies (maladies_parametres) et l'antidote, qui ne soigne aucune maladie
-- (« maladie » = empoisonnement, hors du catalogue des maladies : aucun tirage, aucune contagion).
CREATE OR REPLACE FUNCTION public.medicaments_catalogue_interne()
 RETURNS TABLE (medicament text, maladie text, nom_mj text, pnj_nuit integer, coef numeric)
 LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT m.medicament, m.cle, m.nom_mj, greatest(0, coalesce(m.stock_journalier, 0))::integer, 1::numeric
    FROM public.maladies_parametres m WHERE m.actif AND m.medicament IS NOT NULL
  UNION ALL
  SELECT 'antidote', 'empoisonnement', NULL::text, greatest(0, public.sante_param('antidote_pnj_boites_nuit', 10))::integer,
         greatest(1, public.sante_param('antidote_recette_coef', 3))
   WHERE public.sante_param('antidote_actif', 1) > 0
     AND NOT EXISTS (SELECT 1 FROM public.maladies_parametres WHERE medicament = 'antidote'); /* medicaments_usines_v1 */
$function$;

-- Prix au comptoir : règle commune (2 × coût de revient) ; recette plus riche de l'antidote = prix multiplié d'autant.
CREATE OR REPLACE FUNCTION public.medicament_prix_pays_interne(p_medicament text, p_pays text)
 RETURNS integer LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT CASE WHEN p_medicament = 'antidote'
    THEN greatest(1, round(coalesce((SELECT 2 * prix_base FROM public.ressources_economie WHERE cle = 'medicaments'), 44)
                           * greatest(1, public.sante_param('antidote_recette_coef', 3))))::integer
    ELSE public.pharmacie_prix_pays_interne((SELECT cle FROM public.maladies_parametres WHERE medicament = p_medicament LIMIT 1), p_pays)
  END; /* medicaments_usines_v1 */
$function$;

-- Matière première d'un lot (1 PA d'un joueur = medicament_produits_par_pa boîtes).
CREATE OR REPLACE FUNCTION public.medicament_matiere_lot_interne(p_medicament text)
 RETURNS integer LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT ceil(public.sante_param('medicament_matiere_par_pa', 5)
              * coalesce((SELECT c.coef FROM public.medicaments_catalogue_interne() c WHERE c.medicament = p_medicament), 1))::integer;
$function$;

-- Vente de boîtes du stock national (comptoir ou centre antipoison) : boîtes des joueurs d'abord, puis celles des PNJ ;
-- toute la recette à la caisse de l'usine du pays (8c).
CREATE OR REPLACE FUNCTION public.medicament_vendre_stock_interne(p_pays text, p_medicament text, p_qte integer, p_prix integer)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_j integer; v_p integer; v_de_j integer; v_de_p integer;
BEGIN
  IF p_qte IS NULL OR p_qte < 1 OR p_prix IS NULL OR p_prix < 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'quantite_invalide'); END IF;
  SELECT quantite, quantite_pnj INTO v_j, v_p FROM public.medicaments_stocks WHERE pays = p_pays AND medicament = p_medicament FOR UPDATE;
  IF coalesce(v_j, 0) + coalesce(v_p, 0) < p_qte THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'stock_insuffisant', 'restant', coalesce(v_j, 0) + coalesce(v_p, 0)); END IF;
  v_de_j := least(p_qte, v_j);
  v_de_p := p_qte - v_de_j;
  UPDATE public.medicaments_stocks SET quantite = quantite - v_de_j, quantite_pnj = quantite_pnj - v_de_p, updated_at = now()
   WHERE pays = p_pays AND medicament = p_medicament;
  IF NOT public.usine_medicaments_crediter_interne(p_pays, p_prix * p_qte) THEN
    RAISE EXCEPTION 'medicament_vendre: caisse de l''usine introuvable (%)', p_pays; END IF;
  RETURN jsonb_build_object('ok', true, 'de_joueurs', v_de_j, 'de_pnj', v_de_p, 'montant', p_prix * p_qte,
    'restant', v_j + v_p - p_qte); /* medicaments_usines_v1 */
END $function$;

-- ---------------------------------------------------------------------------------------------------------------
-- 4. Production des joueurs (texte de production + catalogue et recette de l'antidote)
-- ---------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.produire_medicament(p_acteur text, p_pays text, p_medicament text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE c record; v_id text; v_etat jsonb; v_usine jsonb; v_sm jsonb; v_caisse numeric; v_stock_mat numeric; v_stock integer;
        v_place integer; v_produits integer; v_arg numeric; v_liquide numeric;
        v_mat_pa integer := public.medicament_matiere_lot_interne(p_medicament); /* medicaments_usines_v1 */
        v_prod_pa integer := public.sante_param('medicament_produits_par_pa', 10)::integer;
        v_max integer := public.sante_param('medicament_stock_max', 50)::integer;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  IF NOT EXISTS (SELECT 1 FROM public.medicaments_catalogue_interne() m WHERE m.medicament = p_medicament) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'medicament_inconnu'); END IF;
  SELECT * INTO c FROM public.usine_medicaments_chaine_interne(p_pays);
  IF c.ville IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'chaine_inconnue'); END IF;
  IF NOT EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = p_acteur AND country = p_pays
                    AND current_city = c.ville AND current_building = c.building_id) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;
  IF public.matiere_refus_circuit_legal(p_acteur, 'medicaments', 'production') IS NOT NULL THEN
    RETURN public.matiere_refus_circuit_legal(p_acteur, 'medicaments', 'production'); END IF;
  IF public.matiere_refus_circuit_legal(p_acteur, c.matiere, 'transformation') IS NOT NULL THEN
    RETURN public.matiere_refus_circuit_legal(p_acteur, c.matiere, 'transformation'); END IF;

  v_id := p_pays || '_' || c.ville || '_' || c.building_id;
  SELECT public.batiment_etat_lire(data) INTO v_etat FROM public.batiments_etat WHERE id = v_id FOR UPDATE;
  IF v_etat IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'usine_introuvable'); END IF;
  v_usine := coalesce(v_etat->'usine', '{}'::jsonb);
  v_sm := coalesce(v_usine->'stockMatieres', '{}'::jsonb);
  v_caisse := coalesce((v_usine->>'caisse')::numeric, 0);
  v_stock_mat := coalesce((v_sm->>c.matiere)::numeric, 0);
  INSERT INTO public.medicaments_stocks (pays, medicament) VALUES (p_pays, p_medicament) ON CONFLICT DO NOTHING;
  SELECT quantite INTO v_stock FROM public.medicaments_stocks WHERE pays = p_pays AND medicament = p_medicament FOR UPDATE;

  IF v_stock_mat < v_mat_pa THEN RETURN jsonb_build_object('ok', false, 'raison', 'matiere_insuffisante', 'matiere', c.matiere, 'requis', v_mat_pa); END IF;
  IF v_caisse < c.salaire_pa THEN RETURN jsonb_build_object('ok', false, 'raison', 'caisse_insuffisante'); END IF;
  v_place := greatest(0, v_max - v_stock);
  IF v_place <= 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'stock_plein'); END IF;
  v_produits := least(floor(v_prod_pa * public.penurie_coef_interne(p_pays, c.ville, 'medicaments')), v_place)::integer;
  IF v_produits <= 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'penurie', 'produit', 'medicaments'); END IF;

  v_sm := jsonb_set(v_sm, ARRAY[c.matiere], to_jsonb(v_stock_mat - v_mat_pa));
  v_caisse := v_caisse - c.salaire_pa;
  UPDATE public.batiments_etat
     SET data = to_jsonb((v_etat || jsonb_build_object('usine', v_usine || jsonb_build_object('caisse', v_caisse, 'stockMatieres', v_sm)))::text),
         updated_at = now()
   WHERE id = v_id;
  UPDATE public.medicaments_stocks SET quantite = quantite + v_produits, updated_at = now()
   WHERE pays = p_pays AND medicament = p_medicament;
  UPDATE public.personnages_donnees SET arg = coalesce(arg, 0) + c.salaire_pa, liquide = coalesce(liquide, 0) + c.salaire_pa
   WHERE name = p_acteur RETURNING arg, liquide INTO v_arg, v_liquide;
  IF v_arg IS NULL THEN RAISE EXCEPTION 'personnage_introuvable' USING ERRCODE = '42501'; END IF;
  RETURN jsonb_build_object('ok', true, 'medicament', p_medicament, 'produits', v_produits, 'salaire', c.salaire_pa,
    'arg', v_arg, 'liquide', v_liquide, 'caisse_usine', v_caisse, 'stock_produit', v_stock + v_produits,
    'stock_max', v_max, 'stock_matiere', v_stock_mat - v_mat_pa, 'matiere_consommee', v_mat_pa); /* sante_maladies_v1 */ /* medicaments_usines_v1 */
END $function$;

-- Fenêtre de production : médicaments au choix (antidote compris), recette de chacun, stocks des joueurs et des PNJ.
CREATE OR REPLACE FUNCTION public.usine_medicaments_etat()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE a text := public.mon_personnage(); v_pays text;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = a;
  RETURN jsonb_build_object('ok', true, 'pays', v_pays, 'stock_max', public.sante_param('medicament_stock_max', 50)::integer,
    'stock_pnj_max', public.sante_param('medicament_pnj_stock_max', 50)::integer,
    'matiere_par_pa', public.sante_param('medicament_matiere_par_pa', 5)::integer,
    'produits_par_pa', public.sante_param('medicament_produits_par_pa', 10)::integer,
    'medicaments', (SELECT coalesce(jsonb_agg(jsonb_build_object('medicament', m.medicament, 'maladie', m.maladie,
        'stock', coalesce(s.quantite, 0), 'stock_pnj', coalesce(s.quantite_pnj, 0),
        'matiere_par_pa', public.medicament_matiere_lot_interne(m.medicament),
        'prix', public.medicament_prix_pays_interne(m.medicament, v_pays))
        ORDER BY (m.medicament = 'antidote'), m.maladie), '[]'::jsonb)
      FROM public.medicaments_catalogue_interne() m
      LEFT JOIN public.medicaments_stocks s ON s.pays = v_pays AND s.medicament = m.medicament)); /* sante_maladies_v1 */ /* medicaments_usines_v1 */
END $function$;

-- ---------------------------------------------------------------------------------------------------------------
-- 5. Pharmacie : stock des joueurs puis des PNJ, recette à l'usine, paiement en liquide
-- ---------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.pharmacie_etat()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE a text := public.mon_personnage(); pv public.pharmacies_points_vente;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  pv := public.pharmacie_point_interne(a);
  IF pv.id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_a_la_pharmacie'); END IF;
  RETURN jsonb_build_object('ok', true, 'point', pv.id, 'prix_bandelette', public.aliments_param_interne('prix_bandelette', 4), /* aliments_bandelettes_v1 */
    'paiement', 'liquide', 'medicaments', (
    SELECT coalesce(jsonb_agg(jsonb_build_object('medicament', m.medicament, 'maladie', m.maladie, 'nom_mj', m.nom_mj,
             'prix', public.medicament_prix_pays_interne(m.medicament, pv.pays) /* climat_prix_pays_v1 */,
             'restant', coalesce(s.quantite, 0) + coalesce(s.quantite_pnj, 0),
             'stock_joueurs', coalesce(s.quantite, 0), 'stock_pnj', coalesce(s.quantite_pnj, 0))
             /* sante_maladies_v1 */ /* medicaments_usines_v1 */ ORDER BY (m.medicament = 'antidote'), m.maladie), '[]'::jsonb)
      FROM public.medicaments_catalogue_interne() m
      LEFT JOIN public.medicaments_stocks s ON s.pays = pv.pays AND s.medicament = m.medicament));
END $function$;

CREATE OR REPLACE FUNCTION public.pharmacie_acheter_interne(p_acteur text, p_medicament text, p_qte integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE pv public.pharmacies_points_vente; m record; v jsonb; v_prix integer; v_total numeric;
        v_liquide numeric; v_debit numeric; v_dep jsonb; v_dispo integer; v_vente jsonb;
BEGIN
  IF p_qte IS NULL OR p_qte < 1 OR p_qte > 10 THEN RETURN jsonb_build_object('ok', false, 'raison', 'quantite_invalide'); END IF;
  pv := public.pharmacie_point_interne(p_acteur);
  IF pv.id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_a_la_pharmacie'); END IF;
  SELECT * INTO m FROM public.medicaments_catalogue_interne() c WHERE c.medicament = p_medicament;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'medicament_inconnu'); END IF;
  v_dispo := coalesce((SELECT quantite + quantite_pnj FROM public.medicaments_stocks
                        WHERE pays = pv.pays AND medicament = p_medicament FOR UPDATE), 0);
  IF v_dispo <= 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'rupture'); END IF;
  IF p_qte > v_dispo THEN RETURN jsonb_build_object('ok', false, 'raison', 'stock_insuffisant', 'restant', v_dispo); END IF;
  v_prix := public.medicament_prix_pays_interne(p_medicament, pv.pays) /* climat_prix_pays_v1 */;
  v_total := v_prix * p_qte;
  -- Point 5 (Fred, 22/11/2026) : tous les paiements se font en liquide ; la banque est un dépôt volontaire.
  SELECT coalesce(liquide, 0) INTO v_liquide FROM public.personnages_donnees WHERE name = p_acteur;
  IF coalesce(v_liquide, 0) < v_total THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants', 'requis', v_total, 'disponible', coalesce(v_liquide, 0),
      'paiement', 'liquide'); END IF;
  IF (SELECT public.inventaire_place_restante(inventory) FROM public.personnages_donnees WHERE name = p_acteur) < 1 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'inventaire_plein'); END IF;
  v := public.payer_ordre(p_acteur, 'pharmacie_medicaments', 0, 0);
  IF coalesce((v->>'ok')::boolean, false) IS NOT TRUE THEN RETURN v; END IF;
  v_debit := public.argent_debiter_interne(p_acteur, v_total, 'liquide');
  IF v_debit IS DISTINCT FROM v_total THEN RAISE EXCEPTION 'pharmacie_acheter: debit incomplet % / %', v_debit, v_total; END IF;
  -- Boîtes des joueurs d'abord, puis celles des PNJ ; toute la recette à la caisse de l'usine (8c).
  v_vente := public.medicament_vendre_stock_interne(pv.pays, p_medicament, p_qte, v_prix);
  IF coalesce((v_vente->>'ok')::boolean, false) IS NOT TRUE THEN RAISE EXCEPTION 'pharmacie_acheter: vente refusee %', v_vente; END IF;
  v_dep := public.inventaire_deposer_interne(p_acteur, jsonb_build_object('name', CASE p_medicament WHEN 'antinauseeux' THEN 'Anti-nauséeux' WHEN 'aspirine' THEN 'Aspirine' WHEN 'antigrippal' THEN 'Antigrippal' WHEN 'sels_rehydratation' THEN 'Sels de réhydratation' WHEN 'antibiotique' THEN 'Antibiotique' WHEN 'antidote' THEN 'Antidote' ELSE p_medicament END, 'icon', 'ti-pill',
    'type', 'medicament_maladie', 'medicament', p_medicament, 'soigne', m.maladie,
    'stackable', true, 'stackKey', 'medicament_' || p_medicament, 'qty', p_qte));
  IF coalesce((v_dep->>'ok')::boolean, false) IS NOT TRUE THEN RAISE EXCEPTION 'pharmacie_acheter: depot refuse %', v_dep; END IF;
  RETURN jsonb_build_object('ok', true, 'medicament', p_medicament, 'quantite', p_qte, 'prix', v_prix, 'paye', v_total,
    'restant', v_dispo - p_qte, 'de_joueurs', v_vente->'de_joueurs', 'de_pnj', v_vente->'de_pnj')
    || (SELECT jsonb_build_object('inventory', inventory, 'revision', inventory_revision, 'liquide', liquide) FROM public.personnages_donnees WHERE name = p_acteur); /* medicaments_usines_v1 */
END $function$;

-- ---------------------------------------------------------------------------------------------------------------
-- 6. Production des PNJ de l'usine, chaque nuit (8b)
-- ---------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.medicaments_pnj_produire_interne(p_pays text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE c record; r record; v_id text; v_etat jsonb; v_usine jsonb; v_sm jsonb; v_mat numeric; v_mat_avant numeric;
        v_jour date := (statement_timestamp() AT TIME ZONE 'Europe/Paris')::date; v_n integer;
        v_prod_pa integer := greatest(1, public.sante_param('medicament_produits_par_pa', 10))::integer;
        v_max integer := public.sante_param('medicament_pnj_stock_max', 50)::integer;
        v_besoins jsonb := '[]'::jsonb; v_demande numeric := 0; v_f numeric; v_cible integer; v_lot integer;
        v_prod integer; v_cons integer; v_detail jsonb := '[]'::jsonb; e jsonb; v_penurie numeric;
BEGIN
  INSERT INTO public.medicaments_pnj_passes (pays, jour) VALUES (p_pays, v_jour) ON CONFLICT DO NOTHING;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n = 0 THEN RETURN jsonb_build_object('ok', true, 'pays', p_pays, 'deja_fait', true, 'jour', v_jour); END IF;
  SELECT * INTO c FROM public.usine_medicaments_chaine_interne(p_pays);
  IF c.ville IS NULL THEN
    UPDATE public.medicaments_pnj_passes SET detail = '{"raison":"chaine_inconnue"}' WHERE pays = p_pays AND jour = v_jour;
    RETURN jsonb_build_object('ok', false, 'pays', p_pays, 'raison', 'chaine_inconnue'); END IF;
  v_id := p_pays || '_' || c.ville || '_' || c.building_id;
  SELECT public.batiment_etat_lire(data) INTO v_etat FROM public.batiments_etat WHERE id = v_id FOR UPDATE;
  IF v_etat IS NULL THEN
    UPDATE public.medicaments_pnj_passes SET detail = '{"raison":"usine_introuvable"}' WHERE pays = p_pays AND jour = v_jour;
    RETURN jsonb_build_object('ok', false, 'pays', p_pays, 'raison', 'usine_introuvable'); END IF;
  v_usine := coalesce(v_etat->'usine', '{}'::jsonb);
  v_sm := coalesce(v_usine->'stockMatieres', '{}'::jsonb);
  v_mat := greatest(0, coalesce((v_sm->>c.matiere)::numeric, 0));
  v_mat_avant := v_mat;
  v_penurie := public.penurie_coef_interne(p_pays, c.ville, 'medicaments');

  -- Besoins du jour : jusqu'au volume de nuit, sans dépasser le plafond du stock PNJ.
  FOR r IN SELECT * FROM public.medicaments_catalogue_interne() ORDER BY (medicament = 'antidote'), maladie LOOP
    INSERT INTO public.medicaments_stocks (pays, medicament) VALUES (p_pays, r.medicament) ON CONFLICT DO NOTHING;
    SELECT least(r.pnj_nuit, greatest(0, v_max - quantite_pnj)) INTO v_cible
      FROM public.medicaments_stocks WHERE pays = p_pays AND medicament = r.medicament FOR UPDATE;
    v_cible := floor(greatest(0, v_cible) * v_penurie)::integer;
    v_lot := public.medicament_matiere_lot_interne(r.medicament);
    v_besoins := v_besoins || jsonb_build_array(jsonb_build_object('m', r.medicament, 'cible', v_cible, 'lot', v_lot));
    v_demande := v_demande + ceil(v_cible::numeric * v_lot / v_prod_pa);
  END LOOP;

  -- Matière insuffisante : chaque médicament reçoit la même part de ses besoins (prorata).
  v_f := CASE WHEN v_demande <= 0 THEN 0 ELSE least(1, v_mat / v_demande) END;
  FOR e IN SELECT * FROM jsonb_array_elements(v_besoins) LOOP
    v_cible := (e->>'cible')::integer; v_lot := (e->>'lot')::integer;
    v_prod := least(floor(v_cible * v_f)::integer, floor(v_mat * v_prod_pa / v_lot)::integer);
    v_prod := greatest(0, v_prod);
    v_cons := ceil(v_prod::numeric * v_lot / v_prod_pa)::integer;
    IF v_prod > 0 THEN
      UPDATE public.medicaments_stocks SET quantite_pnj = quantite_pnj + v_prod, updated_at = now()
       WHERE pays = p_pays AND medicament = e->>'m';
      v_mat := v_mat - v_cons;
    END IF;
    v_detail := v_detail || jsonb_build_array(jsonb_build_object('medicament', e->>'m', 'produits', v_prod, 'matiere', v_cons));
  END LOOP;

  IF v_mat <> v_mat_avant THEN
    v_sm := jsonb_set(v_sm, ARRAY[c.matiere], to_jsonb(v_mat));
    UPDATE public.batiments_etat
       SET data = to_jsonb((v_etat || jsonb_build_object('usine', v_usine || jsonb_build_object('stockMatieres', v_sm)))::text),
           updated_at = now()
     WHERE id = v_id;
  END IF;
  UPDATE public.medicaments_pnj_passes
     SET detail = jsonb_build_object('matiere', c.matiere, 'avant', v_mat_avant, 'apres', v_mat, 'medicaments', v_detail)
   WHERE pays = p_pays AND jour = v_jour;
  RETURN jsonb_build_object('ok', true, 'pays', p_pays, 'matiere', c.matiere, 'matiere_avant', v_mat_avant, 'matiere_apres', v_mat,
    'medicaments', v_detail); /* medicaments_usines_v1 */
END $function$;

-- ---------------------------------------------------------------------------------------------------------------
-- 7. Usines d'État : fonds de roulement, reversement nocturne, virement volontaire (8c)
-- ---------------------------------------------------------------------------------------------------------------
-- Les usines d'État de chaque pays et la caisse de leur ministère de tutelle (celui qui nomme le directeur).
CREATE OR REPLACE FUNCTION public.usines_etat_liste_interne()
 RETURNS TABLE (pays text, ville text, building_id text, poste_id text, tutelle text)
 LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
  WITH u AS (
    SELECT d.pays, d.ville, d.building_id, d.poste_id FROM public.directeurs_usine_pays d
    UNION ALL
    SELECT 'republic', d.ville, d.building_id, d.poste_id FROM public.directeurs_usine d
     WHERE NOT EXISTS (SELECT 1 FROM public.directeurs_usine_pays x WHERE x.pays = 'republic' AND x.poste_id = d.poste_id))
  SELECT u.pays, u.ville, u.building_id, u.poste_id,
         u.pays || '_gouvernement-' || coalesce((SELECT r.nomme_par FROM public.postes_nommes_regles r WHERE r.poste_id = u.poste_id), 'min_fin')
    FROM u; /* medicaments_usines_v1 */
$function$;

-- Reversement (modèle : entrepot_reverser). Automatique : tout ce qui dépasse le fonds de roulement, une fois par jour.
-- Volontaire : le montant demandé, borné par la trésorerie réelle (refus si la caisse ne le couvre pas).
CREATE OR REPLACE FUNCTION public.usine_reverser_interne(p_pays text, p_ville text, p_batiment text, p_tutelle text,
  p_montant numeric, p_mode text, p_acteur text DEFAULT NULL)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_id text := p_pays || '_' || p_ville || '_' || p_batiment; v_etat jsonb; v_caisse numeric; v_verse numeric;
        v_fonds numeric := public.sante_param('usine_fonds_roulement', 5000); v_jour date := (now() AT TIME ZONE 'Europe/Paris')::date;
        v_rep jsonb; v_flag text;
BEGIN
  IF p_mode NOT IN ('automatique', 'volontaire') THEN RETURN jsonb_build_object('ok', false, 'raison', 'mode_invalide'); END IF;
  SELECT public.batiment_etat_lire(data) INTO v_etat FROM public.batiments_etat WHERE id = v_id FOR UPDATE;
  IF v_etat IS NULL OR jsonb_typeof(v_etat->'usine') IS DISTINCT FROM 'object' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'usine_introuvable', 'usine', v_id); END IF;
  v_caisse := CASE WHEN jsonb_typeof(v_etat->'usine'->'caisse') = 'number' THEN (v_etat->'usine'->>'caisse')::numeric ELSE 0 END;
  IF p_mode = 'automatique' THEN
    v_verse := greatest(0, v_caisse - v_fonds);
  ELSE
    IF p_montant IS NULL OR p_montant <= 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'montant_invalide'); END IF;
    IF p_montant > v_caisse THEN RETURN jsonb_build_object('ok', false, 'raison', 'caisse_insuffisante', 'caisse', v_caisse); END IF;
    v_verse := p_montant;
  END IF;
  IF v_verse <= 0 THEN RETURN jsonb_build_object('ok', true, 'verse', 0, 'caisse', v_caisse, 'roulement', v_fonds); END IF;
  BEGIN
    INSERT INTO public.usines_reversements (id, pays, usine_id, tutelle, jour, montant, mode, acteur)
    VALUES (v_id || ':' || v_jour::text || CASE WHEN p_mode = 'volontaire'
              THEN ':v' || (extract(epoch from clock_timestamp()) * 1000000)::bigint ELSE '' END,
            p_pays, v_id, p_tutelle, v_jour, v_verse, p_mode, p_acteur);
  EXCEPTION WHEN unique_violation THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_reverse_aujourdhui', 'jour', v_jour, 'caisse', v_caisse);
  END;
  v_rep := public.batiment_caisse_mouvement(p_pays, p_ville, p_batiment, 'usine', -v_verse, NULL, 0, NULL, true);
  IF NOT coalesce((v_rep->>'ok')::boolean, false) THEN RAISE EXCEPTION 'usine_reverser: debit refuse %', v_rep; END IF;
  v_flag := current_setting('rp.caisse_interne', true);
  PERFORM set_config('rp.caisse_interne', 'on', true);
  v_rep := public.caisse_institution_mouvement(p_tutelle, v_verse, true);
  PERFORM set_config('rp.caisse_interne', coalesce(v_flag, ''), true);
  IF NOT coalesce((v_rep->>'ok')::boolean, false) THEN RAISE EXCEPTION 'usine_reverser: credit de la tutelle refuse % (%)', v_rep, p_tutelle; END IF;
  RETURN jsonb_build_object('ok', true, 'verse', v_verse, 'tutelle', p_tutelle, 'caisse', v_caisse - v_verse,
    'roulement', v_fonds, 'mode', p_mode, 'jour', v_jour); /* medicaments_usines_v1 */
END $function$;

CREATE OR REPLACE FUNCTION public.usines_reverser_excedent_interne()
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE u record; v jsonb; v_total numeric := 0; v_detail jsonb := '[]'::jsonb;
BEGIN
  FOR u IN SELECT * FROM public.usines_etat_liste_interne() ORDER BY pays, poste_id LOOP
    BEGIN
      v := public.usine_reverser_interne(u.pays, u.ville, u.building_id, u.tutelle, NULL, 'automatique', NULL);
    EXCEPTION WHEN OTHERS THEN
      v := jsonb_build_object('ok', false, 'raison', 'erreur', 'erreur', SQLERRM);
    END;
    IF coalesce((v->>'verse')::numeric, 0) > 0 THEN v_total := v_total + (v->>'verse')::numeric; END IF;
    v_detail := v_detail || jsonb_build_array(jsonb_build_object('usine', u.pays || '_' || u.ville || '_' || u.building_id) || v);
  END LOOP;
  RETURN jsonb_build_object('ok', true, 'total', v_total, 'detail', v_detail); /* medicaments_usines_v1 */
END $function$;

-- Virement volontaire du directeur (ordre existant « virement_usine_ministere », 1 PA) : texte de production, la caisse de
-- tutelle et le journal passent par usine_reverser_interne.
CREATE OR REPLACE FUNCTION public.usine_virer_vers_ministere(p_montant numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; v_poste text; v_bat text; u jsonb; v_res jsonb; v_paie jsonb; v_tutelle text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT coalesce(country, 'republic'), poste ->> 'id', current_building INTO v_pays, v_poste, v_bat
    FROM public.personnages_donnees WHERE name = v_moi;
  u := public.usine_du_directeur_pays_interne(v_pays, v_poste);
  IF u IS NULL OR NOT public.mon_poste_est_dans(v_poste, v_pays) THEN RETURN jsonb_build_object('ok', false, 'raison', 'reserve_directeur'); END IF;
  IF v_bat IS DISTINCT FROM u ->> 'batiment' THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;
  IF p_montant IS NULL OR p_montant <= 0 OR p_montant <> trunc(p_montant) OR p_montant > 100000000 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'montant_invalide'); END IF;
  SELECT l.tutelle INTO v_tutelle FROM public.usines_etat_liste_interne() l WHERE l.pays = v_pays AND l.poste_id = v_poste;
  v_tutelle := coalesce(v_tutelle, v_pays || '_gouvernement-min_fin');
  v_paie := public.payer_ordre(v_moi, 'virement_usine_ministere', 1, 0);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
  v_res := public.usine_reverser_interne(v_pays, u ->> 'ville', u ->> 'batiment', v_tutelle, p_montant, 'volontaire', v_moi);
  IF NOT coalesce((v_res ->> 'ok')::boolean, false) THEN
    RAISE EXCEPTION USING MESSAGE = 'hg_caisse_usine_insuffisante';
  END IF;
  RETURN jsonb_build_object('ok', true, 'montant', p_montant, 'paie', v_paie, 'tutelle', v_tutelle,
    'caisse', v_res->'caisse'); /* medicaments_usines_v1 */
EXCEPTION WHEN raise_exception THEN
  IF SQLERRM = 'hg_caisse_usine_insuffisante' THEN RETURN jsonb_build_object('ok', false, 'raison', 'caisse_insuffisante'); END IF;
  IF SQLERRM = 'hg_caisse_ministere_refus' THEN RETURN jsonb_build_object('ok', false, 'raison', 'caisse_ministere_refus'); END IF;
  RAISE;
END; $function$;

-- Fenêtre du directeur : caisse, fonds de roulement, tutelle.
CREATE OR REPLACE FUNCTION public.usine_tutelle_etat()
 RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text := public.mon_personnage(); v_pays text; v_poste text; l record; v_etat jsonb; v_caisse numeric;
BEGIN
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT coalesce(country, 'republic'), poste ->> 'id' INTO v_pays, v_poste FROM public.personnages_donnees WHERE name = v_moi;
  SELECT * INTO l FROM public.usines_etat_liste_interne() x WHERE x.pays = v_pays AND x.poste_id = v_poste;
  IF l.pays IS NULL OR NOT public.mon_poste_est_dans(v_poste, v_pays) THEN RETURN jsonb_build_object('ok', false, 'raison', 'reserve_directeur'); END IF;
  SELECT public.batiment_etat_lire(data) INTO v_etat FROM public.batiments_etat WHERE id = l.pays || '_' || l.ville || '_' || l.building_id;
  v_caisse := CASE WHEN jsonb_typeof(v_etat->'usine'->'caisse') = 'number' THEN (v_etat->'usine'->>'caisse')::numeric ELSE 0 END;
  RETURN jsonb_build_object('ok', true, 'caisse', v_caisse, 'fonds_roulement', public.sante_param('usine_fonds_roulement', 5000),
    'tutelle', split_part(l.tutelle, '-', 2), 'pays', v_pays); /* medicaments_usines_v1 */
END $function$;

-- ---------------------------------------------------------------------------------------------------------------
-- 8. Centre antipoison : stock d'antidotes, caisse de la structure, rachat nocturne (8d)
-- ---------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.antipoison_centres_interne()
 RETURNS TABLE (id text, pays text, ville text, building_id text, financement text)
 LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT e.id, e.country, e.city, e.building_id,
         coalesce(s.financement, CASE WHEN e.building_id LIKE 'clinique-privee%' THEN 'propre' ELSE 'institution' END)
    FROM public.batiments_etat e LEFT JOIN public.structures_medicales s ON s.building_id = e.building_id
   WHERE e.building_id LIKE 'clinique-privee%' OR e.building_id LIKE 'dispensaire%'; /* medicaments_usines_v1 */
$function$;

CREATE OR REPLACE FUNCTION public.antipoison_stock_interne(p_id text)
 RETURNS integer LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT coalesce((SELECT CASE WHEN jsonb_typeof(public.batiment_etat_lire(data)->'sante'->'antidotes') = 'number'
                               THEN (public.batiment_etat_lire(data)->'sante'->>'antidotes')::integer ELSE 0 END
                     FROM public.batiments_etat WHERE id = p_id), 0);
$function$;

-- Ajuste le stock d'antidotes du centre (sante.antidotes) ; NULL si le stock ne suffit pas ou si le centre n'existe pas.
CREATE OR REPLACE FUNCTION public.antipoison_stock_ajuster_interne(p_id text, p_delta integer)
 RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_etat jsonb; v_sante jsonb; v_n integer;
BEGIN
  SELECT public.batiment_etat_lire(data) INTO v_etat FROM public.batiments_etat WHERE id = p_id FOR UPDATE;
  IF v_etat IS NULL THEN RETURN NULL; END IF;
  v_sante := CASE WHEN jsonb_typeof(v_etat->'sante') = 'object' THEN v_etat->'sante' ELSE '{}'::jsonb END;
  v_n := CASE WHEN jsonb_typeof(v_sante->'antidotes') = 'number' THEN (v_sante->>'antidotes')::integer ELSE 0 END;
  IF v_n + coalesce(p_delta, 0) < 0 THEN RETURN NULL; END IF;
  UPDATE public.batiments_etat
     SET data = to_jsonb((v_etat || jsonb_build_object('sante', v_sante || jsonb_build_object('antidotes', v_n + p_delta)))::text),
         updated_at = now()
   WHERE id = p_id;
  RETURN v_n + p_delta; /* medicaments_usines_v1 */
END $function$;

-- Caisse de la structure (comme vendre_ressource_medicale) : clinique « propre » = sante.caisse ; sinon la caisse
-- institutionnelle <pays>_dispensaire_<ville>.
CREATE OR REPLACE FUNCTION public.antipoison_caisse_lire_interne(p_pays text, p_ville text, p_batiment text, p_financement text)
 RETURNS numeric LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT CASE WHEN p_financement = 'propre'
    THEN coalesce((SELECT CASE WHEN jsonb_typeof(public.batiment_etat_lire(data)->'sante'->'caisse') = 'number'
                               THEN (public.batiment_etat_lire(data)->'sante'->>'caisse')::numeric ELSE 0 END
                     FROM public.batiments_etat WHERE id = p_pays || '_' || p_ville || '_' || p_batiment), 0)
    ELSE coalesce((SELECT CASE WHEN jsonb_typeof(data->'solde') = 'number' THEN (data->>'solde')::numeric ELSE 0 END
                     FROM public.caisses_batiments WHERE id = p_pays || '_dispensaire_' || p_ville), 0) END;
$function$;

CREATE OR REPLACE FUNCTION public.antipoison_caisse_mouvement_interne(p_pays text, p_ville text, p_batiment text, p_financement text, p_delta numeric)
 RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v jsonb; v_flag text;
BEGIN
  IF coalesce(p_delta, 0) = 0 THEN RETURN true; END IF;
  IF p_financement = 'propre' THEN
    v := public.batiment_caisse_mouvement(p_pays, p_ville, p_batiment, 'sante', p_delta, NULL, 0, NULL, true);
  ELSE
    v_flag := current_setting('rp.caisse_interne', true);
    PERFORM set_config('rp.caisse_interne', 'on', true);
    v := public.caisse_institution_mouvement(p_pays || '_dispensaire_' || p_ville, p_delta, true);
    PERFORM set_config('rp.caisse_interne', coalesce(v_flag, ''), true);
  END IF;
  RETURN coalesce((v->>'ok')::boolean, false); /* medicaments_usines_v1 */
END $function$;

-- Rachat nocturne : chaque centre complète son stock jusqu'à antipoison_stock_cible, au prix du comptoir, dans la
-- limite du stock national et de sa caisse ; boîtes des joueurs d'abord, recette à l'usine.
CREATE OR REPLACE FUNCTION public.antipoison_reapprovisionner_interne()
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE c record; v_jour date := (statement_timestamp() AT TIME ZONE 'Europe/Paris')::date; v_n integer;
        v_cible integer := greatest(0, public.sante_param('antipoison_stock_cible', 5))::integer;
        v_stock integer; v_besoin integer; v_prix integer; v_dispo integer; v_caisse numeric; v_qte integer;
        v_vente jsonb; v_detail jsonb := '[]'::jsonb; v_raison text;
BEGIN
  FOR c IN SELECT * FROM public.antipoison_centres_interne() ORDER BY id LOOP
    INSERT INTO public.antipoison_reapprovisionnements (centre_id, jour) VALUES (c.id, v_jour) ON CONFLICT DO NOTHING;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    CONTINUE WHEN v_n = 0;
    v_stock := public.antipoison_stock_interne(c.id);
    v_besoin := greatest(0, v_cible - v_stock);
    v_prix := public.medicament_prix_pays_interne('antidote', c.pays);
    v_dispo := coalesce((SELECT quantite + quantite_pnj FROM public.medicaments_stocks WHERE pays = c.pays AND medicament = 'antidote'), 0);
    v_caisse := public.antipoison_caisse_lire_interne(c.pays, c.ville, c.building_id, c.financement);
    v_qte := least(v_besoin, v_dispo, CASE WHEN v_prix > 0 THEN floor(v_caisse / v_prix)::integer ELSE v_besoin END);
    v_raison := CASE WHEN v_besoin = 0 THEN 'stock_complet' WHEN v_dispo = 0 THEN 'rupture'
                     WHEN v_qte <= 0 THEN 'caisse_insuffisante' ELSE NULL END;
    IF v_qte > 0 THEN
      IF NOT public.antipoison_caisse_mouvement_interne(c.pays, c.ville, c.building_id, c.financement, -(v_prix * v_qte)) THEN
        v_raison := 'caisse_refusee'; v_qte := 0;
      ELSE
        v_vente := public.medicament_vendre_stock_interne(c.pays, 'antidote', v_qte, v_prix);
        IF coalesce((v_vente->>'ok')::boolean, false) IS NOT TRUE THEN RAISE EXCEPTION 'antipoison: vente refusee %', v_vente; END IF;
        IF public.antipoison_stock_ajuster_interne(c.id, v_qte) IS NULL THEN RAISE EXCEPTION 'antipoison: centre introuvable %', c.id; END IF;
      END IF;
    END IF;
    UPDATE public.antipoison_reapprovisionnements SET quantite = greatest(v_qte, 0), montant = greatest(v_qte, 0) * v_prix, raison = v_raison
     WHERE centre_id = c.id AND jour = v_jour;
    v_detail := v_detail || jsonb_build_array(jsonb_build_object('centre', c.id, 'achetes', greatest(v_qte, 0), 'prix', v_prix,
      'stock', v_stock + greatest(v_qte, 0), 'raison', v_raison));
  END LOOP;
  RETURN jsonb_build_object('ok', true, 'centres', v_detail); /* medicaments_usines_v1 */
END $function$;

-- Centre antipoison (texte de production) : antidote du stock du centre, refus sans stock ; paiement en liquide ;
-- le prix du soin va à la caisse de la structure.
CREATE OR REPLACE FUNCTION public.centre_anti_poison_traiter()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_moi text; m record; v_cout integer; v_taux integer; v_jour date; v_tent integer;
  v_paie jsonb; v_roll integer; v_gueri boolean;
  v_centre text; v_fin text; v_par integer := greatest(1, public.sante_param('antipoison_antidotes_par_soin', 1))::integer; v_reste integer; /* medicaments_usines_v1 */
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT current_building, poison_actif, country, current_city, coalesce(liquide, 0) AS liquide INTO m
    FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  IF coalesce(m.current_building, '') LIKE 'clinique-privee%' THEN v_cout := 150; v_taux := 85;
  ELSIF coalesce(m.current_building, '') LIKE 'dispensaire%' THEN v_cout := 60; v_taux := 65;
  ELSE RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;
  IF coalesce((m.poison_actif ->> 'actif')::boolean, false) IS NOT TRUE THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_empoisonne'); END IF;

  v_jour := (now() AT TIME ZONE 'Europe/Paris')::date;
  SELECT tentatives INTO v_tent FROM public.soins_antipoison_tentatives
   WHERE personnage = v_moi AND jour = v_jour FOR UPDATE;
  IF coalesce(v_tent, 0) >= 2 THEN RETURN jsonb_build_object('ok', false, 'raison', 'limite_journaliere'); END IF;

  -- 8d : le centre soigne avec les antidotes de son propre stock ; sans stock, il ne soigne plus jusqu'au rachat.
  v_centre := m.country || '_' || m.current_city || '_' || m.current_building;
  SELECT c.financement INTO v_fin FROM public.antipoison_centres_interne() c WHERE c.id = v_centre;
  IF v_fin IS NULL OR public.antipoison_stock_interne(v_centre) < v_par THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'plus_d_antidote',
      'message', 'Plus d''antidote, réapprovisionnement en attente.'); END IF;
  -- Point 5 : en liquide seulement.
  IF m.liquide < v_cout THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants', 'requis', v_cout, 'disponible', m.liquide, 'paiement', 'liquide'); END IF;

  v_paie := public.payer_ordre(v_moi, 'centre_anti_poison', 1, v_cout);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;

  v_reste := public.antipoison_stock_ajuster_interne(v_centre, -v_par);
  IF v_reste IS NULL THEN RAISE EXCEPTION 'centre_anti_poison: stock d''antidote indisponible (%)', v_centre; END IF;
  PERFORM public.antipoison_caisse_mouvement_interne(m.country, m.current_city, m.current_building, v_fin, v_cout);

  INSERT INTO public.soins_antipoison_tentatives (personnage, jour, tentatives) VALUES (v_moi, v_jour, 1)
  ON CONFLICT (personnage, jour) DO UPDATE SET tentatives = public.soins_antipoison_tentatives.tentatives + 1;

  v_roll := floor(random() * 100)::integer + 1;
  v_gueri := v_roll <= v_taux;
  IF v_gueri THEN
    UPDATE public.personnages_donnees SET poison_actif = NULL, stats_affaiblies = '{}'::jsonb WHERE name = v_moi;
  END IF;

  RETURN (SELECT jsonb_build_object('ok', true, 'gueri', v_gueri, 'taux', v_taux, 'jet', v_roll,
                 'tentatives', coalesce(v_tent, 0) + 1, 'cout', v_cout, 'antidotes_restants', v_reste,
                 'pa', pa, 'liquide', liquide, 'arg', arg)
            FROM public.personnages_donnees WHERE name = v_moi);
END; $function$;

-- ---------------------------------------------------------------------------------------------------------------
-- 9. Antidote pris, empoisonnement annulé au réveil (8d)
-- ---------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.antidote_prendre_interne(p_nom text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_inv jsonb; v_poison jsonb; l jsonb;
BEGIN
  SELECT coalesce(inventory, '[]'::jsonb), poison_actif INTO v_inv, v_poison FROM public.personnages_donnees WHERE name = p_nom FOR UPDATE;
  IF coalesce((v_poison->>'actif')::boolean, false) IS NOT TRUE THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_empoisonne'); END IF;
  IF coalesce((v_poison->>'antidote')::boolean, false) THEN RETURN jsonb_build_object('ok', false, 'raison', 'antidote_deja_pris'); END IF;
  l := public.sovarka_inventaire_ligne_interne(v_inv, ARRAY['medicament_antidote']);
  IF (l->>'i')::integer < 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_de_medicament'); END IF;
  PERFORM public.sovarka_inventaire_retirer_interne(p_nom, l, 1);
  UPDATE public.personnages_donnees SET poison_actif = poison_actif || jsonb_build_object('antidote', true, 'antidotePrisLe', now())
   WHERE name = p_nom;
  RETURN jsonb_build_object('ok', true, 'medicament', 'antidote', 'maladie', 'empoisonnement', 'effet', 'au_reveil')
    || (SELECT jsonb_build_object('inventory', inventory, 'revision', inventory_revision) FROM public.personnages_donnees WHERE name = p_nom); /* medicaments_usines_v1 */
END $function$;

SELECT pg_temp.rp_remplacer('public.medicament_prendre(uuid,text)'::regprocedure,
$a$  SELECT cle INTO v_cle FROM public.maladies_parametres WHERE medicament = p_medicament;
$a$,
$b$  IF p_medicament = 'antidote' THEN /* medicaments_usines_v1_antidote */
    v := public.antidote_prendre_interne(a);
    IF coalesce((v->>'ok')::boolean, false) IS NOT TRUE THEN RETURN v; END IF;
    RETURN public.achat_requete_clore_interne(a, p_requete, 'medicament_prendre', prm, v);
  END IF;
  SELECT cle INTO v_cle FROM public.maladies_parametres WHERE medicament = p_medicament;
$b$, 1, 'medicaments_usines_v1_antidote');

-- Réveil (Dormir) : texte de production intégral (révélation de la MST) ; l'antidote pris annule d'abord l'empoisonnement.
CREATE OR REPLACE FUNCTION public.sante_reveil_interne(p_nom text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE r record; v jsonb; v_perte integer; v_texte text; v_out jsonb := '[]'::jsonb;
        v_jours integer := public.sante_param('mst_fenetre_jours', 10)::integer;
BEGIN
  IF p_nom IS NULL THEN RETURN v_out; END IF;
  -- 8d (Fred, 22/11/2026, soir) : l'antidote pris annule l'empoisonnement au réveil suivant.
  UPDATE public.personnages_donnees SET poison_actif = NULL, stats_affaiblies = '{}'::jsonb
   WHERE name = p_nom AND coalesce((poison_actif->>'actif')::boolean, false) AND coalesce((poison_actif->>'antidote')::boolean, false);
  IF FOUND THEN
    v_texte := 'L''antidote a fait effet pendant la nuit : le poison est neutralisé.';
    PERFORM public.personnage_evenement_ajouter_interne(p_nom, 'antidote_poison_neutralise', v_texte, jsonb_build_object('medicament', 'antidote'));
    v_out := v_out || jsonb_build_array(jsonb_build_object('cle', 'antidote_poison_neutralise', 'texte', v_texte));
  END IF; /* medicaments_usines_v1_reveil */
  FOR r IN SELECT * FROM public.mst_en_attente WHERE nom = p_nom AND revelee_le IS NULL ORDER BY id FOR UPDATE LOOP
    v := public.maladie_contracter_interne(p_nom, 'mst', 'escort');
    IF v IS NOT NULL THEN
      v_perte := coalesce((v->>'sante_perdue')::integer, 0);
      v_texte := 'Ces ' || v_jours || ' derniers jours, vous avez eu des relations avec ' || r.partenaires
        || ' partenaires. L''un d''eux ou l''une d''elles vous a transmis une MST. −' || v_perte || ' points de Santé.';
      PERFORM public.personnage_evenement_ajouter_interne(p_nom, 'mst_revelee', v_texte,
        jsonb_build_object('partenaires', r.partenaires, 'jours', v_jours, 'perte', v_perte, 'maladie', 'mst'));
      v_out := v_out || jsonb_build_array(jsonb_build_object('cle', 'mst_revelee', 'texte', v_texte, 'perte', v_perte,
        'partenaires', r.partenaires));
    END IF;
    UPDATE public.mst_en_attente SET revelee_le = now(), resultat = v WHERE id = r.id;
  END LOOP;
  RETURN v_out; /* sante_maladies_v1_reveil */
END $function$;

-- ---------------------------------------------------------------------------------------------------------------
-- 10. Trousse de premiers secours : recette réglable (8a)
-- ---------------------------------------------------------------------------------------------------------------
SELECT pg_temp.rp_remplacer('public.militaire_trousse_retirer()'::regprocedure,
  'IF v_tex < 1 OR v_med < 1 OR v_des < 1 THEN',
  'IF v_tex < public.sante_param(''trousse_textile'', 1)::integer OR v_med < public.sante_param(''trousse_medicaments'', 1)::integer'
    || ' OR v_des < public.sante_param(''trousse_desinfectant'', 1)::integer THEN /* medicaments_usines_v1_trousse_seuil */',
  1, 'medicaments_usines_v1_trousse_seuil');
SELECT pg_temp.rp_remplacer('public.militaire_trousse_retirer()'::regprocedure,
  'v_tex - 1', 'v_tex - public.sante_param(''trousse_textile'', 1)::integer /* medicaments_usines_v1_trousse_tex */',
  2, 'medicaments_usines_v1_trousse_tex');
SELECT pg_temp.rp_remplacer('public.militaire_trousse_retirer()'::regprocedure,
  'v_med - 1', 'v_med - public.sante_param(''trousse_medicaments'', 1)::integer /* medicaments_usines_v1_trousse_med */',
  2, 'medicaments_usines_v1_trousse_med');
SELECT pg_temp.rp_remplacer('public.militaire_trousse_retirer()'::regprocedure,
  'v_des - 1', 'v_des - public.sante_param(''trousse_desinfectant'', 1)::integer /* medicaments_usines_v1_trousse_des */',
  2, 'medicaments_usines_v1_trousse_des');

-- ---------------------------------------------------------------------------------------------------------------
-- 11. Passe de nuit (une ligne dans api/cron-minuit.js : tâche quotidienne « usines_etat_nuit »)
-- ---------------------------------------------------------------------------------------------------------------
-- Ordre : production des PNJ (8b), rachat d'antidotes par les centres (8d, recette à l'usine), puis reversement de
-- l'excédent des usines d'État à leur tutelle (8c). Chaque étape est rejouable (anti-rejeu par jour).
CREATE OR REPLACE FUNCTION public.usines_etat_nuit()
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE p text; v jsonb; v_prod jsonb := '[]'::jsonb; v_anti jsonb; v_rev jsonb;
BEGIN
  IF NOT public.est_appel_serveur() THEN RETURN jsonb_build_object('ok', false, 'raison', 'reserve_au_serveur'); END IF;
  FOR p IN SELECT DISTINCT pays FROM public.pharmacies_points_vente ORDER BY 1 LOOP
    BEGIN
      v := public.medicaments_pnj_produire_interne(p);
    EXCEPTION WHEN OTHERS THEN
      v := jsonb_build_object('ok', false, 'pays', p, 'raison', 'erreur', 'erreur', SQLERRM);
    END;
    v_prod := v_prod || jsonb_build_array(v);
  END LOOP;
  BEGIN
    v_anti := public.antipoison_reapprovisionner_interne();
  EXCEPTION WHEN OTHERS THEN
    v_anti := jsonb_build_object('ok', false, 'raison', 'erreur', 'erreur', SQLERRM);
  END;
  v_rev := public.usines_reverser_excedent_interne();
  RETURN jsonb_build_object('ok', true, 'production_pnj', v_prod, 'antipoison', v_anti, 'reversements', v_rev); /* medicaments_usines_v1 */
END $function$;

-- ---------------------------------------------------------------------------------------------------------------
-- 12. Droits
-- ---------------------------------------------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.medicaments_catalogue_interne() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.medicament_prix_pays_interne(text, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.medicament_matiere_lot_interne(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.medicament_vendre_stock_interne(text, text, integer, integer) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.medicaments_pnj_produire_interne(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.usines_etat_liste_interne() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.usine_reverser_interne(text, text, text, text, numeric, text, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.usines_reverser_excedent_interne() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.antipoison_centres_interne() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.antipoison_stock_interne(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.antipoison_stock_ajuster_interne(text, integer) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.antipoison_caisse_lire_interne(text, text, text, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.antipoison_caisse_mouvement_interne(text, text, text, text, numeric) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.antipoison_reapprovisionner_interne() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.antidote_prendre_interne(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.usines_etat_nuit() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.usines_etat_nuit() TO service_role;
REVOKE ALL ON FUNCTION public.usine_tutelle_etat() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.usine_tutelle_etat() TO authenticated, service_role;

-- ---------------------------------------------------------------------------------------------------------------
-- 13. Contrôles
-- ---------------------------------------------------------------------------------------------------------------
DO $$
BEGIN
  IF (SELECT count(*) FROM public.medicaments_catalogue_interne()) < 6
     OR NOT EXISTS (SELECT 1 FROM public.medicaments_catalogue_interne() WHERE medicament = 'antidote') THEN
    RAISE EXCEPTION 'medicaments_usines : catalogue sans antidote'; END IF;
  IF public.medicament_prix_pays_interne('antidote', 'republic') <= public.medicament_prix_pays_interne('antibiotique', 'republic') THEN
    RAISE EXCEPTION 'medicaments_usines : l''antidote doit être plus cher'; END IF;
  IF position('medicaments_usines_v1_reveil' IN pg_get_functiondef('public.sante_reveil_interne(text)'::regprocedure)) = 0
     OR position('sante_maladies_v1_reveil' IN pg_get_functiondef('public.sante_reveil_interne(text)'::regprocedure)) = 0 THEN
    RAISE EXCEPTION 'medicaments_usines : réveil incomplet'; END IF;
  IF (SELECT count(*) FROM public.usines_etat_liste_interne()) = 0 THEN RAISE EXCEPTION 'medicaments_usines : aucune usine d''État'; END IF;
END $$;
