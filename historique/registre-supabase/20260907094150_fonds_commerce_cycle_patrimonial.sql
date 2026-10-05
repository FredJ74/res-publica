-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260907094150
-- Nom original      : fonds_commerce_cycle_patrimonial
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-07 09:41:50 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : bf8d6ff59b199fde00d4fb95e2947430
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
CREATE TABLE IF NOT EXISTS locations_archives (
  id text PRIMARY KEY,
  bail_id text,
  country text,
  city text,
  building_id text,
  room_id text,
  lot_id text,
  locataire text,
  proprietaire_murs text,
  loyer integer NOT NULL DEFAULT 0,
  debut integer,
  fin_cause text NOT NULL,
  fonds_id text,
  indemnite integer NOT NULL DEFAULT 0,
  data jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS locations_archives_bail_idx ON locations_archives (bail_id);
CREATE INDEX IF NOT EXISTS locations_archives_lieu_idx ON locations_archives (country, city, building_id);
CREATE INDEX IF NOT EXISTS locations_archives_titulaire_idx ON locations_archives (locataire);
CREATE INDEX IF NOT EXISTS locations_archives_fonds_idx ON locations_archives (fonds_id);
ALTER TABLE locations_archives ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS locations_archives_select ON locations_archives;
CREATE POLICY locations_archives_select ON locations_archives FOR SELECT USING (true);
DROP POLICY IF EXISTS locations_archives_insert ON locations_archives;
CREATE POLICY locations_archives_insert ON locations_archives FOR INSERT WITH CHECK (true);
GRANT SELECT, INSERT ON locations_archives TO anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION mouvement_titulaire(p_ref text, p_delta numeric)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_type text;
  v_id text;
  v_solde numeric;
  v_data text;
  v_json jsonb;
BEGIN
  IF COALESCE(p_ref, '') = '' THEN RETURN false; END IF;
  IF left(p_ref, 5) = 'orga:' THEN
    v_type := 'orga'; v_id := substr(p_ref, 6);
  ELSIF left(p_ref, 3) = 'pj:' THEN
    v_type := 'pj'; v_id := substr(p_ref, 4);
  ELSIF left(p_ref, 6) = 'ville:' THEN
    RETURN false;
  ELSE
    v_type := 'pj'; v_id := p_ref;
  END IF;
  IF COALESCE(v_id, '') = '' THEN RETURN false; END IF;
  IF v_type = 'pj' THEN
    SELECT arg INTO v_solde FROM personnages WHERE name = v_id FOR UPDATE;
    IF NOT FOUND THEN RETURN false; END IF;
    IF COALESCE(v_solde, 0) + p_delta < 0 THEN RETURN false; END IF;
    UPDATE personnages SET arg = COALESCE(arg, 0) + p_delta WHERE name = v_id;
    RETURN true;
  END IF;
  SELECT data INTO v_data FROM organisations WHERE id = v_id FOR UPDATE;
  IF NOT FOUND THEN RETURN false; END IF;
  BEGIN
    v_json := v_data::jsonb;
  EXCEPTION WHEN others THEN RETURN false;
  END;
  IF v_json IS NULL OR jsonb_typeof(v_json) <> 'object' THEN RETURN false; END IF;
  v_solde := GREATEST(0, COALESCE((v_json ->> 'caisse')::numeric, 0));
  IF v_solde + p_delta < 0 THEN RETURN false; END IF;
  UPDATE organisations SET data = jsonb_set(v_json, '{caisse}', to_jsonb(v_solde + p_delta))::text WHERE id = v_id;
  RETURN true;
END;
$$;

CREATE OR REPLACE FUNCTION creer_fonds_commerce(
  p_proprietaire text,
  p_bail_id text,
  p_fonds_id text,
  p_apport integer,
  p_enseigne text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_bail jsonb;
  v_apport integer := GREATEST(0, COALESCE(p_apport, 0));
  v_lot text;
  v_deja integer;
BEGIN
  IF COALESCE(p_proprietaire, '') = '' OR COALESCE(p_bail_id, '') = '' OR COALESCE(p_fonds_id, '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;
  IF v_apport > 0 THEN
    IF NOT mouvement_titulaire(p_proprietaire, -v_apport) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants');
    END IF;
  ELSE
    IF NOT mouvement_titulaire(p_proprietaire, 0) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'proprietaire_absent');
    END IF;
  END IF;
  SELECT count(*) INTO v_deja FROM entreprises WHERE id = p_fonds_id;
  IF v_deja > 0 THEN RAISE EXCEPTION 'fonds_id_deja_pris'; END IF;
  SELECT data INTO v_bail FROM locations_actives WHERE id = p_bail_id FOR UPDATE;
  IF v_bail IS NULL THEN RAISE EXCEPTION 'bail_absent'; END IF;
  IF (v_bail ->> 'locataire') IS DISTINCT FROM p_proprietaire
     AND ('pj:' || COALESCE(v_bail ->> 'locataire', '')) IS DISTINCT FROM p_proprietaire THEN
    RAISE EXCEPTION 'pas_titulaire';
  END IF;
  SELECT count(*) INTO v_deja FROM entreprises
   WHERE data -> 'implantation' ->> 'bailId' = p_bail_id
     AND COALESCE(data ->> 'statut', 'actif') = 'actif';
  IF v_deja > 0 THEN RAISE EXCEPTION 'fonds_deja_present'; END IF;
  v_lot := v_bail ->> 'lotId';
  INSERT INTO entreprises (id, data, updated_at)
  VALUES (p_fonds_id, jsonb_build_object(
    'id', p_fonds_id,
    'version', 2,
    'type', 'fonds_commerce',
    'enseigne', COALESCE(NULLIF(btrim(COALESCE(p_enseigne, '')), ''), 'Fonds de commerce'),
    'proprietaire', p_proprietaire,
    'statut', 'actif',
    'caisse', v_apport,
    'implantation', jsonb_build_object(
      'country', v_bail ->> 'country', 'city', v_bail ->> 'city',
      'buildingId', v_bail ->> 'buildingId', 'roomId', v_bail ->> 'roomId',
      'lotId', v_lot, 'localKey', v_bail ->> 'localKey', 'bailId', p_bail_id),
    'stockMatieres', '{}'::jsonb,
    'stockProduits', '{}'::jsonb,
    'historique', jsonb_build_array(jsonb_build_object(
      'evenement', 'creation', 'proprietaire', p_proprietaire, 'apport', v_apport,
      'horodatage', to_char(now() AT TIME ZONE 'Europe/Paris', 'YYYY-MM-DD"T"HH24:MI:SS')))
  ), now());
  UPDATE locations_actives SET data = v_bail || jsonb_build_object('fondsId', p_fonds_id) WHERE id = p_bail_id;
  RETURN jsonb_build_object('ok', true, 'fondsId', p_fonds_id, 'caisse', v_apport, 'apport', v_apport, 'proprietaire', p_proprietaire);
END;
$$;

CREATE OR REPLACE FUNCTION alimenter_caisse_fonds(p_acteur text, p_fonds_id text, p_montant integer)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_data jsonb;
  v_m integer := COALESCE(p_montant, 0);
BEGIN
  IF COALESCE(p_acteur, '') = '' OR COALESCE(p_fonds_id, '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;
  IF v_m <= 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'montant_invalide'); END IF;
  IF NOT mouvement_titulaire(p_acteur, -v_m) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants');
  END IF;
  SELECT data INTO v_data FROM entreprises WHERE id = p_fonds_id FOR UPDATE;
  IF v_data IS NULL THEN RAISE EXCEPTION 'fonds_absent'; END IF;
  IF COALESCE((v_data ->> 'version')::integer, 0) < 2 THEN RAISE EXCEPTION 'pas_un_fonds'; END IF;
  IF COALESCE(v_data ->> 'statut', 'actif') <> 'actif' THEN RAISE EXCEPTION 'fonds_inactif'; END IF;
  IF (v_data ->> 'proprietaire') IS DISTINCT FROM p_acteur THEN RAISE EXCEPTION 'pas_proprietaire'; END IF;
  UPDATE entreprises
    SET data = jsonb_set(v_data, '{caisse}', to_jsonb(GREATEST(0, COALESCE((v_data ->> 'caisse')::numeric, 0)) + v_m)), updated_at = now()
    WHERE id = p_fonds_id;
  RETURN jsonb_build_object('ok', true, 'montant', v_m, 'caisse', GREATEST(0, COALESCE((v_data ->> 'caisse')::numeric, 0)) + v_m);
END;
$$;

CREATE OR REPLACE FUNCTION retirer_caisse_fonds(p_acteur text, p_fonds_id text, p_montant integer)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_data jsonb;
  v_caisse integer;
  v_m integer := COALESCE(p_montant, 0);
BEGIN
  IF COALESCE(p_acteur, '') = '' OR COALESCE(p_fonds_id, '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;
  IF v_m <= 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'montant_invalide'); END IF;
  SELECT data INTO v_data FROM entreprises WHERE id = p_fonds_id FOR UPDATE;
  IF v_data IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'fonds_absent'); END IF;
  IF COALESCE((v_data ->> 'version')::integer, 0) < 2 THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_un_fonds'); END IF;
  IF COALESCE(v_data ->> 'statut', 'actif') <> 'actif' THEN RETURN jsonb_build_object('ok', false, 'raison', 'fonds_inactif'); END IF;
  IF (v_data ->> 'proprietaire') IS DISTINCT FROM p_acteur THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_proprietaire'); END IF;
  v_caisse := GREATEST(0, COALESCE((v_data ->> 'caisse')::numeric, 0))::integer;
  IF v_m > v_caisse THEN RETURN jsonb_build_object('ok', false, 'raison', 'caisse_insuffisante', 'caisse', v_caisse); END IF;
  UPDATE entreprises SET data = jsonb_set(v_data, '{caisse}', to_jsonb(v_caisse - v_m)), updated_at = now() WHERE id = p_fonds_id;
  IF NOT mouvement_titulaire(p_acteur, v_m) THEN RAISE EXCEPTION 'titulaire_introuvable'; END IF;
  RETURN jsonb_build_object('ok', true, 'montant', v_m, 'caisse', v_caisse - v_m);
END;
$$;

CREATE OR REPLACE FUNCTION vendre_fonds_commerce(p_vendeur text, p_acheteur text, p_fonds_id text, p_prix integer)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_data jsonb;
  v_bail_id text;
  v_bail jsonb;
  v_prix integer := GREATEST(0, COALESCE(p_prix, 0));
  v_caisse integer;
  v_premier text;
  v_second text;
BEGIN
  IF COALESCE(p_vendeur, '') = '' OR COALESCE(p_acheteur, '') = '' OR COALESCE(p_fonds_id, '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;
  IF p_vendeur = p_acheteur THEN RETURN jsonb_build_object('ok', false, 'raison', 'acheteur_identique'); END IF;
  IF left(p_acheteur, 6) = 'ville:' THEN RETURN jsonb_build_object('ok', false, 'raison', 'acheteur_invalide'); END IF;
  IF p_vendeur < p_acheteur THEN v_premier := p_vendeur; v_second := p_acheteur; ELSE v_premier := p_acheteur; v_second := p_vendeur; END IF;
  IF NOT mouvement_titulaire(v_premier, 0) THEN RETURN jsonb_build_object('ok', false, 'raison', 'titulaire_absent'); END IF;
  IF NOT mouvement_titulaire(v_second, 0) THEN RETURN jsonb_build_object('ok', false, 'raison', 'titulaire_absent'); END IF;
  SELECT data INTO v_data FROM entreprises WHERE id = p_fonds_id FOR UPDATE;
  IF v_data IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'fonds_absent'); END IF;
  IF COALESCE((v_data ->> 'version')::integer, 0) < 2 THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_un_fonds'); END IF;
  IF COALESCE(v_data ->> 'statut', 'actif') <> 'actif' THEN RETURN jsonb_build_object('ok', false, 'raison', 'fonds_inactif'); END IF;
  IF (v_data ->> 'proprietaire') IS DISTINCT FROM p_vendeur THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_proprietaire'); END IF;
  IF v_prix > 0 THEN
    IF NOT mouvement_titulaire(p_acheteur, -v_prix) THEN RETURN jsonb_build_object('ok', false, 'raison', 'acheteur_insolvable'); END IF;
    IF NOT mouvement_titulaire(p_vendeur, v_prix) THEN RAISE EXCEPTION 'vendeur_introuvable'; END IF;
  END IF;
  v_caisse := GREATEST(0, COALESCE((v_data ->> 'caisse')::numeric, 0))::integer;
  IF v_caisse > 0 THEN IF NOT mouvement_titulaire(p_vendeur, v_caisse) THEN RAISE EXCEPTION 'extraction_impossible'; END IF; END IF;
  v_data := jsonb_set(v_data, '{proprietaire}', to_jsonb(p_acheteur));
  v_data := jsonb_set(v_data, '{caisse}', to_jsonb(0));
  v_data := jsonb_set(v_data, '{historique}', COALESCE(v_data -> 'historique', '[]'::jsonb) || jsonb_build_array(jsonb_build_object(
      'evenement', 'vente', 'vendeur', p_vendeur, 'acheteur', p_acheteur, 'prix', v_prix, 'caisseExtraite', v_caisse,
      'horodatage', to_char(now() AT TIME ZONE 'Europe/Paris', 'YYYY-MM-DD"T"HH24:MI:SS'))));
  UPDATE entreprises SET data = v_data, updated_at = now() WHERE id = p_fonds_id;
  v_bail_id := v_data -> 'implantation' ->> 'bailId';
  IF COALESCE(v_bail_id, '') <> '' THEN
    SELECT data INTO v_bail FROM locations_actives WHERE id = v_bail_id FOR UPDATE;
    IF v_bail IS NOT NULL THEN
      UPDATE locations_actives
        SET data = v_bail || jsonb_build_object(
              'locataire', CASE WHEN left(p_acheteur, 3) = 'pj:' THEN substr(p_acheteur, 4) ELSE p_acheteur END,
              'locataireRef', p_acheteur,
              'transferts', COALESCE(v_bail -> 'transferts', '[]'::jsonb) || jsonb_build_array(
                jsonb_build_object('cause', 'vente_fonds', 'de', p_vendeur, 'vers', p_acheteur,
                  'horodatage', to_char(now() AT TIME ZONE 'Europe/Paris', 'YYYY-MM-DD"T"HH24:MI:SS'))))
        WHERE id = v_bail_id;
    END IF;
  END IF;
  RETURN jsonb_build_object('ok', true, 'fondsId', p_fonds_id, 'prix', v_prix, 'caisseExtraite', v_caisse, 'acheteur', p_acheteur, 'bailTransfere', COALESCE(v_bail_id, ''));
END;
$$;

CREATE OR REPLACE FUNCTION terminer_bail(p_bail_id text, p_cause text, p_acteur text, p_indemnite integer)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_bail jsonb;
  v_fonds_id text;
  v_fonds jsonb;
  v_prop text;
  v_ind integer := GREATEST(0, COALESCE(p_indemnite, 0));
  v_terrain text;
  v_locataire text;
BEGIN
  IF COALESCE(p_bail_id, '') = '' THEN RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides'); END IF;
  IF p_cause NOT IN ('resiliation_volontaire', 'accord_amiable', 'eviction_judiciaire', 'succession_sans_heritier') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cause_invalide');
  END IF;
  SELECT data INTO v_bail FROM locations_actives WHERE id = p_bail_id FOR UPDATE;
  IF v_bail IS NULL THEN RETURN jsonb_build_object('ok', true, 'deja_termine', true); END IF;
  v_locataire := v_bail ->> 'locataire';
  IF p_cause = 'resiliation_volontaire' THEN
    IF COALESCE(p_acteur, '') = '' THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_requis'); END IF;
    IF v_locataire IS DISTINCT FROM p_acteur AND ('pj:' || COALESCE(v_locataire, '')) IS DISTINCT FROM p_acteur THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pas_titulaire');
    END IF;
  END IF;
  v_terrain := (v_bail ->> 'country') || '_' || (v_bail ->> 'buildingId');
  SELECT (data::jsonb ->> 'proprietaire') INTO v_prop FROM terrains_etat WHERE id = v_terrain;
  IF p_cause = 'accord_amiable' AND v_ind > 0 THEN
    IF COALESCE(v_prop, '') = '' THEN RAISE EXCEPTION 'bailleur_introuvable'; END IF;
    IF NOT mouvement_titulaire(v_prop, -v_ind) THEN RETURN jsonb_build_object('ok', false, 'raison', 'bailleur_insolvable'); END IF;
    IF NOT mouvement_titulaire(COALESCE(v_bail ->> 'locataireRef', v_locataire), v_ind) THEN RAISE EXCEPTION 'locataire_introuvable'; END IF;
  END IF;
  v_fonds_id := v_bail ->> 'fondsId';
  IF COALESCE(v_fonds_id, '') <> '' THEN
    SELECT data INTO v_fonds FROM entreprises WHERE id = v_fonds_id FOR UPDATE;
    IF v_fonds IS NOT NULL AND COALESCE((v_fonds ->> 'version')::integer, 0) >= 2 THEN
      v_fonds := jsonb_set(v_fonds, '{statut}', to_jsonb('abandonne'::text));
      v_fonds := jsonb_set(v_fonds, '{historique}', COALESCE(v_fonds -> 'historique', '[]'::jsonb) || jsonb_build_array(jsonb_build_object(
          'evenement', 'bail_termine', 'cause', p_cause,
          'horodatage', to_char(now() AT TIME ZONE 'Europe/Paris', 'YYYY-MM-DD"T"HH24:MI:SS'))));
      UPDATE entreprises SET data = v_fonds, updated_at = now() WHERE id = v_fonds_id;
    END IF;
  END IF;
  INSERT INTO locations_archives (id, bail_id, country, city, building_id, room_id, lot_id, locataire, proprietaire_murs, loyer, debut, fin_cause, fonds_id, indemnite, data)
  VALUES (
    'bail-' || p_bail_id || '-' || extract(epoch from now())::bigint,
    p_bail_id, v_bail ->> 'country', v_bail ->> 'city', v_bail ->> 'buildingId', v_bail ->> 'roomId', v_bail ->> 'lotId', v_locataire, v_prop,
    GREATEST(0, COALESCE((v_bail ->> 'prix')::numeric, 0))::integer,
    NULLIF(v_bail ->> 'depuis', '')::integer, p_cause, NULLIF(v_fonds_id, ''), v_ind,
    jsonb_build_object('bail', v_bail, 'acteur', p_acteur));
  DELETE FROM locations_actives WHERE id = p_bail_id;
  RETURN jsonb_build_object('ok', true, 'deja_termine', false, 'cause', p_cause, 'fondsId', COALESCE(v_fonds_id, ''), 'indemnite', v_ind, 'proprietaireMurs', COALESCE(v_prop, ''));
END;
$$;

CREATE OR REPLACE FUNCTION resilier_bail_volontaire(p_bail_id text, p_acteur text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF COALESCE(p_bail_id, '') = '' OR COALESCE(p_acteur, '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;
  RETURN terminer_bail(p_bail_id, 'resiliation_volontaire', p_acteur, 0);
END;
$$;

REVOKE ALL ON FUNCTION mouvement_titulaire(text, numeric) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION mouvement_titulaire(text, numeric) TO service_role;
REVOKE ALL ON FUNCTION creer_fonds_commerce(text, text, text, integer, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION creer_fonds_commerce(text, text, text, integer, text) TO anon, authenticated, service_role;
REVOKE ALL ON FUNCTION alimenter_caisse_fonds(text, text, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION alimenter_caisse_fonds(text, text, integer) TO anon, authenticated, service_role;
REVOKE ALL ON FUNCTION retirer_caisse_fonds(text, text, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION retirer_caisse_fonds(text, text, integer) TO anon, authenticated, service_role;
REVOKE ALL ON FUNCTION vendre_fonds_commerce(text, text, text, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION vendre_fonds_commerce(text, text, text, integer) TO service_role;
REVOKE ALL ON FUNCTION terminer_bail(text, text, text, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION terminer_bail(text, text, text, integer) TO service_role;
REVOKE ALL ON FUNCTION resilier_bail_volontaire(text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION resilier_bail_volontaire(text, text) TO anon, authenticated, service_role;