-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260919224608
-- Nom original      : caisse_institution_autorite_lot1
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-19 22:46:08 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 8093c97cc01f055526146b5ccde3df19
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
-- =====================================================================
-- LOT P0-A / INCREMENT 2 — LA CAISSE INSTITUTIONNELLE N'EST PLUS UNE
-- PRIMITIVE OUVERTE AU NAVIGATEUR
-- =====================================================================
-- L'AUDIT A DEMONTRE, banc a l'appui : un joueur ordinaire, sans aucun poste,
-- vidait republic_palais-presidentiel (88 604 -> 0) et creait de toutes pieces
-- une caisse a 99 000 000. Le seul controle etait « mon_personnage() n'est pas
-- nul », c'est-a-dire « il existe un personnage ».
--
-- POURQUOI LA REVOCATION SUFFIT, ET POURQUOI ELLE NE CASSE PAS LES 13 APPELANTS
-- INTERNES. caisse_institution_mouvement est appelee par 13 fonctions SQL
-- (cellule_renseignement_creer, militaire_solde_percevoir, fret_dedouaner,
-- commerce_*, entreprise_preempter...), toutes SECURITY DEFINER et proprietaire
-- postgres, toutes deja gardees par leur propre controle d'autorite. A
-- l'interieur d'une fonction SECURITY DEFINER, l'utilisateur effectif est le
-- PROPRIETAIRE : le test du droit EXECUTE porte donc sur postgres, pas sur le
-- joueur. Revoquer le droit au navigateur ne les touche pas.
--
-- ATTENTION, PIEGE ECARTE : on ne peut PAS distinguer l'appel interne de
-- l'appel direct avec est_appel_serveur(). Une RPC SECURITY DEFINER declenchee
-- par un joueur porte toujours les claims JWT de ce joueur -- est_appel_serveur()
-- y repond false. Seul le droit EXECUTE separe reellement les deux mondes.
--
-- CE QUI REMPLACE LE CHEMIN CLIENT. Les 3 enveloppes JS (crediterCaisseBatiment,
-- debiterCaisseBatimentAtomique, debiterCaisseBatimentPlafonne) concentrent les
-- 29 sites d'appel du jeu : elles seules changent de moteur, aucun des 29
-- appelants n'est modifie -- exactement la methode du chantier du 14 septembre.

-- ---------------------------------------------------------------- observation
CREATE TABLE IF NOT EXISTS public.caisses_mouvements_clients (
  id          bigserial PRIMARY KEY,
  acteur      text,
  caisse      text        NOT NULL,
  delta       numeric     NOT NULL,
  motif       text,
  accepte     boolean     NOT NULL,
  raison      text,
  vu_le       timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS caisses_mouvements_clients_idx
  ON public.caisses_mouvements_clients (caisse, vu_le DESC);
ALTER TABLE public.caisses_mouvements_clients ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.caisses_mouvements_clients FROM PUBLIC, anon, authenticated;
REVOKE ALL ON SEQUENCE public.caisses_mouvements_clients_id_seq FROM PUBLIC, anon, authenticated;

-- ------------------------------------------------- nouvelle porte cliente
CREATE OR REPLACE FUNCTION public.caisse_client_mouvement(
  p_caisse text, p_delta numeric, p_motif text DEFAULT NULL, p_plafonne boolean DEFAULT false)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $fn$
DECLARE
  v_moi text; v_pays text; v_existe boolean; v_solde numeric; v_verse numeric; v_res jsonb;
  v_raison text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;

  IF coalesce(btrim(p_caisse),'') = '' OR p_delta IS NULL OR p_delta = 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;

  -- 1. JURIDICTION : on ne touche que les caisses de SON pays. Les identifiants
  --    sont de la forme <pays>_<batiment> ; tous les appelants legitimes passent
  --    deja state.country, donc ce controle est transparent pour le jeu reel.
  IF v_pays IS NULL OR p_caisse NOT LIKE v_pays || '\_%' THEN
    v_raison := 'caisse_hors_pays';
  ELSE
    SELECT true, (data->>'solde')::numeric INTO v_existe, v_solde
      FROM public.caisses_batiments WHERE id = p_caisse;
    -- 2. AUCUNE CREATION DEPUIS LE NAVIGATEUR. Les 150 caisses du jeu sont
    --    derivees des batiments et creees par la dotation d'amorcage. Une caisse
    --    inventee par le client n'a jamais de raison d'etre -- c'est exactement
    --    l'exploit demontre (zzaudit-caisse-inventee a 99 M).
    IF NOT coalesce(v_existe, false) THEN
      v_raison := 'caisse_inexistante';
    END IF;
  END IF;

  IF v_raison IS NOT NULL THEN
    INSERT INTO public.caisses_mouvements_clients (acteur, caisse, delta, motif, accepte, raison)
    VALUES (v_moi, p_caisse, p_delta, p_motif, false, v_raison);
    RETURN jsonb_build_object('ok', false, 'raison', v_raison);
  END IF;

  -- 3. Le mouvement lui-meme reste porte par la primitive verrouillee, qui garde
  --    son FOR UPDATE et son refus du decouvert. On ne duplique pas sa logique.
  IF p_plafonne THEN
    v_verse := least(greatest(coalesce(v_solde,0), 0), abs(p_delta));
    IF v_verse <= 0 THEN
      INSERT INTO public.caisses_mouvements_clients (acteur, caisse, delta, motif, accepte, raison)
      VALUES (v_moi, p_caisse, p_delta, p_motif, false, 'solde_nul');
      RETURN jsonb_build_object('ok', true, 'verse', 0, 'solde', coalesce(v_solde,0));
    END IF;
    v_res := public.caisse_institution_mouvement(p_caisse, -v_verse, true);
    INSERT INTO public.caisses_mouvements_clients (acteur, caisse, delta, motif, accepte, raison)
    VALUES (v_moi, p_caisse, -v_verse, p_motif, coalesce((v_res->>'ok')::boolean,false), v_res->>'raison');
    IF coalesce((v_res->>'ok')::boolean, false) THEN
      RETURN jsonb_build_object('ok', true, 'verse', v_verse,
                                'solde', (SELECT (data->>'solde')::numeric FROM public.caisses_batiments WHERE id = p_caisse));
    END IF;
    RETURN jsonb_build_object('ok', false, 'raison', v_res->>'raison', 'verse', 0);
  END IF;

  v_res := public.caisse_institution_mouvement(p_caisse, p_delta, true);
  INSERT INTO public.caisses_mouvements_clients (acteur, caisse, delta, motif, accepte, raison)
  VALUES (v_moi, p_caisse, p_delta, p_motif, coalesce((v_res->>'ok')::boolean,false), v_res->>'raison');
  IF coalesce((v_res->>'ok')::boolean, false) THEN
    RETURN jsonb_build_object('ok', true,
      'solde', (SELECT (data->>'solde')::numeric FROM public.caisses_batiments WHERE id = p_caisse));
  END IF;
  RETURN v_res;
END;
$fn$;

REVOKE ALL ON FUNCTION public.caisse_client_mouvement(text, numeric, text, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.caisse_client_mouvement(text, numeric, text, boolean) TO authenticated, service_role;

-- ------------------------------------------------- fermeture des primitives
-- Le navigateur n'appelle plus jamais directement une primitive de caisse.
REVOKE EXECUTE ON FUNCTION public.caisse_institution_mouvement(text, numeric, boolean) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.caisse_institution_mouvement_plafonne(text, numeric) FROM PUBLIC, anon, authenticated;