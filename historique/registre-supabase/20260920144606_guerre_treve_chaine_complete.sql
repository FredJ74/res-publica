-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260920144606
-- Nom original      : guerre_treve_chaine_complete
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-20 14:46:06 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 46688265bc9e053194f52a5ac40c3040
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
-- §6.3 — LA CHAINE DE LA TREVE, ARBITRAGE DU 20 SEPTEMBRE 2026
-- ---------------------------------------------------------------------------
-- CHAINE CANONIQUE :
--   MAE du pays A propose  ->  MAE du pays B (DESTINATAIRE) accepte ou refuse
--                          ->  Ministre de la Defense met en oeuvre le cessez-le-feu.
--
-- CE QUI MANQUAIT. Au lot precedent, l'etape d'acceptation avait ete ISOLEE :
-- la fonction cliente accepterTreve() n'avait ni appelant ni garde, et son
-- autorite n'etait attestee nulle part. Elle l'est desormais. Deux consequences :
--
--   1. LA PROPOSITION DOIT DIRE DE QUEL PAYS ELLE VIENT. Jusqu'ici le
--      cessez-le-feu ne portait que `proposePar`, un NOM DE PERSONNE. On ne
--      pouvait donc pas determiner qui est le destinataire -- et sans cela,
--      « seul le MAE du pays destinataire peut repondre » est inapplicable.
--      On ajoute `proposePays`, renseigne par le serveur.
--
--   2. L'ACTIVATION EXIGE DESORMAIS UNE TREVE ACCEPTEE. Elle se contentait
--      d'une proposition, faute d'etape d'acceptation atteignable. C'est
--      l'application de la chaine arbitree, pas une regle nouvelle : sans
--      accord du pays destinataire, il n'y a rien a mettre en oeuvre.
--
-- Aucune autre regle de guerre n'est touchee.

-- 1. LA PROPOSITION porte desormais le pays du proposant.
CREATE OR REPLACE FUNCTION public.guerre_treve_proposer(p_guerre_id text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_pays text; v_moi text; g record; v_cf jsonb;
BEGIN
  v_pays := public.guerre_acteur_poste('min_ae');
  IF v_pays IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reserve_au_ministre_ae');
  END IF;
  v_moi := public.mon_personnage();

  SELECT * INTO g FROM public.guerres WHERE id = p_guerre_id FOR UPDATE;
  IF NOT FOUND OR g.statut <> 'active' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'guerre_introuvable');
  END IF;
  IF v_pays NOT IN (g.data ->> 'attaquant', g.data ->> 'attaque') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pays_non_belligerant');
  END IF;

  -- Une proposition deja en attente de reponse n'est pas remplacee en silence.
  v_cf := g.data -> 'ceasefire';
  IF v_cf IS NOT NULL AND jsonb_typeof(v_cf) = 'object'
     AND (v_cf ->> 'accepteePar') IS NULL
     AND (v_cf ->> 'refuseePar') IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'proposition_deja_en_attente',
                              'proposePays', v_cf ->> 'proposePays');
  END IF;

  UPDATE public.guerres
     SET data = g.data || jsonb_build_object('ceasefire', jsonb_build_object(
           'proposePar',  v_moi,
           'proposePays', v_pays,          -- <- ce qui rend le destinataire calculable
           'accepteePar', NULL,
           'refuseePar',  NULL,
           'actifPar',    '{}'::jsonb))
   WHERE id = p_guerre_id;

  RETURN jsonb_build_object('ok', true, 'proposePar', v_moi, 'proposePays', v_pays,
    'destinataire', CASE WHEN v_pays = (g.data ->> 'attaquant')
                         THEN g.data ->> 'attaque' ELSE g.data ->> 'attaquant' END);
END;
$$;

-- 2. REPONDRE — le MAE du pays DESTINATAIRE, et lui seul.
CREATE OR REPLACE FUNCTION public.guerre_treve_repondre(p_guerre_id text, p_accepte boolean)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_pays text; v_moi text; g record; v_cf jsonb; v_destinataire text;
BEGIN
  v_pays := public.guerre_acteur_poste('min_ae');
  IF v_pays IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reserve_au_ministre_ae');
  END IF;
  v_moi := public.mon_personnage();

  SELECT * INTO g FROM public.guerres WHERE id = p_guerre_id FOR UPDATE;
  IF NOT FOUND OR g.statut <> 'active' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'guerre_introuvable');
  END IF;

  v_cf := g.data -> 'ceasefire';
  IF v_cf IS NULL OR jsonb_typeof(v_cf) <> 'object' OR (v_cf ->> 'proposePays') IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucune_proposition');
  END IF;
  IF (v_cf ->> 'accepteePar') IS NOT NULL OR (v_cf ->> 'refuseePar') IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'proposition_deja_tranchee');
  END IF;

  -- LE DESTINATAIRE est l'autre belligerant, jamais celui qui a propose.
  v_destinataire := CASE WHEN (v_cf ->> 'proposePays') = (g.data ->> 'attaquant')
                         THEN g.data ->> 'attaque' ELSE g.data ->> 'attaquant' END;
  IF v_pays IS DISTINCT FROM v_destinataire THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reserve_au_destinataire',
                              'destinataire', v_destinataire);
  END IF;

  IF coalesce(p_accepte, false) THEN
    v_cf := v_cf || jsonb_build_object('accepteePar', v_moi, 'accepteePays', v_pays);
  ELSE
    v_cf := v_cf || jsonb_build_object('refuseePar', v_moi, 'refuseePays', v_pays);
  END IF;

  UPDATE public.guerres SET data = g.data || jsonb_build_object('ceasefire', v_cf)
   WHERE id = p_guerre_id;

  RETURN jsonb_build_object('ok', true, 'accepte', coalesce(p_accepte, false), 'par', v_moi);
END;
$$;

-- 3. ACTIVER — inchange, sauf qu'une treve doit avoir ete ACCEPTEE.
CREATE OR REPLACE FUNCTION public.guerre_cessez_le_feu_activer(p_guerre_id text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_pays text; g record; v_cf jsonb; v_actif jsonb; v_tous boolean;
BEGIN
  v_pays := public.guerre_acteur_poste('min_def');
  IF v_pays IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reserve_au_ministre_defense');
  END IF;

  SELECT * INTO g FROM public.guerres WHERE id = p_guerre_id FOR UPDATE;
  IF NOT FOUND OR g.statut <> 'active' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'guerre_introuvable');
  END IF;
  IF v_pays NOT IN (g.data ->> 'attaquant', g.data ->> 'attaque') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pays_non_belligerant');
  END IF;

  v_cf := g.data -> 'ceasefire';
  IF v_cf IS NULL OR jsonb_typeof(v_cf) <> 'object' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucune_treve_proposee');
  END IF;
  IF (v_cf ->> 'refuseePar') IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'treve_refusee');
  END IF;
  IF (v_cf ->> 'accepteePar') IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'treve_non_acceptee');
  END IF;

  v_actif := coalesce(v_cf -> 'actifPar', '{}'::jsonb) || jsonb_build_object(v_pays, true);
  v_tous  := (v_actif ? (g.data ->> 'attaquant')) AND (v_actif ? (g.data ->> 'attaque'));

  UPDATE public.guerres
     SET statut = CASE WHEN v_tous THEN 'terminee' ELSE 'active' END,
         data   = g.data || jsonb_build_object('ceasefire', v_cf || jsonb_build_object('actifPar', v_actif))
   WHERE id = p_guerre_id;

  RETURN jsonb_build_object('ok', true, 'pays', v_pays, 'terminee', v_tous);
END;
$$;

REVOKE ALL ON FUNCTION public.guerre_treve_repondre(text, boolean) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.guerre_treve_repondre(text, boolean) TO authenticated, service_role;