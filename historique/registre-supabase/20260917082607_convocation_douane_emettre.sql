-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260917082607
-- Nom original      : convocation_douane_emettre
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-17 08:26:07 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : e4cc690b0cfcf59e52e5954d20dc0728
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
-- LOT A — CONVOCATION DOUANIERE : L'EFFET ANNONCE EXISTE ENFIN
-- Suite de l'audit des frontieres d'autorite, 17 septembre 2026.
--
-- CONSTAT : lors d'un controle douanier positif, le client lisait la fiche du deposant du fret
-- (sbGet), y ajoutait la convocation en memoire, puis la reecrivait (sbUpdate). Les deux appels
-- portent sur la fiche d'AUTRUI : refuses en silence depuis la fermeture RLS, sbUpdate rendant
-- null sans lever. Le deposant recevait donc le mail « presentez-vous au commissariat sous 24h,
-- faute de quoi vous serez arrete(e) » sans qu'AUCUNE convocation n'existe sur sa fiche.
-- En prime, le motif lire-modifier-reecrire ecrasait les convocations que le deposant aurait pu
-- recevoir entre la lecture et l'ecriture (le trigger personnages_preserver_judiciaire limitait
-- la casse, mais ne faisait pas exister l'ecriture).
--
-- AUTORITE : exiger_poste('chef_douanes'). La regle n'est pas inventee -- data.js declare deja
-- requiresPost:'chef_douanes' sur l'ordre « Controler une caisse de fret », et chef_douanes est un
-- poste nomme enregistre (nomme par min_int). On ne fait qu'appliquer cote serveur ce que l'ordre
-- declare deja cote client.
--
-- RIEN DU GAME DESIGN NE CHANGE : le motif, le delai et la forme de la convocation restent ceux
-- que le client construisait. Seul l'identifiant est genere par le serveur (il l'etait par
-- Date.now() + Math.random cote client, ce qui n'offrait aucune garantie d'unicite reelle).
--
-- IDEMPOTENCE : deux convocations pour le meme deposant, le meme motif et le meme jour d'emission
-- ne sont pas empilees -- un double controle ne peut pas doubler la peine.
CREATE OR REPLACE FUNCTION public.convocation_douane_emettre(
  p_cible text, p_motif text,
  p_jour_emission integer, p_heure_emission integer,
  p_jour_limite integer, p_heure_limite integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $fn$
DECLARE
  v_acteur text; v_liste jsonb; v_conv jsonb; v_id text; v_deja boolean;
BEGIN
  -- Leve si le compte connecte n'est pas le Chef des Douanes en exercice.
  v_acteur := public.exiger_poste('chef_douanes');
  IF v_acteur IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  IF COALESCE(btrim(p_cible), '') = '' OR COALESCE(btrim(p_motif), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;

  SELECT convocations INTO v_liste FROM public.personnages_donnees
   WHERE name = p_cible FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_introuvable');
  END IF;
  IF jsonb_typeof(v_liste) <> 'array' THEN v_liste := '[]'::jsonb; END IF;

  -- Meme motif, meme jour d'emission, non traitee : c'est la meme convocation.
  SELECT EXISTS (
    SELECT 1 FROM jsonb_array_elements(v_liste) e
     WHERE e->>'motif' = p_motif
       AND COALESCE((e->>'jourEmission')::integer, -1) = COALESCE(p_jour_emission, -1)
       AND COALESCE((e->>'traitee')::boolean, false) = false
  ) INTO v_deja;
  IF v_deja THEN
    RETURN jsonb_build_object('ok', true, 'rejeu', true, 'cible', p_cible);
  END IF;

  v_id := 'conv-' || replace(gen_random_uuid()::text, '-', '');
  v_conv := jsonb_build_object(
    'id', v_id, 'motif', p_motif,
    'jourEmission', p_jour_emission, 'heureEmission', p_heure_emission,
    'jourLimite', p_jour_limite, 'heureLimite', p_heure_limite,
    'traitee', false, 'emisePar', v_acteur);

  UPDATE public.personnages_donnees
     SET convocations = v_liste || jsonb_build_array(v_conv), updated_at = now()
   WHERE name = p_cible;

  RETURN jsonb_build_object('ok', true, 'convocation', v_conv, 'cible', p_cible, 'acteur', v_acteur);
END;
$fn$;
REVOKE EXECUTE ON FUNCTION public.convocation_douane_emettre(text, text, integer, integer, integer, integer) FROM anon, public;
GRANT EXECUTE ON FUNCTION public.convocation_douane_emettre(text, text, integer, integer, integer, integer) TO authenticated;