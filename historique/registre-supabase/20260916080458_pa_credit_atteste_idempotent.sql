-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260916080458
-- Nom original      : pa_credit_atteste_idempotent
-- Categorie         : MIXTE -- MIXTE (structure ET mutation de donnees)
-- Date (deduite de la version) : 2026-09-16 08:04:58 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 360a34118688c9d518c380cb100aadc6
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
-- PA SERVEUR-AUTORITAIRES — LOT 2 : LE CREDIT PONCTUEL, RENDU IDEMPOTENT.
--
-- Deux familles de gains ne sont ni un repos ni un bonus differe : le +1 PA d'un aliment frais
-- consomme, et les remboursements de PA quand une operation deja facturee echoue ensuite
-- (candidature dont l'ecriture ne passe pas, cession d'imprimerie interrompue). Les uns comme
-- les autres sont aujourd'hui de simples `state.pa += n` cote client.
--
-- Les transposer tels quels serait ouvrir une porte : un credit qu'on peut redemander est un
-- credit infini. Chaque credit porte donc une REFERENCE unique -- la signature de l'objet
-- consomme, l'identifiant de la requete remboursee -- et la meme reference n'est honoree qu'une
-- fois. Le montant, lui, n'est jamais choisi par le client : il est declare par source.
CREATE TABLE IF NOT EXISTS public.pa_credits_uniques (
  acteur    text NOT NULL,
  source    text NOT NULL,
  reference text NOT NULL,
  montant   integer NOT NULL,
  cree_le   timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (acteur, source, reference)
);
ALTER TABLE public.pa_credits_uniques ENABLE ROW LEVEL SECURITY;
REVOKE INSERT, UPDATE, DELETE, SELECT ON public.pa_credits_uniques FROM anon, authenticated;

-- Montants declares par source. 'aliment_frais' reprend le +1 de consommerAliment ; les
-- remboursements reprennent le cout DECLARE de l'ordre concerne, lu dans ordres_couts -- jamais
-- un montant transmis par le client.
CREATE TABLE IF NOT EXISTS public.pa_credits_sources (
  source  text PRIMARY KEY,
  montant integer,            -- NULL = montant lu dans ordres_couts pour l'ordre p_ordre
  CHECK (montant IS NULL OR (montant > 0 AND montant <= 10))
);
DELETE FROM public.pa_credits_sources;
INSERT INTO public.pa_credits_sources (source, montant) VALUES
  ('aliment_frais', 1),
  ('remboursement_ordre', NULL);

CREATE OR REPLACE FUNCTION public.pa_crediter_atteste(
  p_acteur text, p_source text, p_reference text, p_ordre text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE v_declare boolean; v_montant integer; v_pa integer;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  IF p_reference IS NULL OR btrim(p_reference) = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reference_absente');
  END IF;

  SELECT true, montant INTO v_declare, v_montant
    FROM public.pa_credits_sources WHERE source = p_source;
  IF NOT coalesce(v_declare, false) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'source_non_declaree');
  END IF;

  -- Remboursement : le montant est celui que l'ordre coute REELLEMENT, pas celui qu'on demande.
  IF v_montant IS NULL THEN
    SELECT max(o.pa) INTO v_montant FROM public.ordres_couts o WHERE o.fn = p_ordre;
    IF v_montant IS NULL OR v_montant <= 0 THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'ordre_non_declare');
    END IF;
  END IF;

  BEGIN
    INSERT INTO public.pa_credits_uniques (acteur, source, reference, montant)
    VALUES (p_acteur, p_source, p_reference, v_montant);
  EXCEPTION WHEN unique_violation THEN
    SELECT coalesce(pa, 0) INTO v_pa FROM public.personnages_donnees WHERE name = p_acteur;
    RETURN jsonb_build_object('ok', false, 'raison', 'credit_deja_accorde', 'pa', v_pa);
  END;

  v_pa := public.pa_crediter_interne(p_acteur, v_montant);
  RETURN jsonb_build_object('ok', true, 'pa', v_pa, 'montant', v_montant);
END;
$$;
REVOKE ALL ON FUNCTION public.pa_crediter_atteste(text, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.pa_crediter_atteste(text, text, text, text) TO authenticated, service_role;