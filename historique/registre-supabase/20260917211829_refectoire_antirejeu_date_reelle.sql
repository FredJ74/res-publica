-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260917211829
-- Nom original      : refectoire_antirejeu_date_reelle
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-17 21:18:29 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 06d7cd8bc60256382a3e3c3fb6c111b5
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
  v_jour   text;
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

  IF COALESCE(v_pj.current_building, '') <> 'caserne-militaire' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place');
  END IF;

  -- LE PAYS N'EST PAS CRU. 'caserne-militaire' est le MEME identifiant de batiment dans les
  -- quatre empires : la seule verification de presence ne distinguait pas la caserne ou l'on se
  -- trouve de celle dont on consommait le stock. Le pays est celui du territoire reel, lu sur la
  -- fiche. p_pays reste dans la signature et est ignore, comme p_gain et p_pa_max.
  v_pays := COALESCE(NULLIF(btrim(COALESCE(v_pj.country, '')), ''), 'republic');

  -- LE JOUR N'EST PAS CRU NON PLUS (correctif du 17 septembre 2026). p_jour servait de cle
  -- anti-rejeu : un client qui l'incrementait mangeait autant de fois qu'il voulait -- un robinet
  -- de PA. On applique desormais la convention serveur deja en vigueur pour toutes les autres
  -- gardes « une fois par jour » du projet (pa_repos_nocturne via pa_repos_le,
  -- assemblee_verser_indemnite, calomnie_distribuer_interne, corruption_presse_tenter,
  -- championnat_*) : la DATE REELLE Europe/Paris, derivee du serveur. Aucune horloge nouvelle.
  -- p_jour est conserve dans la signature et desormais ignore.
  --
  -- TRANSITION : une valeur heritee au format entier (ancien jour de jeu) ne peut jamais egaler
  -- une date ISO, donc le premier repas suivant ce deploiement est accorde. C'est voulu et sans
  -- consequence.
  v_jour := (now() AT TIME ZONE 'Europe/Paris')::date::text;

  v_stats := CASE WHEN jsonb_typeof(v_pj.stats) = 'object' THEN v_pj.stats ELSE '{}'::jsonb END;
  IF COALESCE(v_stats ->> 'repasCaserneJour', '') = v_jour THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_mange', 'jourCle', v_jour);
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
         stats = v_stats || jsonb_build_object('repasCaserneJour', v_jour)
   WHERE name = p_joueur;

  -- jourCle est RENVOYEE pour que le client recopie exactement le marqueur pose par le serveur.
  -- Sans cela, il ecrivait state.day dans cette cle et la prochaine sauvegarde complete du
  -- personnage ecrasait le marqueur serveur -- le rejeu redevenait possible des le lendemain.
  RETURN jsonb_build_object('ok', true, 'pa', v_pa, 'rations', v_rations,
                            'fabrique', v_fab, 'proteine', v_prot,
                            'pays', v_pays, 'jourCle', v_jour);
END;
$fn$;

REVOKE ALL ON FUNCTION public.refectoire_repas(text, text, integer, integer, integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.refectoire_repas(text, text, integer, integer, integer) FROM anon;
GRANT EXECUTE ON FUNCTION public.refectoire_repas(text, text, integer, integer, integer) TO authenticated, service_role;