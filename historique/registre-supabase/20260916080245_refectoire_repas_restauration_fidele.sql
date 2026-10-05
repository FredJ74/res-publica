-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260916080245
-- Nom original      : refectoire_repas_restauration_fidele
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-16 08:02:45 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 63fb86503688acaca9a7ea5a59ed37ce
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
-- CORRECTIF IMMEDIAT. En durcissant refectoire_repas au lot precedent, j'ai reecrit la fonction
-- sans avoir lu son corps entier : j'avais perdu la FABRICATION AUTOMATIQUE d'un lot de 10
-- rations a partir des matieres brutes (1 cereale + 1 viande OU poisson) quand le stock de
-- rations tombe a zero, ainsi que le detail du retour ('rations', 'fabrique', 'proteine').
-- La version d'origine est reprise telle quelle depuis migration_effort_de_guerre.sql.
--
-- SEULE MODIFICATION VOULUE, celle du chantier : p_gain et p_pa_max venaient du CLIENT
-- (supabase.js les transmet), donc un joueur pouvait demander p_gain = 999. Ils restent dans la
-- signature pour ne casser aucun appelant, mais sont IGNORES : le gain est de +2 et le plafond
-- de 30, en constantes serveur, exactement les valeurs de jeu actuelles.
-- On ajoute aussi exiger_acteur, absent de l'original : rien n'empechait d'appeler la fonction
-- au nom d'un autre joueur.
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
  PERFORM public.exiger_acteur(p_joueur);
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

  -- +2 PA, plafond 30 : CONSTANTES SERVEUR. p_gain et p_pa_max sont volontairement ignores.
  v_pa := LEAST(30, GREATEST(0, COALESCE(v_pj.pa, 0)) + 2);
  UPDATE public.personnages_donnees
     SET pa = v_pa,
         stats = v_stats || jsonb_build_object('repasCaserneJour', p_jour)
   WHERE name = p_joueur;

  RETURN jsonb_build_object('ok', true, 'pa', v_pa, 'rations', v_rations,
                            'fabrique', v_fab, 'proteine', v_prot);
END;
$fn$;