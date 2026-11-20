-- CRIMINALITÉ — décisions de Fred du 20/11/2026 sur les valeurs provisoires (GAME-DESIGN-CRIMINALITE.md, « Décisions du 20/11/2026 »).
-- Idempotente (raccords marqués, ON CONFLICT, CREATE OR REPLACE). Essayée d'abord dans une transaction annulée.
--  2  Neutralisation : rien à changer (la victime tombe à 0 PA → régime d'hospitalisation pa0, sortie à 20 PA).
--  3-4 Tenue ninja : retirée des armuriers ; fabriquée au marché (1 textile + 1 PA = 1 tenue, prix = 2 × coût de revient :
--      110 FR, 32 PSK) et dans les commerces « Vêtements » (civil et militaire) ; masque de carnaval aussi (civil).
--  5  Porte crochetée : la serrure reste ouverte pour tout le monde jusqu'à ce que le propriétaire la referme avec sa clé.
--  6  GHB : toute boisson bue dans la journée compte (trace boissons_du_jour) ; accroche prête pour la bouteille d'eau.
--  7  Polonium : 150 PSK.
--  9  Échec critique d'une rumeur : annonce nationale (pays du lanceur).
--  11 Gilet pare-balles : un seul objet (fiche unique, gilets militaires ralignés, migration des gilets détenus).
--  12 Vol : documents et dotation militaire volables (catégorie « document ») ; quête, revêtu, immobilier, objets de poste protégés.
--  13 Laissez-passer : l'accès aux archives d'écoute se fait sur présentation d'un document physique (volable).
--  14 Faux laissez-passer au greffe et à l'imprimante papier, identique à un vrai.
--  15 DIS : règle symétrique (+1 / −1 par tranche de 3 autour de 50) pour l'empoisonnement, les explosifs, l'incendie,
--      le crochetage et la rumeur.
--  16 Marché noir : plus aucun bonus de carrière (le renseignement et l'escort perdent leur +15 ; les malus restent).
-- Écarts : rébellion réussie 2 j ; peines automatiques de Sovarka doublées ; progression nocturne du poison au serveur.
BEGIN;

CREATE OR REPLACE FUNCTION pg_temp.rp_raccorder(p_fn regprocedure, p_avant text, p_apres text, p_marque text)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE d text := pg_get_functiondef(p_fn);
BEGIN
  IF position(p_marque IN d) > 0 THEN RETURN; END IF;
  IF (length(d) - length(replace(d, p_avant, ''))) / length(p_avant) <> 1 THEN
    RAISE EXCEPTION '% : ancrage introuvable ou multiple (%)', p_fn, left(p_avant, 60); END IF;
  EXECUTE replace(d, p_avant, p_apres);
  IF position(p_marque IN pg_get_functiondef(p_fn)) = 0 THEN RAISE EXCEPTION '% : raccord absent', p_fn; END IF;
END $$;

-- ── Paramètres ──────────────────────────────────────────────────────────────────────────────────────────────────────
INSERT INTO public.crim_parametres (cle, valeur) VALUES
  ('peine_jours_se_rebeller_republic', 2),   -- rébellion réussie : 2 jours (Fred)
  ('peine_facteur_soviet', 2),               -- peines automatiques de Sovarka : doublées (Fred)
  ('prix_tenue_ninja_republic', 110),        -- (1 textile 5 FR + 1 PA 50 FR) × 2
  ('prix_tenue_ninja_soviet', 32)            -- (1 textile 1 PSK + 1 PA 15 PSK) × 2
ON CONFLICT (cle) DO UPDATE SET valeur = EXCLUDED.valeur;

-- ── Peines : référence de l'empire et peines automatiques (Sovarka × 2) ─────────────────────────────────────────────
-- Référence (inchangée) : paramètre propre à l'empire, sinon Républia, sinon barème. Sert au juge.
CREATE OR REPLACE FUNCTION public.crim_peine_reference_interne(p_acte text, p_pays text)
RETURNS integer LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  WITH c AS (SELECT coalesce((SELECT a.canonique FROM public.infractions_alias a WHERE a.alias = p_acte), p_acte) AS id)
  SELECT coalesce(
    (SELECT valeur FROM public.crim_parametres, c WHERE cle = 'peine_jours_' || c.id || '_' || coalesce(p_pays, 'republic')),
    (SELECT valeur FROM public.crim_parametres, c WHERE cle = 'peine_jours_' || c.id || '_republic'),
    (SELECT i.jours_reference FROM public.infractions i, c WHERE i.id = c.id),
    (SELECT a.peine_jours FROM public.actes_illegaux a, c WHERE a.fn = c.id),
    (SELECT k.jours_reference FROM public.actes_illegaux a JOIN public.infractions_categories k ON k.id = a.type, c WHERE a.fn = c.id),
    (SELECT k.jours_reference FROM public.infractions_categories k, c WHERE k.id = c.id))::integer;
$$;
-- Peine automatique : paramètre explicite de l'empire s'il existe, sinon la référence de Républia × facteur de l'empire
-- (peine_facteur_<empire>, 1 par défaut : les empires non ouverts reprennent Républia ; Sovarka : 2).
CREATE OR REPLACE FUNCTION public.crim_peine_jours_interne(p_acte text, p_pays text)
RETURNS integer LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  WITH c AS (SELECT coalesce((SELECT a.canonique FROM public.infractions_alias a WHERE a.alias = p_acte), p_acte) AS id)
  SELECT coalesce(
    (SELECT valeur FROM public.crim_parametres, c WHERE cle = 'peine_jours_' || c.id || '_' || coalesce(p_pays, 'republic'))::integer,
    (public.crim_peine_reference_interne(p_acte, 'republic')
       * public.crim_param_interne('peine_facteur_' || coalesce(p_pays, 'republic'), 1))::integer);
$$;
-- Le juge module autour de la référence (non doublée) : seules les peines automatiques sont doublées.
SELECT pg_temp.rp_raccorder('public.crim_peine_bornes_juge_interne(jsonb,jsonb,text)'::regprocedure,
  $a$v_ref := coalesce(public.crim_peine_jours_interne(p_calc ->> 'infraction', p_pays),$a$,
  $b$v_ref := coalesce(public.crim_peine_reference_interne(p_calc ->> 'infraction', p_pays) /* crim_peine_juge_reference_v1 */,$b$,
  'crim_peine_juge_reference_v1');

-- ── DIS : règle symétrique autour de 50 (tranches tronquées vers zéro, comme le vol) ───────────────────────────────
CREATE OR REPLACE FUNCTION public.crim_bonus_dis_interne(p_dis numeric)
RETURNS integer LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT trunc((coalesce(p_dis, 50) - public.crim_param_interne('crim_dis_pivot', 50)) / public.crim_param_interne('crim_dis_tranche', 3))::integer; /* crim_dis_symetrique_v1 */
$$;
CREATE OR REPLACE FUNCTION public.crim_crocheter_taux_interne(p_dis numeric, p_carriere text)
RETURNS integer LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT round(public.crim_param_interne('crochetage_base', 30)
         + trunc((coalesce(p_dis, 50) - public.crim_param_interne('crochetage_dis_pivot', 50))
                 / public.crim_param_interne('crochetage_dis_tranche', 2))   /* crim_dis_symetrique_v1 */
         + CASE WHEN p_carriere = 'criminal_c' THEN public.crim_param_interne('crochetage_carriere', 15) ELSE 0 END)::integer;
$$;
CREATE OR REPLACE FUNCTION public.crim_rumeur_taux_interne(p_dis numeric, p_cha numeric)
RETURNS integer LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT (public.crim_param_interne('rumeur_taux_base', 60)
          + public.crim_bonus_dis_interne(p_dis)   /* crim_dis_symetrique_v1 */
          + 2 * greatest(0, floor(coalesce(p_cha, 8)) - 8))::integer;
$$;

-- ── Porte crochetée : ouverte pour tous jusqu'à ce que le propriétaire la referme (serrure_basculer, clé requise) ────
SELECT pg_temp.rp_raccorder('public.crim_crocheter(text,text,uuid)'::regprocedure,
  $a$PERFORM public.crim_intrusion_noter_interne(a, po, 'crochetage', (r ->> 'affaire')::bigint);$a$,
  $b$PERFORM public.crim_intrusion_noter_interne(a, po, 'crochetage', (r ->> 'affaire')::bigint);
    UPDATE public.serrures SET fermee = false WHERE id = (po ->> 'serrure')::uuid; /* crim_porte_ouverte_v1 */$b$,
  'crim_porte_ouverte_v1');
-- Plus de passage personnel limité dans le temps : la porte est ouverte (l'intrusion reste notée pour l'enquête,
-- le témoin et les objets ramassés).
CREATE OR REPLACE FUNCTION public.crim_passage_valide_interne(p_nom text, p_serrure uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT false; /* crim_porte_ouverte_v1 */
$$;

-- ── GHB : « a bu dans la journée » = toute boisson ─────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.boissons_du_jour (nom text NOT NULL, jour date NOT NULL, n integer NOT NULL DEFAULT 0,
  PRIMARY KEY (nom, jour));
ALTER TABLE public.boissons_du_jour ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.boissons_du_jour FROM anon, authenticated;
-- Point d'accroche commun : toute boisson bue (alcoolisée ou non) passe ici. La future bouteille d'eau n'a qu'à porter
-- 'boisson': 'non_alcoolisee' (objet) ou une recette étiquetée non_alcoolisee pour laisser sa trace via inventaire_consommer.
CREATE OR REPLACE FUNCTION public.boisson_bue_interne(p_nom text)
RETURNS void LANGUAGE sql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  INSERT INTO public.boissons_du_jour (nom, jour, n) VALUES (p_nom, (now() AT TIME ZONE 'Europe/Paris')::date, 1)
  ON CONFLICT (nom, jour) DO UPDATE SET n = public.boissons_du_jour.n + 1;
$$;
-- Boisson sans alcool servie par une recette (l'alcool passe déjà par maladie_verre_interne).
CREATE OR REPLACE FUNCTION public.boisson_bue_recette_interne(p_nom text, p_recette text)
RETURNS void LANGUAGE sql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT public.boisson_bue_interne(p_nom)
   WHERE p_nom IS NOT NULL AND (SELECT boisson FROM public.recettes_commerce WHERE id = p_recette) = 'non_alcoolisee';
$$;
CREATE OR REPLACE FUNCTION public.crim_a_bu_interne(p_nom text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT EXISTS (SELECT 1 FROM public.boissons_du_jour WHERE nom = p_nom AND jour = (now() AT TIME ZONE 'Europe/Paris')::date AND n > 0)
      OR EXISTS (SELECT 1 FROM public.verres_du_jour WHERE nom = p_nom AND jour = (now() AT TIME ZONE 'Europe/Paris')::date AND n > 0);
$$;
SELECT pg_temp.rp_raccorder('public.maladie_verre_interne(text)'::regprocedure,
  E'BEGIN\n  INSERT INTO public.verres_du_jour',
  E'BEGIN\n  PERFORM public.boisson_bue_interne(p_nom); /* crim_boisson_bue_v1 */\n  INSERT INTO public.verres_du_jour',
  'crim_boisson_bue_v1');
SELECT pg_temp.rp_raccorder('public.inventaire_consommer(text,integer,jsonb)'::regprocedure,
  $a$IF v_boisson='alcoolisee' THEN PERFORM public.maladie_verre_interne(p_acteur); END IF;$a$,
  $b$IF v_boisson='alcoolisee' THEN PERFORM public.maladie_verre_interne(p_acteur); END IF;
   IF v_boisson='non_alcoolisee' THEN PERFORM public.boisson_bue_interne(p_acteur); END IF; /* crim_boisson_bue_v1 */$b$,
  'crim_boisson_bue_v1');
SELECT pg_temp.rp_raccorder('public.tournee_cloturer_boire(text)'::regprocedure,
  $a$PERFORM public.maladie_verre_interne(x) FROM unnest(v_participants||ARRAY[v_moi]) x WHERE public.boisson_alcoolisee_interne(t.recette_id);$a$,
  $b$PERFORM public.maladie_verre_interne(x) FROM unnest(v_participants||ARRAY[v_moi]) x WHERE public.boisson_alcoolisee_interne(t.recette_id);
   PERFORM public.boisson_bue_recette_interne(x, t.recette_id) FROM unnest(v_participants||ARRAY[v_moi]) x; /* crim_boisson_bue_v1 */$b$,
  'crim_boisson_bue_v1');
SELECT pg_temp.rp_raccorder('public.service_etage_commander(uuid,text)'::regprocedure,
  $a$IF public.boisson_alcoolisee_interne(p_produit) THEN PERFORM public.maladie_verre_interne(moi); END IF;$a$,
  $b$PERFORM public.boisson_bue_recette_interne(moi, p_produit); /* crim_boisson_bue_v1 */
  IF public.boisson_alcoolisee_interne(p_produit) THEN PERFORM public.maladie_verre_interne(moi); END IF;$b$,
  'crim_boisson_bue_v1');
SELECT pg_temp.rp_raccorder('public.consommer_sur_place_commerce(text,text,text,text)'::regprocedure,
  $a$IF public.boisson_alcoolisee_interne(v_ref->>'recette_id') THEN PERFORM public.maladie_verre_interne(v_nom); END IF;$a$,
  $b$PERFORM public.boisson_bue_recette_interne(v_nom, v_ref->>'recette_id'); /* crim_boisson_bue_v1 */
 IF public.boisson_alcoolisee_interne(v_ref->>'recette_id') THEN PERFORM public.maladie_verre_interne(v_nom); END IF;$b$,
  'crim_boisson_bue_v1');
SELECT pg_temp.rp_raccorder('public.diner_commerce_servir_interne(text,bigint)'::regprocedure,
  $a$IF public.boisson_alcoolisee_interne(cfg->>'boisson') THEN -- maladies_boissons_v1$a$,
  $b$PERFORM public.boisson_bue_recette_interne(moi, cfg->>'boisson'); /* crim_boisson_bue_v1 */
    IF NOT i.invite_pnj THEN PERFORM public.boisson_bue_recette_interne(i.invite, cfg->>'boisson'); END IF;
    IF public.boisson_alcoolisee_interne(cfg->>'boisson') THEN -- maladies_boissons_v1$b$,
  'crim_boisson_bue_v1');

-- ── Polonium : 150 PSK (plus vendu au port orphelin de Novomirsk ; reste le marché noir de Sovarka) ────────────────
DELETE FROM public.ordres_couts WHERE fn = 'acheter_polonium' AND pa = 2 AND cost = 600;
INSERT INTO public.ordres_couts (fn, pa, cost) SELECT 'acheter_polonium', 2, 150
 WHERE NOT EXISTS (SELECT 1 FROM public.ordres_couts WHERE fn = 'acheter_polonium' AND pa = 2 AND cost = 150);

-- ── Rumeur : l'échec critique s'annonce dans le pays du lanceur ────────────────────────────────────────────────────
SELECT pg_temp.rp_raccorder('public.rumeur_lancer(text,text,text,text,integer,integer)'::regprocedure,
  $a$PERFORM public.annonce_publique_interne('global', '🗯 ' || v_moi || ' a tenté de répandre des calomnies sur ' || v_label || '.');$a$,
  $b$PERFORM public.annonce_publique_interne(coalesce((SELECT country FROM public.personnages_donnees WHERE name = v_moi), 'republic') /* crim_rumeur_nationale_v1 */,
      '🗯 ' || v_moi || ' a tenté de répandre des calomnies sur ' || v_label || '.');$b$,
  'crim_rumeur_nationale_v1');

-- ── Marché noir : plus aucun bonus de carrière ─────────────────────────────────────────────────────────────────────
SELECT pg_temp.rp_raccorder('public.crime_acheter_arme_noire(text,text,boolean)'::regprocedure,
  $a$/* crim_marche_noir_sans_bonus_v1 */ WHEN 'intel' THEN 15 WHEN 'escort' THEN 15$a$,
  $b$/* crim_marche_noir_sans_bonus_v1 crim_marche_noir_sans_bonus_v2 */$b$,
  'crim_marche_noir_sans_bonus_v2');

-- ── Objets portables : tenue ninja et masque fabriqués (marché, commerces « Vêtements ») ───────────────────────────
CREATE OR REPLACE FUNCTION public.crim_objet_categorie_interne(p_item jsonb)
RETURNS text LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE
    WHEN jsonb_typeof(p_item) <> 'object' THEN NULL
    WHEN nullif(p_item ->> 'revetable', '') IS NOT NULL THEN p_item ->> 'revetable'
    WHEN p_item ->> 'produitMilitaire' = 'gilet_pare_balles' THEN 'gilet'
    WHEN p_item ->> 'type' = 'protection' AND p_item ->> 'name' ILIKE 'gilet%' THEN 'gilet'
    -- Tenue et masque fabriqués : le marché dépose 'type' = id de recette, un commerce de joueur 'recette_id'.
    WHEN coalesce(nullif(p_item ->> 'recette_id', ''), p_item ->> 'type') IN ('tenue_ninja_marche', 'tenue_ninja_militaire') THEN 'tenue_ninja'
    WHEN coalesce(nullif(p_item ->> 'recette_id', ''), p_item ->> 'type') = 'masque_carnaval_habillement' THEN 'masque'
  END; /* crim_tenue_fabriquee_v1 */
$$;

INSERT INTO public.recettes_commerce (id, source, label, pa, portions, materiaux, categorie, types_autorises, pays_autorises,
  villes_autorisees, buildings_autorises, icone, image, description, famille_produit_marche, bonus_integration_ville, generique_id, sous_type) VALUES
 ('tenue_ninja_marche', 'marche', 'Tenue ninja', 1, 1, '{"textile":1}', 'objet', '["marche"]', '["republic","soviet"]',
  '["capitale","ville_a","ville_b"]', '["marche","marche-psm"]', 'ti-shirt', NULL,
  'Noire de la tête aux pieds. Revêtue : +15 % pour se cacher, −15 % aux fouilles qui vous visent.', 'vetement', NULL,
  'accessoire-vestimentaire', 'civil'),
 ('tenue_ninja_militaire', 'commerce', 'Tenue ninja', 1, 1, '{"textile":1}', 'objet', NULL, NULL, NULL, NULL, 'ti-shirt', NULL,
  'Noire de la tête aux pieds. Revêtue : +15 % pour se cacher, −15 % aux fouilles qui vous visent.', NULL, NULL,
  'accessoire-militaire', 'militaire'),
 ('masque_carnaval_habillement', 'commerce', 'Masque de carnaval', 1, 2, '{"textile":1}', 'objet', NULL, NULL, NULL, NULL, 'ti-mask', NULL,
  'Revêtu, vous n''êtes plus qu''un « individu masqué » pour ceux qui vous croisent. Il tombe à l''arrestation.', NULL, NULL,
  'accessoire-vestimentaire', 'civil')
ON CONFLICT (id) DO NOTHING;

-- Cartes des marchés : la tenue ninja s'ajoute (marchés de Républia déjà ouverts, dotations des marchés à venir).
UPDATE public.entreprises
   SET data = jsonb_set(jsonb_set(jsonb_set(data, '{carte}', coalesce(data -> 'carte', '[]'::jsonb) || '["tenue_ninja_marche"]'::jsonb),
              '{parametres,prixVente,tenue_ninja_marche}', '110'::jsonb, true),
              '{parametres,stockMax,tenue_ninja_marche}', '20'::jsonb, true),
       updated_at = now()
 WHERE id IN ('marche-republic-capitale-marche', 'marche-republic-ville_b-marche', 'marche-republic-ville_a-marche-psm-etals')
   AND NOT (coalesce(data -> 'carte', '[]'::jsonb) ? 'tenue_ninja_marche')
   AND jsonb_typeof(data -> 'parametres') = 'object';
UPDATE public.commerces_dotations
   SET carte = coalesce(carte, '[]'::jsonb) || '["tenue_ninja_marche"]'::jsonb,
       parametres = jsonb_set(jsonb_set(parametres, '{prixVente,tenue_ninja_marche}', to_jsonb(CASE WHEN cle LIKE '%soviet%' THEN 32 ELSE 110 END), true),
                              '{stockMax,tenue_ninja_marche}', '20'::jsonb, true)
 WHERE cle IN ('marche', 'marche-psm|etals', 'marche@ville_b', 'marche@soviet.ville_b')
   AND NOT (coalesce(carte, '[]'::jsonb) ? 'tenue_ninja_marche');
-- Boutique « Équipement discret » : plus de tenue ninja chez les armuriers ; aux marchés qui la fabriquent, la carte
-- du marché la vend (Novomirsk et Starovka, sans carte propre, gardent la vente au comptoir).
UPDATE public.crim_boutiques SET cles = array_remove(cles, 'tenue_ninja')
 WHERE id IN ('armurerie-luthecia', 'armurerie-montrouge', 'chasse-peche-psm', 'armurerie-novomirsk', 'chasse-peche-starovka',
              'marche-luthecia', 'marche-montrouge', 'marche-psm', 'marche-krasnov');

-- ── Gilet pare-balles : un seul objet ──────────────────────────────────────────────────────────────────────────────
UPDATE public.objets_modeles SET objet = jsonb_build_object(
    'name', 'Gilet pare-balles', 'icon', 'ti-shield-check', 'type', 'protection', 'legal', true, 'generique_id', 'gilet',
    'imageUrl', 'images/arme-gilet-republic.webp', 'revetable', 'gilet', 'famille', 'armement',
    'sousTypes', jsonb_build_array('protection_individuelle'),
    'desc', 'Revêtu : −20 % aux attaques à l''arme à feu, −5 % à mains nues ou à l''arme blanche.')
 WHERE id = 'gilet';
-- Ramène toute ligne « gilet » à la fiche unique, en gardant son identité, sa provenance (lot, dotation) et son port.
CREATE OR REPLACE FUNCTION public.crim_gilet_unifier_interne(p_item jsonb)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT CASE WHEN public.crim_objet_categorie_interne(p_item) = 'gilet'
    THEN (p_item - 'sousType' - 'desc' - 'name' - 'icon' - 'imageUrl' - 'type')
         || (SELECT objet - 'generique_id' FROM public.objets_modeles WHERE id = 'gilet')
    ELSE p_item END; /* crim_gilet_unique_v1 */
$$;
-- Retrait d'un gilet à la caserne : la ligne déposée suit la fiche unique (deux ancrages remplacés d'un coup).
DO $$
DECLARE f regprocedure := 'public.militaire_retrait(text,text,integer,text,text,integer)'::regprocedure; d text := pg_get_functiondef(f);
  a1 text := E'jsonb_build_array(jsonb_build_object(\n        ''id'', ''mil-''';
  a2 text := $a$coalesce(v_lot ->> 'lot', 'legacy') || '.'));$a$;
BEGIN
  IF position('crim_gilet_unique_v1' IN d) > 0 THEN RETURN; END IF;
  IF (length(d) - length(replace(d, a1, ''))) / length(a1) <> 1 OR (length(d) - length(replace(d, a2, ''))) / length(a2) <> 1 THEN
    RAISE EXCEPTION 'militaire_retrait : ancrage introuvable ou multiple'; END IF;
  EXECUTE replace(replace(d, a1, E'jsonb_build_array(public.crim_gilet_unifier_interne(jsonb_build_object( /* crim_gilet_unique_v1 */\n        ''id'', ''mil-'''),
                  a2, $b$coalesce(v_lot ->> 'lot', 'legacy') || '.')));$b$);
END $$;
-- Gilets déjà détenus : fiche unique, personne ne perd le sien ni l'état revêtu (porte_par conservé).
UPDATE public.personnages_donnees d
   SET inventory = (SELECT jsonb_agg(public.crim_gilet_unifier_interne(e) ORDER BY o) FROM jsonb_array_elements(d.inventory) WITH ORDINALITY t(e, o)),
       updated_at = now()
 WHERE jsonb_typeof(d.inventory) = 'array'
   AND EXISTS (SELECT 1 FROM jsonb_array_elements(d.inventory) e
                WHERE public.crim_objet_categorie_interne(e) = 'gilet' AND e IS DISTINCT FROM public.crim_gilet_unifier_interne(e));
UPDATE public.pnj_possessions SET objet = public.crim_gilet_unifier_interne(objet)
 WHERE public.crim_objet_categorie_interne(objet) = 'gilet' AND objet IS DISTINCT FROM public.crim_gilet_unifier_interne(objet);

-- ── Laissez-passer d'accès (documents physiques) ──────────────────────────────────────────────────────────────────
-- Genres : 'archives_ecoute' (Sovarka) ; QHS et goulag le jour où leur accès sera contrôlé.
CREATE OR REPLACE FUNCTION public.crim_laissez_passer_objet_interne(p_genre text, p_titulaire text)
RETURNS jsonb LANGUAGE sql VOLATILE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT CASE p_genre WHEN 'archives_ecoute' THEN jsonb_strip_nulls(jsonb_build_object(
    'id', 'lp-' || replace(gen_random_uuid()::text, '-', ''), 'type', 'laissez_passer', 'laissez_passer', 'archives_ecoute',
    'name', 'Laissez-passer — archives d''écoute', 'icon', 'ti-id-badge', 'legal', true, 'stackable', false, 'titulaire', p_titulaire,
    'desc', 'Délivré par le ministère de la Sécurité du Peuple' || coalesce(' à ' || p_titulaire, '')
            || '. Ouvre les archives des centres d''écoute de Sovarka à qui le présente.')) END;
$$;
-- Le contrôle d'entrée regarde le document, pas le nom (un laissez-passer volé ou faux ouvre aussi).
CREATE OR REPLACE FUNCTION public.crim_laissez_passer_detenu_interne(p_nom text, p_genre text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT EXISTS (SELECT 1 FROM public.personnages_donnees d,
                   jsonb_array_elements(CASE WHEN jsonb_typeof(d.inventory) = 'array' THEN d.inventory ELSE '[]'::jsonb END) e
                  WHERE d.name = p_nom AND e ->> 'laissez_passer' = p_genre);
$$;
CREATE OR REPLACE FUNCTION public.crim_laissez_passer_remettre_interne(p_nom text, p_genre text, p_par text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE o jsonb := public.crim_laissez_passer_objet_interne(p_genre, p_nom); r jsonb;
BEGIN
  IF o IS NULL THEN RETURN; END IF;
  r := public.inventaire_deposer_interne(p_nom, o);
  IF coalesce((r ->> 'ok')::boolean, false) IS NOT TRUE THEN   -- inventaire plein : le sas de réception le livrera
    INSERT INTO public.objets_recus (id, destinataire, expediteur, data) VALUES (o ->> 'id', p_nom, coalesce(p_par, 'Ministère'), o);
  END IF;
END $$;
-- Retrait (en attendant la décision de Fred) : le document est confisqué s'il est dans l'inventaire du titulaire ;
-- sinon l'habilitation reste retirée au registre mais le document circule.
CREATE OR REPLACE FUNCTION public.crim_laissez_passer_confisquer_interne(p_nom text, p_genre text)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_avant integer; v_apres integer;
BEGIN
  SELECT jsonb_array_length(inventory) INTO v_avant FROM public.personnages_donnees WHERE name = p_nom AND jsonb_typeof(inventory) = 'array' FOR UPDATE;
  IF v_avant IS NULL THEN RETURN 0; END IF;
  UPDATE public.personnages_donnees d
     SET inventory = coalesce((SELECT jsonb_agg(e ORDER BY o) FROM jsonb_array_elements(d.inventory) WITH ORDINALITY t(e, o)
                                WHERE NOT coalesce(e ->> 'laissez_passer' = p_genre AND e ->> 'titulaire' = p_nom, false)), '[]'::jsonb),
         updated_at = now()
   WHERE d.name = p_nom RETURNING jsonb_array_length(d.inventory) INTO v_apres;
  DELETE FROM public.objets_recus WHERE destinataire = p_nom AND data ->> 'laissez_passer' = p_genre AND data ->> 'titulaire' = p_nom;
  RETURN v_avant - v_apres;
END $$;
SELECT pg_temp.rp_raccorder('public.sovarka_habilitation_accorder(text)'::regprocedure,
  $a$IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'deja_habilite'); END IF;$a$,
  $b$IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'deja_habilite'); END IF;
  PERFORM public.crim_laissez_passer_remettre_interne(n, 'archives_ecoute', 'Ministère de la Sécurité du Peuple'); /* crim_laissez_passer_v1 */$b$,
  'crim_laissez_passer_v1');
SELECT pg_temp.rp_raccorder('public.sovarka_habilitation_retirer(text)'::regprocedure,
  $a$IF n IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_habilite'); END IF;$a$,
  $b$IF n IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_habilite'); END IF;
  PERFORM public.crim_laissez_passer_confisquer_interne(n, 'archives_ecoute'); /* crim_laissez_passer_v1 */$b$,
  'crim_laissez_passer_v1');
SELECT pg_temp.rp_raccorder('public.sovarka_ecoute_archives_consulter(text,text)'::regprocedure,
  $a$IF NOT EXISTS (SELECT 1 FROM public.sovarka_habilitations_ecoute WHERE beneficiaire = a) THEN$a$,
  $b$IF NOT public.crim_laissez_passer_detenu_interne(a, 'archives_ecoute') /* crim_laissez_passer_v1 */ THEN$b$,
  'crim_laissez_passer_v1');
-- Habilités d'avant le document (aucun à la date de la migration) : on leur remet le leur.
DO $$ DECLARE h record; BEGIN
  FOR h IN SELECT beneficiaire FROM public.sovarka_habilitations_ecoute LOOP
    IF NOT public.crim_laissez_passer_detenu_interne(h.beneficiaire, 'archives_ecoute') THEN
      PERFORM public.crim_laissez_passer_remettre_interne(h.beneficiaire, 'archives_ecoute', 'Ministère de la Sécurité du Peuple');
    END IF;
  END LOOP;
END $$;

-- ── Faux laissez-passer (greffe et imprimante papier) : identique à un vrai ───────────────────────────────────────
CREATE OR REPLACE FUNCTION public.faux_document_objet_interne(p_doc text)
RETURNS jsonb LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE p_doc
    WHEN 'fausse_identite' THEN '{"name":"Fausse identite","icon":"ti-id-badge","desc":"Change votre nom affiche dans le jeu temporairement."}'
    WHEN 'faux_permis' THEN '{"name":"Faux permis de construire","icon":"ti-building","desc":"Permet de construire sans passer par la mairie."}'
    WHEN 'faux_contrat' THEN '{"name":"Faux contrat commercial","icon":"ti-file-text","desc":"Legitime une transaction illegale ou un transfert."}'
    WHEN 'fausse_convocation' THEN '{"name":"Fausse convocation officielle","icon":"ti-mail","desc":"Attire un PJ dans un lieu de votre choix."}'
    WHEN 'faux_laissez_passer' THEN '{"name":"Laissez-passer — archives d''écoute","icon":"ti-id-badge","desc":"Ouvre les archives des centres d''écoute de Sovarka à qui le présente."}'
  END::jsonb; /* crim_faux_lp_v1 */
$$;
-- Objet remis à la réussite : un faux laissez-passer est un vrai laissez-passer (au nom du faussaire), sans marque.
CREATE OR REPLACE FUNCTION public.faux_document_final_interne(p_doc_objet jsonb, p_doc text, p_auteur text)
RETURNS jsonb LANGUAGE sql VOLATILE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT CASE WHEN p_doc = 'faux_laissez_passer' THEN public.crim_laissez_passer_objet_interne('archives_ecoute', p_auteur)
    ELSE p_doc_objet || jsonb_build_object('id', 'faux-' || replace(gen_random_uuid()::text, '-', ''),
           'type', 'document_falsifie', 'docId', p_doc, 'legal', false) END;
$$;
SELECT pg_temp.rp_raccorder('public.crime_falsifier(text,integer,integer)'::regprocedure,
  $a$IF v_doc IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'document_inconnu'); END IF;$a$,
  $b$v_doc := public.faux_document_objet_interne(p_doc); /* crim_faux_lp_v1 */
  IF v_doc IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'document_inconnu'); END IF;$b$,
  'crim_faux_lp_v1');
SELECT pg_temp.rp_raccorder('public.crime_falsifier(text,integer,integer)'::regprocedure,
  E'jsonb_build_array(v_doc || jsonb_build_object(''id'', ''faux-'' || replace(gen_random_uuid()::text, ''-'', ''''),\n            ''type'', ''document_falsifie'', ''docId'', p_doc, ''legal'', false))',
  'jsonb_build_array(public.faux_document_final_interne(v_doc, p_doc, v_moi)) /* crim_faux_lp_v2 */',
  'crim_faux_lp_v2');
SELECT pg_temp.rp_raccorder('public.faux_document_imprimer(text)'::regprocedure,
  E'jsonb_build_array(v_doc || jsonb_build_object(''id'', ''faux-'' || replace(gen_random_uuid()::text, ''-'', ''''),\n            ''type'', ''document_falsifie'', ''docId'', p_doc, ''legal'', false))',
  'jsonb_build_array(public.faux_document_final_interne(v_doc, p_doc, a)) /* crim_faux_lp_v2 */',
  'crim_faux_lp_v2');

-- ── Vol : documents et dotation militaire volables ─────────────────────────────────────────────────────────────────
-- Protégés : objets revêtus, objets de quête, biens immobiliers, objets de poste. Nouvelle catégorie nommable « document ».
CREATE OR REPLACE FUNCTION public.crim_vol_categorie_interne(p_item jsonb)
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT CASE
    WHEN p_item IS NULL OR jsonb_typeof(p_item) <> 'object' THEN NULL
    WHEN coalesce(p_item ->> 'porte_par', '') <> '' THEN NULL
    WHEN p_item ?| ARRAY['calepinEnigme1', 'quete', 'lie_poste', 'liePoste', 'titre_propriete', 'bien_id']
      OR coalesce(p_item ->> 'type', '') = 'colis_secret_pat' THEN NULL
    WHEN coalesce(p_item ->> 'type', '') ~ '^(document|acte|titre|extrait|certificat|condamnation|recepisse|permis|passeport|diplome|medaille|bail|contrat|carte_|laissez_passer)'
      OR coalesce(p_item ->> 'type', '') = 'tract' OR p_item ? 'laissez_passer' THEN 'document'
    WHEN coalesce(p_item ->> 'type', '') = 'arme' THEN 'arme'
    WHEN coalesce(p_item ->> 'type', '') ~ '^cle' OR coalesce(p_item ->> 'stackKey', '') ~ '^cle' THEN 'cle'
    WHEN coalesce(p_item ->> 'type', '') = 'graisse' OR coalesce(p_item ->> 'stackKey', '') = ANY (public.graisse_cles_interne()) THEN 'graisse'
    WHEN coalesce(p_item ->> 'type', '') ~ '^(soin|medicament|pharmacie)' OR coalesce(p_item ->> 'stackKey', '') ~ '^medicament' THEN 'medicament'
    WHEN public.aliment_objet_comestible_interne(p_item) OR coalesce(p_item ->> 'stackKey', '') IN ('cereales', 'produits_exotiques', 'viande_renne')
      OR coalesce(p_item ->> 'type', '') IN ('nourriture', 'aliment', 'repas') THEN 'nourriture'
    WHEN coalesce(p_item ->> 'type', '') = 'vetement' OR coalesce((p_item ->> 'revetable')::text, '') = 'true'
      OR public.crim_objet_categorie_interne(p_item) IS NOT NULL OR coalesce(p_item ->> 'famille', '') = 'habillement' THEN 'vetement'
    ELSE 'autre' END; /* crim_vol_documents_v1 */
$$;
SELECT pg_temp.rp_raccorder('public.crime_voler(text,text,text,uuid)'::regprocedure,
  $a$NOT IN ('arme', 'cle', 'medicament', 'nourriture', 'vetement', 'graisse')$a$,
  $b$NOT IN ('arme', 'cle', 'medicament', 'nourriture', 'vetement', 'graisse', 'document') /* crim_vol_documents_v1 */$b$,
  'crim_vol_documents_v1');

-- ── Empoisonnement : progression nocturne au serveur (valeurs inchangées) ─────────────────────────────────────────
-- Chaque Dormir réussi divise les PV par deux ; sous 20, PV 0 et hospitalisation d'urgence (clinique pour le président,
-- le Premier ministre et les ministres, dispensaire sinon ; 6/4/2 jours au dispensaire, 3/2/1 en clinique selon le palier).
CREATE OR REPLACE FUNCTION public.crim_poison_nuit_interne(p_nom text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE d record; v_hp integer; v_palier text; v_lieu text; v_duree integer;
        v_jour date := (statement_timestamp() AT TIME ZONE 'Europe/Paris')::date;
BEGIN
  SELECT hp, poison_actif, poste INTO d FROM public.personnages_donnees WHERE name = p_nom FOR UPDATE;
  IF NOT FOUND OR coalesce((d.poison_actif ->> 'actif')::boolean, false) IS NOT TRUE THEN RETURN '{}'::jsonb; END IF;
  v_hp := floor(greatest(0, coalesce(d.hp, 0)) / 2.0)::integer;
  IF v_hp < 20 THEN v_hp := 0; END IF;
  IF v_hp > 0 THEN
    UPDATE public.personnages_donnees SET hp = v_hp, updated_at = clock_timestamp() WHERE name = p_nom;
    RETURN jsonb_build_object('empoisonnement', jsonb_build_object('actif', true, 'pv', v_hp, 'fatal', false));
  END IF;
  v_palier := coalesce(nullif(d.poison_actif ->> 'palier', ''), 'partielle');
  v_lieu := CASE WHEN d.poste ->> 'id' IN ('president', 'pm', 'min_int', 'min_fin', 'min_just', 'min_def', 'min_info', 'min_ae')
                 THEN 'clinique' ELSE 'dispensaire' END;
  v_duree := CASE WHEN v_lieu = 'clinique' THEN CASE v_palier WHEN 'totale' THEN 3 WHEN 'partielle' THEN 2 ELSE 1 END
                  ELSE CASE v_palier WHEN 'totale' THEN 6 WHEN 'partielle' THEN 4 ELSE 2 END END;
  UPDATE public.personnages_donnees
     SET hp = 0, pa = 0, poison_actif = NULL, updated_at = clock_timestamp(),
         hospitalisation = jsonb_build_object('palier', v_palier, 'lieu', v_lieu, 'dateDebutParis', v_jour::text,
                                              'dateFinParis', (v_jour + v_duree)::text)
   WHERE name = p_nom;
  PERFORM public.hospitalisation_lieu_rejoindre_interne(p_nom, v_lieu, NULL, false, true);
  RETURN jsonb_build_object('pa', 0, 'empoisonnement', jsonb_build_object('actif', false, 'pv', 0, 'fatal', true,
    'palier', v_palier, 'lieu', v_lieu));
END $$;
SELECT pg_temp.rp_raccorder('public.pa_repos_nocturne(text)'::regprocedure,
  $a$'sortie_possible', NOT v_prison AND v_j >= 2 AND v_nouveau >= 20);$a$,
  $b$'sortie_possible', NOT v_prison AND v_j >= 2 AND v_nouveau >= 20) || public.crim_poison_nuit_interne(p_acteur) /* crim_poison_nuit_v1 */;$b$,
  'crim_poison_nuit_v1');
SELECT pg_temp.rp_raccorder('public.pa_repos_nocturne(text)'::regprocedure,
  $a$'caserne', v_caserne, 'tente', v_tente, 'logement', v_logement);$a$,
  $b$'caserne', v_caserne, 'tente', v_tente, 'logement', v_logement) || public.crim_poison_nuit_interne(p_acteur) /* crim_poison_nuit_v2 */;$b$,
  'crim_poison_nuit_v2');

-- ── Droits : tout est interne ─────────────────────────────────────────────────────────────────────────────────────
DO $$ DECLARE f text; BEGIN
  FOREACH f IN ARRAY ARRAY['crim_peine_reference_interne(text,text)', 'boisson_bue_interne(text)', 'boisson_bue_recette_interne(text,text)',
    'crim_gilet_unifier_interne(jsonb)', 'crim_laissez_passer_objet_interne(text,text)', 'crim_laissez_passer_detenu_interne(text,text)',
    'crim_laissez_passer_remettre_interne(text,text,text)', 'crim_laissez_passer_confisquer_interne(text,text)',
    'faux_document_final_interne(jsonb,text,text)', 'crim_poison_nuit_interne(text)'] LOOP
    EXECUTE format('REVOKE ALL ON FUNCTION public.%s FROM PUBLIC, anon, authenticated', f);
  END LOOP;
END $$;

COMMIT;
