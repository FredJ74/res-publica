-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260917192721
-- Nom original      : pop_inf_autorite_par_cause
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-17 19:27:21 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : f76d1f79b17efebbb61795c69f0c0f9a
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
-- La POP/INF d'autrui ne se modifie plus que PAR UNE CAUSE DECLAREE.
-- Chaque cause porte son autorite et son amplitude, lues sur les mecaniques existantes.
CREATE OR REPLACE FUNCTION public.personnage_ajuster_pop_inf(
  p_acteur text, p_cible text, p_pop integer, p_inf integer, p_cause text
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $fn$
DECLARE
  v_res jsonb; v_base jsonb;
  v_poste text; v_pays text;
  v_min integer; v_max integer;
  v_serveur boolean := public.est_appel_serveur();
BEGIN
  IF NOT v_serveur THEN PERFORM public.exiger_acteur(p_acteur); END IF;

  IF coalesce(btrim(coalesce(p_cible,'')), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_invalide');
  END IF;

  -- Aucune mecanique du jeu ne modifie l'INF d'un AUTRE personnage aujourd'hui : l'influence
  -- d'une organisation est une autre jauge, portee par la table organisations. On refuse donc,
  -- plutot que de laisser une porte ouverte sans usage.
  IF p_inf IS NOT NULL AND NOT v_serveur THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'inf_sans_cause');
  END IF;

  SELECT pd.poste->>'id', pd.country INTO v_poste, v_pays
    FROM public.personnages_donnees pd WHERE pd.name = p_acteur;

  -- REGISTRE DES CAUSES. Chaque ligne = une mecanique reelle, son autorite et son amplitude.
  IF v_serveur THEN
    v_min := -100; v_max := 100;

  ELSIF p_cause = 'rumeur_pj' THEN
    -- Action grise ouverte a tout joueur. Perte tiree dans 5..20 (appliquerEffetRumeur).
    v_min := -20; v_max := -5;

  ELSIF p_cause = 'rumeur_gouvernement' THEN
    -- Meme action, cible gouvernementale. Perte tiree dans 1..5, appliquee a chaque titulaire.
    v_min := -5; v_max := -1;

  ELSIF p_cause = 'excommunication' THEN
    -- Reserve au Grand Pretre national en exercice. Le Grand Pretre n'est pas un poste porte par
    -- la fiche : c'est la ligne titulaires_pnj(pays, 'grand_pretre', NULL), que le client compare
    -- deja au nom du joueur (estGrandPretreActuel). Meme source de verite cote serveur.
    IF NOT EXISTS (SELECT 1 FROM public.titulaires_pnj t
                    WHERE t.poste_id = 'grand_pretre' AND t.city IS NULL
                      AND t.nom_pnj = p_acteur) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante',
                                'cause', p_cause, 'requis', 'grand_pretre');
    END IF;
    v_min := -15; v_max := -15;

  ELSIF p_cause IN ('dementi_reussi', 'dementi_rate') THEN
    -- Ordre « Dementi officiel » : requiresPost president (palais) ou min_info (ministere).
    IF v_poste IS NULL OR v_poste NOT IN ('president', 'min_info') THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante',
                                'cause', p_cause, 'poste_reel', coalesce(v_poste,'(aucun)'));
    END IF;
    IF p_cause = 'dementi_reussi' THEN v_min := 1; v_max := 100;
    ELSE v_min := -100; v_max := -1; END IF;

  ELSIF p_cause = 'sentence_torture' THEN
    -- Ordre « Rendre la sentence » : requiresPost juge. -100 ramene la POP exactement a zero.
    IF v_poste IS DISTINCT FROM 'juge' THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante',
                                'cause', p_cause, 'poste_reel', coalesce(v_poste,'(aucun)'));
    END IF;
    v_min := -100; v_max := -100;

  ELSIF p_cause = 'football_match' THEN
    -- Gain de popularite d'un titulaire apres un match : +20 (participation) ou +30 (victoire).
    -- RESIDU ASSUME : le championnat n'a pas de moteur serveur, il avance depuis les navigateurs
    -- des joueurs. Aucun poste ne peut donc etre exige ici. L'amplitude est bornee aux deux
    -- seules valeurs declarees et le sens est POSITIF : le pire abus possible est d'elever la POP
    -- d'un personnage, jamais de l'abaisser. Fermeture definitive = moteur serveur du championnat.
    IF coalesce(p_pop,0) NOT IN (20, 30) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'delta_hors_cause',
                                'cause', p_cause, 'pop', p_pop);
    END IF;
    v_min := 20; v_max := 30;

  ELSE
    RETURN jsonb_build_object('ok', false, 'raison', 'cause_non_declaree', 'cause', p_cause);
  END IF;

  IF coalesce(p_pop, 0) < v_min OR coalesce(p_pop, 0) > v_max THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'delta_hors_cause',
                              'cause', p_cause, 'pop', p_pop, 'min', v_min, 'max', v_max);
  END IF;

  SELECT jsonb_set(
           CASE WHEN jsonb_typeof(pp.resources) = 'object' THEN pp.resources ELSE '{}'::jsonb END,
           '{pop}', to_jsonb(greatest(0, least(100,
             coalesce(CASE WHEN jsonb_typeof(pp.resources -> 'pop') = 'number'
                           THEN (pp.resources ->> 'pop')::numeric END, 50)
             + coalesce(p_pop, 0)))))
    INTO v_base
    FROM public.personnages_donnees pp WHERE pp.name = p_cible FOR UPDATE;

  IF v_base IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_introuvable');
  END IF;

  UPDATE public.personnages_donnees
     SET resources = CASE WHEN p_inf IS NULL THEN v_base
            ELSE jsonb_set(v_base, '{inf}', to_jsonb(greatest(0, least(100,
                   coalesce(CASE WHEN jsonb_typeof(v_base -> 'inf') = 'number'
                                 THEN (v_base ->> 'inf')::numeric END, 0) + p_inf))))
          END
   WHERE name = p_cible
   RETURNING resources INTO v_res;

  RETURN jsonb_build_object('ok', true, 'pop', v_res -> 'pop', 'inf', v_res -> 'inf',
                            'cause', p_cause);
END;
$fn$;

REVOKE ALL ON FUNCTION public.personnage_ajuster_pop_inf(text, text, integer, integer, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.personnage_ajuster_pop_inf(text, text, integer, integer, text) FROM anon;
GRANT EXECUTE ON FUNCTION public.personnage_ajuster_pop_inf(text, text, integer, integer, text) TO authenticated, service_role;

-- L'ancienne surcharge sans cause permettait a tout joueur authentifie de modifier de +/-100 la
-- POP de n'importe qui : exiger_acteur prouvait QUI agissait, rien ne verifiait l'autorite sur la
-- CIBLE. Elle n'est plus appelable par un navigateur. Un client en cache qui l'appellerait encore
-- echoue franchement (fail closed), il n'obtient pas un effet non autorise.
REVOKE ALL ON FUNCTION public.personnage_ajuster_pop_inf(text, text, integer, integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.personnage_ajuster_pop_inf(text, text, integer, integer) FROM anon;
REVOKE ALL ON FUNCTION public.personnage_ajuster_pop_inf(text, text, integer, integer) FROM authenticated;