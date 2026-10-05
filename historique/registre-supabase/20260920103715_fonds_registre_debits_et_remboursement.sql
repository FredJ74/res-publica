-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260920103715
-- Nom original      : fonds_registre_debits_et_remboursement
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-20 10:37:15 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : d4197748fc9ddb672006e042a2ed6166
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
-- §6.1 : LE REMBOURSEMENT DEVIENT PROUVABLE
-- ---------------------------------------------------------------------------
-- CE QUI BLOQUAIT L'ACTIVATION DU VERROU arg/liquide. Le debit est serveur depuis
-- le chantier C (debiter_fonds_ordinaires, 23 appelants). Son inverse ne l'est
-- pas : crediterFondsOrdinaires() ajoute localement, et 10 de ses 15 appelants
-- sont des REMBOURSEMENTS -- le serveur a refuse l'action, le client rend
-- l'argent. Une fois le verrou actif, ces remboursements seraient silencieusement
-- ecrases : le joueur aurait paye sans rien recevoir et sans etre rembourse.
--
-- POURQUOI PAS UN MIROIR DE MONTANTS. fonds_credits_sources convient aux credits
-- dont le montant est connu d'avance (300 FR de kompromat, le cout d'un ordre).
-- Il ne convient pas au remboursement d'un debit quelconque : le montant est
-- celui qui a REELLEMENT ete preleve, connu du serveur seul.
--
-- LA SOLUTION EST LA DOCTRINE DU PROJET : l'anti-rejeu EST la cle. Chaque debit
-- laisse une ligne ; rembourser, c'est consommer CETTE ligne, une fois. Le client
-- ne transmet jamais un montant, seulement l'identifiant du debit qu'il veut voir
-- annule -- et cet identifiant ne lui sert a rien s'il n'est pas le sien.
-- La PART eventuelle (remboursement partiel de 30 %) vient de
-- fonds_credits_sources, pas de l'appel.

CREATE TABLE IF NOT EXISTS public.fonds_debits (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  acteur            text NOT NULL,
  montant           numeric NOT NULL CHECK (montant > 0),
  preleve_liquide   numeric NOT NULL DEFAULT 0,
  preleve_national  numeric NOT NULL DEFAULT 0,
  debite_le         timestamptz NOT NULL DEFAULT now(),
  rembourse_le      timestamptz,
  montant_rembourse numeric,
  source_remb       text
);
CREATE INDEX IF NOT EXISTS fonds_debits_acteur_idx ON public.fonds_debits (acteur, debite_le DESC);
ALTER TABLE public.fonds_debits ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.fonds_debits FROM anon, authenticated, public;

-- Le debit inscrit sa ligne et rend son identifiant. Signature et retour existants
-- INCHANGES par ailleurs : les 23 appelants actuels ignorent simplement le champ
-- supplementaire, aucun n'a besoin d'etre touche pour continuer a fonctionner.
CREATE OR REPLACE FUNCTION public.debiter_fonds_ordinaires(p_acteur text, p_montant numeric)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_ok boolean; v_liq_avant numeric; v_nat_avant numeric;
  v_pris_liq numeric; v_pris_nat numeric; v_debit uuid;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  IF p_montant IS NULL OR p_montant <= 0 THEN
    RETURN jsonb_build_object('ok', true, 'montant', 0);
  END IF;
  IF p_montant > 100000000 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'montant_invalide');
  END IF;

  SELECT coalesce(liquide, 0) INTO v_liq_avant
    FROM public.personnages_donnees WHERE name = p_acteur;
  SELECT coalesce(solde, 0) INTO v_nat_avant FROM public.comptes_bancaires
   WHERE personnage = p_acteur AND banque = 'nationale';

  v_ok := public.helvetia_debiter_fonds_ordinaires(p_acteur, p_montant);
  IF NOT v_ok THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants');
  END IF;

  -- Repartition REELLE du prelevement, recalculee sur l'etat d'avant : c'est elle
  -- qu'un remboursement devra restituer, pas une hypothese.
  v_pris_liq := least(coalesce(v_liq_avant, 0), p_montant);
  v_pris_nat := p_montant - v_pris_liq;

  INSERT INTO public.fonds_debits (acteur, montant, preleve_liquide, preleve_national)
  VALUES (p_acteur, p_montant, v_pris_liq, v_pris_nat)
  RETURNING id INTO v_debit;

  RETURN jsonb_build_object('ok', true, 'montant', p_montant, 'debit_id', v_debit,
    'liquide', (SELECT liquide FROM public.personnages_donnees WHERE name = p_acteur),
    'arg', (SELECT arg FROM public.personnages_donnees WHERE name = p_acteur),
    'solde_national', coalesce((SELECT solde FROM public.comptes_bancaires
                                 WHERE personnage = p_acteur AND banque = 'nationale'), 0));
END;
$$;
REVOKE ALL ON FUNCTION public.debiter_fonds_ordinaires(text, numeric) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.debiter_fonds_ordinaires(text, numeric) TO authenticated, service_role;

-- Rembourser = consommer la ligne du debit, une seule fois.
CREATE OR REPLACE FUNCTION public.fonds_rembourser(p_debit_id uuid, p_source text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_moi text; d public.fonds_debits%ROWTYPE;
  v_part numeric; v_fixe numeric; v_montant numeric;
  v_arg numeric; v_liquide numeric; v_maj integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  IF p_debit_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'debit_absent');
  END IF;

  SELECT s.montant, s.part INTO v_fixe, v_part
    FROM public.fonds_credits_sources s WHERE s.source = p_source;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'source_non_declaree');
  END IF;

  -- Verrou sur la ligne : deux remboursements simultanes ne peuvent pas passer.
  SELECT * INTO d FROM public.fonds_debits WHERE id = p_debit_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'debit_introuvable');
  END IF;
  -- Le debit d'autrui n'est pas remboursable : il n'existe pas, pour moi.
  IF d.acteur IS DISTINCT FROM v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'debit_introuvable');
  END IF;
  IF d.rembourse_le IS NOT NULL THEN
    SELECT coalesce(arg,0), coalesce(liquide,0) INTO v_arg, v_liquide
      FROM public.personnages_donnees WHERE name = v_moi;
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_rembourse',
                              'arg', v_arg, 'liquide', v_liquide);
  END IF;

  -- Montant : la part declaree du debit REEL, jamais un montant transmis. Un
  -- montant fixe declare est plafonne par ce qui a ete preleve : une source ne
  -- peut pas rendre plus que ce qui a ete pris.
  v_montant := floor(d.montant * coalesce(v_part, 1));
  IF v_fixe IS NOT NULL THEN v_montant := least(v_fixe, d.montant); END IF;
  IF v_montant IS NULL OR v_montant <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'montant_nul');
  END IF;

  UPDATE public.fonds_debits
     SET rembourse_le = now(), montant_rembourse = v_montant, source_remb = p_source
   WHERE id = p_debit_id AND rembourse_le IS NULL;
  GET DIAGNOSTICS v_maj = ROW_COUNT;
  IF v_maj = 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_rembourse');
  END IF;

  UPDATE public.personnages_donnees
     SET liquide = coalesce(liquide,0) + v_montant,
         arg     = coalesce(arg,0)     + v_montant,
         updated_at = now()
   WHERE name = v_moi
   RETURNING arg, liquide INTO v_arg, v_liquide;

  RETURN jsonb_build_object('ok', true, 'montant', v_montant, 'source', p_source,
                            'arg', v_arg, 'liquide', v_liquide);
END;
$$;
REVOKE ALL ON FUNCTION public.fonds_rembourser(uuid, text) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.fonds_rembourser(uuid, text) TO authenticated, service_role;