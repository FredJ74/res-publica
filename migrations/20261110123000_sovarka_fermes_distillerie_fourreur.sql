-- SOVARKA : FERMES, DISTILLERIE, FOURREUR, ŒUFS ET SUCRE (decisions de Fred du 10/11/2026 a midi ;
-- GAME-DESIGN-NOVOMIRSK.md, « Fermes : production » et point 5 « Batiments dessines »).
--
-- 1. Fermes de Starovka et de Krasnov : une ferme ne consomme que du travail (PA), sans matiere premiere,
--    comme les jardins ouvriers (ouverte a tous, le produit va dans l'inventaire du travailleur) :
--      Starovka : abattre et depecer un renne 5 PA -> 3 viandes, 2 textiles (peaux), 1 bois (bois de renne) ;
--                 traire les rennes 1 PA -> 2 laitages (lait de renne) ;
--      Krasnov  : extraire des legumes 1 PA -> 1 fruits et legumes ; ramasser les oeufs 1 PA -> 1 unite d'oeufs ;
--                 abattre un poulet 2 PA -> 2 viandes ; abattre un lapin 2 PA -> 1 viande et 1 textile (peau).
--    Les appellations « de renne » sont purement RP : viande, laitages, bois, textile sont les matieres existantes.
-- 2. Oeufs : ressource locale (cle `oeufs`), hors ressources_economie donc hors entrepots et trading ; une unite =
--    3 oeufs, toujours mangee d'un coup, sans PA : +2 PA au prochain Dormir (source `oeufs`).
-- 3. Distillerie de Krasnov et fourreur de Starovka : des locaux de Sovarka (droit d'exploiter demande a la
--    mairie, signe chez le notaire) ou l'exploitant ouvre un commerce classique (fonds PJ). Type de commerce
--    « Distillerie » reserve au local de la distillerie : vodka (6 cereales), slivovitz (8 fruits et legumes),
--    samogon (4 fruits et legumes + 2 cereales), 10 bouteilles chacune ; sucre (5 fruits et legumes = 10 sucres).
--    Le fourreur prend le type « Vetements » et nomme lui-meme ses articles (habillage du fonds).
--    Un commerce alimentaire peut revendre les oeufs et le sucre de son proprietaire (« Ressource locale »).
--    A l'achat, ces produits arrivent dans l'inventaire sous leur cle (vodka, slivovitz, samogon, sucre, oeufs) :
--    on peut donc trinquer, rendre service a l'habitant ou manger ses oeufs avec ce qu'on a achete.
-- 4. Maison de Dolgor : le service « 2 viandes de renne » devient « 2 viandes » ; les oeufs et la vodka existent.
-- Plafond de loyer propose pour les deux locaux : 30 PSK (comme les locaux de Starovka), a valider par Fred.
-- Aucune donnee de joueur touchee. Idempotente.
BEGIN;

-- 0. Garde : les noeuds de rue portant les enseignes existent au serveur.
DO $$
BEGIN
  IF (SELECT count(*) FROM public.rue_noeuds_serveur WHERE country = 'soviet' AND noeud IN (
        'starovka-rue-petrole-ferme', 'krasnov-rue-marche-ferme', 'krasnov-rue-distillerie-radar',
        'starovka-rue-restaurant-boutique')) <> 4 THEN
    RAISE EXCEPTION 'noeuds de rue des fermes, de la distillerie ou du fourreur absents du serveur';
  END IF;
END $$;

-- 1. Batiments et sorties de rue.
INSERT INTO public.navigation_lieux_regles(pays, ville, batiment, pieces, ferme, membership) VALUES
  ('soviet', 'ville_a', 'ferme-starovka', '["cour_ferme"]'::jsonb, false, NULL),
  ('soviet', 'ville_b', 'ferme-krasnov', '["cour_ferme"]'::jsonb, false, NULL),
  ('soviet', 'ville_b', 'distillerie-krasnov', '["atelier_distillerie"]'::jsonb, false, NULL),
  ('soviet', 'ville_a', 'fourreur-starovka', '["boutique_fourreur"]'::jsonb, false, NULL)
ON CONFLICT (pays, ville, batiment) DO UPDATE SET pieces = EXCLUDED.pieces, ferme = EXCLUDED.ferme, membership = EXCLUDED.membership;
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES
  ('soviet', 'ville_a', 'starovka-rue-petrole-ferme', 'ferme-starovka'),
  ('soviet', 'ville_b', 'krasnov-rue-marche-ferme', 'ferme-krasnov'),
  ('soviet', 'ville_b', 'krasnov-rue-distillerie-radar', 'distillerie-krasnov'),
  ('soviet', 'ville_a', 'starovka-rue-restaurant-boutique', 'fourreur-starovka')
ON CONFLICT DO NOTHING;

INSERT INTO public.sovarka_locaux (pays, ville, batiment, piece, label, origine, loyer, plafond) VALUES
  ('soviet', 'ville_b', 'distillerie-krasnov', 'atelier_distillerie', 'Distillerie de Krasnov', 'centre', 0, 30),
  ('soviet', 'ville_a', 'fourreur-starovka', 'boutique_fourreur', 'Fourreur « La Fourrure chaude »', 'centre', 0, 30)
ON CONFLICT DO NOTHING;

INSERT INTO public.ordres_couts (fn, pa, cost)
SELECT x.fn, x.pa, 0 FROM (VALUES ('ferme_renne', 5), ('ferme_traire', 1), ('ferme_legumes', 1), ('ferme_oeufs', 1),
                                  ('ferme_poulet', 2), ('ferme_lapin', 2), ('manger_oeufs', 0)) x(fn, pa)
 WHERE NOT EXISTS (SELECT 1 FROM public.ordres_couts o WHERE o.fn = x.fn AND o.pa = x.pa AND o.cost = 0);
INSERT INTO public.pa_bonus_differes (source, montant) VALUES ('oeufs', 2) ON CONFLICT (source) DO NOTHING;

-- 2. Fermes.
CREATE OR REPLACE FUNCTION public.sovarka_ferme_travaux_interne(p_ville text, p_batiment text)
RETURNS jsonb LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE
    WHEN p_ville = 'ville_a' AND p_batiment = 'ferme-starovka' THEN
      '{"renne":{"fn":"ferme_renne","pa":5,"label":"Abattre et dépecer un renne","produits":[{"cle":"viande","qte":3},{"cle":"textile","qte":2},{"cle":"bois","qte":1}]},
        "traire":{"fn":"ferme_traire","pa":1,"label":"Traire les rennes","produits":[{"cle":"laitages","qte":2}]}}'::jsonb
    WHEN p_ville = 'ville_b' AND p_batiment = 'ferme-krasnov' THEN
      '{"legumes":{"fn":"ferme_legumes","pa":1,"label":"Extraire des légumes","produits":[{"cle":"fruits_legumes","qte":1}]},
        "oeufs":{"fn":"ferme_oeufs","pa":1,"label":"Ramasser les œufs","produits":[{"cle":"oeufs","qte":1}]},
        "poulet":{"fn":"ferme_poulet","pa":2,"label":"Abattre un poulet","produits":[{"cle":"viande","qte":2}]},
        "lapin":{"fn":"ferme_lapin","pa":2,"label":"Abattre un lapin","produits":[{"cle":"viande","qte":1},{"cle":"textile","qte":1}]}}'::jsonb
  END;
$$;

-- Objet de pile d'une matiere de ferme (nom et icone des matieres du jeu ; « Tissus et peaux » pour le textile).
CREATE OR REPLACE FUNCTION public.sovarka_matiere_objet_interne(p_cle text, p_qte integer, p_desc text)
RETURNS jsonb LANGUAGE sql IMMUTABLE AS $$
  SELECT jsonb_build_object('name', CASE p_cle WHEN 'viande' THEN 'Viande' WHEN 'textile' THEN 'Tissus et peaux'
           WHEN 'bois' THEN 'Bois' WHEN 'laitages' THEN 'Laitages' WHEN 'fruits_legumes' THEN 'Fruits & légumes'
           WHEN 'oeufs' THEN 'Œufs (par 3)' WHEN 'sucre' THEN 'Sucre' ELSE p_cle END,
         'icon', CASE p_cle WHEN 'viande' THEN 'ti-meat' WHEN 'textile' THEN 'ti-shirt' WHEN 'bois' THEN 'ti-trees'
           WHEN 'laitages' THEN 'ti-milk' WHEN 'fruits_legumes' THEN 'ti-apple' WHEN 'oeufs' THEN 'ti-egg' ELSE 'ti-package' END,
         'stackable', true, 'stackKey', p_cle, 'qty', p_qte, 'desc', p_desc);
$$;

CREATE OR REPLACE FUNCTION public.sovarka_ferme_travailler_interne(p_acteur text, p_travail text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE p record; t jsonb; e jsonb; v jsonb; v_dep jsonb; v_total integer;
BEGIN
  SELECT country, current_city, current_building INTO p FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  t := CASE WHEN p.country = 'soviet' THEN public.sovarka_ferme_travaux_interne(p.current_city, p.current_building) END -> p_travail;
  IF t IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;
  IF EXISTS (SELECT 1 FROM public.detention_active(p_acteur)) THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_indisponible'); END IF;
  SELECT sum((x->>'qte')::integer) INTO v_total FROM jsonb_array_elements(t->'produits') x;
  IF (SELECT public.inventaire_place_restante(inventory) FROM public.personnages_donnees WHERE name = p_acteur) < v_total THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'inventaire_plein'); END IF;
  v := public.payer_ordre(p_acteur, t->>'fn', (t->>'pa')::integer, 0);
  IF coalesce((v->>'ok')::boolean, false) IS NOT TRUE THEN RETURN v; END IF;
  FOR e IN SELECT * FROM jsonb_array_elements(t->'produits') LOOP
    v_dep := public.inventaire_deposer_interne(p_acteur, public.sovarka_matiere_objet_interne(e->>'cle', (e->>'qte')::integer,
      CASE WHEN p.current_city = 'ville_a' THEN 'De la ferme de Starovka.' ELSE 'Du kolkhoze de Krasnov.' END));
    IF coalesce((v_dep->>'ok')::boolean, false) IS NOT TRUE THEN RAISE EXCEPTION 'sovarka_ferme: depot refuse %', v_dep; END IF;
  END LOOP;
  RETURN jsonb_build_object('ok', true, 'travail', p_travail, 'label', t->>'label', 'produits', t->'produits',
    'pa', v->'pa', 'liquide', v->'liquide', 'arg', v->'arg')
    || (SELECT jsonb_build_object('inventory', inventory, 'revision', inventory_revision) FROM public.personnages_donnees WHERE name = p_acteur);
END $$;
REVOKE ALL ON FUNCTION public.sovarka_ferme_travailler_interne(text, text) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.sovarka_ferme_travailler(p_requete uuid, p_travail text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); prm jsonb := jsonb_build_object('travail', p_travail); v jsonb; d text;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  v := public.achat_requete_ouvrir_interne(a, p_requete, 'sovarka_ferme_travailler', prm);
  IF v IS NOT NULL THEN RETURN v; END IF;
  BEGIN
    v := public.sovarka_ferme_travailler_interne(a, p_travail);
    IF (v->>'ok')::boolean IS DISTINCT FROM true THEN RAISE EXCEPTION 'refus' USING ERRCODE = 'HG001', DETAIL = coalesce(v, '{"ok":false}')::text; END IF;
  EXCEPTION WHEN SQLSTATE 'HG001' THEN GET STACKED DIAGNOSTICS d = PG_EXCEPTION_DETAIL; RETURN d::jsonb;
  END;
  RETURN public.achat_requete_clore_interne(a, p_requete, 'sovarka_ferme_travailler', prm, v);
END $$;
REVOKE ALL ON FUNCTION public.sovarka_ferme_travailler(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.sovarka_ferme_travailler(uuid, text) TO authenticated;

-- 3. Manger ses oeufs : une unite (3 oeufs), sans PA, +2 PA au prochain Dormir. Partout (a l'hopital compris).
CREATE OR REPLACE FUNCTION public.sovarka_oeufs_manger_interne(p_acteur text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE l jsonb; v_bonus integer; v jsonb; v_differe integer;
BEGIN
  PERFORM 1 FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  l := public.sovarka_inventaire_ligne_interne((SELECT inventory FROM public.personnages_donnees WHERE name = p_acteur), ARRAY['oeufs']);
  IF (l->>'i')::integer < 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_d_oeufs'); END IF;
  SELECT montant INTO v_bonus FROM public.pa_bonus_differes WHERE source = 'oeufs';
  v := public.payer_ordre(p_acteur, 'manger_oeufs', 0, 0);
  IF coalesce((v->>'ok')::boolean, false) IS NOT TRUE THEN RETURN v; END IF;
  PERFORM public.sovarka_inventaire_retirer_interne(p_acteur, l, 1);
  UPDATE public.personnages_donnees SET bonus_pa_differe = least(30, coalesce(bonus_pa_differe, 0) + v_bonus), updated_at = now()
   WHERE name = p_acteur RETURNING bonus_pa_differe INTO v_differe;
  RETURN jsonb_build_object('ok', true, 'bonus', v_bonus, 'bonus_pa_differe', v_differe, 'pa', v->'pa')
    || (SELECT jsonb_build_object('inventory', inventory, 'revision', inventory_revision) FROM public.personnages_donnees WHERE name = p_acteur);
END $$;
REVOKE ALL ON FUNCTION public.sovarka_oeufs_manger_interne(text) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.sovarka_oeufs_manger(p_requete uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); prm jsonb := '{}'::jsonb; v jsonb; d text;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  v := public.achat_requete_ouvrir_interne(a, p_requete, 'sovarka_oeufs_manger', prm);
  IF v IS NOT NULL THEN RETURN v; END IF;
  BEGIN
    v := public.sovarka_oeufs_manger_interne(a);
    IF (v->>'ok')::boolean IS DISTINCT FROM true THEN RAISE EXCEPTION 'refus' USING ERRCODE = 'HG001', DETAIL = coalesce(v, '{"ok":false}')::text; END IF;
  EXCEPTION WHEN SQLSTATE 'HG001' THEN GET STACKED DIAGNOSTICS d = PG_EXCEPTION_DETAIL; RETURN d::jsonb;
  END;
  RETURN public.achat_requete_clore_interne(a, p_requete, 'sovarka_oeufs_manger', prm, v);
END $$;
REVOKE ALL ON FUNCTION public.sovarka_oeufs_manger(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.sovarka_oeufs_manger(uuid) TO authenticated;

-- 4. Maisons : « 2 viandes » chez Dolgor ; oeufs et vodka (ressources locales) peuvent desormais etre demandes.
CREATE OR REPLACE FUNCTION public.sovarka_maison_interne(p_ville text, p_batiment text)
RETURNS jsonb LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE
    WHEN p_ville = 'ville_a' AND p_batiment = 'maison-starovka' THEN jsonb_build_object('id', 'maison-starovka', 'habitant', 'Dolgor Tsybikova',
      'besoins', '[{"cle":"bois","qte":3,"label":"3 bois"},{"cle":"poisson","qte":2,"label":"2 poissons"},{"cle":"carburant","qte":1,"label":"1 bidon de carburant"},{"cle":"viande","qte":2,"label":"2 viandes"},{"cle":"vodka","qte":1,"label":"1 bouteille de vodka"}]'::jsonb)
    WHEN p_ville = 'ville_b' AND p_batiment = 'maison-krasnov' THEN jsonb_build_object('id', 'maison-krasnov', 'habitant', 'Stepan Kouznetsov',
      'besoins', '[{"cle":"bois","qte":3,"label":"3 bois"},{"cle":"fruits_legumes","qte":5,"label":"5 fruits et légumes"},{"cle":"oeufs","qte":2,"label":"6 œufs"},{"cle":"vodka","qte":1,"label":"1 bouteille de vodka"}]'::jsonb)
  END;
$$;

CREATE OR REPLACE FUNCTION public.sovarka_maison_service_interne(p_maison jsonb, p_jour date)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  WITH b AS (
    SELECT e, row_number() OVER () - 1 AS k
      FROM jsonb_array_elements(p_maison->'besoins') e
     WHERE EXISTS (SELECT 1 FROM public.ressources_economie r WHERE r.cle = e->>'cle')
        OR e->>'cle' IN ('oeufs', 'vodka')  -- ressources locales de Sovarka (fermes et distillerie, 10/11/2026)
  )
  SELECT e FROM b WHERE k = abs(hashtext((p_maison->>'id') || ':' || p_jour::text)) % greatest(1, (SELECT count(*) FROM b));
$$;

-- 5. Distillerie, sucre et revente des ressources locales : catalogue des commerces PJ.
INSERT INTO public.catalogue_types (id, libelle, ordre) VALUES ('distillerie', 'Distillerie', 15) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.catalogue_generiques (id, libelle, famille_id, regime, est_service, empilable, individualise, consommable, equipable, note) VALUES
  ('alcool-de-distillerie', 'Alcool de distillerie', 'boissons', 'libre', false, true, false, false, false,
   'Sovarka, distillerie de Krasnov (Fred, 10/11/2026) : vodka, slivovitz, samogon, livres sous leur cle de pile.'),
  ('sucre', 'Sucre', 'produits-transformes', 'libre', false, true, false, false, false,
   'Sovarka, distillerie de Krasnov (Fred, 10/11/2026) : ressource locale, sans effet pour l''instant.'),
  ('ressource-locale', 'Ressource locale', 'produits-frais', 'libre', false, true, false, false, false,
   'Sovarka (Fred, 10/11/2026) : oeufs et sucre, hors entrepots et trading, revendus par un commerce classique.')
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.catalogue_generique_type (generique_id, type_id)
SELECT x.g, x.t FROM (VALUES ('alcool-de-distillerie', 'distillerie'), ('sucre', 'distillerie'), ('ressource-locale', 'commerce-alimentaire')) x(g, t)
 WHERE NOT EXISTS (SELECT 1 FROM public.catalogue_generique_type c WHERE c.generique_id = x.g AND c.type_id = x.t);

INSERT INTO public.recettes_commerce (id, source, label, pa, portions, materiaux, categorie, stack_key, icone, description, generique_id) VALUES
  ('vodka_distillerie', 'commerce_pj', 'Vodka', 1, 10, '{"cereales":6}'::jsonb, 'boisson', 'vodka', 'ti-bottle',
   'Dix bouteilles de vodka de grain.', 'alcool-de-distillerie'),
  ('slivovitz_distillerie', 'commerce_pj', 'Slivovitz', 1, 10, '{"fruits_legumes":8}'::jsonb, 'boisson', 'slivovitz', 'ti-bottle',
   'Dix bouteilles d''eau-de-vie de prune.', 'alcool-de-distillerie'),
  ('samogon_distillerie', 'commerce_pj', 'Samogon', 1, 10, '{"fruits_legumes":4,"cereales":2}'::jsonb, 'boisson', 'samogon', 'ti-bottle',
   'Dix bouteilles de gnôle de contrebande, la moins chère.', 'alcool-de-distillerie'),
  ('sucre_distillerie', 'commerce_pj', 'Sucre de betterave', 1, 10, '{"fruits_legumes":5}'::jsonb, 'alimentaire', 'sucre', 'ti-cube',
   'Dix sucres tirés de la betterave.', 'sucre'),
  ('oeufs_revente', 'commerce_pj', 'Œufs frais (par 3)', 1, 5, '{"oeufs":5}'::jsonb, 'alimentaire', 'oeufs', 'ti-egg',
   'Cinq unités de trois œufs, ramassés par le commerçant.', 'ressource-locale'),
  ('sucre_revente', 'commerce_pj', 'Sucre', 1, 10, '{"sucre":10}'::jsonb, 'alimentaire', 'sucre', 'ti-cube',
   'Dix sucres revendus au détail.', 'ressource-locale')
ON CONFLICT (id) DO NOTHING;

-- Type « Distillerie » reserve au commerce installe dans la distillerie de Krasnov (patch en place, ancrage verifie).
DO $raccord$
DECLARE d text; avant text; apres text;
BEGIN
  d := pg_get_functiondef('public.fonds_definir_types(text,text,text[])'::regprocedure);
  IF position('sovarka_distillerie_type_v1' IN d) = 0 THEN
    avant := E'  v_max := public.fonds_types_max(v_data ->> ''proprietaire'');';
    apres := E'  -- sovarka_distillerie_type_v1 (Fred, 10/11/2026) : le type Distillerie n''existe qu''a la distillerie de Krasnov.\n'
          || E'  IF ''distillerie'' = ANY (v_connus) AND (v_data->''implantation''->>''country'', v_data->''implantation''->>''city'', v_data->''implantation''->>''buildingId'')\n'
          || E'     IS DISTINCT FROM (''soviet'', ''ville_b'', ''distillerie-krasnov'') THEN\n'
          || E'    RETURN jsonb_build_object(''ok'', false, ''raison'', ''type_reserve_distillerie'');\n'
          || E'  END IF;\n'
          || avant;
    IF (length(d) - length(replace(d, avant, ''))) / length(avant) <> 1 THEN RAISE EXCEPTION 'fonds_definir_types : ancrage introuvable'; END IF;
    EXECUTE replace(d, avant, apres);
  END IF;
END $raccord$;

-- A l'achat, un produit de ces trois generiques arrive sous sa cle de pile (vodka, slivovitz, samogon, sucre, oeufs).
DO $raccord$
DECLARE d text; avant text; apres text;
BEGIN
  d := pg_get_functiondef('public.acheter_produit_commerce_interne(text,text,text,text,integer)'::regprocedure);
  IF position('sovarka_ressource_locale_pile_v1' IN d) = 0 THEN
    avant := E'''stackable'', true, ''stackKey'', p_reference_id, ''qty'', v_qte);';
    apres := E'''stackable'', true, ''qty'', v_qte,\n'
          || E'                 -- sovarka_ressource_locale_pile_v1 (10/11/2026) : alcools de distillerie, sucre et oeufs gardent leur cle.\n'
          || E'                 ''stackKey'', coalesce((SELECT rc.stack_key FROM public.recettes_commerce rc WHERE rc.id = v_ref->>''recette_id''\n'
          || E'                   AND rc.generique_id IN (''alcool-de-distillerie'', ''sucre'', ''ressource-locale'')), p_reference_id));';
    IF (length(d) - length(replace(d, avant, ''))) / length(avant) <> 1 THEN RAISE EXCEPTION 'acheter_produit_commerce_interne : ancrage introuvable'; END IF;
    EXECUTE replace(d, avant, apres);
  END IF;
END $raccord$;

-- 6. Controles structurels.
DO $$
BEGIN
  IF position('sovarka_distillerie_type_v1' IN pg_get_functiondef('public.fonds_definir_types(text,text,text[])'::regprocedure)) = 0
     OR position('sovarka_ressource_locale_pile_v1' IN pg_get_functiondef('public.acheter_produit_commerce_interne(text,text,text,text,integer)'::regprocedure)) = 0
     OR (SELECT count(*) FROM public.recettes_commerce WHERE id IN ('vodka_distillerie', 'slivovitz_distillerie', 'samogon_distillerie',
           'sucre_distillerie', 'oeufs_revente', 'sucre_revente')) <> 6
     OR EXISTS (SELECT 1 FROM public.ressources_economie WHERE cle IN ('oeufs', 'sucre'))
     OR (SELECT count(*) FROM public.sovarka_locaux WHERE batiment IN ('distillerie-krasnov', 'fourreur-starovka')) <> 2 THEN
    RAISE EXCEPTION 'sovarka_fermes_distillerie_fourreur : controle structurel en echec';
  END IF;
END $$;

COMMIT;
