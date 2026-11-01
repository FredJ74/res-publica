-- Catalogues de Montrouge (Claude, 01/11/2026, recette PJ M-02 et M-03, PR #304).
-- Indépendante de l'écran : l'écran actuel ne lit que la carte enregistrée.
--
-- M-02. Le marché de Montrouge (bâtiment 'marche', partagé avec Luthécia) affichait les huit
-- produits de Luthécia : la dotation serveur n'a qu'une clé 'marche' (celle de Luthécia), et le
-- rattrapage de entreprise_assurer_existence les rajoute à chaque chargement. Correctif : une
-- dotation peut être propre à une ville, clé '<clé>@<ville>', lue avant la clé générale (même
-- principe que la branche data.city de DOTATIONS_COMMERCE_PILOTE.marche à l'écran). Dotation
-- 'marche@ville_b' = celle de l'écran, plus la barquette de carbonade-frites demandée par Fred
-- (aliment du marché, la carbonade de la brasserie reste un plat servi à table). Carte et
-- paramètres de l'entreprise de Montrouge nettoyés ; stocks, caisse et historique conservés.
--
-- M-03. Le Café des Cheminots garde dans sa carte le bœuf bourguignon du Café de la Gare, reliquat
-- d'un ancien rattrapage (sa dotation ne le contient plus) : retiré de la carte seulement.
BEGIN;

-- 1. Dotation propre à une ville lue en premier (rattrapage et création).
DO $$
DECLARE d text; a text; b text;
BEGIN
  d := pg_get_functiondef('public.entreprise_assurer_existence(text,text,text,text,text,text)'::regprocedure);
  IF position('''@'' || p_ville' IN d) > 0 THEN RETURN; END IF;  -- déjà appliqué
  a := E'    SELECT * INTO v_dot FROM public.commerces_dotations WHERE cle = v_cle;\n    IF NOT FOUND THEN\n      SELECT * INTO v_dot FROM public.commerces_dotations WHERE cle = p_batiment;';
  b := E'    SELECT * INTO v_dot FROM public.commerces_dotations WHERE cle = v_cle;\n    v_data := jsonb_build_object(';
  IF position(a IN d) = 0 OR position(b IN d) = 0 THEN
    RAISE EXCEPTION 'entreprise_assurer_existence_inattendue';
  END IF;
  d := replace(d, a, E'    SELECT * INTO v_dot FROM public.commerces_dotations WHERE cle = v_cle || ''@'' || p_ville;\n    IF NOT FOUND THEN\n      SELECT * INTO v_dot FROM public.commerces_dotations WHERE cle = v_cle;\n    END IF;\n    IF NOT FOUND THEN\n      SELECT * INTO v_dot FROM public.commerces_dotations WHERE cle = p_batiment;');
  d := replace(d, b, E'    SELECT * INTO v_dot FROM public.commerces_dotations WHERE cle = v_cle || ''@'' || p_ville;\n    IF NOT FOUND THEN\n      SELECT * INTO v_dot FROM public.commerces_dotations WHERE cle = v_cle;\n    END IF;\n    v_data := jsonb_build_object(');
  EXECUTE d;
END $$;

-- 2. Barquette de carbonade-frites : recette du marché de Montrouge (gabarit du casse-croûte).
INSERT INTO public.recettes_commerce (id, source, label, pa, portions, materiaux, prix_fixe, categorie,
  types_autorises, pays_autorises, villes_autorisees, buildings_autorises, effets, stack_key, sous_type,
  icone, image, description, famille_produit_marche, bonus_integration_ville, generique_id, label_forme)
SELECT 'carbonade_frites_marche', source, 'Barquette de carbonade-frites', pa, 6, materiaux, prix_fixe,
  categorie, types_autorises, pays_autorises, villes_autorisees, buildings_autorises, effets, stack_key,
  sous_type, 'ti-bowl', 'images/montrouge/montrouge-plat-carbonade.jpg', description,
  famille_produit_marche, bonus_integration_ville, generique_id, label_forme
FROM public.recettes_commerce WHERE id = 'casse_croute_cheminot'
ON CONFLICT (id) DO NOTHING;

-- 3. Dotation du marché de Montrouge.
INSERT INTO public.commerces_dotations (cle, type, caisse, stock_matieres, cout_moyen_matieres, carte, parametres)
VALUES ('marche@ville_b', 'marche', 0,
  '{"cereales":10,"viande":10,"textile":10,"bois":10}',
  '{"cereales":3,"viande":5,"textile":5,"bois":5}',
  '["casse_croute_cheminot","casquette_montrouge","carte_montrouge_place_rail","carte_montrouge_touristique","carte_montrouge_musee_rail","carbonade_frites_marche"]',
  '{"stockMax":{"casse_croute_cheminot":20,"casquette_montrouge":20,"carte_montrouge_place_rail":20,"carte_montrouge_touristique":20,"carte_montrouge_musee_rail":20,"carbonade_frites_marche":20},"prixVente":{"casse_croute_cheminot":15,"casquette_montrouge":20,"carte_montrouge_place_rail":7,"carte_montrouge_touristique":7,"carte_montrouge_musee_rail":7,"carbonade_frites_marche":19}}')
ON CONFLICT (cle) DO NOTHING;

-- 4. Entreprise du marché de Montrouge : carte et paramètres limités à sa dotation (prix déjà
--    fixés conservés), stocks, caisse et historique intacts.
UPDATE public.entreprises e SET data = jsonb_set(jsonb_set(jsonb_set(e.data,
    '{carte}', d.carte),
    '{parametres,prixVente}', (SELECT COALESCE(jsonb_object_agg(k, COALESCE(e.data->'parametres'->'prixVente'->k, v)), '{}')
                               FROM jsonb_each(d.parametres->'prixVente') x(k, v)), true),
    '{parametres,stockMax}', (SELECT COALESCE(jsonb_object_agg(k, COALESCE(e.data->'parametres'->'stockMax'->k, v)), '{}')
                              FROM jsonb_each(d.parametres->'stockMax') x(k, v)), true),
  updated_at = now()
FROM public.commerces_dotations d
WHERE d.cle = 'marche@ville_b' AND e.id = 'marche-republic-ville_b-marche';

-- 5. Café des Cheminots : bœuf bourguignon retiré de la carte (stock et historique conservés).
UPDATE public.entreprises SET data = jsonb_set(data, '{carte}', (data->'carte') - 'boeuf_bourguignon'), updated_at = now()
WHERE id = 'cafe-republic-ville_b-cafe-tabac-cheminots-montrouge' AND data->'carte' ? 'boeuf_bourguignon';

-- Contrôles.
DO $$
DECLARE c jsonb; f jsonb; l jsonb;
BEGIN
  SELECT data->'carte' INTO c FROM public.entreprises WHERE id = 'marche-republic-ville_b-marche';
  SELECT data->'carte' INTO f FROM public.entreprises WHERE id = 'cafe-republic-ville_b-cafe-tabac-cheminots-montrouge';
  SELECT data->'carte' INTO l FROM public.entreprises WHERE id = 'marche-republic-capitale-marche';
  IF c IS NULL OR c ? 'croque_monsieur_luthecia' OR NOT c ? 'carbonade_frites_marche' OR jsonb_array_length(c) <> 6 THEN
    RAISE EXCEPTION 'marche_montrouge_inattendu: %', c; END IF;
  IF f IS NULL OR f ? 'boeuf_bourguignon' OR NOT f ? 'sandwich_cheminots' THEN RAISE EXCEPTION 'cafe_cheminots_inattendu: %', f; END IF;
  IF l IS NULL OR NOT l ? 'croque_monsieur_luthecia' OR l ? 'casse_croute_cheminot' THEN RAISE EXCEPTION 'marche_luthecia_touche: %', l; END IF;
  IF position('''@'' || p_ville' IN pg_get_functiondef('public.entreprise_assurer_existence(text,text,text,text,text,text)'::regprocedure)) = 0 THEN
    RAISE EXCEPTION 'dotation_par_ville_absente'; END IF;
END $$;

COMMIT;
