-- =============================================================================
-- EFFORT DE GUERRE — SOCLE DE DONNEES (13 septembre 2026)
-- =============================================================================
-- APPLIQUE EN PRODUCTION EN TROIS MIGRATIONS, dans cet ordre :
--   20260913000654  effort_guerre_tables_et_reserve
--   20260913000821  effort_guerre_stock_caserne_et_refectoire
--   20260913001007  effort_guerre_production_et_ravitaillement
--   + effort_guerre_correctif_entrepots_vides   (garde FOREACH sur tableau vide)
--   + effort_guerre_durcissement_droits_rpc     (REVOKE nommant anon/authenticated)
-- Ce fichier est leur reunion, a l'identique. Il est rejouable : tout y est
-- CREATE TABLE IF NOT EXISTS / CREATE OR REPLACE FUNCTION.
-- =============================================================================
-- Deux tables et six RPC. Aucune donnee existante n'est modifiee ni supprimee :
--   * l'etat de l'Effort (drapeau, curseurs) vit dans budgets_nationaux.data.effortGuerre
--   * la reserve militaire dans batiments_etat.data.entrepot.reserveMilitaire
--   * le stock militaire dans budgets_nationaux.data.stockArmurerieMilitaire (cle existante)
--   * le refectoire dans budgets_nationaux.data.refectoire
-- tous crees a la demande, tous retro-compatibles avec l'absence de la cle.
--
-- CONVENTION batiments_etat.data : colonne jsonb contenant une CHAINE JSON (double
-- encodage historique). Toutes les RPC ci-dessous normalisent a la lecture
-- (jsonb_typeof = 'string' -> #>> '{}') et reecrivent en to_jsonb(texte), exactement
-- comme batiment_caisse_mouvement (migration_caisses_batiments_etat.sql).
-- budgets_nationaux.data et entreprises.data sont, eux, du jsonb NATIF.
--
-- VERROUS : toute RPC qui touche plusieurs lignes les verrouille dans un ordre
-- deterministe (id croissant, puis toujours la meme sequence de tables) — deux
-- appels simultanes se serialisent au lieu de s'ecraser, sans inter-blocage possible.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. FILE DES COMMANDES MILITAIRES (FIFO)
-- -----------------------------------------------------------------------------
-- Une ligne par commande. Le reliquat non produit vaut (quantite_demandee -
-- quantite_produite) ; l'annulation et la fin d'Effort passent le statut a
-- 'annulee' sans jamais toucher quantite_produite, qui reste la trace de ce qui a
-- reellement ete produit, paye et livre.
CREATE TABLE IF NOT EXISTS public.commandes_militaires (
  id                 text PRIMARY KEY,
  pays               text NOT NULL,
  produit            text NOT NULL,
  quantite_demandee  integer NOT NULL CHECK (quantite_demandee > 0),
  quantite_produite  integer NOT NULL DEFAULT 0 CHECK (quantite_produite >= 0),
  statut             text NOT NULL DEFAULT 'en_cours',
  ministre           text,
  created_at         timestamptz NOT NULL DEFAULT now(),
  updated_at         timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT commandes_militaires_statut CHECK (statut IN ('en_cours','terminee','annulee')),
  CONSTRAINT commandes_militaires_reliquat CHECK (quantite_produite <= quantite_demandee)
);

-- FIFO : l'ordre de service est celui de creation, a statut egal.
CREATE INDEX IF NOT EXISTS commandes_militaires_fifo
  ON public.commandes_militaires (pays, statut, created_at);

-- -----------------------------------------------------------------------------
-- 2. REGISTRE DES SORTIES DE MATERIEL MILITAIRE
-- -----------------------------------------------------------------------------
-- Registre UNIQUE, partage par les armes et les explosifs : la decision du 13/09
-- demande de reutiliser un registre generique plutot que d'ouvrir deux bureaucraties.
-- Il s'arrete au Lieutenant — la redistribution ulterieure a ses hommes n'est jamais
-- enregistree. Une SUBTILISATION n'ecrit jamais ici : c'est precisement ce qui la
-- distingue d'un retrait reglementaire.
CREATE TABLE IF NOT EXISTS public.retraits_materiel_militaire (
  id          bigserial PRIMARY KEY,
  pays        text NOT NULL,
  materiel    text NOT NULL,
  lot         text,
  quantite    integer NOT NULL CHECK (quantite > 0),
  lieutenant  text NOT NULL,
  section     text,
  jour        integer,
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS retraits_materiel_militaire_pays
  ON public.retraits_materiel_militaire (pays, created_at DESC);

-- Lecture publique (le registre est consultable en jeu), ecriture par RPC uniquement.
ALTER TABLE public.commandes_militaires        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.retraits_materiel_militaire ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS commandes_militaires_lecture ON public.commandes_militaires;
CREATE POLICY commandes_militaires_lecture ON public.commandes_militaires
  FOR SELECT USING (true);

DROP POLICY IF EXISTS retraits_materiel_militaire_lecture ON public.retraits_materiel_militaire;
CREATE POLICY retraits_materiel_militaire_lecture ON public.retraits_materiel_militaire
  FOR SELECT USING (true);

-- =============================================================================
-- HELPERS INTERNES
-- =============================================================================
-- Normalisation du blob batiments_etat (chaine JSON ou objet).
CREATE OR REPLACE FUNCTION public.eg_etat_lire(p_brut jsonb)
RETURNS jsonb LANGUAGE sql IMMUTABLE
SET search_path TO 'public', 'pg_temp'
AS $fn$
  SELECT CASE
    WHEN p_brut IS NULL THEN '{}'::jsonb
    WHEN jsonb_typeof(p_brut) = 'string' THEN (p_brut #>> '{}')::jsonb
    WHEN jsonb_typeof(p_brut) = 'object' THEN p_brut
    ELSE '{}'::jsonb END;
$fn$;

-- Id de ligne batiments_etat a partir d'une entree {building, city}.
CREATE OR REPLACE FUNCTION public.eg_etat_id(p_pays text, p_entrepot jsonb)
RETURNS text LANGUAGE sql IMMUTABLE
SET search_path TO 'public', 'pg_temp'
AS $fn$
  SELECT p_pays || '_' || (p_entrepot ->> 'city') || '_' || (p_entrepot ->> 'building');
$fn$;

-- =============================================================================
-- 3. RESERVE MILITAIRE SUR LES ENTREPOTS
-- =============================================================================
-- effort_reserve_appliquer(pays, entrepots, ressources, pct)
--   p_entrepots : [{"building":"entrepot-logistique-luthecia","city":"capitale"}, ...]
--                 L'enumeration vient du client/cron (source unique cote JS), la RPC
--                 ne devine jamais quels batiments sont des entrepots.
--   p_ressources: matieres eligibles, deduites des recettes militaires cote JS.
--
-- Recalcule la reserve NATIONALE et la repartit sur les entrepots au prorata de leur
-- stock reel. Aucun stock n'est cree, deplace ni paye : la reserve est une quantite
-- marquee indisponible aux usages civils, la marchandise reste ou elle est.
-- pct = 0 libere tout (fin d'Effort, curseur a zero) : la cle est alors retiree.
CREATE OR REPLACE FUNCTION public.effort_reserve_appliquer(
  p_pays       text,
  p_entrepots  jsonb,
  p_ressources text[],
  p_pct        numeric
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $fn$
DECLARE
  v_pct      numeric;
  v_ent      jsonb;
  v_id       text;
  v_ids      text[] := ARRAY[]::text[];
  v_etats    jsonb := '{}'::jsonb;
  v_d        jsonb;
  v_stock    jsonb;
  v_res      text;
  v_total    numeric;
  v_cible    numeric;
  v_pose     numeric;
  v_q        numeric;
  v_dispo    numeric;
  v_reste    numeric;
  v_avance   boolean;
  v_reserves jsonb := '{}'::jsonb;
  v_totaux   jsonb := '{}'::jsonb;
  v_obj      jsonb;
BEGIN
  IF COALESCE(btrim(p_pays), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;
  IF p_entrepots IS NULL OR jsonb_typeof(p_entrepots) <> 'array'
     OR jsonb_array_length(p_entrepots) = 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucun_entrepot');
  END IF;
  IF p_ressources IS NULL OR array_length(p_ressources, 1) IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucune_ressource');
  END IF;

  v_pct := LEAST(100, GREATEST(0, COALESCE(p_pct, 0)));

  -- Ordre de verrouillage deterministe : id croissant.
  SELECT array_agg(x ORDER BY x) INTO v_ids
  FROM (SELECT public.eg_etat_id(p_pays, e) AS x
        FROM jsonb_array_elements(p_entrepots) AS e) s;

  FOREACH v_id IN ARRAY v_ids LOOP
    SELECT public.eg_etat_lire(data) INTO v_d
      FROM public.batiments_etat WHERE id = v_id FOR UPDATE;
    IF NOT FOUND THEN CONTINUE; END IF;
    v_etats := v_etats || jsonb_build_object(v_id, v_d);
  END LOOP;

  IF v_etats = '{}'::jsonb THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucun_entrepot_trouve');
  END IF;

  -- --- Cible nationale, puis repartition au prorata des stocks reels -----------
  FOREACH v_res IN ARRAY p_ressources LOOP
    v_total := 0;
    FOR v_id IN SELECT k FROM jsonb_object_keys(v_etats) k ORDER BY 1 LOOP
      v_stock := COALESCE(v_etats -> v_id -> 'entrepot' -> 'stock', '{}'::jsonb);
      v_total := v_total + GREATEST(0, COALESCE((v_stock ->> v_res)::numeric, 0));
    END LOOP;

    v_cible  := floor(v_total * v_pct / 100.0);
    v_totaux := v_totaux || jsonb_build_object(v_res, v_cible);

    -- Passe 1 : part proportionnelle tronquee, bornee par le stock local.
    v_pose := 0;
    FOR v_id IN SELECT k FROM jsonb_object_keys(v_etats) k ORDER BY 1 LOOP
      v_stock := COALESCE(v_etats -> v_id -> 'entrepot' -> 'stock', '{}'::jsonb);
      v_dispo := GREATEST(0, COALESCE((v_stock ->> v_res)::numeric, 0));
      v_q := CASE WHEN v_total > 0 THEN LEAST(v_dispo, floor(v_cible * v_dispo / v_total)) ELSE 0 END;
      v_reserves := v_reserves || jsonb_build_object(
        v_id, COALESCE(v_reserves -> v_id, '{}'::jsonb) || jsonb_build_object(v_res, v_q));
      v_pose := v_pose + v_q;
    END LOOP;

    -- Passe 2 : le reste de la troncature va, unite par unite, aux entrepots qui ont
    -- encore du stock libre. Aucune reserve ne depasse jamais le stock reellement present.
    v_reste := v_cible - v_pose;
    WHILE v_reste > 0 LOOP
      v_avance := false;
      FOR v_id IN SELECT k FROM jsonb_object_keys(v_etats) k ORDER BY 1 LOOP
        EXIT WHEN v_reste <= 0;
        v_stock := COALESCE(v_etats -> v_id -> 'entrepot' -> 'stock', '{}'::jsonb);
        v_dispo := GREATEST(0, COALESCE((v_stock ->> v_res)::numeric, 0));
        v_q := COALESCE((v_reserves -> v_id ->> v_res)::numeric, 0);
        IF v_q < v_dispo THEN
          v_reserves := v_reserves || jsonb_build_object(
            v_id, (v_reserves -> v_id) || jsonb_build_object(v_res, v_q + 1));
          v_reste  := v_reste - 1;
          v_avance := true;
        END IF;
      END LOOP;
      EXIT WHEN NOT v_avance;   -- plus aucune place : la cible n'est pas atteignable
    END LOOP;
  END LOOP;

  -- --- Ecriture ---------------------------------------------------------------
  FOR v_id IN SELECT k FROM jsonb_object_keys(v_etats) k ORDER BY 1 LOOP
    v_d   := v_etats -> v_id;
    v_obj := COALESCE(v_d -> 'entrepot', '{}'::jsonb);
    IF v_pct = 0 THEN
      v_obj := v_obj - 'reserveMilitaire';
    ELSE
      v_obj := v_obj || jsonb_build_object('reserveMilitaire',
                                           COALESCE(v_reserves -> v_id, '{}'::jsonb));
    END IF;
    v_d := v_d || jsonb_build_object('entrepot', v_obj);
    UPDATE public.batiments_etat
       SET data = to_jsonb(v_d::text), updated_at = now()
     WHERE id = v_id;
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'pct', v_pct,
                            'reserves', v_reserves, 'totaux', v_totaux);
END;
$fn$;

-- =============================================================================
-- 4. STOCK MILITAIRE DE LA CASERNE (avec file de lots)
-- =============================================================================
-- budgets_nationaux.data.stockArmurerieMilitaire : compteurs (cle historique, conservee).
-- budgets_nationaux.data.lotsMilitaires[produit]  : file FIFO [{lot, qte}] permettant
--   d'attribuer une provenance a chaque unite sortie. Un stock anterieur a ce chantier
--   (ou une desynchronisation) est servi sous le lot 'legacy' : jamais de refus pour
--   absence de lot, jamais de creation d'unite.
--
-- p_delta > 0 : production (p_lot obligatoire) — ajoute au compteur et a la file.
-- p_delta < 0 : retrait ou subtilisation — consomme la file FIFO, renvoie les lots servis.
CREATE OR REPLACE FUNCTION public.caserne_stock_mouvement(
  p_pays    text,
  p_produit text,
  p_delta   integer,
  p_lot     text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $fn$
DECLARE
  v_data   jsonb;
  v_stock  jsonb;
  v_lots   jsonb;
  v_file   jsonb;
  v_cur    integer;
  v_reste  integer;
  v_servis jsonb := '[]'::jsonb;
  v_tete   jsonb;
  v_q      integer;
  v_pris   integer;
BEGIN
  IF COALESCE(btrim(p_pays), '') = '' OR COALESCE(btrim(p_produit), '') = ''
     OR p_delta IS NULL OR p_delta = 0 OR abs(p_delta) > 100000 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;
  IF p_delta > 0 AND COALESCE(btrim(p_lot), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'lot_obligatoire');
  END IF;

  SELECT data INTO v_data FROM public.budgets_nationaux WHERE id = p_pays FOR UPDATE;
  IF NOT FOUND THEN
    IF p_delta < 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'stock_insuffisant', 'stock', 0); END IF;
    v_data := '{}'::jsonb;
    INSERT INTO public.budgets_nationaux (id, data, updated_at) VALUES (p_pays, v_data, now());
  END IF;
  v_data := COALESCE(v_data, '{}'::jsonb);

  v_stock := CASE WHEN jsonb_typeof(v_data -> 'stockArmurerieMilitaire') = 'object'
                  THEN v_data -> 'stockArmurerieMilitaire' ELSE '{}'::jsonb END;
  v_lots  := CASE WHEN jsonb_typeof(v_data -> 'lotsMilitaires') = 'object'
                  THEN v_data -> 'lotsMilitaires' ELSE '{}'::jsonb END;
  v_cur   := GREATEST(0, COALESCE((v_stock ->> p_produit)::integer, 0));
  v_file  := CASE WHEN jsonb_typeof(v_lots -> p_produit) = 'array'
                  THEN v_lots -> p_produit ELSE '[]'::jsonb END;

  IF v_cur + p_delta < 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'stock_insuffisant', 'stock', v_cur);
  END IF;

  IF p_delta > 0 THEN
    v_file := v_file || jsonb_build_array(jsonb_build_object('lot', p_lot, 'qte', p_delta));
  ELSE
    -- Consommation FIFO. Si la file est plus courte que le compteur (stock anterieur au
    -- systeme de lots), le solde est servi sous 'legacy' : le compteur reste l'autorite.
    v_reste := -p_delta;
    WHILE v_reste > 0 AND jsonb_array_length(v_file) > 0 LOOP
      v_tete := v_file -> 0;
      v_q    := GREATEST(0, COALESCE((v_tete ->> 'qte')::integer, 0));
      v_pris := LEAST(v_q, v_reste);
      IF v_pris > 0 THEN
        v_servis := v_servis || jsonb_build_array(
          jsonb_build_object('lot', v_tete ->> 'lot', 'qte', v_pris));
        v_reste := v_reste - v_pris;
      END IF;
      IF v_q - v_pris <= 0 THEN
        v_file := v_file - 0;
      ELSE
        v_file := jsonb_set(v_file, ARRAY['0','qte'], to_jsonb(v_q - v_pris));
      END IF;
    END LOOP;
    IF v_reste > 0 THEN
      v_servis := v_servis || jsonb_build_array(jsonb_build_object('lot', 'legacy', 'qte', v_reste));
    END IF;
  END IF;

  v_stock := v_stock || jsonb_build_object(p_produit, v_cur + p_delta);
  v_lots  := v_lots  || jsonb_build_object(p_produit, v_file);
  v_data  := v_data  || jsonb_build_object('stockArmurerieMilitaire', v_stock,
                                           'lotsMilitaires', v_lots);

  UPDATE public.budgets_nationaux SET data = v_data, updated_at = now() WHERE id = p_pays;

  RETURN jsonb_build_object('ok', true, 'produit', p_produit,
                            'stock', v_cur + p_delta, 'lots', v_servis);
END;
$fn$;

-- =============================================================================
-- 5. RETRAIT REGLEMENTAIRE PAR LE CHEF DE SECTION
-- =============================================================================
-- Decremente le stock ET inscrit au registre dans la MEME transaction : jamais de
-- materiel sorti sans trace, jamais de trace sans materiel. Verifie cote serveur
-- que le demandeur est bien un lieutenant physiquement present a la caserne.
CREATE OR REPLACE FUNCTION public.militaire_retrait(
  p_pays      text,
  p_produit   text,
  p_quantite  integer,
  p_lieutenant text,
  p_section   text,
  p_jour      integer
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $fn$
DECLARE
  v_pj   personnages%ROWTYPE;
  v_mvt  jsonb;
  v_lot  jsonb;
BEGIN
  IF COALESCE(p_quantite, 0) <= 0 OR p_quantite > 1000 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'quantite_invalide');
  END IF;
  IF p_produit NOT IN ('arme_de_poing', 'mitraillette', 'explosif_militaire') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'produit_invalide');
  END IF;

  SELECT * INTO v_pj FROM public.personnages WHERE name = p_lieutenant FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_absent'); END IF;

  -- Le retrait est un acte physique : il se fait a l'armurerie de la caserne.
  IF COALESCE(v_pj.current_building, '') <> 'caserne-militaire' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place');
  END IF;
  IF COALESCE(v_pj.poste ->> 'id', '') <> 'lieutenant' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_chef_de_section');
  END IF;

  v_mvt := public.caserne_stock_mouvement(p_pays, p_produit, -p_quantite, NULL);
  IF COALESCE((v_mvt ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_mvt; END IF;

  -- Une ligne de registre par lot servi : le registre dit la verite sur la provenance.
  FOR v_lot IN SELECT value FROM jsonb_array_elements(COALESCE(v_mvt -> 'lots', '[]'::jsonb)) LOOP
    INSERT INTO public.retraits_materiel_militaire
      (pays, materiel, lot, quantite, lieutenant, section, jour)
    VALUES (p_pays, p_produit, v_lot ->> 'lot', (v_lot ->> 'qte')::integer,
            p_lieutenant, p_section, p_jour);
  END LOOP;

  RETURN v_mvt || jsonb_build_object('registre', true);
END;
$fn$;

-- =============================================================================
-- 6. REFECTOIRE — REPAS DE LA CASERNE
-- =============================================================================
-- Tout-ou-rien : la ration, la fabrication automatique du lot de 10, le marqueur
-- quotidien et le gain de PA sont poses dans une seule transaction. Aucune matiere
-- n'est consommee partiellement, aucun PA n'est accorde sans ration reellement mangee.
-- Viande et poisson sont equivalents : regle deterministe = viande d'abord, poisson ensuite.
CREATE OR REPLACE FUNCTION public.refectoire_repas(
  p_pays   text,
  p_joueur text,
  p_jour   integer,
  p_pa_max integer DEFAULT 30,
  p_gain   integer DEFAULT 2
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $fn$
DECLARE
  v_pj     personnages%ROWTYPE;
  v_stats  jsonb;
  v_data   jsonb;
  v_ref    jsonb;
  v_brut   jsonb;
  v_rations integer;
  v_cer    integer;
  v_via    integer;
  v_poi    integer;
  v_prot   text;
  v_fab    boolean := false;
  v_pa     integer;
BEGIN
  IF COALESCE(btrim(p_pays), '') = '' OR COALESCE(btrim(p_joueur), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;

  SELECT * INTO v_pj FROM public.personnages WHERE name = p_joueur FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_absent'); END IF;

  -- Presence physique verifiee cote serveur : tout PJ present, quel que soit son statut.
  IF COALESCE(v_pj.current_building, '') <> 'caserne-militaire' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place');
  END IF;

  v_stats := CASE WHEN jsonb_typeof(v_pj.stats) = 'object' THEN v_pj.stats ELSE '{}'::jsonb END;
  IF COALESCE((v_stats ->> 'repasCaserneJour')::integer, -1) = p_jour THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_mange');
  END IF;

  SELECT data INTO v_data FROM public.budgets_nationaux WHERE id = p_pays FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'refectoire_vide'); END IF;
  v_data := COALESCE(v_data, '{}'::jsonb);

  v_ref  := CASE WHEN jsonb_typeof(v_data -> 'refectoire') = 'object'
                 THEN v_data -> 'refectoire' ELSE '{}'::jsonb END;
  v_brut := CASE WHEN jsonb_typeof(v_ref -> 'brut') = 'object'
                 THEN v_ref -> 'brut' ELSE '{}'::jsonb END;
  v_rations := GREATEST(0, COALESCE((v_ref ->> 'rations')::integer, 0));

  IF v_rations <= 0 THEN
    -- Fabrication automatique d'un lot de 10 : 1 cereale + 1 (viande OU poisson).
    v_cer := GREATEST(0, COALESCE((v_brut ->> 'cereales')::integer, 0));
    v_via := GREATEST(0, COALESCE((v_brut ->> 'viande')::integer, 0));
    v_poi := GREATEST(0, COALESCE((v_brut ->> 'poisson')::integer, 0));
    IF v_cer < 1 OR (v_via + v_poi) < 1 THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'ingredients_insuffisants',
                                'cereales', v_cer, 'viande', v_via, 'poisson', v_poi);
    END IF;
    v_prot := CASE WHEN v_via >= 1 THEN 'viande' ELSE 'poisson' END;
    v_brut := v_brut || jsonb_build_object('cereales', v_cer - 1,
                                           v_prot, (CASE WHEN v_prot = 'viande' THEN v_via ELSE v_poi END) - 1);
    v_rations := 10;
    v_fab := true;
  END IF;

  v_rations := v_rations - 1;
  v_ref  := v_ref || jsonb_build_object('brut', v_brut, 'rations', v_rations);
  v_data := v_data || jsonb_build_object('refectoire', v_ref);
  UPDATE public.budgets_nationaux SET data = v_data, updated_at = now() WHERE id = p_pays;

  v_pa := LEAST(COALESCE(p_pa_max, 30),
                GREATEST(0, COALESCE(v_pj.pa, 0)) + GREATEST(0, COALESCE(p_gain, 2)));
  UPDATE public.personnages
     SET pa = v_pa,
         stats = v_stats || jsonb_build_object('repasCaserneJour', p_jour)
   WHERE name = p_joueur;

  RETURN jsonb_build_object('ok', true, 'pa', v_pa, 'rations', v_rations,
                            'fabrique', v_fab, 'proteine', v_prot);
END;
$fn$;

-- =============================================================================
-- 7. PRODUCTION MILITAIRE — UNE UNITE DE RECETTE, TOUT OU RIEN
-- =============================================================================
-- Une passe = un lot de recette (p_produit_par_lot unites). Tout est applique ou rien :
--   1. matieres prelevees sur la RESERVE MILITAIRE des entrepots (stock ET reserve)
--   2. caisse de la caserne debitee du cout de revient
--   3. caisse de l'armurerie creditee du MEME montant (regle du 13/09 : marge = cout de revient,
--      aucun second paiement des matieres, aucune main-d'oeuvre separee, aucune seconde marge)
--   4. stock militaire de la caserne credite, avec son lot
--   5. commande avancee, terminee si complete
--   6. inscription au registre des ventes d'armes, au montant reellement paye
--
-- p_recette : {"materiaux":{"metal":2,"bois":1},"produitParLot":1}
-- Le cout est calcule PAR L'APPELANT (coutRevientLotMilitaire / coutRevientLotMilitaireServeur),
-- source unique, pour que le montant credite et le montant facture soient le meme nombre.
CREATE OR REPLACE FUNCTION public.effort_produire_lot(
  p_pays        text,
  p_commande_id text,
  p_armurerie   text,
  p_entrepots   jsonb,
  p_recette     jsonb,
  p_cout_revient numeric,
  p_lot         text,
  p_arme_label  text,
  p_ville_arm   text,
  p_jour        integer
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $fn$
DECLARE
  v_cmd      public.commandes_militaires%ROWTYPE;
  v_ids      text[];
  v_id       text;
  v_etats    jsonb := '{}'::jsonb;
  v_d        jsonb;
  v_mat      text;
  v_besoin   numeric;
  v_dispo    numeric;
  v_reste    numeric;
  v_pris     numeric;
  v_stock    jsonb;
  v_res      jsonb;
  v_obj      jsonb;
  v_caisse   text;
  v_solde    numeric;
  v_ent      jsonb;
  v_arm      jsonb;
  v_parlot   integer;
  v_mvt      jsonb;
  v_conso    jsonb := '{}'::jsonb;
BEGIN
  IF COALESCE(p_cout_revient, -1) < 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cout_invalide');
  END IF;
  IF p_entrepots IS NULL OR jsonb_typeof(p_entrepots) <> 'array'
     OR jsonb_array_length(p_entrepots) = 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucun_entrepot');
  END IF;
  v_parlot := GREATEST(1, COALESCE((p_recette ->> 'produitParLot')::integer, 1));

  -- --- 1. Commande (verrou en premier, c'est la racine de la transaction) ------
  SELECT * INTO v_cmd FROM public.commandes_militaires
    WHERE id = p_commande_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'commande_absente'); END IF;
  IF v_cmd.statut <> 'en_cours' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'commande_close');
  END IF;
  IF v_cmd.quantite_produite + v_parlot > v_cmd.quantite_demandee THEN
    v_parlot := v_cmd.quantite_demandee - v_cmd.quantite_produite;
    IF v_parlot <= 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'commande_complete'); END IF;
  END IF;

  -- --- 2. Entrepots (ordre deterministe) --------------------------------------
  SELECT COALESCE(array_agg(x ORDER BY x), ARRAY[]::text[]) INTO v_ids
  FROM (SELECT public.eg_etat_id(p_pays, e) AS x FROM jsonb_array_elements(p_entrepots) e) s;

  FOREACH v_id IN ARRAY v_ids LOOP
    SELECT public.eg_etat_lire(data) INTO v_d FROM public.batiments_etat WHERE id = v_id FOR UPDATE;
    IF FOUND THEN v_etats := v_etats || jsonb_build_object(v_id, v_d); END IF;
  END LOOP;
  IF v_etats = '{}'::jsonb THEN RETURN jsonb_build_object('ok', false, 'raison', 'aucun_entrepot_trouve'); END IF;

  -- Verification globale AVANT toute mutation : les matieres sont prises sur la reserve
  -- militaire, jamais sur le stock civil libre.
  FOR v_mat IN SELECT k FROM jsonb_object_keys(COALESCE(p_recette -> 'materiaux', '{}'::jsonb)) k LOOP
    v_besoin := COALESCE((p_recette -> 'materiaux' ->> v_mat)::numeric, 0);
    v_dispo := 0;
    FOR v_id IN SELECT k2 FROM jsonb_object_keys(v_etats) k2 ORDER BY 1 LOOP
      v_ent := COALESCE(v_etats -> v_id -> 'entrepot', '{}'::jsonb);
      v_dispo := v_dispo + LEAST(
        GREATEST(0, COALESCE((v_ent -> 'stock' ->> v_mat)::numeric, 0)),
        GREATEST(0, COALESCE((v_ent -> 'reserveMilitaire' ->> v_mat)::numeric, 0)));
    END LOOP;
    IF v_dispo < v_besoin THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'matieres_insuffisantes',
                                'matiere', v_mat, 'requis', v_besoin, 'reserve', v_dispo);
    END IF;
  END LOOP;

  -- --- 3. Caisse de la caserne (tout-ou-rien, aucun credit) --------------------
  v_caisse := p_pays || '_caserne-militaire';
  SELECT COALESCE((data ->> 'solde')::numeric, 0) INTO v_solde
    FROM public.caisses_batiments WHERE id = v_caisse FOR UPDATE;
  IF NOT FOUND THEN v_solde := 0; END IF;
  IF v_solde < p_cout_revient THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caisse_insuffisante', 'solde', v_solde);
  END IF;

  -- --- 4. Armurerie -----------------------------------------------------------
  SELECT data INTO v_arm FROM public.entreprises WHERE id = p_armurerie FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'armurerie_absente'); END IF;

  -- ===== A partir d'ici, tout est applique =====================================

  -- Prelevement des matieres, au prorata de ce que chaque entrepot a en reserve.
  FOR v_mat IN SELECT k FROM jsonb_object_keys(COALESCE(p_recette -> 'materiaux', '{}'::jsonb)) k LOOP
    v_reste := COALESCE((p_recette -> 'materiaux' ->> v_mat)::numeric, 0);
    FOR v_id IN SELECT k2 FROM jsonb_object_keys(v_etats) k2 ORDER BY 1 LOOP
      EXIT WHEN v_reste <= 0;
      v_d    := v_etats -> v_id;
      v_ent  := COALESCE(v_d -> 'entrepot', '{}'::jsonb);
      v_stock := COALESCE(v_ent -> 'stock', '{}'::jsonb);
      v_res   := COALESCE(v_ent -> 'reserveMilitaire', '{}'::jsonb);
      v_pris := LEAST(v_reste,
                      GREATEST(0, COALESCE((v_stock ->> v_mat)::numeric, 0)),
                      GREATEST(0, COALESCE((v_res   ->> v_mat)::numeric, 0)));
      IF v_pris <= 0 THEN CONTINUE; END IF;
      v_stock := v_stock || jsonb_build_object(v_mat, COALESCE((v_stock ->> v_mat)::numeric, 0) - v_pris);
      v_res   := v_res   || jsonb_build_object(v_mat, COALESCE((v_res   ->> v_mat)::numeric, 0) - v_pris);
      v_ent   := v_ent   || jsonb_build_object('stock', v_stock, 'reserveMilitaire', v_res);
      v_etats := v_etats || jsonb_build_object(v_id, v_d || jsonb_build_object('entrepot', v_ent));
      v_reste := v_reste - v_pris;
      v_conso := v_conso || jsonb_build_object(v_mat,
        COALESCE((v_conso ->> v_mat)::numeric, 0) + v_pris);
    END LOOP;
  END LOOP;

  FOR v_id IN SELECT k FROM jsonb_object_keys(v_etats) k ORDER BY 1 LOOP
    UPDATE public.batiments_etat
       SET data = to_jsonb((v_etats -> v_id)::text), updated_at = now()
     WHERE id = v_id;
  END LOOP;

  -- Caisse caserne -> caisse armurerie, meme montant, aucune creation de monnaie.
  UPDATE public.caisses_batiments
     SET data = COALESCE(data, '{}'::jsonb) || jsonb_build_object('solde', v_solde - p_cout_revient),
         updated_at = now()
   WHERE id = v_caisse;

  v_arm := COALESCE(v_arm, '{}'::jsonb);
  v_arm := v_arm || jsonb_build_object(
    'caisse', COALESCE((v_arm ->> 'caisse')::numeric, 0) + p_cout_revient,
    'historique', COALESCE(v_arm -> 'historique', '[]'::jsonb) || jsonb_build_array(
      jsonb_build_object('jour', p_jour, 'montant', p_cout_revient,
                         'motif', 'Commande militaire — ' || COALESCE(p_arme_label, ''))));
  UPDATE public.entreprises SET data = v_arm, updated_at = now() WHERE id = p_armurerie;

  -- Livraison au stock de la caserne, sous son lot de production.
  v_mvt := public.caserne_stock_mouvement(p_pays, v_cmd.produit, v_parlot, p_lot);
  IF COALESCE((v_mvt ->> 'ok')::boolean, false) IS NOT TRUE THEN
    RAISE EXCEPTION 'caserne_stock_mouvement a echoue: %', v_mvt;
  END IF;

  UPDATE public.commandes_militaires
     SET quantite_produite = quantite_produite + v_parlot,
         statut = CASE WHEN quantite_produite + v_parlot >= quantite_demandee
                       THEN 'terminee' ELSE 'en_cours' END,
         updated_at = now()
   WHERE id = p_commande_id;

  -- Registre des ventes d'armes : le montant REELLEMENT credite a l'armurier.
  INSERT INTO public.registre_ventes_armes (joueur, arme, prix, pays, city, jour, heure)
  VALUES (COALESCE(v_arm ->> 'proprietaire', 'PNJ'),
          COALESCE(p_arme_label, v_cmd.produit) || ' (commande militaire)',
          round(p_cout_revient)::integer, p_pays, p_ville_arm, COALESCE(p_jour, 1), 0);

  RETURN jsonb_build_object('ok', true, 'produit', v_cmd.produit, 'quantite', v_parlot,
                            'lot', p_lot, 'cout', p_cout_revient, 'matieres', v_conso,
                            'armurerie', p_armurerie,
                            'caisseArmurerie', COALESCE((v_arm ->> 'caisse')::numeric, 0));
END;
$fn$;

-- =============================================================================
-- 8. RAVITAILLEMENT — ACHAT ALIMENTAIRE VERS LE REFECTOIRE
-- =============================================================================
-- Les denrees sont REELLEMENT ACHETEES au prix normal : la caisse de la caserne paie,
-- les caisses des entrepots encaissent. Aucun stock n'est cree. Le plafond est le
-- minimum entre l'objectif du curseur, le stock reel et ce que la caisse peut payer.
-- Viande et poisson sont equivalents : viande d'abord, poisson pour le solde.
CREATE OR REPLACE FUNCTION public.effort_ravitailler(
  p_pays      text,
  p_entrepots jsonb,
  p_cibles    jsonb,
  p_prix      jsonb
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $fn$
DECLARE
  v_ids     text[];
  v_id      text;
  v_etats   jsonb := '{}'::jsonb;
  v_d       jsonb;
  v_res     text;
  v_reste   numeric;
  v_pris    numeric;
  v_prix    numeric;
  v_cout    numeric;
  v_total   numeric := 0;
  v_caisse  text;
  v_solde   numeric;
  v_ent     jsonb;
  v_stock   jsonb;
  v_resv    jsonb;
  v_dispo   numeric;
  v_achats  jsonb := '{}'::jsonb;
  v_data    jsonb;
  v_ref     jsonb;
  v_brut    jsonb;
BEGIN
  -- array_agg sur zero ligne renvoie NULL, et FOREACH sur NULL leve une erreur 22004 au lieu de
  -- sortir proprement : on refuse donc explicitement un tableau vide (correctif du 13/09/2026).
  IF p_entrepots IS NULL OR jsonb_typeof(p_entrepots) <> 'array'
     OR jsonb_array_length(p_entrepots) = 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucun_entrepot');
  END IF;

  v_caisse := p_pays || '_caserne-militaire';
  SELECT COALESCE((data ->> 'solde')::numeric, 0) INTO v_solde
    FROM public.caisses_batiments WHERE id = v_caisse FOR UPDATE;
  IF NOT FOUND THEN v_solde := 0; END IF;
  IF v_solde <= 0 THEN RETURN jsonb_build_object('ok', true, 'achats', '{}'::jsonb, 'total', 0); END IF;

  SELECT COALESCE(array_agg(x ORDER BY x), ARRAY[]::text[]) INTO v_ids
  FROM (SELECT public.eg_etat_id(p_pays, e) AS x FROM jsonb_array_elements(p_entrepots) e) s;
  FOREACH v_id IN ARRAY v_ids LOOP
    SELECT public.eg_etat_lire(data) INTO v_d FROM public.batiments_etat WHERE id = v_id FOR UPDATE;
    IF FOUND THEN v_etats := v_etats || jsonb_build_object(v_id, v_d); END IF;
  END LOOP;
  IF v_etats = '{}'::jsonb THEN RETURN jsonb_build_object('ok', false, 'raison', 'aucun_entrepot_trouve'); END IF;

  FOR v_res IN SELECT k FROM jsonb_object_keys(COALESCE(p_cibles, '{}'::jsonb)) k ORDER BY 1 LOOP
    v_reste := GREATEST(0, COALESCE((p_cibles ->> v_res)::numeric, 0));
    v_prix  := GREATEST(0, COALESCE((p_prix ->> v_res)::numeric, 0));
    CONTINUE WHEN v_reste <= 0 OR v_prix <= 0;

    FOR v_id IN SELECT k2 FROM jsonb_object_keys(v_etats) k2 ORDER BY 1 LOOP
      EXIT WHEN v_reste <= 0 OR v_solde < v_prix;
      v_d     := v_etats -> v_id;
      v_ent   := COALESCE(v_d -> 'entrepot', '{}'::jsonb);
      v_stock := COALESCE(v_ent -> 'stock', '{}'::jsonb);
      v_resv  := COALESCE(v_ent -> 'reserveMilitaire', '{}'::jsonb);
      -- Le ravitaillement achete sur le stock LIBRE : il ne pioche pas dans la reserve
      -- de production militaire, qui est destinee aux armureries.
      v_dispo := GREATEST(0, COALESCE((v_stock ->> v_res)::numeric, 0))
               - GREATEST(0, COALESCE((v_resv  ->> v_res)::numeric, 0));
      v_pris := LEAST(v_reste, GREATEST(0, v_dispo), floor(v_solde / v_prix));
      CONTINUE WHEN v_pris <= 0;

      v_cout  := v_pris * v_prix;
      v_stock := v_stock || jsonb_build_object(v_res, COALESCE((v_stock ->> v_res)::numeric, 0) - v_pris);
      v_ent   := v_ent || jsonb_build_object('stock', v_stock,
                   'caisse', COALESCE((v_ent ->> 'caisse')::numeric, 0) + v_cout);
      v_etats := v_etats || jsonb_build_object(v_id, v_d || jsonb_build_object('entrepot', v_ent));
      v_solde := v_solde - v_cout;
      v_total := v_total + v_cout;
      v_reste := v_reste - v_pris;
      v_achats := v_achats || jsonb_build_object(v_res,
        COALESCE((v_achats ->> v_res)::numeric, 0) + v_pris);
    END LOOP;
  END LOOP;

  IF v_total <= 0 THEN RETURN jsonb_build_object('ok', true, 'achats', '{}'::jsonb, 'total', 0); END IF;

  FOR v_id IN SELECT k FROM jsonb_object_keys(v_etats) k ORDER BY 1 LOOP
    UPDATE public.batiments_etat
       SET data = to_jsonb((v_etats -> v_id)::text), updated_at = now() WHERE id = v_id;
  END LOOP;

  UPDATE public.caisses_batiments
     SET data = COALESCE(data, '{}'::jsonb) || jsonb_build_object('solde', v_solde), updated_at = now()
   WHERE id = v_caisse;

  SELECT data INTO v_data FROM public.budgets_nationaux WHERE id = p_pays FOR UPDATE;
  v_data := COALESCE(v_data, '{}'::jsonb);
  v_ref  := CASE WHEN jsonb_typeof(v_data -> 'refectoire') = 'object' THEN v_data -> 'refectoire' ELSE '{}'::jsonb END;
  v_brut := CASE WHEN jsonb_typeof(v_ref -> 'brut') = 'object' THEN v_ref -> 'brut' ELSE '{}'::jsonb END;
  FOR v_res IN SELECT k FROM jsonb_object_keys(v_achats) k LOOP
    v_brut := v_brut || jsonb_build_object(v_res,
      COALESCE((v_brut ->> v_res)::numeric, 0) + COALESCE((v_achats ->> v_res)::numeric, 0));
  END LOOP;
  v_ref  := v_ref || jsonb_build_object('brut', v_brut);
  v_data := v_data || jsonb_build_object('refectoire', v_ref);
  UPDATE public.budgets_nationaux SET data = v_data, updated_at = now() WHERE id = p_pays;

  RETURN jsonb_build_object('ok', true, 'achats', v_achats, 'total', v_total, 'solde', v_solde);
END;
$fn$;

-- =============================================================================
-- DROITS
-- =============================================================================
-- ATTENTION : Supabase applique des ALTER DEFAULT PRIVILEGES qui accordent EXECUTE a anon et
-- authenticated sur toute nouvelle fonction du schema public. Un « REVOKE ALL FROM PUBLIC » ne
-- les retire donc PAS -- il faut nommer les roles. Sans cela, les trois operations purement
-- nocturnes seraient appelables avec la cle anon depuis n'importe quel navigateur.
-- Les operations declenchees par un joueur restent accessibles a anon (le jeu n'a pas
-- d'autre identite) mais toute la validation est SERVEUR. Les deux operations purement
-- nocturnes (production, ravitaillement) ne sont executables QUE par le cron.
REVOKE ALL ON FUNCTION public.effort_reserve_appliquer(text, jsonb, text[], numeric) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.caserne_stock_mouvement(text, text, integer, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.militaire_retrait(text, text, integer, text, text, integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.refectoire_repas(text, text, integer, integer, integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.effort_produire_lot(text, text, text, jsonb, jsonb, numeric, text, text, text, integer) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.effort_ravitailler(text, jsonb, jsonb, jsonb) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.effort_reserve_appliquer(text, jsonb, text[], numeric) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.militaire_retrait(text, text, integer, text, text, integer)  TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.refectoire_repas(text, text, integer, integer, integer)      TO anon, authenticated, service_role;
-- caserne_stock_mouvement est la primitive brute (elle ne verifie ni poste ni presence) :
-- seuls le cron et les RPC ci-dessus (SECURITY DEFINER) l'appellent. La subtilisation passe
-- par militaire_subtiliser, plus bas.
GRANT EXECUTE ON FUNCTION public.caserne_stock_mouvement(text, text, integer, text) TO service_role;
GRANT EXECUTE ON FUNCTION public.effort_produire_lot(text, text, text, jsonb, jsonb, numeric, text, text, text, integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.effort_ravitailler(text, jsonb, jsonb, jsonb) TO service_role;

-- =============================================================================
-- 9. SUBTILISATION D'UN EXPLOSIF MILITAIRE
-- =============================================================================
-- Retire une unite du stock reel SANS aucune inscription au registre : c'est la
-- difference exacte avec militaire_retrait. Accessible a tout PJ physiquement present
-- a la caserne, quel que soit son statut. Le jet de reussite reste cote client (meme
-- doctrine que le vol de materiaux de chantier) ; cette RPC n'est appelee qu'apres
-- une reussite, et echoue proprement si le stock est vide entre-temps.
CREATE OR REPLACE FUNCTION public.militaire_subtiliser(
  p_pays   text,
  p_joueur text
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $fn$
DECLARE
  v_pj  personnages%ROWTYPE;
BEGIN
  SELECT * INTO v_pj FROM public.personnages WHERE name = p_joueur FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_absent'); END IF;
  IF COALESCE(v_pj.current_building, '') <> 'caserne-militaire' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place');
  END IF;
  RETURN public.caserne_stock_mouvement(p_pays, 'explosif_militaire', -1, NULL);
END;
$fn$;

REVOKE ALL ON FUNCTION public.militaire_subtiliser(text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.militaire_subtiliser(text, text) TO anon, authenticated, service_role;
