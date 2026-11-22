-- LOT DE KRASNOV, POINT 2 : MARCHÉ DE KRASNOV, INTERFACE UNIQUE (GAME-DESIGN-KRASNOV-LOT-20261120.md, feu vert de Fred
-- le 20/11/2026 ; étape I de la mission de la nuit du 22/11/2026). Point 3 : l'eau déjà puisée y est vendue 2 PSK.
--
-- Une seule fenêtre : la liste des produits et trois colonnes, Acheter / Vendre / Produire. Un seul « Valider » exécute
-- tout ou rien (marche_krasnov_valider). Le serveur décide de tout : prix, stock, caisse, PA, argent, place.
--   * Vendre : ouvert pour tous les produits de la liste, objets compris ; rachat = prix de vente moins 25 %
--     (arrondi à l'unité inférieure, en faveur du marché) ; le produit vendu entre dans le stock et la caisse paie.
--   * Produire : seulement les transformés ; la fournée puise dans le stock du marché et y verse les produits ;
--     le fabricant touche 15 PSK par PA, payés par la caisse du marché.
--   * Caisse du marché : « soviet_marche_ville_b » (caisses_batiments), dotation de départ au premier passage.
--   * Prix des transformés = (matières à 2 PSK + PA à 15 PSK) / unités × 2 : confiture 10, pain noir 8,
--     goulash 13 (non chiffré par Fred : calculé par la formule), chemise 18.
-- Fonctions nouvelles uniquement ; aucune fonction commune modifiée. Le goulag n'est pas touché. Idempotente.
BEGIN;

CREATE TABLE IF NOT EXISTS public.marche_krasnov_produits (
  cle text PRIMARY KEY,
  ordre integer NOT NULL,
  label text NOT NULL,
  genre text NOT NULL CHECK (genre IN ('brut', 'transforme', 'objet')),
  prix_vente integer NOT NULL CHECK (prix_vente > 0),
  prix_rachat integer NOT NULL CHECK (prix_rachat >= 0),
  recette jsonb,                       -- transformés : matières puisées dans le stock du marché, par fournée
  pa integer NOT NULL DEFAULT 0,       -- transformés : PA par fournée
  unites integer NOT NULL DEFAULT 0,   -- transformés : unités produites par fournée
  stock_max integer NOT NULL DEFAULT 60,
  effet text,
  actif boolean NOT NULL DEFAULT true
);
CREATE TABLE IF NOT EXISTS public.marche_krasnov_stock (
  cle text PRIMARY KEY REFERENCES public.marche_krasnov_produits (cle),
  qte integer NOT NULL DEFAULT 0 CHECK (qte >= 0)
);
ALTER TABLE public.marche_krasnov_produits ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.marche_krasnov_stock ENABLE ROW LEVEL SECURITY;

INSERT INTO public.marche_krasnov_produits (cle, ordre, label, genre, prix_vente, prix_rachat, recette, pa, unites, stock_max, effet) VALUES
  ('fruits_legumes', 10, 'Fruits et légumes', 'brut', 2, 1, NULL, 0, 0, 60, 'Se mangent crus : +1 PA au prochain Dormir (un seul repas brut par nuit).'),
  ('oeufs', 20, 'Œufs (lot de 3)', 'brut', 3, 2, NULL, 0, 0, 60, 'Se mangent par 3 : +2 PA au prochain Dormir.'),
  ('viande', 30, 'Volaille (viande)', 'brut', 3, 2, NULL, 0, 0, 60, 'Se mange crue : +1 PA au prochain Dormir, avec un risque d''intoxication.'),
  ('sucre', 40, 'Sucre', 'brut', 2, 1, NULL, 0, 0, 60, 'Sert à faire la confiture.'),
  ('cereales', 50, 'Céréales', 'brut', 2, 1, NULL, 0, 0, 60, 'Servent à faire le pain noir.'),
  ('poisson', 60, 'Poisson', 'brut', 2, 1, NULL, 0, 0, 60, 'Sert à faire le goulash.'),
  ('textile', 70, 'Textile', 'brut', 2, 1, NULL, 0, 0, 60, 'Sert à faire la chemise de bûcheron.'),
  ('bouteille_eau', 80, 'Bouteille d''eau', 'brut', 2, 1, NULL, 0, 0, 60, 'Protège de la canicule ; sert à faire le pain noir. Gratuite à la fontaine de la place de l''Ours.'),
  ('graisse_ours', 90, 'Bocal de graisse d''ours', 'brut', 16, 12, NULL, 0, 0, 30, 'Protège du blizzard (consommé).'),
  ('confiture', 100, 'Confiture d''airelles (bocal)', 'transforme', 10, 7, '{"fruits_legumes":1,"sucre":1}', 1, 4, 60, '+1 PA au prochain Dormir, en plus d''un repas brut.'),
  ('pain_noir', 110, 'Pain noir', 'transforme', 8, 6, '{"cereales":1,"bouteille_eau":1}', 1, 5, 60, '+1 PA au prochain Dormir (c''est un repas : pas en plus d''un repas brut).'),
  ('goulash', 120, 'Portion de goulash', 'transforme', 13, 9, '{"fruits_legumes":1,"poisson":1}', 1, 3, 60, '+2 PA tout de suite.'),
  ('chemise', 130, 'Chemise de bûcheron à carreaux', 'transforme', 18, 13, '{"textile":1}', 1, 2, 30, 'À revêtir : +1 ENT tant que vous êtes à Krasnov (effet perdu si vous revêtez la tenue ninja ou le gilet).'),
  ('tenue_ninja', 140, 'Tenue ninja', 'objet', 32, 24, NULL, 0, 0, 10, 'Revêtue : +15 % pour se cacher, −15 % aux fouilles qui vous visent.'),
  ('masque_carnaval', 150, 'Masque de carnaval', 'objet', 20, 15, NULL, 0, 0, 10, 'Revêtu, vous n''êtes plus qu''un « personnage masqué » pour ceux qui vous croisent.')
ON CONFLICT (cle) DO NOTHING;

INSERT INTO public.marche_krasnov_stock (cle, qte) VALUES
  ('fruits_legumes', 20), ('oeufs', 10), ('viande', 10), ('sucre', 10), ('cereales', 10), ('poisson', 10), ('textile', 10),
  ('bouteille_eau', 30), ('graisse_ours', 10), ('confiture', 8), ('pain_noir', 10), ('goulash', 6), ('chemise', 4),
  ('tenue_ninja', 2), ('masque_carnaval', 2)
ON CONFLICT (cle) DO NOTHING;

-- Réglages : salaire de production (15 PSK par PA), décote de rachat (25 %, pour mémoire : les prix de rachat sont
-- en table), dotation de départ de la caisse (1 000 PSK, valeur provisoire à faire valider par Fred).
INSERT INTO public.aliments_parametres (cle, valeur) VALUES
  ('marche_krasnov_salaire_pa', 15), ('marche_krasnov_decote_rachat_pct', 25), ('marche_krasnov_dotation', 1000)
ON CONFLICT (cle) DO NOTHING;

-- Caisse du marché : dotation de départ (une seule fois).
INSERT INTO public.caisses_batiments (id, data, updated_at)
SELECT 'soviet_marche_ville_b', jsonb_build_object('solde', public.aliments_param_interne('marche_krasnov_dotation', 1000)), now()
WHERE NOT EXISTS (SELECT 1 FROM public.caisses_batiments WHERE id = 'soviet_marche_ville_b');

-- La graisse d'ours de Krasnov passe dans la fenêtre unique (16 PSK) : plus de second guichet au marché.
DELETE FROM public.graisses_points_vente WHERE id = 'marche-krasnov';

-- Objet déposé dans l'inventaire pour une unité du produit (la quantité est posée par l'appelant).
CREATE OR REPLACE FUNCTION public.marche_krasnov_objet_interne(p_cle text)
RETURNS jsonb LANGUAGE sql STABLE SET search_path TO 'public', 'pg_temp' AS $$
  SELECT CASE
    WHEN p_cle IN ('fruits_legumes', 'oeufs', 'viande', 'sucre', 'cereales', 'poisson', 'textile')
      THEN jsonb_build_object('name', p_cle, 'stackable', true, 'stackKey', p_cle, 'qty', 1)
    WHEN p_cle = 'bouteille_eau' THEN public.climat_objet_interne('bouteille_eau', 1)
    WHEN p_cle = 'graisse_ours' THEN public.graisse_objet_interne('graisse_ours', 1)
    WHEN p_cle = 'confiture' THEN jsonb_build_object('name', 'Confiture d''airelles', 'type', 'kolkhoze_confiture_airelles',
      'familleProduitMarche', 'aliment', 'dateAchat', floor(extract(epoch FROM clock_timestamp()) * 1000)::bigint,
      'stackable', true, 'stackKey', 'kolkhoze_confiture_airelles', 'qty', 1, 'icon', 'ti-jar', 'legal', true,
      'desc', 'Un bocal du marché de Krasnov : +1 PA au prochain Dormir, en plus d''un repas brut.')
    WHEN p_cle = 'pain_noir' THEN jsonb_build_object('name', 'Pain noir', 'type', 'krasnov_pain_noir', 'stackable', true,
      'stackKey', 'krasnov_pain_noir', 'qty', 1, 'icon', 'ti-bread', 'legal', true,
      'desc', 'Le pain de seigle du marché de Krasnov : +1 PA au prochain Dormir (un repas, pas en plus d''un repas brut).')
    WHEN p_cle = 'goulash' THEN jsonb_build_object('name', 'Portion de goulash', 'type', 'krasnov_goulash', 'stackable', true,
      'stackKey', 'krasnov_goulash', 'qty', 1, 'icon', 'ti-bowl', 'legal', true,
      'desc', 'Le ragoût du marché de Krasnov, servi brûlant : +2 PA tout de suite.')
    WHEN p_cle = 'chemise' THEN jsonb_build_object('name', 'Chemise de bûcheron à carreaux', 'type', 'chemise_bucheron_krasnov',
      'recette_id', 'chemise_bucheron_krasnov', 'generique_id', 'accessoire-vestimentaire', 'revetable', 'chemise',
      'familleProduitMarche', 'integration_locale', 'bonusIntegrationVille', 'soviet.ville_b', 'icon', 'ti-shirt', 'legal', true,
      'desc', 'La flanelle rouge et noire des forestiers. Revêtue : +1 ENT tant que vous êtes à Krasnov (perdu avec la tenue ninja ou le gilet).')
    WHEN p_cle = 'tenue_ninja' THEN jsonb_build_object('name', 'Tenue ninja', 'type', 'tenue_ninja_marche', 'recette_id', 'tenue_ninja_marche',
      'generique_id', 'accessoire-vestimentaire', 'icon', 'ti-shirt', 'imageUrl', 'images/objet-tenue-ninja.webp', 'legal', true,
      'desc', 'Noire de la tête aux pieds. Revêtue : +15 % pour se cacher, −15 % aux fouilles qui vous visent.')
    WHEN p_cle = 'masque_carnaval' THEN jsonb_build_object('name', 'Masque de carnaval', 'type', 'masque_carnaval_habillement',
      'recette_id', 'masque_carnaval_habillement', 'generique_id', 'accessoire-vestimentaire', 'icon', 'ti-mask',
      'imageUrl', 'images/objet-masque-carnaval.webp', 'legal', true,
      'desc', 'Revêtu, vous n''êtes plus qu''un « personnage masqué » pour ceux qui vous croisent. Il tombe à l''arrestation.')
  END;
$$;

-- Clé de pile (produits empilables) ou identifiant d'objet (objets un par un) reconnu dans l'inventaire.
CREATE OR REPLACE FUNCTION public.marche_krasnov_reconnait_interne(p_cle text, p_e jsonb)
RETURNS boolean LANGUAGE sql STABLE SET search_path TO 'public', 'pg_temp' AS $$
  SELECT jsonb_typeof(p_e) = 'object' AND nullif(p_e ->> 'porte_par', '') IS NULL AND CASE
    WHEN p_cle IN ('chemise', 'tenue_ninja', 'masque_carnaval') THEN
      coalesce(nullif(p_e ->> 'recette_id', ''), p_e ->> 'type') = (public.marche_krasnov_objet_interne(p_cle) ->> 'type')
    ELSE coalesce((p_e ->> 'stackable')::boolean, false) AND p_e ->> 'stackKey' = (public.marche_krasnov_objet_interne(p_cle) ->> 'stackKey')
  END;
$$;

-- Quantité de ce produit que le personnage peut vendre (objets portés exclus).
CREATE OR REPLACE FUNCTION public.marche_krasnov_possede_interne(p_inv jsonb, p_cle text)
RETURNS integer LANGUAGE sql STABLE SET search_path TO 'public', 'pg_temp' AS $$
  SELECT coalesce(floor(sum(CASE WHEN p_cle IN ('chemise', 'tenue_ninja', 'masque_carnaval') THEN 1
                                 ELSE greatest(0, coalesce((e ->> 'qty')::numeric, 1)) END)), 0)::integer
    FROM jsonb_array_elements(CASE WHEN jsonb_typeof(p_inv) = 'array' THEN p_inv ELSE '[]'::jsonb END) e
   WHERE public.marche_krasnov_reconnait_interne(p_cle, e);
$$;

-- Retire p_qte unités du produit de l'inventaire donné (renvoie le nouvel inventaire ; NULL si la quantité manque).
CREATE OR REPLACE FUNCTION public.marche_krasnov_retirer_interne(p_inv jsonb, p_cle text, p_qte integer)
RETURNS jsonb LANGUAGE plpgsql STABLE SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_inv jsonb := CASE WHEN jsonb_typeof(p_inv) = 'array' THEN p_inv ELSE '[]'::jsonb END; v_reste integer := coalesce(p_qte, 0);
        r record; v_q numeric; v_pris numeric; v_suppr integer[] := '{}';
BEGIN
  IF v_reste <= 0 THEN RETURN v_inv; END IF;
  IF public.marche_krasnov_possede_interne(v_inv, p_cle) < v_reste THEN RETURN NULL; END IF;
  FOR r IN SELECT (o - 1)::integer AS i, e FROM jsonb_array_elements(v_inv) WITH ORDINALITY x(e, o)
            WHERE public.marche_krasnov_reconnait_interne(p_cle, e)
            ORDER BY public.aliment_recu_interne(e) NULLS FIRST, o LOOP
    EXIT WHEN v_reste <= 0;
    IF p_cle IN ('chemise', 'tenue_ninja', 'masque_carnaval') THEN
      v_suppr := v_suppr || r.i; v_reste := v_reste - 1;
    ELSE
      v_q := greatest(0, coalesce((r.e ->> 'qty')::numeric, 1));
      v_pris := least(v_q, v_reste);
      IF v_q - v_pris <= 0 THEN v_suppr := v_suppr || r.i;
      ELSE v_inv := jsonb_set(v_inv, ARRAY[r.i::text, 'qty'], to_jsonb(v_q - v_pris)); END IF;
      v_reste := v_reste - v_pris::integer;
    END IF;
  END LOOP;
  IF v_reste > 0 THEN RETURN NULL; END IF;
  RETURN (SELECT coalesce(jsonb_agg(e ORDER BY o), '[]'::jsonb) FROM jsonb_array_elements(v_inv) WITH ORDINALITY x(e, o)
           WHERE NOT ((o - 1)::integer = ANY (v_suppr)));
END $$;

-- Argent disponible : liquide puis compte de la banque nationale (même règle que argent_debiter_interne).
CREATE OR REPLACE FUNCTION public.marche_krasnov_argent_interne(p_nom text)
RETURNS numeric LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT greatest(0, coalesce((SELECT liquide FROM public.personnages_donnees WHERE name = p_nom), 0))
       + greatest(0, coalesce((SELECT solde FROM public.comptes_bancaires WHERE personnage = p_nom AND banque = 'nationale' ORDER BY id LIMIT 1), 0));
$$;

CREATE OR REPLACE FUNCTION public.marche_krasnov_caisse_interne()
RETURNS numeric LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT coalesce((SELECT CASE WHEN jsonb_typeof(data -> 'solde') = 'number' THEN (data ->> 'solde')::numeric END
                     FROM public.caisses_batiments WHERE id = 'soviet_marche_ville_b'), 0);
$$;

-- État de la fenêtre : produits, prix, stock du marché, quantités du joueur, caisse, PA, argent, place.
CREATE OR REPLACE FUNCTION public.marche_krasnov_etat()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); d record;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country, current_city, current_building, current_room, pa, inventory INTO d FROM public.personnages_donnees WHERE name = a;
  RETURN jsonb_build_object('ok', true,
    'ici', d.country = 'soviet' AND d.current_city = 'ville_b' AND d.current_building = 'marche' AND d.current_room = 'marche_ext',
    'devise', 'PSK', 'caisse', public.marche_krasnov_caisse_interne(), 'pa', coalesce(d.pa, 0),
    'argent', public.marche_krasnov_argent_interne(a), 'place', public.inventaire_place_restante(d.inventory),
    'salaire_pa', public.aliments_param_interne('marche_krasnov_salaire_pa', 15),
    'produits', coalesce((SELECT jsonb_agg(jsonb_build_object('cle', p.cle, 'label', p.label, 'genre', p.genre,
        'prix_vente', p.prix_vente, 'prix_rachat', p.prix_rachat, 'recette', p.recette, 'pa', p.pa, 'unites', p.unites,
        'stock', coalesce(s.qte, 0), 'stock_max', p.stock_max, 'effet', p.effet,
        'possede', public.marche_krasnov_possede_interne(d.inventory, p.cle),
        'empile', p.cle NOT IN ('chemise', 'tenue_ninja', 'masque_carnaval')) ORDER BY p.ordre)
      FROM public.marche_krasnov_produits p LEFT JOIN public.marche_krasnov_stock s ON s.cle = p.cle WHERE p.actif), '[]'::jsonb));
END $$;

-- Exécute en une fois toutes les lignes { cle, acheter, vendre, produire } : tout ou rien.
-- Ordre : on vend (le stock monte), on produit (la fournée puise et verse dans le stock), on achète.
CREATE OR REPLACE FUNCTION public.marche_krasnov_valider(p_requete uuid, p_lignes jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); prm jsonb := jsonb_build_object('lignes', p_lignes); v jsonb; d record;
  l jsonb; p record; v_cle text; v_q jsonb := '{}'::jsonb; v_a integer; v_v integer; v_p integer;
  v_pa integer := 0; v_gain numeric := 0; v_cout numeric := 0; v_salaire numeric := 0; v_sal_pa numeric;
  v_stock jsonb := '{}'::jsonb; v_avant integer; v_final integer; v_mi text; v_mq jsonb; v_inv jsonb; v_place integer;
  v_besoin_place integer := 0; v_caisse numeric; v_argent numeric; v_dep jsonb; v_obj jsonb; i integer; v_debit numeric;
  v_lignes_ok jsonb := '[]'::jsonb;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_requete IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'requete_absente'); END IF;
  IF jsonb_typeof(p_lignes) IS DISTINCT FROM 'array' THEN RETURN jsonb_build_object('ok', false, 'raison', 'lignes_invalides'); END IF;
  v := public.achat_requete_ouvrir_interne(a, p_requete, 'marche_krasnov_valider', prm);
  IF v IS NOT NULL THEN RETURN v; END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended('marche_krasnov', 0));
  SELECT name, country, current_city, current_building, current_room, pa, inventory, est_emprisonne INTO d
    FROM public.personnages_donnees WHERE name = a FOR UPDATE;
  IF coalesce(jsonb_typeof(d.est_emprisonne), 'null') <> 'null' AND d.est_emprisonne <> 'false'::jsonb THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'emprisonne'); END IF;
  IF (d.country, d.current_city, d.current_building, d.current_room) IS DISTINCT FROM ('soviet', 'ville_b', 'marche', 'marche_ext') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_au_marche'); END IF;

  -- Lecture des lignes (une clé peut revenir : les quantités s'additionnent).
  FOR l IN SELECT value FROM jsonb_array_elements(p_lignes) LOOP
    v_cle := l ->> 'cle';
    IF NOT EXISTS (SELECT 1 FROM public.marche_krasnov_produits WHERE cle = v_cle AND actif) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'produit_inconnu', 'cle', v_cle); END IF;
    v_a := CASE WHEN coalesce(l ->> 'acheter', '0') ~ '^[0-9]{1,4}$' THEN coalesce(l ->> 'acheter', '0')::integer END;
    v_v := CASE WHEN coalesce(l ->> 'vendre', '0') ~ '^[0-9]{1,4}$' THEN coalesce(l ->> 'vendre', '0')::integer END;
    v_p := CASE WHEN coalesce(l ->> 'produire', '0') ~ '^[0-9]{1,4}$' THEN coalesce(l ->> 'produire', '0')::integer END;
    IF v_a IS NULL OR v_v IS NULL OR v_p IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'quantite_invalide', 'cle', v_cle); END IF;
    v_q := jsonb_set(v_q, ARRAY[v_cle], jsonb_build_object(
      'a', coalesce((v_q -> v_cle ->> 'a')::integer, 0) + v_a,
      'v', coalesce((v_q -> v_cle ->> 'v')::integer, 0) + v_v,
      'p', coalesce((v_q -> v_cle ->> 'p')::integer, 0) + v_p));
  END LOOP;
  IF NOT EXISTS (SELECT 1 FROM jsonb_each(v_q) x WHERE (x.value ->> 'a')::integer + (x.value ->> 'v')::integer + (x.value ->> 'p')::integer > 0) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'rien_a_faire'); END IF;

  -- Calculs et contrôles, avant toute écriture.
  v_sal_pa := public.aliments_param_interne('marche_krasnov_salaire_pa', 15);
  FOR p IN SELECT pr.*, coalesce(s.qte, 0) AS stock FROM public.marche_krasnov_produits pr
             LEFT JOIN public.marche_krasnov_stock s ON s.cle = pr.cle WHERE pr.actif LOOP
    v_stock := jsonb_set(v_stock, ARRAY[p.cle], to_jsonb(p.stock));
  END LOOP;
  FOR p IN SELECT pr.* FROM public.marche_krasnov_produits pr WHERE pr.cle IN (SELECT jsonb_object_keys(v_q)) ORDER BY pr.ordre LOOP
    v_a := (v_q -> p.cle ->> 'a')::integer; v_v := (v_q -> p.cle ->> 'v')::integer; v_p := (v_q -> p.cle ->> 'p')::integer;
    IF v_p > 0 AND p.genre <> 'transforme' THEN RETURN jsonb_build_object('ok', false, 'raison', 'production_impossible', 'cle', p.cle, 'label', p.label); END IF;
    IF v_v > public.marche_krasnov_possede_interne(d.inventory, p.cle) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'vous_n_en_avez_pas_assez', 'cle', p.cle, 'label', p.label,
        'possede', public.marche_krasnov_possede_interne(d.inventory, p.cle)); END IF;
    v_pa := v_pa + v_p * p.pa;
    v_gain := v_gain + v_v * p.prix_rachat;
    v_cout := v_cout + v_a * p.prix_vente;
    v_besoin_place := v_besoin_place + v_a;
    v_stock := jsonb_set(v_stock, ARRAY[p.cle], to_jsonb((v_stock ->> p.cle)::integer + v_v + v_p * p.unites));
    IF v_p > 0 THEN
      FOR v_mi, v_mq IN SELECT key, value FROM jsonb_each(p.recette) LOOP
        v_stock := jsonb_set(v_stock, ARRAY[v_mi], to_jsonb((v_stock ->> v_mi)::integer - v_p * (v_mq #>> '{}')::integer));
      END LOOP;
    END IF;
  END LOOP;
  v_salaire := v_pa * v_sal_pa;
  -- Matières de la production : contrôlées avant les achats (on ne fabrique pas avec ce qu'on achète ensuite).
  FOR p IN SELECT pr.* FROM public.marche_krasnov_produits pr WHERE pr.actif ORDER BY pr.ordre LOOP
    IF (v_stock ->> p.cle)::integer < 0 THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'matiere_manquante', 'cle', p.cle, 'label', p.label,
        'manque', -(v_stock ->> p.cle)::integer); END IF;
  END LOOP;
  FOR p IN SELECT pr.*, coalesce(s.qte, 0) AS stock FROM public.marche_krasnov_produits pr
             LEFT JOIN public.marche_krasnov_stock s ON s.cle = pr.cle WHERE pr.cle IN (SELECT jsonb_object_keys(v_q)) ORDER BY pr.ordre LOOP
    v_a := (v_q -> p.cle ->> 'a')::integer;
    v_final := (v_stock ->> p.cle)::integer - v_a;
    IF v_final < 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'stock_insuffisant', 'cle', p.cle, 'label', p.label,
      'disponible', (v_stock ->> p.cle)::integer); END IF;
    IF v_final > p.stock_max AND v_final > p.stock THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'stock_marche_plein', 'cle', p.cle, 'label', p.label, 'stock_max', p.stock_max); END IF;
    v_stock := jsonb_set(v_stock, ARRAY[p.cle], to_jsonb(v_final));
  END LOOP;
  IF coalesce(d.pa, 0) < v_pa THEN RETURN jsonb_build_object('ok', false, 'raison', 'pa_insuffisants', 'requis', v_pa, 'pa', coalesce(d.pa, 0)); END IF;
  v_argent := public.marche_krasnov_argent_interne(a);
  IF v_argent + v_gain + v_salaire < v_cout THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'argent_insuffisant', 'requis', v_cout - v_gain - v_salaire, 'argent', v_argent); END IF;
  v_caisse := public.marche_krasnov_caisse_interne();
  IF v_caisse + v_cout < v_gain + v_salaire THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caisse_vide', 'caisse', v_caisse, 'requis', v_gain + v_salaire - v_cout); END IF;

  -- Inventaire : on retire d'abord ce qui est vendu, puis on vérifie la place pour ce qui est acheté.
  v_inv := d.inventory;
  FOR v_cle IN SELECT key FROM jsonb_each(v_q) WHERE (value ->> 'v')::integer > 0 LOOP
    v_inv := public.marche_krasnov_retirer_interne(v_inv, v_cle, (v_q -> v_cle ->> 'v')::integer);
    IF v_inv IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'vous_n_en_avez_pas_assez', 'cle', v_cle); END IF;
  END LOOP;
  v_place := public.inventaire_place_restante(v_inv);
  IF v_place < v_besoin_place THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'inventaire_plein', 'place', v_place, 'requis', v_besoin_place); END IF;

  -- Écritures : tout ou rien (un échec annule le bloc entier).
  BEGIN
    UPDATE public.personnages_donnees SET inventory = v_inv, pa = coalesce(pa, 0) - v_pa, updated_at = now() WHERE name = a;
    FOR v_cle IN SELECT key FROM jsonb_each(v_q) WHERE (value ->> 'a')::integer > 0 LOOP
      v_a := (v_q -> v_cle ->> 'a')::integer;
      v_obj := public.marche_krasnov_objet_interne(v_cle);
      IF coalesce((v_obj ->> 'stackable')::boolean, false) THEN
        v_dep := public.inventaire_deposer_interne(a, v_obj || jsonb_build_object('qty', v_a));
        IF coalesce((v_dep ->> 'ok')::boolean, false) IS NOT TRUE OR (v_dep ->> 'qte')::integer <> v_a THEN
          RAISE EXCEPTION 'marche_krasnov_depot:%', v_cle; END IF;
      ELSE
        FOR i IN 1 .. v_a LOOP
          v_dep := public.inventaire_deposer_interne(a, v_obj - 'qty');
          IF coalesce((v_dep ->> 'ok')::boolean, false) IS NOT TRUE THEN RAISE EXCEPTION 'marche_krasnov_depot:%', v_cle; END IF;
        END LOOP;
      END IF;
    END LOOP;
    FOR v_cle IN SELECT jsonb_object_keys(v_stock) LOOP
      INSERT INTO public.marche_krasnov_stock (cle, qte) VALUES (v_cle, (v_stock ->> v_cle)::integer)
      ON CONFLICT (cle) DO UPDATE SET qte = EXCLUDED.qte;
    END LOOP;
    IF v_gain + v_salaire > 0 THEN PERFORM public.argent_crediter_interne(a, v_gain + v_salaire, 'liquide'); END IF;
    IF v_cout > 0 THEN
      v_debit := public.argent_debiter_interne(a, v_cout, 'liquide_puis_nationale');
      IF v_debit IS DISTINCT FROM v_cout THEN RAISE EXCEPTION 'marche_krasnov_debit'; END IF;
    END IF;
    IF v_cout - v_gain - v_salaire <> 0 THEN
      PERFORM set_config('rp.caisse_interne', 'on', true);
      v := public.caisse_institution_mouvement('soviet_marche_ville_b', v_cout - v_gain - v_salaire, false);
      IF coalesce((v ->> 'ok')::boolean, false) IS NOT TRUE THEN RAISE EXCEPTION 'marche_krasnov_caisse:%', v ->> 'raison'; END IF;
    END IF;
  EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'echec_execution', 'detail', SQLERRM);
  END;

  FOR v_cle IN SELECT key FROM jsonb_each(v_q) LOOP
    v_lignes_ok := v_lignes_ok || jsonb_build_object('cle', v_cle,
      'label', (SELECT label FROM public.marche_krasnov_produits WHERE cle = v_cle),
      'acheter', (v_q -> v_cle ->> 'a')::integer, 'vendre', (v_q -> v_cle ->> 'v')::integer, 'produire', (v_q -> v_cle ->> 'p')::integer,
      'produits', (v_q -> v_cle ->> 'p')::integer * (SELECT unites FROM public.marche_krasnov_produits WHERE cle = v_cle));
  END LOOP;
  RETURN public.achat_requete_clore_interne(a, p_requete, 'marche_krasnov_valider', prm,
    jsonb_build_object('ok', true, 'depense', v_cout, 'gain_ventes', v_gain, 'salaire', v_salaire, 'pa_depenses', v_pa,
      'lignes', v_lignes_ok, 'pa', (SELECT pa FROM public.personnages_donnees WHERE name = a),
      'etat', public.marche_krasnov_etat()));
END $$;

-- Manger ce qui vient du marché et que l'inventaire commun ne sait pas consommer : pain noir, goulash, fruits et légumes.
-- (La confiture est l'objet existant du kolkhoze, consommée par inventaire_consommer : +1 PA au prochain Dormir, cumulable.)
CREATE OR REPLACE FUNCTION public.marche_krasnov_manger(p_requete uuid, p_cle text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); prm jsonb := jsonb_build_object('cle', p_cle); v jsonb; d record; v_inv jsonb;
        v_pile jsonb; v_avarie boolean := false; v_b integer; v_pa integer; v_mal jsonb; v_stack text;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_cle IS NULL OR p_cle NOT IN ('pain_noir', 'goulash', 'fruits_legumes') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'non_comestible'); END IF;
  v := public.achat_requete_ouvrir_interne(a, p_requete, 'marche_krasnov_manger', prm);
  IF v IS NOT NULL THEN RETURN v; END IF;
  SELECT pa, inventory, est_emprisonne INTO d FROM public.personnages_donnees WHERE name = a FOR UPDATE;
  v_stack := public.marche_krasnov_objet_interne(p_cle) ->> 'stackKey';
  SELECT e INTO v_pile FROM jsonb_array_elements(CASE WHEN jsonb_typeof(d.inventory) = 'array' THEN d.inventory ELSE '[]'::jsonb END) WITH ORDINALITY x(e, o)
   WHERE e ->> 'stackKey' = v_stack AND coalesce((e ->> 'qty')::numeric, 1) >= 1 ORDER BY public.aliment_recu_interne(e) NULLS FIRST, o LIMIT 1;
  IF v_pile IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_dans_l_inventaire', 'cle', p_cle); END IF;
  IF p_cle IN ('pain_noir', 'fruits_legumes') AND public.repas_differe_deja_pris_interne(a, 'repas_brut') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'repas_brut_deja_pris'); END IF;
  v_avarie := public.aliment_pile_avariee_interne(v_pile);
  v_inv := public.marche_krasnov_retirer_interne(d.inventory, p_cle, 1);
  IF v_inv IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_dans_l_inventaire', 'cle', p_cle); END IF;
  UPDATE public.personnages_donnees SET inventory = v_inv, updated_at = now() WHERE name = a;
  IF p_cle = 'goulash' THEN
    UPDATE public.personnages_donnees SET pa = least(public.maladie_pa_plafond_interne(a, coalesce(pa, 0)), greatest(0, coalesce(pa, 0) + 2))
     WHERE name = a RETURNING pa INTO v_pa;
  ELSE
    v_b := public.repas_differe_crediter_interne(a, 'repas_brut', 'repas_brut');
  END IF;
  IF v_avarie THEN
    v_mal := public.maladie_tirer_interne(a, 'intoxication', public.maladie_risque_interne('intoxication', 'aliment_avarie'), 'aliment_avarie');
  END IF;
  RETURN public.achat_requete_clore_interne(a, p_requete, 'marche_krasnov_manger', prm,
    jsonb_build_object('ok', true, 'cle', p_cle, 'gain_pa', CASE WHEN p_cle = 'goulash' THEN 2 END,
      'bonus_differe', CASE WHEN p_cle <> 'goulash' THEN 1 END, 'bonus_pa_differe', v_b, 'maladie', v_mal,
      'pa', (SELECT pa FROM public.personnages_donnees WHERE name = a)));
END $$;

REVOKE ALL ON FUNCTION public.marche_krasnov_objet_interne(text), public.marche_krasnov_reconnait_interne(text, jsonb),
  public.marche_krasnov_possede_interne(jsonb, text), public.marche_krasnov_retirer_interne(jsonb, text, integer),
  public.marche_krasnov_argent_interne(text), public.marche_krasnov_caisse_interne() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.marche_krasnov_etat(), public.marche_krasnov_valider(uuid, jsonb), public.marche_krasnov_manger(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.marche_krasnov_etat(), public.marche_krasnov_valider(uuid, jsonb), public.marche_krasnov_manger(uuid, text) TO authenticated;

DO $$ BEGIN
  IF (SELECT count(*) FROM public.marche_krasnov_produits) < 15 OR (SELECT count(*) FROM public.marche_krasnov_stock) < 15
     OR NOT EXISTS (SELECT 1 FROM public.caisses_batiments WHERE id = 'soviet_marche_ville_b')
     OR EXISTS (SELECT 1 FROM public.marche_krasnov_produits WHERE public.marche_krasnov_objet_interne(cle) IS NULL)
     OR EXISTS (SELECT 1 FROM public.marche_krasnov_produits WHERE prix_rachat > prix_vente) THEN
    RAISE EXCEPTION 'marche_krasnov_unique : contrôle structurel en échec';
  END IF;
END $$;
COMMIT;
