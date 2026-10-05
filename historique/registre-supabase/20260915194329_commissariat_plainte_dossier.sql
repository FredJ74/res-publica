-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260915194329
-- Nom original      : commissariat_plainte_dossier
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-15 19:43:29 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 81f904b6a091be1af681047a4fb3526f
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
-- COMMISSARIAT — LOT 3 : LA PLAINTE DEVIENT UN DOSSIER, INSTRUIT PAR LE COMMISSAIRE.
--
-- CE QUI EXISTAIT. Un insert PostgREST direct dans plaintes_en_cours (RLS allow_all : n'importe
-- qui pouvait modifier ou supprimer l'affaire d'autrui), puis, 24 h plus tard et UNIQUEMENT si le
-- plaignant revenait passer minuit ou dormir, un jet 1d100 decidait seul : < 40 classee sans
-- notification, 40-74 enquete, >= 75 « transmise au tribunal » avec une garde a vue annoncee par
-- mail mais qui n'existait dans aucune table -- enregistrerDetention sur un tiers se heurtant a la
-- policy detentions_ecriture_soi. Une plainte dont l'auteur ne revenait pas restait pending a vie.
--
-- CE QUE POSE CE LOT. Plus aucun tirage aleatoire, plus aucune transmission automatique, plus
-- aucune dependance au retour du plaignant : la plainte cree un DOSSIER adresse au commissaire
-- competent de la ville, et c'est lui qui tranche.
--   - commissaire PJ  : le dossier l'attend, il classe ou il ouvre l'enquete (plainte_traiter).
--   - commissaire PNJ : l'institution ne s'arrete pas. Il examine le dossier IMMEDIATEMENT, sur un
--                       critere deterministe et deja existant -- celui de mener_enquete : la cible
--                       a-t-elle, dans cette ville, un acte trace et non encore decouvert ?
--                       Oui -> enquete ouverte, acte demasque, garde a vue de 2 jours reelle.
--                       Non -> classement sans suite. Aucun de, aucune IA.
--
-- La garde a vue passe par detention_ouvrir_interne, la primitive du lot 1 : c'est la meme
-- ecriture que pour l'arrestation d'urgence, donc une detention qui EXISTE vraiment.

-- ---------------------------------------------------------------------------
-- Instruction d'un dossier : coeur partage par le commissaire PJ et le commissaire PNJ.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.plainte_instruire_interne(
  p_pays text, p_ville text, p_cible text, p_motif text, p_instructeur text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_acte   public.actions_tracables%ROWTYPE;
  v_jour   integer;
  v_det    jsonb;
  v_motifs jsonb;
BEGIN
  -- Le critere de mener_enquete, a l'identique : un acte de CETTE ville, de CETTE cible,
  -- non encore decouvert, et non expire.
  SELECT * INTO v_acte FROM public.actions_tracables a
   WHERE a.country = p_pays AND a.city = p_ville AND a.auteur = p_cible
     AND a.decouvert IS NOT TRUE
   ORDER BY a.jour DESC
   LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', true, 'decision', 'classee',
                              'motif_decision', 'aucun_element_a_charge');
  END IF;

  UPDATE public.actions_tracables SET decouvert = true WHERE id = v_acte.id;

  SELECT coalesce(d.day, 1) INTO v_jour FROM public.personnages_donnees d WHERE d.name = p_cible;
  v_motifs := jsonb_build_array(jsonb_build_object(
    'type', coalesce(v_acte.type_action, 'Acte illegal decouvert par enquete'),
    'cible', v_acte.cible,
    'jour_fait', v_acte.jour,
    'city', p_ville,
    'ref_type', 'action_tracee',
    'ref_id', v_acte.id,
    'jours', 2,
    'source', 'garde_a_vue',
    'date_evenement', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));

  v_det := public.detention_ouvrir_interne(
    p_cible, coalesce(v_acte.type_action, 'Acte illegal decouvert par enquete'), 2,
    p_ville, p_pays, v_motifs, p_instructeur, 'garde_a_vue_enquete');

  RETURN jsonb_build_object('ok', true, 'decision', 'enquete_ouverte',
                            'acte', coalesce(v_acte.type_action, 'acte illegal'),
                            'detention', v_det);
END;
$$;
REVOKE ALL ON FUNCTION public.plainte_instruire_interne(text,text,text,text,text)
  FROM PUBLIC, anon, authenticated;

-- ---------------------------------------------------------------------------
-- DEPOT D'UNE PLAINTE.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.plainte_deposer(p_cible text, p_motif text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_nom text; v_pays text; v_ville text; v_jour integer;
  v_commissaire text; v_est_pj boolean := false;
  v_id text; v_res jsonb; v_statut text; v_data jsonb;
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

  -- ANTI-SPAM (l'audit n'en avait trouve aucun) : une seule plainte en cours par plaignant et
  -- par cible. Le dossier doit etre instruit avant qu'un second soit ouvert sur le meme sujet.
  IF EXISTS (SELECT 1 FROM public.plaintes_en_cours p
              WHERE p.country = v_pays
                AND p.data ->> 'auteur' = v_nom
                AND p.data ->> 'cible' = coalesce(nullif(btrim(p_cible), ''), 'X')
                AND p.data ->> 'status' = 'deposee') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'plainte_deja_en_cours');
  END IF;

  -- Commissaire competent : un PJ en poste dans cette ville, sinon le PNJ titulaire.
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
    -- Le dossier attend la decision du commissaire joueur. Rien n'est decide a sa place.
    v_statut := 'deposee';
    v_res := jsonb_build_object('ok', true, 'decision', 'transmise_commissaire');
  ELSE
    -- Institution tenue par un PNJ : elle instruit, immediatement et sans hasard.
    v_res := public.plainte_instruire_interne(v_pays, v_ville, coalesce(nullif(btrim(p_cible), ''), 'X'),
                                              p_motif, coalesce(v_commissaire, 'Commissariat'));
    v_statut := v_res ->> 'decision';
  END IF;

  v_data := jsonb_build_object(
    'id', v_id, 'auteur', v_nom, 'cible', coalesce(nullif(btrim(p_cible), ''), 'X'),
    'motif', p_motif, 'jour', v_jour, 'status', v_statut,
    'commissaire', v_commissaire, 'commissaire_pj', v_est_pj,
    'decide_le', CASE WHEN v_est_pj THEN NULL
                      ELSE to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') END,
    'motif_decision', v_res ->> 'motif_decision');

  INSERT INTO public.plaintes_en_cours (id, country, city, data)
  VALUES (v_id, v_pays, v_ville, v_data);

  RETURN v_res || jsonb_build_object('id', v_id, 'commissaire', v_commissaire,
                                     'commissaire_pj', v_est_pj, 'ville', v_ville);
END;
$$;
REVOKE ALL ON FUNCTION public.plainte_deposer(text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.plainte_deposer(text, text) TO authenticated, service_role;

-- ---------------------------------------------------------------------------
-- DECISION DU COMMISSAIRE PJ.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.plainte_traiter(p_id text, p_decision text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_nom text; v_poste text; v_poste_city text; v_pays text;
  v_data jsonb; v_ville text; v_pays_plainte text; v_res jsonb;
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

  SELECT p.data, p.city, p.country INTO v_data, v_ville, v_pays_plainte
    FROM public.plaintes_en_cours p WHERE p.id = p_id FOR UPDATE;
  IF v_data IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'dossier_introuvable');
  END IF;
  -- Un commissaire n'instruit que les dossiers de SA ville et de son empire.
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
     SET data = v_data || jsonb_build_object(
           'status', v_res ->> 'decision',
           'instruit_par', v_nom,
           'motif_decision', v_res ->> 'motif_decision',
           'decide_le', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'))
   WHERE id = p_id;

  RETURN v_res || jsonb_build_object('id', p_id);
END;
$$;
REVOKE ALL ON FUNCTION public.plainte_traiter(text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.plainte_traiter(text, text) TO authenticated, service_role;

-- ---------------------------------------------------------------------------
-- RLS : la table cesse d'etre ouverte a tous les vents.
-- L'audit avait releve une policy ALL / public / USING(true) : n'importe quel joueur pouvait
-- creer, requalifier ou SUPPRIMER l'affaire d'autrui. La lecture reste ouverte (le registre des
-- plaintes est consultable au tribunal), mais plus aucune ecriture cliente n'est possible :
-- tout passe par les deux RPC ci-dessus, qui portent les regles.
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS allow_all_plaintes_en_cours ON public.plaintes_en_cours;
ALTER TABLE public.plaintes_en_cours ENABLE ROW LEVEL SECURITY;
CREATE POLICY plaintes_lecture ON public.plaintes_en_cours
  FOR SELECT TO anon, authenticated USING (true);
REVOKE INSERT, UPDATE, DELETE ON public.plaintes_en_cours FROM anon, authenticated;