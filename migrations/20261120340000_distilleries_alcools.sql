-- ÉCONOMIE DE LA DISTILLERIE ET DES ALCOOLS (décisions de Fred du 20/11/2026). GAME-DESIGN-DISTILLERIE-ALCOOLS.md.
--  • Deux matières d'alcool : la matière historique « alcool » devient l'ALCOOL PUR (industriel, désinfectant) — même clé,
--    pour ne casser aucun usage (chaîne du désinfectant, contrebande, exports) — et une nouvelle matière SPIRITUEUX
--    (l'alcool à boire : bars, buvettes). Les deux viennent des distilleries d'État, aux mêmes rendements.
--  • SUCRE : matière du circuit logistique (5 fruits et légumes → 10 sucres ; 15 PSK / 30 FR le PA payé au PJ), produit
--    par les distilleries d'État de jour (PJ) et de nuit. Les œufs restent hors circuit.
--  • Recettes de bars qui consommaient l'alcool → spiritueux ; stocks des commerces convertis ; stocks des entrepôts de
--    Sovarka (très au-dessus des besoins) partagés moitié alcool pur, moitié spiritueux.
--  • Flux internationaux quotidiens (commerce_contrats) selon la décision de Fred.
--  • Distillerie de Krasnov jamais à louer (local retiré) ; directeur PNJ en Sovarka, nommé par le ministre de
--    l'Économie (min_fin, comme en Républia).
--  • Spiritueux locaux de collection (effet identique à un spiritueux) : distillerie_bouteille_acheter.
-- Idempotente.
BEGIN;

-- 1. Matières
INSERT INTO public.ressources_economie (cle, prix_base, prix_achat_fournisseur, plafond, source) VALUES
  ('spiritueux', 14, 7, 100, 'transformation'),
  ('sucre', 5, 2.5, 150, 'transformation')
ON CONFLICT (cle) DO NOTHING;

-- 2. Chaînes de production (PJ et nuit). Républia : PSM ; Sovarka : distillerie de Krasnov.
INSERT INTO public.chaines_production_usine (produit, ville, building_id, matiere, salaire_pa)
SELECT 'spiritueux', 'ville_a', 'pole-tabac-alcools-psm', 'cereales', 55
 WHERE NOT EXISTS (SELECT 1 FROM public.chaines_production_usine WHERE produit = 'spiritueux');
INSERT INTO public.chaines_production_usine (produit, ville, building_id, matiere, salaire_pa)
SELECT 'sucre', 'ville_a', 'pole-tabac-alcools-psm', 'fruits_legumes', 30
 WHERE NOT EXISTS (SELECT 1 FROM public.chaines_production_usine WHERE produit = 'sucre');
INSERT INTO public.chaines_production_pays (pays, produit, ville, building_id, matiere, salaire_pa, rang)
SELECT 'soviet', 'spiritueux', 'ville_b', 'distillerie-krasnov', 'fruits_legumes', 15, 6
 WHERE NOT EXISTS (SELECT 1 FROM public.chaines_production_pays WHERE pays = 'soviet' AND produit = 'spiritueux');
INSERT INTO public.chaines_production_pays (pays, produit, ville, building_id, matiere, salaire_pa, rang)
SELECT 'soviet', 'sucre', 'ville_b', 'distillerie-krasnov', 'fruits_legumes', 15, 7
 WHERE NOT EXISTS (SELECT 1 FROM public.chaines_production_pays WHERE pays = 'soviet' AND produit = 'sucre');
UPDATE public.directeurs_usine_pays SET produits = (SELECT jsonb_agg(DISTINCT x) FROM jsonb_array_elements_text(produits || '["spiritueux","sucre"]'::jsonb) x)
 WHERE building_id = 'distillerie-krasnov' AND NOT (produits @> '["spiritueux","sucre"]'::jsonb);
UPDATE public.directeurs_usine SET produits = (SELECT jsonb_agg(DISTINCT x) FROM jsonb_array_elements_text(produits || '["spiritueux","sucre"]'::jsonb) x)
 WHERE poste_id = 'directeur_tabac_alcools' AND NOT (produits @> '["spiritueux","sucre"]'::jsonb);

-- 3. Bars et buvettes : on boit du spiritueux, plus de l'alcool pur.
UPDATE public.recettes_commerce SET materiaux = (materiaux - 'alcool') || jsonb_build_object('spiritueux', materiaux -> 'alcool')
 WHERE materiaux ? 'alcool' AND boisson = 'alcoolisee';
UPDATE public.entreprises SET data = jsonb_set(data, '{stockMatieres}',
  ((data -> 'stockMatieres') - 'alcool') || jsonb_build_object('spiritueux',
    coalesce((data -> 'stockMatieres' ->> 'spiritueux')::numeric, 0) + coalesce((data -> 'stockMatieres' ->> 'alcool')::numeric, 0)))
 WHERE jsonb_typeof(data -> 'stockMatieres') = 'object' AND data -> 'stockMatieres' ? 'alcool';

-- 4. Entrepôts de Sovarka : la moitié du stock d'alcool devient du spiritueux (une seule fois).
UPDATE public.batiments_etat b SET data = to_jsonb((e || jsonb_build_object('entrepot',
    (e -> 'entrepot') || jsonb_build_object('stock', ((e -> 'entrepot' -> 'stock') - 'alcool') || jsonb_build_object(
      'alcool', ceil(coalesce((e -> 'entrepot' -> 'stock' ->> 'alcool')::numeric, 0) / 2),
      'spiritueux', coalesce((e -> 'entrepot' -> 'stock' ->> 'spiritueux')::numeric, 0) + floor(coalesce((e -> 'entrepot' -> 'stock' ->> 'alcool')::numeric, 0) / 2))))
  )::text), updated_at = now()
  FROM (SELECT id, public.batiment_etat_lire(data) AS e FROM public.batiments_etat) x
 WHERE b.id = x.id AND b.id LIKE 'soviet\_%' AND jsonb_typeof(x.e -> 'entrepot' -> 'stock') = 'object'
   AND coalesce((x.e -> 'entrepot' -> 'stock' ->> 'alcool')::numeric, 0) > 0
   AND NOT (x.e -> 'entrepot' -> 'stock') ? 'spiritueux';
UPDATE public.ports_stock SET cle = 'spiritueux' WHERE cle = 'alcool' AND pays = 'soviet'
   AND NOT EXISTS (SELECT 1 FROM public.ports_stock p2 WHERE p2.pays = 'soviet' AND p2.cle = 'spiritueux');

-- 5. Flux internationaux quotidiens (Fred, 20/11/2026). Al-Khalija ne distille rien mais importe : parodie assumée.
UPDATE public.commerce_contrats SET cle = 'spiritueux', note = 'Fred 20/11 : spiritueux'
 WHERE origine = 'republic' AND destination = 'soviet' AND cle = 'alcool';
INSERT INTO public.commerce_contrats (origine, destination, cle, quantite, note)
SELECT v.o, v.d, v.c, v.q, 'Fred 20/11' FROM (VALUES
  ('republic', 'khalija', 'alcool', 50), ('republic', 'khalija', 'spiritueux', 50),
  ('soviet', 'khalija', 'alcool', 50), ('soviet', 'khalija', 'spiritueux', 50),
  ('narco', 'khalija', 'fruits_legumes', 100), ('republic', 'khalija', 'fruits_legumes', 50)) v(o, d, c, q)
 WHERE NOT EXISTS (SELECT 1 FROM public.commerce_contrats x WHERE x.origine = v.o AND x.destination = v.d AND x.cle = v.c);

-- 6. Distillerie d'État de Krasnov : jamais à louer ; directeur PNJ (nommé par le ministre de l'Économie).
DELETE FROM public.sovarka_locaux WHERE batiment = 'distillerie-krasnov' AND entreprise_id IS NULL;
INSERT INTO public.titulaires_pnj (id, country, poste_id, city, nom_pnj, updated_at)
SELECT 'soviet_directeur_tabac_alcools_national', 'soviet', 'directeur_tabac_alcools', NULL, 'Anatoli Pokhmelkine (PNJ)', now()
 WHERE NOT EXISTS (SELECT 1 FROM public.titulaires_pnj WHERE country = 'soviet' AND poste_id = 'directeur_tabac_alcools');

-- 7. Spiritueux locaux de collection : même effet qu'un spiritueux, autre étiquette. Chaque bouteille vient du stock de
--    spiritueux de la vente directe de la distillerie d'État ; prix = celui du spiritueux en vente directe.
CREATE OR REPLACE FUNCTION public.distillerie_spiritueux_locaux_interne(p_pays text)
RETURNS text[] LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE p_pays WHEN 'soviet' THEN ARRAY['Vodka', 'Slivovitz', 'Samogon']
                     WHEN 'republic' THEN ARRAY['Champagne', 'Cognac', 'Pastis']
                     WHEN 'narco' THEN ARRAY['Tequila']          -- deux autres noms à fixer à l'ouverture d'El Estado
                     ELSE ARRAY[]::text[] END;                     -- Al-Khalija : aucun
$$;
CREATE OR REPLACE FUNCTION public.distillerie_bouteille_acheter_interne(p_acteur text, p_nom text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE p record; v_bat text; v_id text; v_etat jsonb; v_usine jsonb; v_vd jsonb; v_stock numeric; v_prix numeric; v_dep jsonb; v_refus jsonb;
  v_liquide numeric; v_arg numeric; v_compte text; v_solde numeric; v_pris_liquide numeric;
BEGIN
  v_refus := public.mineur_refus_interne(p_acteur, NULL, 'alcool');
  IF v_refus IS NOT NULL THEN RETURN v_refus; END IF;
  SELECT country, current_city, current_building INTO p FROM public.personnages_donnees WHERE name = p_acteur;
  v_bat := CASE WHEN p.country = 'soviet' AND p.current_city = 'ville_b' AND p.current_building = 'distillerie-krasnov' THEN 'distillerie-krasnov'
                WHEN p.country = 'republic' AND p.current_city = 'ville_a' AND p.current_building = 'pole-tabac-alcools-psm' THEN 'pole-tabac-alcools-psm' END;
  IF v_bat IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;
  IF NOT (p_nom = ANY (public.distillerie_spiritueux_locaux_interne(p.country))) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'spiritueux_inconnu'); END IF;
  v_id := p.country || '_' || p.current_city || '_' || v_bat;
  SELECT public.batiment_etat_lire(data) INTO v_etat FROM public.batiments_etat WHERE id = v_id FOR UPDATE;
  v_usine := coalesce(v_etat -> 'usine', '{}'::jsonb); v_vd := coalesce(v_usine -> 'venteDirecte', '{}'::jsonb);
  v_stock := coalesce((v_vd ->> 'spiritueux')::numeric, 0);
  IF v_stock < 1 THEN RETURN jsonb_build_object('ok', false, 'raison', 'rupture'); END IF;
  v_prix := ceil(coalesce((v_usine -> 'prixManuel' ->> 'spiritueux')::numeric,
                     public.prix_ressource_selon_stock('spiritueux', v_stock) * public.coef_prix_matieres(p.country)));
  -- Paiement comme la vente directe : liquide d'abord, puis compte national (prix variable : pas d'ordre à coût fixe).
  SELECT coalesce(liquide, 0), coalesce(arg, 0) INTO v_liquide, v_arg FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  SELECT id, coalesce(solde, 0) INTO v_compte, v_solde FROM public.comptes_bancaires WHERE personnage = p_acteur AND banque = 'nationale' FOR UPDATE;
  IF v_liquide + coalesce(v_solde, 0) < v_prix THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants', 'requis', v_prix, 'disponible', v_liquide + coalesce(v_solde, 0)); END IF;
  v_dep := public.inventaire_deposer_interne(p_acteur, jsonb_build_object('name', p_nom, 'icon', 'ti-bottle', 'stackable', true,
    'stackKey', 'spiritueux_' || lower(p_nom), 'qty', 1, 'legal', true, 'boisson', 'alcoolisee', 'type', 'spiritueux_local',
    'desc', 'Spiritueux de la distillerie d''État. Bouteille de collection : même effet qu''un spiritueux.'));
  IF coalesce((v_dep ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN coalesce(v_dep, jsonb_build_object('ok', false, 'raison', 'inventaire_plein')); END IF;
  v_pris_liquide := least(v_liquide, v_prix);
  UPDATE public.personnages_donnees SET liquide = v_liquide - v_pris_liquide, arg = v_arg - v_prix WHERE name = p_acteur;
  IF v_prix - v_pris_liquide > 0 THEN
    UPDATE public.comptes_bancaires SET solde = solde - (v_prix - v_pris_liquide), updated_at = now() WHERE id = v_compte; END IF;
  v_usine := v_usine || jsonb_build_object('venteDirecte', jsonb_set(v_vd, '{spiritueux}', to_jsonb(v_stock - 1)),
                                           'caisse', coalesce((v_usine ->> 'caisse')::numeric, 0) + v_prix);
  UPDATE public.batiments_etat SET data = to_jsonb((v_etat || jsonb_build_object('usine', v_usine))::text), updated_at = now() WHERE id = v_id;
  RETURN jsonb_build_object('ok', true, 'nom', p_nom, 'paye', v_prix);
END $$;
REVOKE ALL ON FUNCTION public.distillerie_bouteille_acheter_interne(text, text) FROM PUBLIC, anon, authenticated;

-- Commande à clé d'unicité (même enveloppe que acheter_vente_directe_usine : rejeu sans double paiement).
CREATE OR REPLACE FUNCTION public.distillerie_bouteille_acheter(p_requete uuid, p_acteur text, p_nom text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE prm jsonb; v jsonb; d text;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  prm := jsonb_build_object('nom', p_nom);
  v := public.achat_requete_ouvrir_interne(p_acteur, p_requete, 'distillerie_bouteille_acheter', prm);
  IF v IS NOT NULL THEN RETURN v; END IF;
  BEGIN
    v := public.distillerie_bouteille_acheter_interne(p_acteur, p_nom);
    IF (v->>'ok')::boolean IS DISTINCT FROM true THEN RAISE EXCEPTION 'achat_refuse' USING ERRCODE = 'HG001', DETAIL = coalesce(v, '{"ok":false}')::text; END IF;
  EXCEPTION WHEN SQLSTATE 'HG001' THEN GET STACKED DIAGNOSTICS d = PG_EXCEPTION_DETAIL; RETURN d::jsonb;
  END;
  RETURN public.achat_requete_clore_interne(p_acteur, p_requete, 'distillerie_bouteille_acheter', prm, v);
END $$;
REVOKE ALL ON FUNCTION public.distillerie_bouteille_acheter(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.distillerie_bouteille_acheter(uuid, text, text) TO authenticated;

-- 8. Ordres et salaires des deux nouvelles chaînes (1 PA, gratuit ; Sovarka 15 PSK le PA, comme l'alcool).
INSERT INTO public.ordres_couts (fn, pa, cost)
SELECT v.f, 1, 0 FROM (VALUES ('produire_spiritueux'), ('produire_sucre')) v(f)
 WHERE NOT EXISTS (SELECT 1 FROM public.ordres_couts o WHERE o.fn = v.f);
INSERT INTO public.salaires_production_pays (pays, produit, salaire_pa)
SELECT 'soviet', v.p, 15 FROM (VALUES ('spiritueux'), ('sucre')) v(p)
 WHERE NOT EXISTS (SELECT 1 FROM public.salaires_production_pays s WHERE s.pays = 'soviet' AND s.produit = v.p);

-- 9. PÉNURIES DÉCLARÉES PAR LE MJ. Une matière, une zone (pays, ville ou tout le pays), une intensité (1 à 100 % de
--    production coupée), une durée (fin automatique) ou levée manuelle ; destruction de stock et annonce optionnelles.
--    Coupe : les livraisons et la production locale de la matière (nuit), les chaînes qui la PRODUISENT (nuit et PJ).
CREATE TABLE IF NOT EXISTS public.penuries (
  id bigserial PRIMARY KEY,
  matiere text NOT NULL,
  pays text NOT NULL,
  ville text,                                   -- NULL : tout le pays
  intensite integer NOT NULL CHECK (intensite BETWEEN 1 AND 100),
  debut timestamptz NOT NULL DEFAULT now(),
  fin timestamptz,                              -- NULL : jusqu'à la levée manuelle
  destruction_pct integer NOT NULL DEFAULT 0 CHECK (destruction_pct BETWEEN 0 AND 100),
  detruit jsonb NOT NULL DEFAULT '{}'::jsonb,
  annonce text,
  levee_le timestamptz,
  cree_par uuid);
ALTER TABLE public.penuries ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.penuries FROM anon, authenticated;

-- Part de production qui subsiste (1 = normale, 0 = coupée) : la pénurie active la plus forte qui vise la matière et la zone.
CREATE OR REPLACE FUNCTION public.penurie_coef_interne(p_pays text, p_ville text, p_matiere text)
RETURNS numeric LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT coalesce(1 - max(intensite) / 100.0, 1) FROM public.penuries
   WHERE matiere = p_matiere AND pays = p_pays AND (ville IS NULL OR ville = p_ville)
     AND levee_le IS NULL AND debut <= now() AND (fin IS NULL OR fin > now());
$$;
REVOKE ALL ON FUNCTION public.penurie_coef_interne(text, text, text) FROM PUBLIC, anon, authenticated;

-- Lecture pour la nuit de la Républia (api/cron-minuit.js, clé de service).
CREATE OR REPLACE FUNCTION public.penuries_actives_lire()
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT coalesce(jsonb_agg(jsonb_build_object('matiere', matiere, 'pays', pays, 'ville', ville, 'intensite', intensite)), '[]'::jsonb)
    FROM public.penuries WHERE levee_le IS NULL AND debut <= now() AND (fin IS NULL OR fin > now());
$$;
REVOKE ALL ON FUNCTION public.penuries_actives_lire() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.penuries_actives_lire() TO service_role;

CREATE OR REPLACE FUNCTION public.admin_penuries_lire()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
BEGIN
  PERFORM public.admin_exiger();
  RETURN jsonb_build_object('ok', true,
    'matieres', (SELECT jsonb_agg(cle ORDER BY cle) FROM public.ressources_economie),
    'penuries', (SELECT coalesce(jsonb_agg(to_jsonb(p) || jsonb_build_object('active',
                   p.levee_le IS NULL AND p.debut <= now() AND (p.fin IS NULL OR p.fin > now())) ORDER BY p.id DESC), '[]'::jsonb)
                 FROM (SELECT * FROM public.penuries ORDER BY id DESC LIMIT 50) p));
END $$;

CREATE OR REPLACE FUNCTION public.admin_penurie_declarer(p_matiere text, p_pays text, p_ville text, p_intensite integer,
  p_duree_jours integer, p_destruction_pct integer, p_annonce text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_id bigint; v_ville text := nullif(btrim(coalesce(p_ville, '')), ''); v_annonce text := nullif(btrim(coalesce(p_annonce, '')), '');
  v_pct integer := coalesce(p_destruction_pct, 0); r record; v_e jsonb; v_q numeric; v_perte numeric; v_detruit jsonb := '{}'::jsonb;
BEGIN
  PERFORM public.admin_exiger();
  IF NOT EXISTS (SELECT 1 FROM public.ressources_economie WHERE cle = p_matiere) THEN RETURN jsonb_build_object('ok', false, 'raison', 'matiere_inconnue'); END IF;
  IF p_pays NOT IN ('republic', 'soviet', 'khalija', 'narco') THEN RETURN jsonb_build_object('ok', false, 'raison', 'pays_invalide'); END IF;
  IF v_ville IS NOT NULL AND v_ville NOT IN ('capitale', 'ville_a', 'ville_b') THEN RETURN jsonb_build_object('ok', false, 'raison', 'ville_invalide'); END IF;
  IF p_intensite IS NULL OR p_intensite NOT BETWEEN 1 AND 100 THEN RETURN jsonb_build_object('ok', false, 'raison', 'intensite_invalide'); END IF;
  IF p_duree_jours IS NOT NULL AND p_duree_jours < 1 THEN RETURN jsonb_build_object('ok', false, 'raison', 'duree_invalide'); END IF;
  IF v_pct NOT BETWEEN 0 AND 100 THEN RETURN jsonb_build_object('ok', false, 'raison', 'destruction_invalide'); END IF;
  -- Destruction optionnelle : une part du stock de la matière dans les entrepôts de la zone.
  IF v_pct > 0 THEN
    FOR r IN SELECT id, public.batiment_etat_lire(data) e FROM public.batiments_etat
              WHERE id LIKE p_pays || '\_%' AND id LIKE '%entrepot%' AND (v_ville IS NULL OR id LIKE p_pays || '\_' || v_ville || '\_%') FOR UPDATE LOOP
      v_q := coalesce((r.e -> 'entrepot' -> 'stock' ->> p_matiere)::numeric, 0);
      IF v_q <= 0 THEN CONTINUE; END IF;
      v_perte := floor(v_q * v_pct / 100.0);
      IF v_perte <= 0 THEN CONTINUE; END IF;
      v_e := jsonb_set(r.e, ARRAY['entrepot', 'stock', p_matiere], to_jsonb(v_q - v_perte));
      UPDATE public.batiments_etat SET data = to_jsonb(v_e::text), updated_at = now() WHERE id = r.id;
      v_detruit := v_detruit || jsonb_build_object(r.id, v_perte);
    END LOOP;
  END IF;
  INSERT INTO public.penuries (matiere, pays, ville, intensite, fin, destruction_pct, detruit, annonce, cree_par)
  VALUES (p_matiere, p_pays, v_ville, p_intensite, CASE WHEN p_duree_jours IS NULL THEN NULL ELSE now() + make_interval(days => p_duree_jours) END,
          v_pct, v_detruit, v_annonce, auth.uid())
  RETURNING id INTO v_id;
  IF v_annonce IS NOT NULL THEN
    INSERT INTO public.evenements_globaux (country, city, texte, jour) VALUES (p_pays, v_ville, '⚠️ ' || v_annonce, NULL);
    INSERT INTO public.journal_articles_en_attente (id, country, rubrique, titre, texte, statut, origine, priorite, dedup_key, created_at)
    VALUES ('penurie-' || v_id, p_pays, 'politique', 'Pénurie', v_annonce, 'attente', 'penurie', 'importante', 'penurie-' || v_id, now())
    ON CONFLICT (id) DO NOTHING;
  END IF;
  INSERT INTO public.admin_journal (admin_user_id, admin_libelle, action, parametres, ok)
  VALUES (auth.uid(), 'MJ', 'penurie_declarer', jsonb_build_object('id', v_id, 'matiere', p_matiere, 'pays', p_pays, 'ville', v_ville,
          'intensite', p_intensite, 'duree_jours', p_duree_jours, 'destruction_pct', v_pct, 'detruit', v_detruit, 'annonce', v_annonce), true);
  RETURN jsonb_build_object('ok', true, 'id', v_id, 'detruit', v_detruit);
END $$;

CREATE OR REPLACE FUNCTION public.admin_penurie_lever(p_id bigint)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
BEGIN
  PERFORM public.admin_exiger();
  UPDATE public.penuries SET levee_le = now() WHERE id = p_id AND levee_le IS NULL;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'introuvable_ou_levee'); END IF;
  INSERT INTO public.admin_journal (admin_user_id, admin_libelle, action, parametres, ok)
  VALUES (auth.uid(), 'MJ', 'penurie_lever', jsonb_build_object('id', p_id), true);
  RETURN jsonb_build_object('ok', true, 'id', p_id);
END $$;
REVOKE ALL ON FUNCTION public.admin_penuries_lire(), public.admin_penurie_declarer(text, text, text, integer, integer, integer, text),
  public.admin_penurie_lever(bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_penuries_lire(), public.admin_penurie_declarer(text, text, text, integer, integer, integer, text),
  public.admin_penurie_lever(bigint) TO authenticated;

-- Branchements : production PJ (Républia et Sovarka), nuit de Sovarka (production locale et chaînes).
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
SELECT pg_temp.rp_raccorder((SELECT oid FROM pg_proc WHERE proname = 'produire_en_usine' AND pronamespace = 'public'::regnamespace)::regprocedure,
  $a$  v_produits := least(10, v_place)::int;$a$,
  $b$  v_produits := least(floor(10 * public.penurie_coef_interne(p_pays, v_ville, p_produit)), v_place)::int; /* penuries_v1 */
  IF v_produits <= 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'penurie', 'produit', p_produit); END IF;$b$,
  'penuries_v1');
SELECT pg_temp.rp_raccorder((SELECT oid FROM pg_proc WHERE proname = 'sovarka_production_passe' AND pronamespace = 'public'::regnamespace)::regprocedure,
  $a$    v_add := least(r.quantite, greatest(0, c_capacite - v_stock));$a$,
  $b$    v_add := least(floor(r.quantite * public.penurie_coef_interne('soviet', r.ville, r.cle))::integer, greatest(0, c_capacite - v_stock)); /* penuries_v1 */$b$,
  'penuries_v1');
SELECT pg_temp.rp_raccorder((SELECT oid FROM pg_proc WHERE proname = 'sovarka_production_passe' AND pronamespace = 'public'::regnamespace)::regprocedure,
  $a$      v_q := v_base + CASE WHEN v_k <= v_reste THEN 1 ELSE 0 END;$a$,
  $b$      v_q := floor((v_base + CASE WHEN v_k <= v_reste THEN 1 ELSE 0 END) * public.penurie_coef_interne('soviet', r.ville, r.produit))::integer; /* penuries_v1_chaines */$b$,
  'penuries_v1_chaines');
SELECT pg_temp.rp_raccorder((SELECT oid FROM pg_proc WHERE proname = 'sovarka_production_passe' AND pronamespace = 'public'::regnamespace)::regprocedure,
  $a$    v_vdq := least(2 * c_volume - v_vers,$a$,
  $b$    v_vdq := least(floor((2 * c_volume - v_vers) * public.penurie_coef_interne('soviet', r.ville, r.produit))::integer, /* penuries_v1_vd */$b$,
  'penuries_v1_vd');

COMMIT;
