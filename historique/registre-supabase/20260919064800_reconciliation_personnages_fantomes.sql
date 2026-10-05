-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260919064800
-- Nom original      : reconciliation_personnages_fantomes
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-19 06:48:00 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : d1781208bd0963c43827c7d96bb962b2
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
-- =========================================================================================
-- RECONCILIATION D'UN PERSONNAGE FANTOME (19 septembre 2026)
-- =========================================================================================
-- CONSTAT. La beta n'utilise que l'identite Supabase ANONYME : les 333 comptes existants n'ont
-- aucune adresse e-mail. Aucune table ne relie un personnage disparu a un compte -- seule
-- personnages_donnees.user_id porte un uid, et un fantome n'a precisement plus de ligne.
-- last_sign_in_at ne sert a rien non plus : il n'est ecrit qu'a la creation du jeton, pas a
-- chaque requete, donc une session longue ne le rafraichit jamais.
--
-- Il est donc IMPOSSIBLE de deduire l'uid d'un joueur fantome des donnees serveur existantes.
-- Ce registre est le moyen minimal pour qu'il nous le fournisse LUI-MEME, sans console, sans
-- manipulation, sans adresse e-mail : il lui suffit de recharger le jeu. Le bandeau « personnage
-- introuvable » qui s'affiche alors declare son uid et une EMPREINTE de son personnage local.
--
-- L'EMPREINTE N'EST PAS UN PSEUDO. Elle porte les champs fixes a la creation et jamais modifies
-- ensuite -- archetype, carriere, origine, ecole, les six caracteristiques. Un imposteur qui
-- taperait le bon nom devrait en plus deviner cette combinaison. C'est elle qu'on compare a la
-- sauvegarde avant toute restauration, jamais le nom seul.
CREATE TABLE IF NOT EXISTS public.reconciliation_fantomes (
  user_id    uuid PRIMARY KEY,
  nom_local  text NOT NULL,
  empreinte  jsonb NOT NULL,
  vu_le      timestamptz NOT NULL DEFAULT now(),
  traite     boolean NOT NULL DEFAULT false
);
ALTER TABLE public.reconciliation_fantomes ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.reconciliation_fantomes FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.personnage_fantome_declarer(p_nom text, p_empreinte jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_uid uuid; v_nom text;
BEGIN
  v_uid := auth.uid();
  IF v_uid IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'non_authentifie'); END IF;
  v_nom := btrim(coalesce(p_nom, ''));
  IF v_nom = '' OR length(v_nom) > 80 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'nom_invalide');
  END IF;

  -- Ce compte a deja un personnage : ce n'est pas un fantome, rien a reconcilier.
  IF EXISTS (SELECT 1 FROM public.personnages_donnees WHERE user_id = v_uid) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'compte_deja_pourvu');
  END IF;
  -- Le nom reclame appartient a un personnage VIVANT : on n'enregistre pas une revendication
  -- sur l'identite de quelqu'un d'autre.
  IF EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = v_nom) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'nom_deja_pris');
  END IF;

  INSERT INTO public.reconciliation_fantomes (user_id, nom_local, empreinte, vu_le)
  VALUES (v_uid, v_nom, coalesce(p_empreinte, '{}'::jsonb), now())
  ON CONFLICT (user_id) DO UPDATE
    SET nom_local = EXCLUDED.nom_local, empreinte = EXCLUDED.empreinte, vu_le = now();

  RETURN jsonb_build_object('ok', true, 'enregistre', v_nom);
END;
$$;

REVOKE ALL ON FUNCTION public.personnage_fantome_declarer(text, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.personnage_fantome_declarer(text, jsonb) TO authenticated;