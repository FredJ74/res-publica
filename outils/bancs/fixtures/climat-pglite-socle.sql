-- Socle minimal pour éprouver les migrations climat dans PGlite (banc local, jamais la production).
-- Tables climat et fonctions dans leur état de production du 21/11/2026 (après 20261121120000), réduites à ce que la
-- migration 20261121130000 utilise. Les fonctions extérieures au climat sont des bouchons explicites.
SET check_function_bodies = off;
CREATE ROLE anon; CREATE ROLE authenticated;
CREATE SCHEMA IF NOT EXISTS auth;
CREATE OR REPLACE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$ SELECT nullif(current_setting('test.uid', true), '')::uuid $$;

CREATE TABLE public.personnages (name text PRIMARY KEY, user_id uuid);
CREATE TABLE public.personnages_donnees (name text PRIMARY KEY, country text, current_city text, current_building text, current_room text,
  current_street text, inventory jsonb DEFAULT '[]', inventory_revision integer DEFAULT 1, liquide numeric DEFAULT 0, pa integer DEFAULT 10,
  poste jsonb, created_at timestamp DEFAULT localtimestamp, updated_at timestamptz);
CREATE OR REPLACE FUNCTION public.mon_personnage() RETURNS text LANGUAGE sql STABLE AS $$ SELECT name FROM public.personnages WHERE user_id = auth.uid() LIMIT 1 $$;
CREATE TABLE public.aliments_parametres (cle text PRIMARY KEY, valeur numeric);
INSERT INTO public.aliments_parametres VALUES ('crue_perte_pct', 20), ('sac_protection_pct', 10), ('sacs_plafond', 1), ('catastrophe_part_pct', 50),
  ('catastrophe_delai_h', 72), ('prix_sac_sable', 60);
CREATE OR REPLACE FUNCTION public.aliments_param_interne(p_cle text, p_defaut numeric) RETURNS numeric LANGUAGE sql STABLE AS $$
  SELECT coalesce((SELECT valeur FROM public.aliments_parametres WHERE cle = p_cle), p_defaut) $$;
CREATE TABLE public.entreprises (id text PRIMARY KEY, data jsonb, updated_at timestamptz);
CREATE TABLE public.batiments_etat (id text PRIMARY KEY, data text, updated_at timestamptz);
CREATE OR REPLACE FUNCTION public.batiment_etat_lire(p text) RETURNS jsonb LANGUAGE sql IMMUTABLE AS $$ SELECT p::jsonb $$;
CREATE TABLE public.evenements_globaux (id bigserial PRIMARY KEY, country text, city text, texte text, jour date);
CREATE TABLE public.journal_articles_en_attente (id text PRIMARY KEY, country text, rubrique text, titre text, texte text, statut text,
  origine text, priorite text, dedup_key text, created_at timestamptz);
CREATE TABLE public.caisses_batiments (id text PRIMARY KEY, data jsonb);
CREATE TABLE public.mails_test (destinataire text, sujet text, corps text);
CREATE TABLE public.ressources_economie_test (cle text PRIMARY KEY, prix_base numeric);
INSERT INTO public.ressources_economie_test VALUES ('bois', 10), ('metal', 15);
CREATE OR REPLACE FUNCTION public.ressources_economie_pays(p_pays text) RETURNS SETOF public.ressources_economie_test LANGUAGE sql STABLE AS $$
  SELECT * FROM public.ressources_economie_test $$;
CREATE TABLE public.recettes_commerce (id text PRIMARY KEY, prix_fixe numeric);

-- Bouchons des fonctions extérieures au climat.
CREATE OR REPLACE FUNCTION public.mail_systeme_poser_interne(a text, b text, c text, d text, e text) RETURNS jsonb LANGUAGE sql AS $$
  INSERT INTO public.mails_test VALUES (b, c, d) RETURNING '{}'::jsonb $$;
CREATE OR REPLACE FUNCTION public.caisse_institution_mouvement(p_id text, p_montant numeric, p_x boolean) RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE v numeric;
BEGIN
  SELECT coalesce((data->>'solde')::numeric, 0) INTO v FROM public.caisses_batiments WHERE id = p_id;
  IF coalesce(v, 0) + p_montant < 0 THEN RETURN '{"ok": false}'; END IF;
  INSERT INTO public.caisses_batiments VALUES (p_id, jsonb_build_object('solde', coalesce(v, 0) + p_montant))
  ON CONFLICT (id) DO UPDATE SET data = EXCLUDED.data;
  RETURN '{"ok": true}';
END $$;
CREATE OR REPLACE FUNCTION public.entrepot_caisse_id(p text) RETURNS text LANGUAGE sql IMMUTABLE AS $$ SELECT 'entrepot:' || p $$;
CREATE OR REPLACE FUNCTION public.achat_requete_ouvrir_interne(a text, r uuid, f text, p jsonb) RETURNS jsonb LANGUAGE sql AS $$ SELECT NULL::jsonb $$;
CREATE OR REPLACE FUNCTION public.achat_requete_clore_interne(a text, r uuid, f text, p jsonb, v jsonb) RETURNS jsonb LANGUAGE sql AS $$ SELECT v $$;
CREATE OR REPLACE FUNCTION public.payer_ordre(a text, f text, pa integer, c numeric) RETURNS jsonb LANGUAGE sql AS $$
  UPDATE public.personnages_donnees SET pa = pa - $3 WHERE name = $1 RETURNING jsonb_build_object('ok', true, 'pa', pa) $$;
CREATE OR REPLACE FUNCTION public.inventaire_quantite(p_inv jsonb, p_cle text) RETURNS numeric LANGUAGE sql IMMUTABLE AS $$
  SELECT coalesce(sum(coalesce((x->>'qty')::numeric, 1)), 0) FROM jsonb_array_elements(coalesce(p_inv, '[]')) x WHERE x->>'stackKey' = p_cle $$;
CREATE OR REPLACE FUNCTION public.inventaire_retirer(p_inv jsonb, p_cle text, p_n numeric) RETURNS jsonb LANGUAGE sql IMMUTABLE AS $$
  SELECT coalesce(jsonb_agg(CASE WHEN x->>'stackKey' = p_cle THEN jsonb_set(x, '{qty}', to_jsonb((x->>'qty')::numeric - p_n)) ELSE x END), '[]')
    FROM jsonb_array_elements(p_inv) x $$;

-- ── Tables climat (production) ─────────────────────────────────────────────────────────────────
CREATE TABLE public.climat_parametres (type text NOT NULL, pays text NOT NULL, actif boolean NOT NULL DEFAULT true, frequence text NOT NULL,
  par_periode integer NOT NULL DEFAULT 1, delai_min integer NOT NULL DEFAULT 0, delai_max integer NOT NULL DEFAULT 0, duree_heures integer NOT NULL DEFAULT 24,
  preavis_heures integer NOT NULL DEFAULT 48, bloque_chantiers boolean NOT NULL DEFAULT false, PRIMARY KEY (type, pays));
INSERT INTO public.climat_parametres VALUES
  ('blizzard', 'soviet', true, 'mandat', 1, 0, 0, 24, 48, true), ('crue', 'republic', true, 'trimestre_propage', 1, 1, 3, 6, 48, true),
  ('canicule', 'republic', true, 'trimestre_propage', 1, 2, 4, 6, 48, true), ('orage', 'republic', true, 'trimestre_propage', 1, 1, 2, 6, 48, true),
  ('orage', 'soviet', true, 'trimestre_propage', 1, 1, 2, 6, 48, true), ('brouillard', 'republic', true, 'mois', 2, 0, 0, 6, 48, false),
  ('brouillard', 'soviet', true, 'mois', 2, 0, 0, 6, 48, false);
CREATE TABLE public.climat_zones_inondables (pays text, ville text, batiment text, nom text, PRIMARY KEY (pays, ville, batiment));
INSERT INTO public.climat_zones_inondables VALUES ('republic', 'ville_b', 'entrepot-logistique-montrouge', 'l''entrepôt logistique'),
  ('republic', 'ville_b', 'zone-production', 'la zone de production'), ('republic', 'ville_a', 'marche-psm', 'le marché');
CREATE TABLE public.climat_evenements (id bigserial PRIMARY KEY, type text NOT NULL, pays text NOT NULL, ville text NOT NULL, debut timestamptz NOT NULL,
  fin timestamptz NOT NULL, periode text NOT NULL, lieux jsonb NOT NULL DEFAULT '[]', alerte_le timestamptz, origine text NOT NULL DEFAULT 'calendrier',
  annule boolean NOT NULL DEFAULT false, cree_le timestamptz NOT NULL DEFAULT now(), effets_le timestamptz, fin_traitee_le timestamptz, CHECK (fin > debut));
CREATE TABLE public.climat_protections (id bigserial PRIMARY KEY, pays text NOT NULL, ville text NOT NULL, batiment text NOT NULL, pose_par text NOT NULL,
  pose_le timestamptz NOT NULL DEFAULT now(), evenement bigint, sacs integer NOT NULL DEFAULT 1);
CREATE TABLE public.climat_crue_pertes (evenement bigint NOT NULL, cible text NOT NULL, pays text NOT NULL, ville text NOT NULL, batiment text NOT NULL,
  proprietaire text, protege boolean NOT NULL, valeur numeric NOT NULL DEFAULT 0, detail jsonb NOT NULL DEFAULT '{}', indemnite numeric NOT NULL DEFAULT 0,
  PRIMARY KEY (evenement, cible));
CREATE TABLE public.climat_catastrophes (evenement bigint PRIMARY KEY, pays text NOT NULL, propose_par text, propose_le timestamptz, declare_par text,
  declare_le timestamptz, option text CHECK (option IN ('sacs', 'tous')), cout numeric);

-- ── Fonctions climat (état de production) ──────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.climat_villes_interne(p_pays text) RETURNS text[] LANGUAGE sql IMMUTABLE AS $$ SELECT ARRAY['capitale', 'ville_a', 'ville_b']; $$;
CREATE OR REPLACE FUNCTION public.climat_nom_ville_interne(p_pays text, p_ville text) RETURNS text LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE p_pays WHEN 'republic' THEN CASE p_ville WHEN 'capitale' THEN 'Luthécia' WHEN 'ville_a' THEN 'Port-Sainte-Marie' WHEN 'ville_b' THEN 'Montrouge' END
                     ELSE CASE p_ville WHEN 'capitale' THEN 'Novomirsk' WHEN 'ville_a' THEN 'Starovka' WHEN 'ville_b' THEN 'Krasnov' END END; $$;
CREATE OR REPLACE FUNCTION public.climat_minuit_interne(p_jour date) RETURNS timestamptz LANGUAGE sql IMMUTABLE AS $$ SELECT (p_jour::timestamp) AT TIME ZONE 'Europe/Paris'; $$;
CREATE OR REPLACE FUNCTION public.climat_nom_type_interne(p_type text) RETURNS text LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE p_type WHEN 'crue' THEN 'Crue' WHEN 'orage' THEN 'Orage' WHEN 'canicule' THEN 'Canicule'
                     WHEN 'brouillard' THEN 'Brouillard' WHEN 'blizzard' THEN 'Blizzard' ELSE 'Événement climatique' END; $$;
CREATE OR REPLACE FUNCTION public.climat_lieu_est_gare_interne(p_batiment text) RETURNS boolean LANGUAGE sql IMMUTABLE AS $$
  SELECT coalesce(p_batiment ~ '(multimodal|multinodal)' OR p_batiment ~ '^hall_gare' OR (p_batiment ~ '(^|-)gare(-|$)' AND p_batiment !~ '^cafe-'), false); $$;
-- Consigne réduite à une étiquette (son texte complet est éprouvé par test-climat-definitif-20261121.cjs).
CREATE OR REPLACE FUNCTION public.climat_consigne_interne(p_type text, p_pays text, p_ville text) RETURNS text LANGUAGE sql STABLE AS $$ SELECT 'Consigne ' || p_type || '.' $$;
CREATE OR REPLACE FUNCTION public.climat_stock_amputer_interne(p_stock jsonb, p_pct numeric, p_pays text)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE k text; q numeric; p numeric; v_stock jsonb := coalesce(p_stock, '{}'::jsonb); v_perdu jsonb := '{}'::jsonb; v_valeur numeric := 0; v_prix numeric;
BEGIN
  IF jsonb_typeof(v_stock) <> 'object' THEN RETURN jsonb_build_object('stock', p_stock, 'perdu', '{}'::jsonb, 'valeur', 0); END IF;
  FOR k, q IN SELECT key, CASE WHEN value ~ '^-?[0-9.]+$' THEN value::numeric ELSE 0 END FROM jsonb_each_text(v_stock) LOOP
    p := floor(greatest(q, 0) * p_pct / 100);
    IF p > 0 THEN
      v_stock := jsonb_set(v_stock, ARRAY[k], to_jsonb(q - p));
      v_perdu := v_perdu || jsonb_build_object(k, p);
      SELECT prix_base INTO v_prix FROM public.ressources_economie_pays(p_pays) WHERE cle = k;
      IF v_prix IS NULL THEN SELECT prix_fixe INTO v_prix FROM public.recettes_commerce WHERE id = k; END IF;
      v_valeur := v_valeur + p * coalesce(v_prix, 0);
    END IF;
  END LOOP;
  RETURN jsonb_build_object('stock', v_stock, 'perdu', v_perdu, 'valeur', round(v_valeur, 2));
END $$;
-- Règle du 19/11 encore présente en production (retirée par la migration éprouvée).
CREATE OR REPLACE FUNCTION public.climat_sacs_reste_pct_interne(p_sacs numeric) RETURNS numeric LANGUAGE sql STABLE AS $$ SELECT 100 - least(p_sacs, 9) * 10 $$;
CREATE OR REPLACE FUNCTION public.climat_sacs_poses_interne(p_pays text, p_ville text, p_batiment text) RETURNS integer LANGUAGE sql STABLE AS $$ SELECT 0 $$;
-- Planificateur (production, inchangé par la migration).
CREATE OR REPLACE FUNCTION public.climat_planifier_interne()
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $function$
DECLARE c public.climat_parametres; v_auj date := (now() AT TIME ZONE 'Europe/Paris')::date; v_min date; v_deb date; v_fin date;
        k integer; v_periode text; v_villes text[]; v_ville text; v_jour date; v_n integer := 0; v_marge integer; v_jours date[];
BEGIN
  FOR c IN SELECT * FROM public.climat_parametres WHERE actif AND frequence IN ('trimestre_propage', 'mois') AND par_periode > 0 LOOP
    v_min := v_auj + ceil(c.preavis_heures / 24.0)::integer + 1;
    FOR k IN 0 .. 1 LOOP
      IF c.frequence = 'trimestre_propage' THEN
        v_deb := (date_trunc('quarter', v_auj::timestamp) + make_interval(months => 3 * k))::date;
        v_fin := (v_deb + interval '3 months')::date - 1;
        v_periode := to_char(v_deb, 'YYYY') || '-T' || extract(quarter FROM v_deb)::text;
        IF EXISTS (SELECT 1 FROM public.climat_evenements WHERE type = c.type AND pays = c.pays AND periode = v_periode AND origine = 'calendrier') THEN CONTINUE; END IF;
        v_marge := 2 * c.delai_max;
        v_deb := greatest(v_deb, v_min);
        IF v_fin - v_marge < v_deb THEN CONTINUE; END IF;
        SELECT array_agg(x ORDER BY random()) INTO v_villes FROM unnest(public.climat_villes_interne(c.pays)) x;
        v_jour := v_deb + floor(random() * (v_fin - v_marge - v_deb + 1))::integer;
        FOREACH v_ville IN ARRAY v_villes LOOP
          IF public.climat_creer_interne(c.type, c.pays, v_ville, v_jour, v_periode, 'calendrier') IS NOT NULL THEN v_n := v_n + 1; END IF;
          v_jour := v_jour + c.delai_min + floor(random() * (c.delai_max - c.delai_min + 1))::integer;
        END LOOP;
      ELSE
        v_deb := (date_trunc('month', v_auj::timestamp) + make_interval(months => k))::date;
        v_fin := (v_deb + interval '1 month')::date - 1;
        v_periode := to_char(v_deb, 'YYYY-MM');
        FOREACH v_ville IN ARRAY public.climat_villes_interne(c.pays) LOOP
          IF EXISTS (SELECT 1 FROM public.climat_evenements WHERE type = c.type AND pays = c.pays AND ville = v_ville AND periode = v_periode AND origine = 'calendrier') THEN CONTINUE; END IF;
          IF v_fin < greatest(v_deb, v_min) THEN CONTINUE; END IF;
          SELECT array_agg(d ORDER BY d) INTO v_jours FROM (
            SELECT d::date FROM generate_series(greatest(v_deb, v_min), v_fin, interval '1 day') d ORDER BY random() LIMIT c.par_periode) s;
          FOREACH v_jour IN ARRAY coalesce(v_jours, '{}') LOOP
            IF public.climat_creer_interne(c.type, c.pays, v_ville, v_jour, v_periode, 'calendrier') IS NOT NULL THEN v_n := v_n + 1; END IF;
          END LOOP;
        END LOOP;
      END IF;
    END LOOP;
  END LOOP;
  RETURN v_n;
END $function$;
