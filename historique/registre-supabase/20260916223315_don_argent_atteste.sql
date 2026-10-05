-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260916223315
-- Nom original      : don_argent_atteste
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-16 22:33:15 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 041860217ce563a5584175bd59b8d5b2
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
-- LOT 2 — DONS D'ARGENT : FERMETURE D'UNE CREATION MONETAIRE TRIVIALE
-- Audit des frontieres d'autorite, 17 septembre 2026.
--
-- CONSTAT PROUVE (transaction annulee) : la table dons_en_attente portait une politique RLS
-- « allow_all » (role public, ALL, USING true, WITH CHECK true). Un visiteur SANS AUCUN COMPTE a
-- insere INSERT INTO dons_en_attente ('Arnie', 999999999, 'zztest-attaquant-sans-compte', false)
-- et la ligne a ete acceptee. Le client du destinataire (recupererDonsEnAttente) credite ensuite
-- cette somme a sa prochaine connexion : creation monetaire pure, a distance, sur n'importe qui.
-- sbDeposerDon n'etait qu'un sbInsert brut, sans RPC ni preuve que l'expediteur ait ete debite.
--
-- FERMETURE : plus aucune ecriture cliente directe. Les DEUX seuls emetteurs legitimes du depot
-- passent par une RPC SECURITY DEFINER qui atteste l'acteur et realise la contrepartie :
--   1. don_argent_deposer      : don entre joueurs, DEBITE reellement l'expediteur ;
--   2. naturalisation_traiter  : remboursement institutionnel, reserve au Ministre de l'Interieur.

-- -------------------------------------------------------------------------------------
-- 1. DON ENTRE JOUEURS. L'expediteur n'est plus un parametre : c'est le personnage du compte
-- connecte. Le debit passe par helvetia_debiter_fonds_ordinaires, primitive existante (liquide
-- d'abord, complete par la Banque nationale, jamais de debit partiel) -- exactement la regle de
-- depense ordinaire deja appliquee partout ailleurs. Aucun montant, aucun taux n'est invente.
-- IDEMPOTENCE : p_requete rend un double-clic ou un rejeu reseau sans effet (le meme don n'est
-- depose qu'une fois), sur le modele de tracts_donner_joueur.
-- -------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.dons_requetes (
  requete text PRIMARY KEY,
  expediteur text NOT NULL,
  destinataire text NOT NULL,
  montant integer NOT NULL,
  don_id bigint,
  cree_le timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.dons_requetes ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.don_argent_deposer(
  p_requete text, p_destinataire text, p_montant integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $fn$
DECLARE v_moi text; v_deja record; v_id bigint;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  IF COALESCE(btrim(p_requete), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'requete_invalide');
  END IF;
  IF p_montant IS NULL OR p_montant <= 0 OR p_montant > 100000000 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'montant_invalide');
  END IF;
  IF COALESCE(btrim(p_destinataire), '') = '' OR p_destinataire = v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'destinataire_invalide');
  END IF;

  -- Rejeu : meme requete = meme resultat, aucun second debit.
  SELECT * INTO v_deja FROM public.dons_requetes WHERE requete = p_requete;
  IF FOUND THEN
    RETURN jsonb_build_object('ok', true, 'rejeu', true, 'montant', v_deja.montant,
                              'destinataire', v_deja.destinataire);
  END IF;

  PERFORM 1 FROM public.personnages_donnees WHERE name = p_destinataire FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'destinataire_introuvable');
  END IF;

  -- CONTREPARTIE REELLE : sans debit effectif, aucun depot. Fail-closed.
  IF NOT public.helvetia_debiter_fonds_ordinaires(v_moi, p_montant) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants');
  END IF;

  INSERT INTO public.dons_en_attente (destinataire, montant, expediteur, traite)
  VALUES (p_destinataire, p_montant, v_moi, false)
  RETURNING id INTO v_id;

  INSERT INTO public.dons_requetes (requete, expediteur, destinataire, montant, don_id)
  VALUES (p_requete, v_moi, p_destinataire, p_montant, v_id);

  RETURN jsonb_build_object('ok', true, 'don_id', v_id, 'montant', p_montant,
    'expediteur', v_moi, 'destinataire', p_destinataire,
    'arg', (SELECT arg FROM public.personnages_donnees WHERE name = v_moi),
    'liquide', (SELECT liquide FROM public.personnages_donnees WHERE name = v_moi));
END;
$fn$;
REVOKE EXECUTE ON FUNCTION public.don_argent_deposer(text, text, integer) FROM anon, public;
GRANT EXECUTE ON FUNCTION public.don_argent_deposer(text, text, integer) TO authenticated;