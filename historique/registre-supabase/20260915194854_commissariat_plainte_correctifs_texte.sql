-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260915194854
-- Nom original      : commissariat_plainte_correctifs_texte
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-15 19:48:54 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 64e258dd115ce2538fcfb2d934fffa13
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
-- CORRECTIF DU LOT 3. plaintes_en_cours.data est une colonne TEXT (elle contient le JSON
-- serialise par sbSavePlainte, que sbLoadPlaintes relit avec JSON.parse) -- et non un jsonb.
-- Les deux RPC du lot 3 y appliquaient des operateurs jsonb (p.data ->> 'auteur') : la creation
-- passait, mais tout appel aurait echoue a l'execution. On caste explicitement dans les deux sens.

CREATE OR REPLACE FUNCTION public.plainte_deposer(p_cible text, p_motif text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_nom text; v_pays text; v_ville text; v_jour integer;
  v_commissaire text; v_est_pj boolean := false;
  v_id text; v_res jsonb; v_statut text; v_data jsonb; v_cible text;
BEGIN
  SELECT d.name, d.country, coalesce(d.current_city, 'capitale'), coalesce(d.day, 1)
    INTO v_nom, v_pays, v_ville, v_jour
    FROM public.personnages_donnees d WHERE d.user_id = auth.uid() LIMIT 1;
  IF v_nom IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  IF p_motif IS NULL OR btrim(p_motif) = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'motif_absent');
  END IF;
  v_cible := coalesce(nullif(btrim(p_cible), ''), 'X');

  -- ANTI-SPAM (l'audit n'en avait trouve aucun) : une seule plainte en cours par plaignant et
  -- par cible. Le dossier doit etre instruit avant qu'un second soit ouvert sur le meme sujet.
  IF EXISTS (SELECT 1 FROM public.plaintes_en_cours p
              WHERE p.country = v_pays
                AND p.data IS NOT NULL AND left(btrim(p.data), 1) = '{'
                AND (p.data::jsonb) ->> 'auteur' = v_nom
                AND (p.data::jsonb) ->> 'cible'  = v_cible
                AND (p.data::jsonb) ->> 'status' = 'deposee') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'plainte_deja_en_cours');
  END IF;

  SELECT d.name INTO v_commissaire
    FROM public.personnages_donnees d
   WHERE d.country = v_pays AND d.poste ->> 'id' = 'commissaire' AND d.poste ->> 'city' = v_ville
   LIMIT 1;
  IF v_commissaire IS NOT NULL THEN
    v_est_pj := true;
  ELSE
    SELECT t.nom_pnj INTO v_commissaire FROM public.titulaires_pnj t
     WHERE t.country = v_pays AND t.poste_id = 'commissaire' AND t.city = v_ville LIMIT 1;
  END IF;

  v_id := 'plainte-' || (extract(epoch from clock_timestamp())*1000)::bigint || '-' ||
          substr(md5(random()::text), 1, 6);

  IF v_est_pj THEN
    v_statut := 'deposee';
    v_res := jsonb_build_object('ok', true, 'decision', 'transmise_commissaire');
  ELSE
    v_res := public.plainte_instruire_interne(v_pays, v_ville, v_cible, p_motif,
                                              coalesce(v_commissaire, 'Commissariat'));
    v_statut := v_res ->> 'decision';
  END IF;

  v_data := jsonb_build_object(
    'id', v_id, 'auteur', v_nom, 'cible', v_cible, 'motif', p_motif,
    'jour', v_jour, 'city', v_ville, 'country', v_pays, 'status', v_statut,
    'commissaire', v_commissaire, 'commissaire_pj', v_est_pj,
    'decide_le', CASE WHEN v_est_pj THEN NULL
                      ELSE to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') END,
    'motif_decision', v_res ->> 'motif_decision');

  INSERT INTO public.plaintes_en_cours (id, country, city, data)
  VALUES (v_id, v_pays, v_ville, v_data::text);

  RETURN v_res || jsonb_build_object('id', v_id, 'commissaire', v_commissaire,
                                     'commissaire_pj', v_est_pj, 'ville', v_ville);
END;
$$;

CREATE OR REPLACE FUNCTION public.plainte_traiter(p_id text, p_decision text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_nom text; v_poste text; v_poste_city text; v_pays text;
  v_brut text; v_data jsonb; v_ville text; v_pays_plainte text; v_res jsonb;
BEGIN
  SELECT a.nom, a.poste_id, a.poste_city, a.pays
    INTO v_nom, v_poste, v_poste_city, v_pays
    FROM public.acteur_poste_courant() a;
  IF v_nom IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  IF v_poste IS DISTINCT FROM 'commissaire' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante');
  END IF;
  IF p_decision NOT IN ('classer', 'enqueter') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'decision_invalide');
  END IF;

  SELECT p.data, p.city, p.country INTO v_brut, v_ville, v_pays_plainte
    FROM public.plaintes_en_cours p WHERE p.id = p_id FOR UPDATE;
  IF v_brut IS NULL OR left(btrim(v_brut), 1) <> '{' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'dossier_introuvable');
  END IF;
  v_data := v_brut::jsonb;

  IF v_pays_plainte IS DISTINCT FROM v_pays OR v_ville IS DISTINCT FROM v_poste_city THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'hors_juridiction');
  END IF;
  IF v_data ->> 'status' IS DISTINCT FROM 'deposee' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'dossier_deja_instruit');
  END IF;

  IF p_decision = 'classer' THEN
    v_res := jsonb_build_object('ok', true, 'decision', 'classee',
                                'motif_decision', 'classement_du_commissaire');
  ELSE
    v_res := public.plainte_instruire_interne(v_pays, v_ville, v_data ->> 'cible',
                                              v_data ->> 'motif', v_nom);
  END IF;

  UPDATE public.plaintes_en_cours
     SET data = (v_data || jsonb_build_object(
           'status', v_res ->> 'decision',
           'instruit_par', v_nom,
           'motif_decision', v_res ->> 'motif_decision',
           'decide_le', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')))::text
   WHERE id = p_id;

  RETURN v_res || jsonb_build_object('id', p_id);
END;
$$;

-- RLS CIBLEE. La table heberge AUSSI les affaires transmises au tribunal, ecrites par cinq autres
-- sites via sbSavePlainte : un REVOKE global des ecritures aurait casse tout le circuit judiciaire.
-- Discriminant : les dossiers du nouveau circuit portent la cle 'commissaire_pj', qu'aucune
-- affaire historique ne possede. Ils deviennent inaccessibles en ecriture a tout client -- seules
-- plainte_deposer et plainte_traiter, qui portent les regles d'autorite et de juridiction, y
-- touchent. Les affaires historiques gardent exactement les droits qu'elles avaient.
-- Aucune policy DELETE, dans les deux cas : plus personne n'efface une affaire.
GRANT INSERT, UPDATE ON public.plaintes_en_cours TO authenticated;
REVOKE DELETE ON public.plaintes_en_cours FROM anon, authenticated;

DROP POLICY IF EXISTS plaintes_insertion_affaires ON public.plaintes_en_cours;
DROP POLICY IF EXISTS plaintes_maj_affaires ON public.plaintes_en_cours;

CREATE POLICY plaintes_insertion_affaires ON public.plaintes_en_cours
  FOR INSERT TO authenticated
  WITH CHECK (data IS NULL OR left(btrim(data), 1) <> '{'
              OR NOT ((data::jsonb) ? 'commissaire_pj'));

CREATE POLICY plaintes_maj_affaires ON public.plaintes_en_cours
  FOR UPDATE TO authenticated
  USING (data IS NULL OR left(btrim(data), 1) <> '{'
         OR NOT ((data::jsonb) ? 'commissaire_pj'))
  WITH CHECK (data IS NULL OR left(btrim(data), 1) <> '{'
              OR NOT ((data::jsonb) ? 'commissaire_pj'));