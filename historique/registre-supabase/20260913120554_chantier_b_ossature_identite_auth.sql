-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260913120554
-- Nom original      : chantier_b_ossature_identite_auth
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-13 12:05:54 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 5a2b205de0e57ee4318898eab51d33bd
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
-- ============================================================================
-- CHANTIER B / PHASE 3 — OSSATURE DU LIEN auth.users <-> personnage
-- 14 septembre 2026. INERTE A CE STADE : rien n'est ferme, aucune policy n'est
-- modifiee, aucun comportement de jeu ne change. Cette migration ne fait que
-- rendre le lien EXPRIMABLE, pour que la suite du chantier puisse s'y adosser.
-- ============================================================================
-- LE DEFAUT QU'ELLE PREPARE A CORRIGER. L'identite metier du jeu est aujourd'hui
-- le NOM du personnage, fourni librement par le client : creation.js charge
-- n'importe quel personnage sur simple saisie de son nom, et 52 RPC exposees a
-- anon prennent l'acteur en parametre texte (p_personnage, p_joueur, p_nom...).
-- Rien, nulle part, ne verifie que l'appelant EST celui qu'il declare etre.

-- 1) Le lien lui-meme. Nullable pour l'instant : aucune ligne existante n'a de
--    proprietaire demontrable, et on ne lie jamais un compte au hasard.
ALTER TABLE public.personnages
  ADD COLUMN IF NOT EXISTS user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL;

-- Un compte ne peut posseder qu'un personnage. Index PARTIEL : les lignes non
-- encore rattachees (user_id NULL) ne se genent pas entre elles.
CREATE UNIQUE INDEX IF NOT EXISTS personnages_user_id_unique
  ON public.personnages (user_id) WHERE user_id IS NOT NULL;

COMMENT ON COLUMN public.personnages.user_id IS
  'Compte auth.users proprietaire de ce personnage. NULL = personnage non rattache (heritage pre-authentification).';

-- 2) L'appelant est-il le serveur ? service_role traverse tout : cron, endpoints
--    /api/*, RPC systeme. Le cas "pas de JWT du tout" (psql, migrations) compte
--    aussi comme serveur.
CREATE OR REPLACE FUNCTION public.est_appel_serveur()
RETURNS boolean
LANGUAGE sql STABLE
SET search_path = public, pg_temp
AS $$
  SELECT coalesce(
    nullif(current_setting('request.jwt.claim.role', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role'),
    'service_role'
  ) = 'service_role';
$$;

-- 3) Le personnage possede par le compte connecte (NULL si aucun).
CREATE OR REPLACE FUNCTION public.mon_personnage()
RETURNS text
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT p.name FROM public.personnages p
  WHERE p.user_id IS NOT NULL AND p.user_id = auth.uid()
  LIMIT 1;
$$;

-- 4) Le predicat central. Vrai si l'appelant est le serveur, ou si le nom
--    designe bien le personnage du compte connecte. Destine AUSSI BIEN aux
--    policies RLS qu'aux RPC.
CREATE OR REPLACE FUNCTION public.est_mon_personnage(p_nom text)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT public.est_appel_serveur()
      OR (p_nom IS NOT NULL AND auth.uid() IS NOT NULL
          AND EXISTS (SELECT 1 FROM public.personnages p
                      WHERE p.name = p_nom AND p.user_id = auth.uid()));
$$;

-- 5) LA BRIQUE A POSER EN TETE DES RPC. Une seule ligne par RPC suffira a
--    rendre les 52 fonctions non usurpables : "PERFORM exiger_acteur(p_joueur);".
--    On leve plutot que de rendre false : une RPC qui poursuit silencieusement
--    apres une usurpation serait pire qu'une erreur visible.
CREATE OR REPLACE FUNCTION public.exiger_acteur(p_nom text)
RETURNS void
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.est_mon_personnage(p_nom) THEN
    RAISE EXCEPTION 'acteur_non_authentifie: % n''appartient pas au compte connecte', coalesce(p_nom, '(null)')
      USING ERRCODE = '42501';
  END IF;
END;
$$;

-- Ces quatre fonctions sont evaluees DANS les policies et DANS les RPC, donc par
-- le role appelant : anon et authenticated doivent pouvoir les executer. Elles ne
-- revelent rien (un booleen, ou le nom de son propre personnage).
GRANT EXECUTE ON FUNCTION public.est_appel_serveur() TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.mon_personnage() TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.est_mon_personnage(text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.exiger_acteur(text) TO anon, authenticated;