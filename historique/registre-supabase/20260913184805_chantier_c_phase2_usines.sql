-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260913184805
-- Nom original      : chantier_c_phase2_usines
-- Categorie         : MIXTE -- MIXTE (structure ET mutation de donnees)
-- Date (deduite de la version) : 2026-09-13 18:48:05 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 8b7946339f4eaf4cde521eeca602c75d
--
-- ARCHIVE DOCUMENTAIRE exportee de supabase_migrations.schema_migrations.
-- Ce fichier NE FAIT PAS partie d'une chaine de reconstruction et NE DOIT
-- PAS etre rejoue, ni execute automatiquement, ni servir a installer une
-- base neuve. Voir historique/registre-supabase/README.md.
--
-- Le SQL ci-dessous est conserve INTEGRALEMENT, SANS AUCUNE MODIFICATION :
-- ni correction, ni mise en forme, ni separation des parties DDL et DML,
-- ni ajout d'idempotence. On archive ce qui s'est reellement passe.
-- ============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- ============================================================================
-- CHANTIER C / PHASE 2 — FAMILLE « USINES »
-- 13 septembre 2026. Trois chemins : vente directe, production, rachat de matiere.
-- ============================================================================
-- CE QUI ETAIT OUVERT, et c'est le pire des trois cas rencontres jusqu'ici :
--   * vente directe : le navigateur choisissait le prix et reecrivait la caisse ;
--   * PRODUCTION : il decidait de LA QUANTITE PRODUITE **et se versait lui-meme
--     son salaire** (state.arg += c.salairePA) ;
--   * rachat de matiere : il fixait le montant que l'usine lui versait.
-- Trois facons de creer de la valeur a volonte.

-- Miroir des chaines de production, extrait de CHAINES_PRODUCTION_USINE
-- (plateau-justice-economie.js). Des donnees, jamais une regle.
CREATE TABLE IF NOT EXISTS public.chaines_production_usine (
  produit text PRIMARY KEY, ville text NOT NULL, building_id text NOT NULL,
  matiere text NOT NULL, salaire_pa numeric NOT NULL
);
ALTER TABLE public.chaines_production_usine ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS chaines_production_lecture ON public.chaines_production_usine;
CREATE POLICY chaines_production_lecture ON public.chaines_production_usine
  FOR SELECT TO anon, authenticated USING (true);
TRUNCATE public.chaines_production_usine;
INSERT INTO public.chaines_production_usine VALUES
('medicaments','capitale','usine-pharmaceutique-luthecia','plantes',84),
('alcool','ville_a','pole-tabac-alcools-psm','cereales',55),
('tabac','ville_a','pole-tabac-alcools-psm','plantes',66),
('carburant','ville_b','raffinerie-montrouge','petrole',70),
('desinfectant','capitale','usine-pharmaceutique-luthecia','alcool',70);

-- Prix d'une ressource selon le taux de remplissage du stock. Transcription
-- EXACTE de getPrixRessource (data.js) : 0 % rempli -> +40 %, 50 % -> prix de
-- base, 100 % -> -40 %, arrondi au centime.
CREATE OR REPLACE FUNCTION public.prix_ressource_selon_stock(p_cle text, p_en_stock numeric)
RETURNS numeric LANGUAGE plpgsql STABLE SET search_path = public, pg_temp AS $$
DECLARE v_base numeric; v_plafond numeric; v_taux numeric;
BEGIN
  SELECT prix_base, plafond INTO v_base, v_plafond FROM public.ressources_economie WHERE cle = p_cle;
  IF v_base IS NULL THEN RETURN NULL; END IF;   -- jamais de tarif invente
  v_taux := greatest(0, least(1, coalesce(p_en_stock,0) / nullif(v_plafond,0)));
  RETURN round(v_base * (1 + (0.5 - v_taux) * 0.8), 2);
END; $$;

-- Helper commun : place restante dans l'inventaire, regle de addToInventory.
CREATE OR REPLACE FUNCTION public.inventaire_place_restante(p_inv jsonb)
RETURNS integer LANGUAGE sql IMMUTABLE SET search_path = public, pg_temp AS $$
  SELECT greatest(0, 100 - coalesce((SELECT sum(coalesce((e->>'qty')::numeric,
           (e->>'encombrement')::numeric, 1)) FROM jsonb_array_elements(coalesce(p_inv,'[]'::jsonb)) e), 0))::int;
$$;

-- Helper commun : ajoute une quantite empilable a un inventaire jsonb.
CREATE OR REPLACE FUNCTION public.inventaire_ajouter(p_inv jsonb, p_cle text, p_qte int, p_desc text)
RETURNS jsonb LANGUAGE plpgsql IMMUTABLE SET search_path = public, pg_temp AS $$
DECLARE v_inv jsonb := coalesce(p_inv, '[]'::jsonb);
BEGIN
  IF p_qte <= 0 THEN RETURN v_inv; END IF;
  IF EXISTS (SELECT 1 FROM jsonb_array_elements(v_inv) e WHERE e->>'stackKey' = p_cle) THEN
    SELECT jsonb_agg(CASE WHEN e->>'stackKey' = p_cle
             THEN jsonb_set(e, '{qty}', to_jsonb(coalesce((e->>'qty')::numeric,1) + p_qte))
             ELSE e END) INTO v_inv FROM jsonb_array_elements(v_inv) e;
    RETURN v_inv;
  END IF;
  RETURN v_inv || jsonb_build_array(jsonb_build_object(
    'name', p_cle, 'stackable', true, 'stackKey', p_cle, 'qty', p_qte, 'desc', p_desc));
END; $$;

-- Helper commun : retire une quantite empilable, sans jamais passer sous zero.
CREATE OR REPLACE FUNCTION public.inventaire_retirer(p_inv jsonb, p_cle text, p_qte int)
RETURNS jsonb LANGUAGE sql IMMUTABLE SET search_path = public, pg_temp AS $$
  SELECT coalesce(jsonb_agg(e) FILTER (WHERE coalesce((e->>'qty')::numeric, 1) > 0), '[]'::jsonb)
  FROM (SELECT CASE WHEN e->>'stackKey' = p_cle
                    THEN jsonb_set(e, '{qty}', to_jsonb(coalesce((e->>'qty')::numeric,1) - p_qte))
                    ELSE e END AS e
        FROM jsonb_array_elements(coalesce(p_inv,'[]'::jsonb)) e) x;
$$;

-- Helper commun : quantite detenue d'une ressource empilable.
CREATE OR REPLACE FUNCTION public.inventaire_quantite(p_inv jsonb, p_cle text)
RETURNS numeric LANGUAGE sql IMMUTABLE SET search_path = public, pg_temp AS $$
  SELECT coalesce((SELECT sum(coalesce((e->>'qty')::numeric,1))
                   FROM jsonb_array_elements(coalesce(p_inv,'[]'::jsonb)) e
                   WHERE e->>'stackKey' = p_cle), 0);
$$;

-- ============================================================================
-- F2 — VENTE DIRECTE EN USINE : le joueur achete un produit fini au comptoir.
CREATE OR REPLACE FUNCTION public.acheter_vente_directe_usine(
  p_acteur text, p_pays text, p_ville text, p_batiment text, p_achats jsonb)
RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = public, pg_temp AS $$
DECLARE
  v_id text := p_pays || '_' || p_ville || '_' || p_batiment;
  v_etat jsonb; v_usine jsonb; v_vd jsonb; v_prix_manuel jsonb;
  v_cle text; v_qte int; v_stock numeric; v_prix numeric;
  v_total numeric := 0; v_lignes jsonb := '[]'::jsonb;
  v_inv jsonb; v_place int; v_liquide numeric; v_arg numeric;
  v_compte_id text; v_solde numeric := 0; v_pris_liquide numeric; v_pris_national numeric;
  v_paye numeric := 0; v_idx int; v_ligne jsonb; v_ajoute int;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  IF p_achats IS NULL OR jsonb_typeof(p_achats) <> 'object' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'achats_absents');
  END IF;

  SELECT public.batiment_etat_lire(data) INTO v_etat
  FROM public.batiments_etat WHERE id = v_id FOR UPDATE;
  IF v_etat IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'usine_introuvable'); END IF;
  v_usine := coalesce(v_etat->'usine', '{}'::jsonb);
  v_vd := coalesce(v_usine->'venteDirecte', '{}'::jsonb);
  v_prix_manuel := coalesce(v_usine->'prixManuel', '{}'::jsonb);

  SELECT coalesce(inventory,'[]'::jsonb), coalesce(liquide,0), coalesce(arg,0)
    INTO v_inv, v_liquide, v_arg
  FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  IF v_inv IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;
  SELECT id, solde INTO v_compte_id, v_solde FROM public.comptes_bancaires
  WHERE personnage = p_acteur AND banque = 'nationale' FOR UPDATE;
  v_solde := coalesce(v_solde, 0);
  v_place := public.inventaire_place_restante(v_inv);

  FOR v_cle, v_qte IN SELECT key, (value #>> '{}')::int FROM jsonb_each(p_achats) LOOP
    IF v_qte IS NULL OR v_qte <= 0 THEN CONTINUE; END IF;
    v_stock := coalesce((v_vd->>v_cle)::numeric, 0);
    IF v_qte > v_stock THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'stock_insuffisant', 'cle', v_cle, 'disponible', v_stock);
    END IF;
    -- Prix : celui du directeur s'il en a fixe un, sinon le prix variable selon
    -- le remplissage -- exactement getPrixRessource(cle, enStock).
    v_prix := coalesce((v_prix_manuel->>v_cle)::numeric, public.prix_ressource_selon_stock(v_cle, v_stock));
    IF v_prix IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'ressource_inconnue', 'cle', v_cle);
    END IF;
    v_total := v_total + v_qte * v_prix;
    v_lignes := v_lignes || jsonb_build_object('cle', v_cle, 'qte', v_qte, 'prix', v_prix);
  END LOOP;

  IF jsonb_array_length(v_lignes) = 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'rien_a_acheter'); END IF;
  IF v_liquide + v_solde < v_total THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants', 'requis', v_total,
                              'disponible', v_liquide + v_solde);
  END IF;

  FOR v_idx IN 0 .. jsonb_array_length(v_lignes) - 1 LOOP
    v_ligne := v_lignes -> v_idx; v_cle := v_ligne->>'cle';
    v_ajoute := least((v_ligne->>'qte')::int, v_place);
    IF v_ajoute <= 0 THEN CONTINUE; END IF;
    v_place := v_place - v_ajoute;
    v_paye := v_paye + v_ajoute * (v_ligne->>'prix')::numeric;
    v_inv := public.inventaire_ajouter(v_inv, v_cle, v_ajoute, 'Produit acheté en vente directe.');
    v_vd := jsonb_set(v_vd, ARRAY[v_cle], to_jsonb(coalesce((v_vd->>v_cle)::numeric,0) - v_ajoute));
  END LOOP;
  IF v_paye <= 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'inventaire_plein'); END IF;

  v_pris_liquide := least(v_liquide, v_paye);
  v_pris_national := v_paye - v_pris_liquide;
  UPDATE public.personnages_donnees
     SET inventory = v_inv, liquide = v_liquide - v_pris_liquide, arg = v_arg - v_paye
   WHERE name = p_acteur;
  IF v_pris_national > 0 AND v_compte_id IS NOT NULL THEN
    UPDATE public.comptes_bancaires SET solde = solde - v_pris_national, updated_at = now() WHERE id = v_compte_id;
  END IF;

  v_usine := v_usine || jsonb_build_object('venteDirecte', v_vd,
               'caisse', coalesce((v_usine->>'caisse')::numeric,0) + v_paye);
  UPDATE public.batiments_etat
     SET data = to_jsonb((v_etat || jsonb_build_object('usine', v_usine))::text), updated_at = now()
   WHERE id = v_id;

  RETURN jsonb_build_object('ok', true, 'paye', v_paye, 'lignes', v_lignes, 'inventory', v_inv,
    'liquide', v_liquide - v_pris_liquide, 'arg', v_arg - v_paye,
    'solde_national', v_solde - v_pris_national, 'caisse_usine', (v_usine->>'caisse')::numeric);
END; $$;
REVOKE ALL ON FUNCTION public.acheter_vente_directe_usine(text,text,text,text,jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.acheter_vente_directe_usine(text,text,text,text,jsonb) TO authenticated;

-- ============================================================================
-- F5 — PRODUCTION EN USINE : le joueur travaille, l'usine le paie.
-- Le serveur decide de la quantite produite ET du salaire ; le client ne dit que
-- ce qu'il veut produire. Les PA restent preleves par payer_ordre cote client,
-- comme avant (cost:0, le salaire etant un GAIN et non un cout).
CREATE OR REPLACE FUNCTION public.produire_en_usine(p_acteur text, p_pays text, p_produit text)
RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = public, pg_temp AS $$
DECLARE
  v_ville text; v_bat text; v_matiere text; v_salaire numeric;
  v_id text; v_etat jsonb; v_usine jsonb; v_vd jsonb; v_sm jsonb;
  v_caisse numeric; v_stock_mat numeric; v_stock_prod numeric; v_place numeric; v_produits int;
  v_arg numeric; v_liquide numeric;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  SELECT ville, building_id, matiere, salaire_pa INTO v_ville, v_bat, v_matiere, v_salaire
  FROM public.chaines_production_usine WHERE produit = p_produit;
  IF v_ville IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'chaine_inconnue'); END IF;

  v_id := p_pays || '_' || v_ville || '_' || v_bat;
  SELECT public.batiment_etat_lire(data) INTO v_etat FROM public.batiments_etat WHERE id = v_id FOR UPDATE;
  IF v_etat IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'usine_introuvable'); END IF;
  v_usine := coalesce(v_etat->'usine', '{}'::jsonb);
  v_vd := coalesce(v_usine->'venteDirecte', '{}'::jsonb);
  v_sm := coalesce(v_usine->'stockMatieres', '{}'::jsonb);
  v_caisse := coalesce((v_usine->>'caisse')::numeric, 0);
  v_stock_mat := coalesce((v_sm->>v_matiere)::numeric, 0);
  v_stock_prod := coalesce((v_vd->>p_produit)::numeric, 0);

  -- Memes trois conditions qu'avant, dans le meme ordre.
  IF v_stock_mat < 5 THEN RETURN jsonb_build_object('ok', false, 'raison', 'matiere_insuffisante', 'matiere', v_matiere); END IF;
  IF v_caisse < v_salaire THEN RETURN jsonb_build_object('ok', false, 'raison', 'caisse_insuffisante'); END IF;
  v_place := greatest(0, 50 - v_stock_prod);
  IF v_place <= 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'stock_plein'); END IF;

  v_produits := least(10, v_place)::int;   -- PRODUIT_PAR_PA_USINE, plafonne par la place
  v_sm := jsonb_set(v_sm, ARRAY[v_matiere], to_jsonb(v_stock_mat - 5));  -- MATIERE_PAR_PA_USINE
  v_vd := jsonb_set(v_vd, ARRAY[p_produit], to_jsonb(v_stock_prod + v_produits));
  v_caisse := v_caisse - v_salaire;

  UPDATE public.batiments_etat
     SET data = to_jsonb((v_etat || jsonb_build_object('usine',
           v_usine || jsonb_build_object('caisse', v_caisse, 'venteDirecte', v_vd, 'stockMatieres', v_sm)))::text),
         updated_at = now()
   WHERE id = v_id;

  -- Le salaire sort de la caisse de l'usine et entre en liquide : aucune valeur
  -- creee, exactement comme le credit generique du jeu (crediterFondsOrdinaires).
  UPDATE public.personnages_donnees
     SET arg = coalesce(arg,0) + v_salaire, liquide = coalesce(liquide,0) + v_salaire
   WHERE name = p_acteur
   RETURNING arg, liquide INTO v_arg, v_liquide;
  IF v_arg IS NULL THEN RAISE EXCEPTION 'personnage_introuvable' USING ERRCODE = '42501'; END IF;

  RETURN jsonb_build_object('ok', true, 'produits', v_produits, 'salaire', v_salaire,
    'arg', v_arg, 'liquide', v_liquide, 'caisse_usine', v_caisse,
    'stock_produit', v_stock_prod + v_produits, 'stock_matiere', v_stock_mat - 5);
END; $$;
REVOKE ALL ON FUNCTION public.produire_en_usine(text,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.produire_en_usine(text,text,text) TO authenticated;