-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260917214959
-- Nom original      : militaire_compagnie_creer_atomique
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-17 21:49:59 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : f20c3d86d145bad4a55f0a35afbc6757
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
CREATE OR REPLACE FUNCTION public.militaire_compagnie_creer()
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $fn$
DECLARE
  c_contingent constant integer := 96;   -- 4 sections x 24 places
  c_sections   constant integer := 4;
  c_cout       constant numeric := 20000;
  c_pa         constant integer := 3;
  v_moi text; v_pays text; v_pa integer; v_id text; v_prefixe text;
  v_paye jsonb; v_caisse jsonb;
  v_sections jsonb; v_reserve jsonb;
BEGIN
  v_moi := public.exiger_poste('commandant');
  IF v_moi IS NULL THEN v_moi := public.mon_personnage(); END IF;
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  SELECT coalesce(country, 'republic'), coalesce(pa, 0) INTO v_pays, v_pa
    FROM public.personnages_donnees WHERE name = v_moi;
  IF v_pays IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;

  -- ==========================================================================================
  -- ORDRE DES OPERATIONS, et il compte. Un simple RETURN ne defait RIEN : seule une exception
  -- annule ce qui precede. Une premiere version prelevait les PA puis rendait proprement
  -- {ok:false} si la caisse refusait -- et les PA restaient preleves pour rien. Le banc l'a
  -- montre (PA 7 -> 4 sur un refus). D'ou cet ordre :
  --   1. pre-controle des PA, sans rien ecrire -> motif propre si insuffisants ;
  --   2. debit de la caisse, sous verrou -> motif propre si insuffisante, rien d'ecrit avant ;
  --   3. payer_ordre, qui fait AUTORITE sur les PA -> s'il refuse malgre le pre-controle (course
  --      entre deux appels), on LEVE, ce qui annule le debit de la caisse.
  -- ==========================================================================================
  IF v_pa < c_pa THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pa_insuffisants', 'requis', c_pa, 'pa_reel', v_pa);
  END IF;

  v_caisse := public.caisse_institution_mouvement(v_pays || '_caserne-militaire', -c_cout, true);
  IF NOT coalesce((v_caisse->>'ok')::boolean, false) THEN
    RETURN jsonb_build_object('ok', false,
      'raison', coalesce(v_caisse->>'raison', 'caisse_refusee'), 'cout', c_cout);
  END IF;

  v_paye := public.payer_ordre(v_moi, 'recruter_compagnie', c_pa, 0);
  IF NOT coalesce((v_paye->>'ok')::boolean, false) THEN
    RAISE EXCEPTION 'militaire_compagnie_creer: paiement des PA refuse (%)',
      coalesce(v_paye->>'raison', 'motif inconnu');
  END IF;

  v_id := 'compagnie-' || v_pays || '-' || floor(extract(epoch FROM clock_timestamp()) * 1000)::bigint::text;
  v_prefixe := to_char(now() AT TIME ZONE 'Europe/Paris', 'YYYYMM');

  SELECT jsonb_agg(jsonb_build_object(
           'id', v_id || '-s' || i, 'numero', i, 'lieutenantNom', NULL,
           'soldats', '[]'::jsonb) ORDER BY i)
    INTO v_sections FROM generate_series(1, c_sections) AS g(i);

  SELECT jsonb_agg(jsonb_build_object(
           'matricule', v_prefixe || '-' || lpad(i::text, 3, '0'),
           'formation', jsonb_build_object('force', 0, 'endurance', 0, 'tir', 0),
           'arme', 'corps_a_corps',
           'ville', 'caserne', 'buildingId', 'caserne-militaire', 'roomId', 'corps_garde',
           'leaderCourant', NULL, 'pa', 12) ORDER BY i)
    INTO v_reserve FROM generate_series(1, c_contingent) AS g(i);

  INSERT INTO public.compagnies_militaires (id, data)
  VALUES (v_id, jsonb_build_object(
    'id', v_id, 'pays', v_pays, 'capitaineNom', NULL,
    'contingentInitial', c_contingent,
    'reserve', v_reserve,
    'sections', v_sections));

  RETURN jsonb_build_object('ok', true, 'compagnie', v_id, 'contingent', c_contingent,
                            'sections', c_sections, 'cout', c_cout, 'pa', v_paye->'pa');
END;
$fn$;

REVOKE ALL ON FUNCTION public.militaire_compagnie_creer() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.militaire_compagnie_creer() FROM anon;
GRANT EXECUTE ON FUNCTION public.militaire_compagnie_creer() TO authenticated, service_role;