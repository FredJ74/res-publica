-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260916223338
-- Nom original      : naturalisation_traiter_atteste
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-16 22:33:38 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 6ccf72f5d163c211e53097a3fa3d46a4
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
-- LOT 2 (suite) — REMBOURSEMENT DE NATURALISATION, SEUL AUTRE EMETTEUR LEGITIME D'UN DON.
-- Avant : le client du Ministre appelait sbDeposerDon('<demandeur>', floor(montant*0.5),
-- 'Service de l'Immigration') -- un INSERT brut, sans autorite ni montant attestes.
-- Ici, RIEN du game design ne change : meme autorite (data.js declare deja
-- requiresPost:'min_int' sur l'ordre « Demandes de naturalisation »), meme taux (50 %), meme
-- delai de 48 h (date_traitement_possible, deja porte par la ligne). Tout est desormais RELU
-- cote serveur au lieu d'etre fourni par le navigateur.
-- IDEMPOTENCE : la transition n'est possible que depuis statut='pending', sous verrou de ligne --
-- un double-clic ne peut pas rembourser deux fois.
CREATE OR REPLACE FUNCTION public.naturalisation_traiter(
  p_demande_id text, p_accepter boolean)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $fn$
DECLARE v_acteur text; v_pays text; v_d record; v_rembours integer := 0; v_id bigint;
BEGIN
  -- Autorite : exiger_poste leve si le compte n'est pas le Ministre de l'Interieur en exercice.
  v_acteur := public.exiger_poste('min_int');
  IF v_acteur IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_acteur;

  SELECT * INTO v_d FROM public.demandes_naturalisation
   WHERE id = p_demande_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'demande_introuvable');
  END IF;
  -- Un ministre ne traite que les demandes visant SON pays.
  IF v_d.pays_vise IS DISTINCT FROM v_pays THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'hors_juridiction');
  END IF;
  IF COALESCE(v_d.statut, 'pending') <> 'pending' THEN
    RETURN jsonb_build_object('ok', true, 'rejeu', true, 'statut', v_d.statut);
  END IF;
  -- Delai de 48 h : la ligne porte deja l'echeance, le serveur la fait respecter.
  IF v_d.date_traitement_possible IS NOT NULL
     AND (EXTRACT(epoch FROM now()) * 1000) < v_d.date_traitement_possible THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'delai_non_ecoule');
  END IF;

  IF p_accepter THEN
    UPDATE public.demandes_naturalisation SET statut = 'acceptee' WHERE id = p_demande_id;
    RETURN jsonb_build_object('ok', true, 'statut', 'acceptee', 'demandeur', v_d.demandeur);
  END IF;

  -- REFUS : remboursement de la moitie, montant relu sur la ligne, jamais fourni par le client.
  v_rembours := floor(COALESCE(v_d.montant, 0) * 0.5)::integer;
  UPDATE public.demandes_naturalisation SET statut = 'refusee' WHERE id = p_demande_id;
  IF v_rembours > 0 THEN
    INSERT INTO public.dons_en_attente (destinataire, montant, expediteur, traite)
    VALUES (v_d.demandeur, v_rembours, 'Service de l''Immigration', false)
    RETURNING id INTO v_id;
  END IF;
  RETURN jsonb_build_object('ok', true, 'statut', 'refusee', 'demandeur', v_d.demandeur,
                            'remboursement', v_rembours, 'don_id', v_id);
END;
$fn$;
REVOKE EXECUTE ON FUNCTION public.naturalisation_traiter(text, boolean) FROM anon, public;
GRANT EXECUTE ON FUNCTION public.naturalisation_traiter(text, boolean) TO authenticated;