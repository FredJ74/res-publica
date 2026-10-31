-- APPLICATION ATTESTÉE par le registre canonique du 31/10/2026 : version 20261027112035.
-- Archivage documentaire seulement ; ne pas rejouer.
-- APPLIQUEE le 27/10/2026 par Claude via MCP apply_migration -- registre Supabase 20261027112035.
-- Eprouvee avant application en transaction annulee, au role authenticated (retrait refuse sans ecrou, accepte juste apres, enquete ouverte). Baseline NON reextrait.
-- ============================================================================
-- AVIS DE RECHERCHE ET ENQUETES : DEUX FAILLES FERMEES (27 octobre 2026)
-- ============================================================================
-- Audit « une seule verite », passe de minuit cote ecran.
--   1. recherche_retirer : un joueur recherche pouvait effacer lui-meme tous ses motifs de
--      recherche d'un seul appel. Les retraits legitimes appeles par l'ecran sont : le motif juge
--      juste apres une arrestation (le joueur vient d'etre ecroue), et l'extinction de la
--      desertion (mobilisation levee, ou incorporation d'un detenu). Le serveur l'exige desormais.
--      La justification apres convocation, troisieme cas, passe par convocation_se_justifier.
--   2. enquete_garde_a_vue : elle mettait en garde a vue (2 jours) n'importe qui, pour peu qu'une
--      « enquete » figure sur la fiche de l'appelant -- fiche qu'il ecrit lui-meme, sans aucun
--      controle de poste. Le seul chemin du jeu qui creait ces enquetes n'a plus de bouton (ordre
--      « ouvrir_enquete_cible » absent de data.js). La fonction n'est plus appelable.
--   3. Ouvrir une enquete (Ministre de la Justice) : jet (90 %), frais de 400 FR sur la caisse du
--      ministere, annonce et courrier etaient decides par l'ecran. enquete_ouvrir les fait.
-- Idempotente. Aucun acte de joueur.
-- ============================================================================

DO $do$
DECLARE v_def text;
BEGIN
  v_def := pg_get_functiondef('public.recherche_retirer(text[],text,text)'::regprocedure);
  IF position('retrait_non_autorise' IN v_def) = 0 THEN
    v_def := replace(v_def,
      E'    v_cible := v_moi;\n  ELSE',
      E'    v_cible := v_moi;\n'
      || E'    -- UN JOUEUR N''EFFACE PAS SES PROPRES POURSUITES (27/10/2026). Seuls deux cas sont admis :\n'
      || E'    -- la desertion qui s''eteint (mobilisation levee, ou detenu incorpore), et le motif juge\n'
      || E'    -- juste apres une arrestation (une detention vient d''etre ouverte a son nom).\n'
      || E'    IF NOT (\n'
      || E'         (p_actes <@ ARRAY[''desertion'']::text[]\n'
      || E'          AND (NOT coalesce((SELECT (b.data ->> ''mobilisationNationaleActive'')::boolean FROM public.budgets_nationaux b\n'
      || E'                              JOIN public.personnages_donnees d ON d.country = b.id WHERE d.name = v_moi), false)\n'
      || E'               OR EXISTS (SELECT 1 FROM public.detention_active(v_moi))))\n'
      || E'      OR EXISTS (SELECT 1 FROM public.detentions t WHERE t.nom = v_moi AND t.created_at > now() - interval ''15 minutes'')\n'
      || E'    ) THEN\n'
      || E'      RETURN jsonb_build_object(''ok'', false, ''raison'', ''retrait_non_autorise'');\n'
      || E'    END IF;\n'
      || E'  ELSE');
    IF position('retrait_non_autorise' IN v_def) = 0 THEN RAISE EXCEPTION 'recherche_retirer : motif introuvable'; END IF;
    EXECUTE v_def;
  END IF;
END $do$;

REVOKE ALL ON FUNCTION public.enquete_garde_a_vue(text, text, text) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.enquete_ouvrir(p_type_cible text, p_cible text, p_nom_cible text DEFAULT NULL)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; v_poste text; v_paie jsonb; v_caisse jsonb; v_reussi boolean; v_nom text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country, poste ->> 'id' INTO v_pays, v_poste FROM public.personnages_donnees WHERE name = v_moi;
  IF v_poste IS DISTINCT FROM 'min_just' THEN RETURN jsonb_build_object('ok', false, 'raison', 'reserve_min_just'); END IF;
  IF p_type_cible NOT IN ('citoyen', 'club_sportif', 'entreprise', 'organisation') OR coalesce(p_cible, '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_invalide'); END IF;
  IF p_type_cible = 'citoyen' AND NOT EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = p_cible) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_invalide'); END IF;
  v_nom := coalesce(nullif(btrim(p_nom_cible), ''), p_cible);
  v_paie := public.payer_ordre(v_moi, 'ouvrir_enquete', 2, 0);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
  PERFORM set_config('rp.caisse_interne', 'on', true);
  v_caisse := public.caisse_institution_mouvement(v_pays || '_gouvernement-min_just', -400, true);
  PERFORM set_config('rp.caisse_interne', '', true);
  IF coalesce((v_caisse ->> 'ok')::boolean, false) IS NOT TRUE THEN
    RAISE EXCEPTION 'enquete_ouvrir: caisse insuffisante' USING ERRCODE = 'P0001', HINT = 'caisse_insuffisante';
  END IF;
  v_reussi := random() < 0.9;
  IF v_reussi THEN
    PERFORM public.annonce_publique_interne(v_pays, '🔍 Le Ministère de la Justice ouvre une enquête sur ' || v_nom || '.');
    IF p_type_cible = 'citoyen' THEN
      PERFORM public.mail_systeme_poser_interne('Ministère de la Justice', p_cible, 'Enquête ouverte',
        'Une enquête judiciaire a été ouverte à votre sujet.', to_char(now() AT TIME ZONE 'Europe/Paris', 'DD/MM/YYYY HH24:MI'));
    END IF;
  END IF;
  RETURN jsonb_build_object('ok', true, 'reussi', v_reussi, 'cout', 400) || jsonb_build_object('paie', v_paie);
EXCEPTION WHEN SQLSTATE 'P0001' THEN
  IF SQLERRM LIKE 'enquete_ouvrir: caisse insuffisante%' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caisse_insuffisante');
  END IF;
  RAISE;
END; $function$;
REVOKE ALL ON FUNCTION public.enquete_ouvrir(text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.enquete_ouvrir(text, text, text) TO authenticated;
