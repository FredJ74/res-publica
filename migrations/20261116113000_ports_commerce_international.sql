-- PORTS ET COMMERCE INTERNATIONAL (Fred, 16/11/2026, GAME-DESIGN-REGULATION-PRODUCTION.md).
-- Socle commun, quatre empires (Républia, Sovarka, El Estado, Al-Khalija) :
--  * chaque pays a un port industriel et sa caisse (caisses_batiments) ; caisse de départ 20 000 ;
--  * importations payées par le port au prix d'exportation du pays d'origine, cédées aux entrepôts au prix
--    de cession du port (défaut : prix intérieur) ; un produit, un prix intérieur ; la vente à perte reste
--    dans la caisse du port ;
--  * exportations : le port achète aux entrepôts au prix intérieur et vend au prix d'exportation qu'il fixe ;
--  * le Commandant du Port (capitaine_port) règle fléchage vers les entrepôts, prix de cession et
--    d'exportation, quotas d'importation et d'exportation, taux de douane (0 à 30 %) ;
--  * droits de douane ET amendes de fausse déclaration vont à la caisse du port ;
--  * le ministre de l'Économie (min_fin) dote le port : virement ponctuel ou dotation quotidienne ;
--  * balance commerciale publique, par jour (ports_balance_jours), reprise au journal du jour ;
--  * El Estado et Al-Khalija, non jouables : commandant PNJ au réglage par défaut ; leur État couvre le
--    déficit du port (pnj_couvre_deficit) tant que l'empire n'est pas ouvert.
-- Remplace : exportations du port de PSM, importations d'El Estado à Starovka, exportations de Sovarka,
-- importations gratuites de Républia (pétrole, produits exotiques, bois de Sovarka) et distribution du
-- stock portuaire de PSM, jusqu'ici dans api/cron-minuit.js.
BEGIN;

CREATE OR REPLACE FUNCTION pg_temp.hg_remplacer(p_sig text, p_avant text, p_apres text, p_nb integer DEFAULT 1) RETURNS void
LANGUAGE plpgsql AS $f$
DECLARE d text;
BEGIN
  d := pg_get_functiondef(p_sig::regprocedure);
  IF position(p_apres IN d) > 0 THEN RETURN; END IF;
  IF (length(d) - length(replace(d, p_avant, ''))) / length(p_avant) <> p_nb THEN
    RAISE EXCEPTION 'remplacement % : motif attendu % fois', p_sig, p_nb;
  END IF;
  EXECUTE replace(d, p_avant, p_apres);
END $f$;

-- ---------------------------------------------------------------------------------------------
-- 1. Tables
-- ---------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.ports_commerce (
  pays text PRIMARY KEY,
  nom text NOT NULL,
  caisse_id text NOT NULL,
  ville text, batiment text,
  entrepots text[] NOT NULL DEFAULT '{}',
  taux_douane numeric NOT NULL DEFAULT 10 CHECK (taux_douane BETWEEN 0 AND 30),
  repartition jsonb NOT NULL DEFAULT '{}'::jsonb,
  prix_cession jsonb NOT NULL DEFAULT '{}'::jsonb,
  prix_export jsonb NOT NULL DEFAULT '{}'::jsonb,
  quotas_import jsonb NOT NULL DEFAULT '{}'::jsonb,
  quotas_export jsonb NOT NULL DEFAULT '{}'::jsonb,
  dotation_jour numeric NOT NULL DEFAULT 0 CHECK (dotation_jour BETWEEN 0 AND 1000000),
  pnj_couvre_deficit boolean NOT NULL DEFAULT false,
  modifie_par text, updated_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE IF NOT EXISTS public.ports_stock (
  pays text NOT NULL, cle text NOT NULL, qte integer NOT NULL DEFAULT 0 CHECK (qte >= 0),
  PRIMARY KEY (pays, cle));
CREATE TABLE IF NOT EXISTS public.ports_productions (
  pays text NOT NULL, cle text NOT NULL, quantite integer NOT NULL CHECK (quantite >= 0), libelle text,
  PRIMARY KEY (pays, cle));
CREATE TABLE IF NOT EXISTS public.commerce_contrats (
  origine text NOT NULL, destination text NOT NULL, cle text NOT NULL,
  quantite integer NOT NULL CHECK (quantite >= 0), note text,
  PRIMARY KEY (origine, destination, cle), CHECK (origine <> destination));
CREATE TABLE IF NOT EXISTS public.ports_journal (
  id bigserial PRIMARY KEY, pays text NOT NULL, jour date NOT NULL, nature text NOT NULL,
  cle text, quantite integer, montant numeric NOT NULL DEFAULT 0, partenaire text,
  detail jsonb, cree_le timestamptz NOT NULL DEFAULT now());
CREATE INDEX IF NOT EXISTS ports_journal_pays_jour ON public.ports_journal (pays, jour DESC, id DESC);
CREATE TABLE IF NOT EXISTS public.ports_balance_jours (
  pays text NOT NULL, jour date NOT NULL,
  exportations numeric NOT NULL DEFAULT 0, importations numeric NOT NULL DEFAULT 0,
  detail jsonb, PRIMARY KEY (pays, jour));
CREATE TABLE IF NOT EXISTS public.commerce_passes (jour date PRIMARY KEY, resultat jsonb NOT NULL);

ALTER TABLE public.ports_commerce ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ports_stock ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ports_productions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.commerce_contrats ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ports_journal ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ports_balance_jours ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.commerce_passes ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.ports_commerce, public.ports_stock, public.ports_productions, public.commerce_contrats,
  public.ports_journal, public.ports_balance_jours, public.commerce_passes FROM anon, authenticated;
REVOKE ALL ON SEQUENCE public.ports_journal_id_seq FROM anon, authenticated;

-- ---------------------------------------------------------------------------------------------
-- 2. Ports, contrats (volumes d'avant ce lot, à relire par Fred), production intérieure, caisses
-- ---------------------------------------------------------------------------------------------
DO $seed$
DECLARE v_neuf boolean; v_solde numeric; v_etat jsonb; k text; v integer; r record;
BEGIN
  FOR r IN SELECT * FROM (VALUES
    ('republic', 'Port Industriel de Port-Sainte-Marie', 'republic_port-sainte-marie', 'ville_a', 'port-sainte-marie',
       ARRAY['republic_capitale_entrepot-logistique-luthecia','republic_ville_a_entrepot-logistique-psm','republic_ville_b_entrepot-logistique-montrouge'], false),
    ('soviet', 'Port Industriel de Starovka', 'soviet_port-starovka', 'ville_a', 'port-starovka',
       ARRAY['soviet_capitale_entrepot-logistique-novomirsk','soviet_ville_a_entrepot-logistique-starovka','soviet_ville_b_entrepot-logistique-krasnov'], false),
    ('narco', 'Port d''El Estado', 'narco_port-industriel', NULL, NULL, ARRAY[]::text[], true),
    ('khalija', 'Port d''Al-Khalija', 'khalija_port-industriel', NULL, NULL, ARRAY[]::text[], true)
  ) t(pays, nom, caisse, ville, batiment, entrepots, pnj) LOOP
    v_neuf := NULL;
    INSERT INTO public.ports_commerce (pays, nom, caisse_id, ville, batiment, entrepots, pnj_couvre_deficit)
    VALUES (r.pays, r.nom, r.caisse, r.ville, r.batiment, r.entrepots, r.pnj)
    ON CONFLICT (pays) DO NOTHING RETURNING true INTO v_neuf;
    IF coalesce(v_neuf, false) THEN
      -- Caisse de départ : 20 000 (décision de Fred, 16/11/2026).
      SELECT coalesce((data->>'solde')::numeric, 0) INTO v_solde FROM public.caisses_batiments WHERE id = r.caisse;
      IF NOT FOUND THEN
        INSERT INTO public.caisses_batiments (id, data, updated_at) VALUES (r.caisse, jsonb_build_object('solde', 20000), now());
      ELSIF v_solde < 20000 THEN
        UPDATE public.caisses_batiments SET data = data || jsonb_build_object('solde', 20000), updated_at = now() WHERE id = r.caisse;
      END IF;
      INSERT INTO public.ports_journal (pays, jour, nature, montant, detail)
      VALUES (r.pays, (now() AT TIME ZONE 'Europe/Paris')::date, 'dotation_initiale', 20000 - least(coalesce(v_solde, 0), 20000),
              jsonb_build_object('motif', 'caisse_de_depart_20000', 'solde_avant', coalesce(v_solde, 0)));
      -- Stock du port de PSM (ancien état du bâtiment) repris dans ports_stock.
      IF r.pays = 'republic' THEN
        SELECT public.batiment_etat_lire(data) INTO v_etat FROM public.batiments_etat WHERE id = 'republic_ville_a_port-sainte-marie';
        FOR k, v IN SELECT key, floor((value #>> '{}')::numeric)::integer FROM jsonb_each(coalesce(v_etat #> '{port,stock}', '{}'::jsonb))
                    WHERE jsonb_typeof(value) = 'number' LOOP
          IF v > 0 THEN
            INSERT INTO public.ports_stock (pays, cle, qte) VALUES ('republic', k, v)
            ON CONFLICT (pays, cle) DO UPDATE SET qte = public.ports_stock.qte + excluded.qte;
          END IF;
        END LOOP;
        IF jsonb_typeof(v_etat #> '{port,repartition}') = 'object' THEN
          UPDATE public.ports_commerce SET repartition = v_etat #> '{port,repartition}' WHERE pays = 'republic';
        END IF;
      END IF;
    END IF;
  END LOOP;

  INSERT INTO public.commerce_contrats (origine, destination, cle, quantite, note) VALUES
    ('republic', 'khalija', 'cereales', 225, 'Républia : 1,5 ville'),
    ('republic', 'khalija', 'viande', 125, 'Républia : 1 ville'),
    ('republic', 'soviet', 'medicaments', 25, 'Fred 15/11'),
    ('republic', 'soviet', 'alcool', 50, 'Républia : 0,5 ville'),
    ('republic', 'soviet', 'plantes', 38, 'moitié de Pharmanov'),
    ('narco', 'soviet', 'plantes', 37, 'autre moitié de Pharmanov'),
    ('narco', 'soviet', 'tabac', 50, 'proposé par Claude'),
    ('soviet', 'republic', 'minerai', 84, 'Sovarka : 0,5 ville, tous pays'),
    ('soviet', 'khalija', 'minerai', 83, 'Sovarka : 0,5 ville, tous pays'),
    ('soviet', 'narco', 'minerai', 83, 'Sovarka : 0,5 ville, tous pays'),
    ('soviet', 'republic', 'metal', 34, 'Sovarka : 0,5 ville, tous pays'),
    ('soviet', 'khalija', 'metal', 33, 'Sovarka : 0,5 ville, tous pays'),
    ('soviet', 'narco', 'metal', 33, 'Sovarka : 0,5 ville, tous pays'),
    ('soviet', 'republic', 'petrole', 200, 'Sovarka : 1 ville'),
    ('soviet', 'republic', 'bois', 150, 'ancien flux « Bois — Sovarka »'),
    ('soviet', 'khalija', 'viande', 63, 'Sovarka : 0,5 ville'),
    ('soviet', 'khalija', 'cereales', 75, 'Sovarka : 0,5 ville'),
    ('khalija', 'republic', 'petrole', 133, 'ancienne part d''Al-Khalija (2/3 d''une ville)'),
    ('narco', 'republic', 'produits_exotiques', 125, 'El Estado : 1 ville')
  ON CONFLICT DO NOTHING;
  INSERT INTO public.ports_productions (pays, cle, quantite, libelle)
  VALUES ('republic', 'bois', 150, 'Scierie Guy Tarembois (Port-Sainte-Marie)')
  ON CONFLICT DO NOTHING;

  -- Commandants PNJ (intérim) : Sovarka (Tömör Ochirov), El Estado, Al-Khalija.
  INSERT INTO public.titulaires_pnj (id, country, poste_id, city, nom_pnj, updated_at) VALUES
    ('soviet_capitaine_port_national', 'soviet', 'capitaine_port', NULL, 'Commandant Tömör Ochirov (PNJ)', now()),
    ('narco_capitaine_port_national', 'narco', 'capitaine_port', NULL, 'El Capitan Turbio (PNJ)', now()),
    ('khalija_capitaine_port_national', 'khalija', 'capitaine_port', NULL, 'Cheikh Ibn Fret (PNJ)', now())
  ON CONFLICT (id) DO NOTHING;
END $seed$;

-- ---------------------------------------------------------------------------------------------
-- 3. Primitives
-- ---------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.port_taux_douane(p_pays text)
RETURNS numeric LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT coalesce((SELECT taux_douane FROM public.ports_commerce WHERE pays = p_pays), 10);
$$;

CREATE OR REPLACE FUNCTION public.port_prix_base_interne(p_pays text, p_cle text)
RETURNS numeric LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT prix_base FROM public.ressources_economie_pays(p_pays) WHERE cle = p_cle;
$$;

-- Prix d'exportation par défaut : le cours international (prix de base de la table des ressources, celui
-- de Républia ; Sovarka vendait déjà ses exportations à ce prix, double de son prix intérieur).
-- Prix de cession par défaut : le prix intérieur du pays.
CREATE OR REPLACE FUNCTION public.port_prix_reference_interne(p_pays text, p_cle text, p_sorte text)
RETURNS numeric LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT CASE WHEN p_sorte = 'export' THEN (SELECT prix_base FROM public.ressources_economie WHERE cle = p_cle)
              ELSE public.port_prix_base_interne(p_pays, p_cle) END;
$$;

CREATE OR REPLACE FUNCTION public.port_prix_interne(p_pays text, p_cle text, p_sorte text)
RETURNS numeric LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT coalesce(
    (SELECT (CASE p_sorte WHEN 'export' THEN p.prix_export ELSE p.prix_cession END ->> p_cle)::numeric
       FROM public.ports_commerce p WHERE p.pays = p_pays),
    public.port_prix_reference_interne(p_pays, p_cle, p_sorte));
$$;

CREATE OR REPLACE FUNCTION public.port_caisse_solde_interne(p_caisse text)
RETURNS numeric LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT coalesce((SELECT (data->>'solde')::numeric FROM public.caisses_batiments WHERE id = p_caisse), 0);
$$;

CREATE OR REPLACE FUNCTION public.port_caisse_mouvement_interne(p_caisse text, p_delta numeric)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v jsonb;
BEGIN
  IF coalesce(p_delta, 0) = 0 THEN RETURN true; END IF;
  PERFORM set_config('rp.caisse_interne', 'on', true);
  v := public.caisse_institution_mouvement(p_caisse, round(p_delta, 2), false);
  PERFORM set_config('rp.caisse_interne', '', true);
  RETURN coalesce((v->>'ok')::boolean, false);
END $$;

-- Place d'un entrepôt pour une ressource : plafond de la ressource en Républia (comme l'ancienne
-- distribution du port de PSM), capacité totale de 5 000 unités en Sovarka (sovarka_production_passe).
CREATE OR REPLACE FUNCTION public.port_entrepot_place_interne(p_pays text, p_entrepot text, p_cle text)
RETURNS integer LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_obj jsonb; v_total integer;
BEGIN
  SELECT CASE WHEN jsonb_typeof(data) = 'string' THEN (data #>> '{}')::jsonb ELSE data END INTO v_obj
    FROM public.batiments_etat WHERE id = p_entrepot;
  IF NOT FOUND THEN RETURN 0; END IF;
  IF p_pays = 'soviet' THEN
    SELECT coalesce(sum(floor((value #>> '{}')::numeric)), 0)::integer INTO v_total
      FROM jsonb_each(coalesce(v_obj #> '{entrepot,stock}', '{}'::jsonb)) WHERE jsonb_typeof(value) = 'number';
    RETURN greatest(0, 5000 - v_total);
  END IF;
  RETURN greatest(0, coalesce((SELECT plafond FROM public.ressources_economie WHERE cle = p_cle), 0)
                     - coalesce((v_obj #>> ARRAY['entrepot','stock',p_cle])::numeric, 0)::integer);
END $$;

-- Répartition entière d'un total selon des poids (plus forts restes).
CREATE OR REPLACE FUNCTION public.repartir_plus_forts_restes(p_total integer, p_poids numeric[])
RETURNS integer[] LANGUAGE plpgsql IMMUTABLE AS $$
DECLARE v_somme numeric := 0; v_res integer[] := ARRAY[]::integer[]; v_rest numeric[] := ARRAY[]::numeric[];
  v_part numeric; v_reste integer; i integer; j integer;
BEGIN
  FOR i IN 1..cardinality(p_poids) LOOP v_somme := v_somme + greatest(coalesce(p_poids[i], 0), 0); END LOOP;
  IF coalesce(p_total, 0) <= 0 OR v_somme <= 0 THEN
    FOR i IN 1..cardinality(p_poids) LOOP v_res := v_res || 0; END LOOP; RETURN v_res;
  END IF;
  v_reste := p_total;
  FOR i IN 1..cardinality(p_poids) LOOP
    v_part := p_total * greatest(coalesce(p_poids[i], 0), 0) / v_somme;
    v_res := v_res || floor(v_part)::integer; v_rest := v_rest || (v_part - floor(v_part));
    v_reste := v_reste - floor(v_part)::integer;
  END LOOP;
  WHILE v_reste > 0 LOOP
    j := 1;
    FOR i IN 2..cardinality(p_poids) LOOP IF v_rest[i] > v_rest[j] THEN j := i; END IF; END LOOP;
    v_res[j] := v_res[j] + 1; v_rest[j] := -1; v_reste := v_reste - 1;
  END LOOP;
  RETURN v_res;
END $$;

CREATE OR REPLACE FUNCTION public.port_journal_interne(p_pays text, p_jour date, p_nature text, p_cle text,
  p_quantite integer, p_montant numeric, p_partenaire text, p_detail jsonb)
RETURNS void LANGUAGE sql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  INSERT INTO public.ports_journal (pays, jour, nature, cle, quantite, montant, partenaire, detail)
  VALUES (p_pays, p_jour, p_nature, p_cle, p_quantite, round(coalesce(p_montant, 0), 2), p_partenaire, p_detail);
$$;

REVOKE ALL ON FUNCTION public.port_prix_base_interne(text, text), public.port_prix_interne(text, text, text),
  public.port_prix_reference_interne(text, text, text),
  public.port_caisse_solde_interne(text), public.port_caisse_mouvement_interne(text, numeric),
  public.port_entrepot_place_interne(text, text, text), public.port_journal_interne(text, date, text, text, integer, numeric, text, jsonb)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.port_taux_douane(text) TO authenticated;

-- ---------------------------------------------------------------------------------------------
-- 4. Passe de nuit : dotations, production intérieure, contrats, cession aux entrepôts, balance
-- ---------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.commerce_international_passe(p_jour date, p_interdites jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $function$
DECLARE
  v_deja jsonb; p record; o record; d record; c record; s record;
  v_src text; v_m numeric; v_q integer; v_quota integer; v_px numeric; v_dom numeric; v_pc numeric;
  v_total integer; v_stocks integer[]; v_preleve integer[]; v_i integer; v_k integer; v_achat numeric;
  v_used jsonb := '{}'::jsonb; v_contrats jsonb := '[]'::jsonb; v_cessions jsonb := '[]'::jsonb;
  v_dotations jsonb := '[]'::jsonb; v_poids numeric[]; v_parts integer[]; v_place integer; v_afford integer;
  v_cede integer; v_rep jsonb; v_raison text; v_res jsonb; v_solde numeric;
BEGIN
  IF NOT public.est_appel_serveur() THEN RETURN jsonb_build_object('ok', false, 'raison', 'reserve_serveur'); END IF;
  IF p_jour IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'jour_absent'); END IF;
  IF p_interdites IS NULL OR jsonb_typeof(p_interdites) <> 'object' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'legalite_non_verifiable'); END IF;
  SELECT resultat INTO v_deja FROM public.commerce_passes WHERE jour = p_jour;
  IF FOUND THEN RETURN v_deja || jsonb_build_object('rejeu', true); END IF;
  PERFORM pg_advisory_xact_lock(hashtext('commerce_international_passe'));
  SELECT resultat INTO v_deja FROM public.commerce_passes WHERE jour = p_jour;
  IF FOUND THEN RETURN v_deja || jsonb_build_object('rejeu', true); END IF;

  -- 4.1 Dotations quotidiennes du ministre de l'Économie (caisse du ministère, plafonnées à son solde).
  FOR p IN SELECT * FROM public.ports_commerce WHERE dotation_jour > 0 ORDER BY pays LOOP
    v_src := p.pays || '_gouvernement-min_fin';
    v_m := least(p.dotation_jour, greatest(public.port_caisse_solde_interne(v_src), 0));
    IF v_m > 0 AND public.port_caisse_mouvement_interne(v_src, -v_m) THEN
      PERFORM public.port_caisse_mouvement_interne(p.caisse_id, v_m);
      PERFORM public.port_journal_interne(p.pays, p_jour, 'dotation', NULL, NULL, v_m, 'min_fin',
        jsonb_build_object('recurrente', true, 'demandee', p.dotation_jour));
    END IF;
    v_dotations := v_dotations || jsonb_build_object('pays', p.pays, 'demandee', p.dotation_jour, 'versee', coalesce(v_m, 0));
  END LOOP;

  -- 4.2 Production intérieure qui arrive par le port (Scierie Guy Tarembois).
  FOR s IN SELECT * FROM public.ports_productions WHERE quantite > 0 LOOP
    IF coalesce(p_interdites -> s.pays ? s.cle, false) THEN CONTINUE; END IF;
    INSERT INTO public.ports_stock (pays, cle, qte) VALUES (s.pays, s.cle, s.quantite)
    ON CONFLICT (pays, cle) DO UPDATE SET qte = public.ports_stock.qte + excluded.qte;
    PERFORM public.port_journal_interne(s.pays, p_jour, 'production', s.cle, s.quantite, 0, NULL,
      jsonb_build_object('libelle', s.libelle));
  END LOOP;

  -- 4.3 Contrats entre pays.
  FOR c IN SELECT * FROM public.commerce_contrats WHERE quantite > 0 ORDER BY origine, destination, cle LOOP
    SELECT * INTO o FROM public.ports_commerce WHERE pays = c.origine;
    IF NOT FOUND THEN CONTINUE; END IF;
    SELECT * INTO d FROM public.ports_commerce WHERE pays = c.destination;
    IF NOT FOUND THEN CONTINUE; END IF;
    v_raison := NULL; v_q := c.quantite;
    IF coalesce(p_interdites -> c.origine ? c.cle, false) OR coalesce(p_interdites -> c.destination ? c.cle, false) THEN
      v_raison := 'interdit_par_la_loi'; v_q := 0;
    END IF;
    v_quota := (o.quotas_export ->> c.cle)::integer;
    IF v_q > 0 AND v_quota IS NOT NULL THEN
      v_q := least(v_q, greatest(0, v_quota - coalesce((v_used ->> ('x:' || c.origine || ':' || c.cle))::integer, 0)));
      IF v_q = 0 THEN v_raison := 'quota_exportation'; END IF;
    END IF;
    v_quota := (d.quotas_import ->> c.cle)::integer;
    IF v_q > 0 AND v_quota IS NOT NULL THEN
      v_q := least(v_q, greatest(0, v_quota - coalesce((v_used ->> ('i:' || c.destination || ':' || c.cle))::integer, 0)));
      IF v_q = 0 THEN v_raison := 'quota_importation'; END IF;
    END IF;
    v_stocks := ARRAY[]::integer[]; v_total := 0;
    IF cardinality(o.entrepots) > 0 THEN
      FOR v_i IN 1..cardinality(o.entrepots) LOOP
        v_stocks := v_stocks || coalesce(public.exportation_stock_interne(o.entrepots[v_i], c.cle, 0), 0);
        v_total := v_total + v_stocks[v_i];
      END LOOP;
      IF v_q > 0 THEN v_q := least(v_q, v_total); IF v_q = 0 THEN v_raison := 'stock_insuffisant'; END IF; END IF;
    END IF;
    v_px := public.port_prix_interne(c.origine, c.cle, 'export');
    v_dom := coalesce(public.port_prix_base_interne(c.origine, c.cle), 0);
    IF coalesce(v_px, 0) <= 0 THEN v_q := 0; v_raison := coalesce(v_raison, 'prix_absent'); END IF;
    IF v_q > 0 THEN
      v_solde := public.port_caisse_solde_interne(d.caisse_id);
      IF d.pnj_couvre_deficit THEN
        IF v_solde < v_q * v_px THEN
          PERFORM public.port_caisse_mouvement_interne(d.caisse_id, v_q * v_px - v_solde);
          PERFORM public.port_journal_interne(d.pays, p_jour, 'dotation_etat_pnj', NULL, NULL, v_q * v_px - v_solde, NULL,
            jsonb_build_object('motif', 'empire_non_ouvert'));
        END IF;
      ELSE
        v_q := least(v_q, floor(greatest(v_solde, 0) / v_px)::integer);
        IF v_q = 0 THEN v_raison := 'caisse_port_insuffisante'; END IF;
      END IF;
    END IF;
    IF v_q > 0 AND cardinality(o.entrepots) > 0 AND v_dom > v_px THEN
      -- Vente à perte à l'étranger : le port d'origine doit pouvoir payer ses entrepôts.
      v_q := least(v_q, floor(greatest(public.port_caisse_solde_interne(o.caisse_id), 0) / (v_dom - v_px))::integer);
      IF v_q = 0 THEN v_raison := 'caisse_port_origine_insuffisante'; END IF;
    END IF;
    IF v_q > 0 THEN
      IF NOT public.port_caisse_mouvement_interne(d.caisse_id, -(v_q * v_px)) THEN
        RAISE EXCEPTION 'commerce: debit port % impossible', d.pays; END IF;
      PERFORM public.port_caisse_mouvement_interne(o.caisse_id, v_q * v_px);
      PERFORM public.port_journal_interne(d.pays, p_jour, 'importation', c.cle, v_q, -(v_q * v_px), c.origine,
        jsonb_build_object('prix', v_px));
      PERFORM public.port_journal_interne(o.pays, p_jour, 'exportation', c.cle, v_q, v_q * v_px, c.destination,
        jsonb_build_object('prix', v_px));
      IF cardinality(o.entrepots) > 0 THEN
        v_preleve := public.repartir_plus_forts_restes(v_q, v_stocks::numeric[]);
        v_achat := 0;
        FOR v_i IN 1..cardinality(o.entrepots) LOOP
          v_k := least(v_preleve[v_i], v_stocks[v_i]);
          IF v_k > 0 THEN
            PERFORM public.exportation_stock_interne(o.entrepots[v_i], c.cle, -v_k);
            IF NOT public.exportation_caisse_interne(o.entrepots[v_i], v_k * v_dom) THEN
              RAISE EXCEPTION 'commerce: caisse entrepot % absente', o.entrepots[v_i]; END IF;
            v_achat := v_achat + v_k * v_dom;
          END IF;
        END LOOP;
        IF v_achat > 0 THEN
          IF NOT public.port_caisse_mouvement_interne(o.caisse_id, -v_achat) THEN
            RAISE EXCEPTION 'commerce: le port % ne peut payer ses entrepots', o.pays; END IF;
          PERFORM public.port_journal_interne(o.pays, p_jour, 'achat_entrepots', c.cle, v_q, -v_achat, NULL,
            jsonb_build_object('prix', v_dom, 'preleve', to_jsonb(v_preleve)));
        END IF;
      END IF;
      IF cardinality(d.entrepots) > 0 THEN
        INSERT INTO public.ports_stock (pays, cle, qte) VALUES (d.pays, c.cle, v_q)
        ON CONFLICT (pays, cle) DO UPDATE SET qte = public.ports_stock.qte + excluded.qte;
      END IF;
      v_used := v_used
        || jsonb_build_object('x:' || c.origine || ':' || c.cle, coalesce((v_used ->> ('x:' || c.origine || ':' || c.cle))::integer, 0) + v_q)
        || jsonb_build_object('i:' || c.destination || ':' || c.cle, coalesce((v_used ->> ('i:' || c.destination || ':' || c.cle))::integer, 0) + v_q);
    END IF;
    v_contrats := v_contrats || jsonb_build_object('origine', c.origine, 'destination', c.destination, 'cle', c.cle,
      'contrat', c.quantite, 'livre', greatest(v_q, 0), 'prix', v_px, 'raison', v_raison);
  END LOOP;

  -- 4.4 Cession du stock des ports aux entrepôts (fléchage du commandant, défaut 1/3 chacun), au prix
  -- de cession ; ce qu'un entrepôt ne peut ni stocker ni payer reste au port pour la nuit suivante.
  FOR p IN SELECT * FROM public.ports_commerce WHERE cardinality(entrepots) = 3 ORDER BY pays LOOP
    FOR s IN SELECT cle, qte FROM public.ports_stock WHERE pays = p.pays AND qte > 0 ORDER BY cle LOOP
      IF coalesce(p_interdites -> p.pays ? s.cle, false) THEN CONTINUE; END IF;
      v_pc := public.port_prix_interne(p.pays, s.cle, 'cession');
      v_rep := p.repartition -> s.cle;
      v_poids := ARRAY[coalesce((v_rep->>'capitale')::numeric, 1), coalesce((v_rep->>'ville_a')::numeric, 1),
                       coalesce((v_rep->>'ville_b')::numeric, 1)];
      v_parts := public.repartir_plus_forts_restes(s.qte, v_poids);
      v_cede := 0; v_achat := 0;
      FOR v_i IN 1..3 LOOP
        v_k := v_parts[v_i];
        IF v_k <= 0 THEN CONTINUE; END IF;
        v_place := public.port_entrepot_place_interne(p.pays, p.entrepots[v_i], s.cle);
        v_afford := CASE WHEN coalesce(v_pc, 0) > 0
                         THEN floor(greatest(public.exportation_solde_interne(p.entrepots[v_i]), 0) / v_pc)::integer
                         ELSE v_k END;
        v_k := least(v_k, v_place, v_afford);
        IF v_k > 0 AND (coalesce(v_pc, 0) = 0 OR public.exportation_caisse_interne(p.entrepots[v_i], -(v_k * v_pc))) THEN
          PERFORM public.exportation_stock_interne(p.entrepots[v_i], s.cle, v_k);
          v_cede := v_cede + v_k; v_achat := v_achat + v_k * coalesce(v_pc, 0);
        END IF;
      END LOOP;
      IF v_cede > 0 THEN
        UPDATE public.ports_stock SET qte = qte - v_cede WHERE pays = p.pays AND cle = s.cle;
        PERFORM public.port_caisse_mouvement_interne(p.caisse_id, v_achat);
        PERFORM public.port_journal_interne(p.pays, p_jour, 'cession', s.cle, v_cede, v_achat, NULL,
          jsonb_build_object('prix', v_pc));
      END IF;
      v_cessions := v_cessions || jsonb_build_object('pays', p.pays, 'cle', s.cle, 'stock', s.qte, 'cede', v_cede, 'prix', v_pc);
    END LOOP;
  END LOOP;

  -- 4.5 Balance commerciale du jour (exportations - importations, en valeur).
  INSERT INTO public.ports_balance_jours (pays, jour, exportations, importations, detail)
  SELECT p2.pays, p_jour,
         coalesce(sum(j.montant) FILTER (WHERE j.nature = 'exportation'), 0),
         coalesce(-sum(j.montant) FILTER (WHERE j.nature = 'importation'), 0),
         jsonb_build_object('caisse', public.port_caisse_solde_interne(p2.caisse_id),
                            'douane', coalesce(sum(j.montant) FILTER (WHERE j.nature IN ('douane', 'amende')), 0))
    FROM public.ports_commerce p2
    LEFT JOIN public.ports_journal j ON j.pays = p2.pays AND j.jour = p_jour
   GROUP BY p2.pays, p2.caisse_id
  ON CONFLICT (pays, jour) DO UPDATE SET exportations = excluded.exportations, importations = excluded.importations,
    detail = excluded.detail;

  v_res := jsonb_build_object('ok', true, 'jour', p_jour, 'dotations', v_dotations, 'contrats', v_contrats, 'cessions', v_cessions);
  INSERT INTO public.commerce_passes (jour, resultat) VALUES (p_jour, v_res);
  RETURN v_res;
END $function$;
REVOKE ALL ON FUNCTION public.commerce_international_passe(date, jsonb) FROM PUBLIC, anon, authenticated;

-- ---------------------------------------------------------------------------------------------
-- 5. Lecture publique (balance commerciale publique, décision de Fred)
-- ---------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.port_lire(p_pays text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $function$
DECLARE v_moi text; v_pays text; p record; v_cles text[]; v_ressources jsonb; v_titulaire text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  v_pays := coalesce(p_pays, (SELECT country FROM public.personnages_donnees WHERE name = v_moi), 'republic');
  SELECT * INTO p FROM public.ports_commerce WHERE pays = v_pays;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'port_inconnu'); END IF;
  SELECT array_agg(DISTINCT x) INTO v_cles FROM (
    SELECT cle AS x FROM public.commerce_contrats WHERE origine = v_pays OR destination = v_pays
    UNION SELECT cle FROM public.ports_stock WHERE pays = v_pays AND qte > 0
    UNION SELECT cle FROM public.ports_productions WHERE pays = v_pays
    UNION SELECT jsonb_object_keys(p.prix_export || p.prix_cession || p.quotas_import || p.quotas_export || p.repartition)) t
   WHERE x IN (SELECT cle FROM public.ressources_economie);
  SELECT coalesce(jsonb_agg(jsonb_build_object(
      'cle', k,
      'stock', coalesce((SELECT qte FROM public.ports_stock WHERE pays = v_pays AND cle = k), 0),
      'prix_interieur', public.port_prix_base_interne(v_pays, k),
      'prix_cession', public.port_prix_interne(v_pays, k, 'cession'),
      'prix_export', public.port_prix_interne(v_pays, k, 'export'),
      'cours_international', public.port_prix_reference_interne(v_pays, k, 'export'),
      'cession_fixe', p.prix_cession ? k, 'export_fixe', p.prix_export ? k,
      'quota_import', p.quotas_import -> k, 'quota_export', p.quotas_export -> k,
      'repartition', p.repartition -> k) ORDER BY k), '[]'::jsonb)
    INTO v_ressources FROM unnest(coalesce(v_cles, ARRAY[]::text[])) k;
  SELECT titulaire INTO v_titulaire FROM public.postes_attribues
   WHERE poste_id = 'capitaine_port' AND country = v_pays ORDER BY updated_at DESC NULLS LAST LIMIT 1;
  RETURN jsonb_build_object('ok', true, 'pays', v_pays, 'nom', p.nom, 'a_un_batiment', p.batiment IS NOT NULL,
    'caisse', public.port_caisse_solde_interne(p.caisse_id), 'taux_douane', p.taux_douane,
    'dotation_jour', p.dotation_jour, 'pnj_couvre_deficit', p.pnj_couvre_deficit,
    'commandant', coalesce(v_titulaire, (SELECT nom_pnj FROM public.titulaires_pnj WHERE country = v_pays AND poste_id = 'capitaine_port' LIMIT 1)),
    'commandant_pj', v_titulaire IS NOT NULL,
    'est_commandant', public.mon_poste_est_dans('capitaine_port', v_pays),
    'est_ministre', public.mon_poste_est_dans('min_fin', v_pays),
    'modifie_par', p.modifie_par, 'modifie_le', p.updated_at,
    'ressources', v_ressources,
    'contrats', (SELECT coalesce(jsonb_agg(jsonb_build_object('origine', origine, 'destination', destination,
                   'cle', cle, 'quantite', quantite) ORDER BY origine, destination, cle), '[]'::jsonb)
                   FROM public.commerce_contrats WHERE origine = v_pays OR destination = v_pays),
    'derniere_passe', (SELECT jsonb_build_object('jour', cp.jour, 'contrats',
                         (SELECT coalesce(jsonb_agg(x), '[]'::jsonb) FROM jsonb_array_elements(cp.resultat->'contrats') x
                           WHERE x->>'origine' = v_pays OR x->>'destination' = v_pays))
                         FROM public.commerce_passes cp ORDER BY cp.jour DESC LIMIT 1),
    'balance', (SELECT coalesce(jsonb_agg(jsonb_build_object('jour', b.jour, 'exportations', b.exportations,
                  'importations', b.importations, 'solde', b.exportations - b.importations) ORDER BY b.jour DESC), '[]'::jsonb)
                  FROM (SELECT * FROM public.ports_balance_jours WHERE pays = v_pays ORDER BY jour DESC LIMIT 7) b),
    'journal', (SELECT coalesce(jsonb_agg(jsonb_build_object('jour', j.jour, 'nature', j.nature, 'cle', j.cle,
                  'quantite', j.quantite, 'montant', j.montant, 'partenaire', j.partenaire) ORDER BY j.id DESC), '[]'::jsonb)
                  FROM (SELECT * FROM public.ports_journal WHERE pays = v_pays ORDER BY id DESC LIMIT 40) j));
END $function$;
REVOKE ALL ON FUNCTION public.port_lire(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.port_lire(text) TO authenticated;

-- ---------------------------------------------------------------------------------------------
-- 6. Le Commandant du Port règle son port (dans son bureau)
-- ---------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.port_commandant_regler(p_action text, p_params jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $function$
DECLARE v_moi text; m record; p record; v_cle text; v_base numeric; v_val numeric; v_a numeric; v_b numeric; v_c numeric;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country, current_city, current_building INTO m FROM public.personnages_donnees WHERE name = v_moi;
  IF NOT public.mon_poste_est_dans('capitaine_port', m.country) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reserve_commandant_port'); END IF;
  SELECT * INTO p FROM public.ports_commerce WHERE pays = m.country FOR UPDATE;
  IF NOT FOUND OR p.batiment IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'port_inconnu'); END IF;
  IF m.current_city IS DISTINCT FROM p.ville OR m.current_building IS DISTINCT FROM p.batiment THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;
  v_cle := p_params ->> 'cle';
  IF p_action <> 'taux_douane' THEN
    IF v_cle IS NULL OR NOT EXISTS (SELECT 1 FROM public.ressources_economie WHERE cle = v_cle) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'ressource_inconnue'); END IF;
    v_base := public.port_prix_base_interne(m.country, v_cle);
  END IF;
  IF p_action = 'taux_douane' THEN
    v_val := (p_params ->> 'taux')::numeric;
    IF v_val IS NULL OR v_val < 0 OR v_val > 30 THEN RETURN jsonb_build_object('ok', false, 'raison', 'taux_hors_bornes'); END IF;
    UPDATE public.ports_commerce SET taux_douane = round(v_val, 1) WHERE pays = p.pays;
  ELSIF p_action = 'repartition' THEN
    v_a := (p_params ->> 'capitale')::numeric; v_b := (p_params ->> 'ville_a')::numeric; v_c := (p_params ->> 'ville_b')::numeric;
    IF v_a IS NULL OR v_b IS NULL OR v_c IS NULL OR least(v_a, v_b, v_c) < 0 OR abs(v_a + v_b + v_c - 100) > 0.1 THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'repartition_invalide'); END IF;
    UPDATE public.ports_commerce SET repartition = repartition
      || jsonb_build_object(v_cle, jsonb_build_object('capitale', v_a, 'ville_a', v_b, 'ville_b', v_c)) WHERE pays = p.pays;
  ELSIF p_action IN ('prix_export', 'prix_cession') THEN
    v_base := public.port_prix_reference_interne(m.country, v_cle, CASE WHEN p_action = 'prix_export' THEN 'export' ELSE 'cession' END);
    v_val := (p_params ->> 'prix')::numeric;
    IF v_val IS NOT NULL AND (v_val < round(v_base * 0.1, 2) OR v_val > round(v_base * 5, 2)) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'prix_hors_bornes', 'min', round(v_base * 0.1, 2), 'max', round(v_base * 5, 2)); END IF;
    IF p_action = 'prix_export' THEN
      UPDATE public.ports_commerce SET prix_export = CASE WHEN v_val IS NULL THEN prix_export - v_cle
        ELSE prix_export || jsonb_build_object(v_cle, round(v_val, 2)) END WHERE pays = p.pays;
    ELSE
      UPDATE public.ports_commerce SET prix_cession = CASE WHEN v_val IS NULL THEN prix_cession - v_cle
        ELSE prix_cession || jsonb_build_object(v_cle, round(v_val, 2)) END WHERE pays = p.pays;
    END IF;
  ELSIF p_action IN ('quota_import', 'quota_export') THEN
    v_val := (p_params ->> 'quota')::numeric;
    IF v_val IS NOT NULL AND (v_val < 0 OR v_val > 100000 OR v_val <> trunc(v_val)) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'quota_invalide'); END IF;
    IF p_action = 'quota_import' THEN
      UPDATE public.ports_commerce SET quotas_import = CASE WHEN v_val IS NULL THEN quotas_import - v_cle
        ELSE quotas_import || jsonb_build_object(v_cle, v_val::integer) END WHERE pays = p.pays;
    ELSE
      UPDATE public.ports_commerce SET quotas_export = CASE WHEN v_val IS NULL THEN quotas_export - v_cle
        ELSE quotas_export || jsonb_build_object(v_cle, v_val::integer) END WHERE pays = p.pays;
    END IF;
  ELSE
    RETURN jsonb_build_object('ok', false, 'raison', 'action_inconnue');
  END IF;
  UPDATE public.ports_commerce SET modifie_par = v_moi, updated_at = now() WHERE pays = p.pays;
  PERFORM public.port_journal_interne(p.pays, (now() AT TIME ZONE 'Europe/Paris')::date, 'reglage', v_cle, NULL, 0, v_moi,
    jsonb_build_object('action', p_action, 'params', p_params));
  RETURN jsonb_build_object('ok', true) || public.port_lire(p.pays);
END $function$;
REVOKE ALL ON FUNCTION public.port_commandant_regler(text, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.port_commandant_regler(text, jsonb) TO authenticated;

-- L'ancienne porte de répartition du port de PSM passe par la nouvelle (même contrôle, tout pays).
CREATE OR REPLACE FUNCTION public.fixer_repartition_port(p_cle text, p_capitale numeric, p_ville_a numeric, p_ville_b numeric)
RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT public.port_commandant_regler('repartition',
    jsonb_build_object('cle', p_cle, 'capitale', p_capitale, 'ville_a', p_ville_a, 'ville_b', p_ville_b));
$$;

-- Retour d'un Commandant PNJ (poste vacant) : le PNJ applique le réglage par défaut (doctrine du
-- 25/08/2026, étendue à tous les réglages du port). La dotation du ministre n'est pas touchée.
CREATE OR REPLACE FUNCTION public.port_reglages_par_defaut(p_pays text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
BEGIN
  IF NOT public.est_appel_serveur() THEN RETURN jsonb_build_object('ok', false, 'raison', 'reserve_serveur'); END IF;
  UPDATE public.ports_commerce SET repartition = '{}', prix_cession = '{}', prix_export = '{}', quotas_import = '{}',
    quotas_export = '{}', taux_douane = 10, modifie_par = 'PNJ', updated_at = now() WHERE pays = p_pays;
  RETURN jsonb_build_object('ok', FOUND);
END $$;
REVOKE ALL ON FUNCTION public.port_reglages_par_defaut(text) FROM PUBLIC, anon, authenticated;

-- ---------------------------------------------------------------------------------------------
-- 7. Le ministre de l'Économie dote le port : virement ponctuel (1 PA) ou dotation quotidienne
-- ---------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.port_dotation_ministre(p_action text, p_montant numeric)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $function$
DECLARE v_moi text; v_pays text; p record; v_paie jsonb; v_jour date := (now() AT TIME ZONE 'Europe/Paris')::date;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT coalesce(country, 'republic') INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;
  IF NOT public.mon_poste_est_dans('min_fin', v_pays) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reserve_ministre_finances'); END IF;
  SELECT * INTO p FROM public.ports_commerce WHERE pays = v_pays FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'port_inconnu'); END IF;
  IF p_montant IS NULL OR p_montant < 0 OR p_montant <> trunc(p_montant) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'montant_invalide'); END IF;
  IF p_action = 'recurrente' THEN
    IF p_montant > 1000000 THEN RETURN jsonb_build_object('ok', false, 'raison', 'montant_invalide'); END IF;
    UPDATE public.ports_commerce SET dotation_jour = p_montant, updated_at = now() WHERE pays = v_pays;
    PERFORM public.port_journal_interne(v_pays, v_jour, 'reglage', NULL, NULL, 0, v_moi,
      jsonb_build_object('action', 'dotation_quotidienne', 'montant', p_montant));
    RETURN jsonb_build_object('ok', true, 'dotation_jour', p_montant);
  ELSIF p_action = 'ponctuelle' THEN
    IF p_montant <= 0 OR p_montant > 100000000 THEN RETURN jsonb_build_object('ok', false, 'raison', 'montant_invalide'); END IF;
    IF public.port_caisse_solde_interne(v_pays || '_gouvernement-min_fin') < p_montant THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'caisse_insuffisante'); END IF;
    v_paie := public.payer_ordre(v_moi, 'gestion_industrielle_portuaire', 1, 0);
    IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
    IF NOT public.port_caisse_mouvement_interne(v_pays || '_gouvernement-min_fin', -p_montant) THEN
      RAISE EXCEPTION 'port_dotation: caisse du ministere insuffisante'; END IF;
    PERFORM public.port_caisse_mouvement_interne(p.caisse_id, p_montant);
    PERFORM public.port_journal_interne(v_pays, v_jour, 'dotation', NULL, NULL, p_montant, v_moi,
      jsonb_build_object('recurrente', false));
    RETURN jsonb_build_object('ok', true, 'montant', p_montant, 'paie', v_paie,
      'caisse_port', public.port_caisse_solde_interne(p.caisse_id));
  END IF;
  RETURN jsonb_build_object('ok', false, 'raison', 'action_inconnue');
END $function$;
REVOKE ALL ON FUNCTION public.port_dotation_ministre(text, numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.port_dotation_ministre(text, numeric) TO authenticated;

-- ---------------------------------------------------------------------------------------------
-- 8. Douane : taux du Commandant du Port ; droits ET amendes à la caisse du port
-- ---------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.port_amende_crediter_interne(p_pays text, p_batiment text, p_montant numeric)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_caisse text; v jsonb;
BEGIN
  IF coalesce(p_montant, 0) <= 0 THEN RETURN jsonb_build_object('ok', true, 'montant', 0); END IF;
  v_caisse := coalesce((SELECT caisse_id FROM public.ports_commerce WHERE pays = p_pays),
                       p_pays || '_' || coalesce(p_batiment, 'port-sainte-marie'));
  PERFORM set_config('rp.caisse_interne', 'on', true);
  v := public.caisse_institution_mouvement(v_caisse, p_montant, false);
  PERFORM set_config('rp.caisse_interne', '', true);
  IF coalesce((v->>'ok')::boolean, false) THEN
    PERFORM public.port_journal_interne(p_pays, (now() AT TIME ZONE 'Europe/Paris')::date, 'amende', NULL, NULL, p_montant, NULL, NULL);
  END IF;
  RETURN v || jsonb_build_object('montant', p_montant);
END $$;
REVOKE ALL ON FUNCTION public.port_amende_crediter_interne(text, text, numeric) FROM PUBLIC, anon, authenticated;

SELECT pg_temp.hg_remplacer('public.fret_dedouaner(uuid)',
  'v_douane := round(v_val * 10 / 100.0);',
  'v_douane := round(v_val * public.port_taux_douane(c.pays_destination) / 100.0); /* ports_commerce_v1 */');
SELECT pg_temp.hg_remplacer('public.fret_dedouaner(uuid)',
  '      v_mvt := public.caisse_institution_mouvement(v_caisse, v_douane + v_gard, false);',
  '      v_mvt := public.caisse_institution_mouvement(v_caisse, v_douane + v_gard, false);
      IF v_douane > 0 AND coalesce((v_mvt->>''ok'')::boolean, false) THEN
        PERFORM public.port_journal_interne(c.pays_destination, (now() AT TIME ZONE ''Europe/Paris'')::date, ''douane'', NULL, NULL, v_douane, v_moi, NULL);
      END IF;');
SELECT pg_temp.hg_remplacer('public.fret_dedouaner(uuid)',
  'v_mvt := public.fret_tresor_crediter_interne(c.pays_destination, v_amende);',
  'v_mvt := public.port_amende_crediter_interne(c.pays_destination, c.building_destination, v_amende);');
SELECT pg_temp.hg_remplacer('public.fret_caisse_commande_interne(text,text,uuid,jsonb)',
  'v := public.fret_tresor_crediter_interne(coalesce(c.pays_destination, c.pays_origine, ''republic''), c.amende_due);',
  'v := public.port_amende_crediter_interne(coalesce(c.pays_destination, c.pays_origine, ''republic''), c.building_destination, c.amende_due);');
SELECT pg_temp.hg_remplacer('public.fret_objet_agir(uuid,uuid,text,uuid,integer,integer,bigint)',
  'v:=public.fret_tresor_crediter_interne(c.pays_destination,prix);',
  'v:=public.port_amende_crediter_interne(c.pays_destination,c.building_destination,prix);');
SELECT pg_temp.hg_remplacer('public.fret_inspecter_interne(uuid,text)',
  'v_amende := floor(2 * 0.10 * v_valeur)::integer;',
  'v_amende := floor(2 * public.port_taux_douane(v_pays) / 100.0 * v_valeur)::integer; /* ports_commerce_v1 */');
SELECT pg_temp.hg_remplacer('public.fret_inspecter_interne(uuid,text)',
  ' FR au Trésor (double des droits de douane sur leur valeur), payable au port. À défaut, le destinataire devra la régler pour retirer la caisse ; si personne ne paie, la caisse sera saisie et vendue au profit du Trésor.',
  ' (double des droits de douane sur leur valeur), versée à la caisse du port et payable au port. À défaut, le destinataire devra la régler pour retirer la caisse ; si personne ne paie, la caisse sera saisie et vendue au profit du port.');

-- ---------------------------------------------------------------------------------------------
-- 9. Pêche à Port-Sainte-Marie : depuis le Port de Plaisance seulement (Fred, 16/11/2026)
-- ---------------------------------------------------------------------------------------------
SELECT pg_temp.hg_remplacer('public.recolte_effectuer(text,integer,integer)',
  '  v_refus := public.regulation_production_refus_interne(v_moi, m.country, m.current_city, p_matiere);',
  '  IF m.country = ''republic'' AND m.current_city = ''ville_a'' AND p_matiere = ''Poisson''
     AND (SELECT current_building FROM public.personnages_donnees WHERE name = v_moi) IS DISTINCT FROM ''port-plaisance-psm'' THEN
    RETURN jsonb_build_object(''ok'', false, ''raison'', ''peche_au_port_de_plaisance''); END IF;
  v_refus := public.regulation_production_refus_interne(v_moi, m.country, m.current_city, p_matiere);');

-- ---------------------------------------------------------------------------------------------
-- 10. Contrôles structurels
-- ---------------------------------------------------------------------------------------------
DO $c$
BEGIN
  IF (SELECT count(*) FROM public.ports_commerce) <> 4 THEN RAISE EXCEPTION 'ports: 4 pays attendus'; END IF;
  IF public.port_caisse_solde_interne('soviet_port-starovka') < 20000 THEN RAISE EXCEPTION 'caisse de depart'; END IF;
  IF public.repartir_plus_forts_restes(10, ARRAY[1,1,1]::numeric[]) <> ARRAY[4,3,3] THEN RAISE EXCEPTION 'restes'; END IF;
  IF position('port_taux_douane' IN pg_get_functiondef('public.fret_dedouaner(uuid)'::regprocedure)) = 0
     OR position('fret_tresor_crediter_interne' IN pg_get_functiondef('public.fret_dedouaner(uuid)'::regprocedure)) > 0 THEN
    RAISE EXCEPTION 'douane non raccordee'; END IF;
  IF position('peche_au_port_de_plaisance' IN pg_get_functiondef('public.recolte_effectuer(text,integer,integer)'::regprocedure)) = 0 THEN
    RAISE EXCEPTION 'peche'; END IF;
  IF has_function_privilege('authenticated', 'public.commerce_international_passe(date, jsonb)', 'EXECUTE') THEN
    RAISE EXCEPTION 'passe ouverte aux clients'; END IF;
END $c$;

COMMIT;
