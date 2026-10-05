-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260917210517
-- Nom original      : refectoire_pays_derive_serveur
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-17 21:05:17 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 7905aea078e66d136e745dc36e1e50b3
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
CREATE OR REPLACE FUNCTION public.refectoire_repas(
  p_pays text, p_joueur text, p_jour integer,
  p_pa_max integer DEFAULT 30, p_gain integer DEFAULT 2
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $fn$
DECLARE
  v_pj     personnages%ROWTYPE;
  v_pays   text;
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
  IF COALESCE(btrim(p_joueur), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;

  SELECT * INTO v_pj FROM public.personnages WHERE name = p_joueur FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_absent'); END IF;

  -- Presence physique verifiee cote serveur : tout PJ present, quel que soit son statut.
  IF COALESCE(v_pj.current_building, '') <> 'caserne-militaire' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place');
  END IF;

  -- ==========================================================================================
  -- LE PAYS N'EST PLUS CRU (17 septembre 2026, audit d'autorite). p_pays etait transmis par le
  -- navigateur alors que 'caserne-militaire' est LE MEME identifiant de batiment dans les quatre
  -- empires : la seule verification de presence ne distinguait donc pas la caserne ou l'on se
  -- trouve de celle dont on consommait le stock. Un joueur pouvait manger les rations d'un autre
  -- empire. Le pays est desormais celui du TERRITOIRE ou le personnage se trouve reellement, lu
  -- sur sa propre fiche. p_pays est conserve dans la signature pour ne pas casser les appelants,
  -- et volontairement ignore -- meme convention que p_gain et p_pa_max ci-dessous.
  -- ==========================================================================================
  v_pays := COALESCE(NULLIF(btrim(COALESCE(v_pj.country, '')), ''), 'republic');

  v_stats := CASE WHEN jsonb_typeof(v_pj.stats) = 'object' THEN v_pj.stats ELSE '{}'::jsonb END;
  IF COALESCE((v_stats ->> 'repasCaserneJour')::integer, -1) = p_jour THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_mange');
  END IF;

  SELECT data INTO v_data FROM public.budgets_nationaux WHERE id = v_pays FOR UPDATE;
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
  UPDATE public.budgets_nationaux SET data = v_data, updated_at = now() WHERE id = v_pays;

  -- +2 PA, plafond 30 : CONSTANTES SERVEUR. p_gain et p_pa_max sont volontairement ignores.
  v_pa := LEAST(30, GREATEST(0, COALESCE(v_pj.pa, 0)) + 2);
  UPDATE public.personnages_donnees
     SET pa = v_pa,
         stats = v_stats || jsonb_build_object('repasCaserneJour', p_jour)
   WHERE name = p_joueur;

  RETURN jsonb_build_object('ok', true, 'pa', v_pa, 'rations', v_rations,
                            'fabrique', v_fab, 'proteine', v_prot, 'pays', v_pays);
END;
$fn$;

REVOKE ALL ON FUNCTION public.refectoire_repas(text, text, integer, integer, integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.refectoire_repas(text, text, integer, integer, integer) FROM anon;
GRANT EXECUTE ON FUNCTION public.refectoire_repas(text, text, integer, integer, integer) TO authenticated, service_role;