-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260924221220
-- Nom original      : securite_demandes_grace
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-24 22:12:20 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 1225e39fc6270fff1c2b8346ca9b8f1e
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
-- La grace est un acte a deux mains, et le jeu le dit lui-meme : data.js declare
--   {fn:'proposer_grace', requiresPost:'min_just'}  et  {fn:'gracier', requiresPost:'president'}.
-- La table, elle, etait ouverte a tout le monde, sans compte : lire les recommandations, en
-- fabriquer au nom du Ministre de la Justice, ou gracier a la place du President.
--
-- Helper reutilisable : « j'occupe ce poste, atteste ». Meme source d'autorite que
-- affaire_autorite_de() -- la colonne poste de personnages_donnees, tenue par le trigger
-- d'attestation, jamais une declaration du client.
CREATE OR REPLACE FUNCTION public.mon_poste_est(p_poste text)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.personnages_donnees d
     WHERE d.user_id = auth.uid()
       AND (d.poste ->> 'id') = p_poste
  );
$$;

-- Meme chose, mais bornee au pays de l'affaire : un President de Republia n'a rien a voir dans
-- les graces d'Helvetia.
CREATE OR REPLACE FUNCTION public.mon_poste_est_dans(p_poste text, p_pays text)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.personnages_donnees d
     WHERE d.user_id = auth.uid()
       AND (d.poste ->> 'id') = p_poste
       AND (p_pays IS NULL OR d.country = p_pays)
  );
$$;

ALTER TABLE public.demandes_grace ENABLE ROW LEVEL SECURITY;

-- Lecture : le President qui doit trancher, le Ministre qui a recommande. Personne d'autre.
CREATE POLICY "grace lue par le president et le proposant" ON public.demandes_grace
  FOR SELECT TO authenticated
  USING (public.mon_poste_est_dans('president', data ->> 'pays')
         OR (data ->> 'proposePar') = (SELECT public.mon_personnage()));

-- Recommander : le Ministre de la Justice, en son propre nom.
CREATE POLICY "grace proposee par le ministre de la justice" ON public.demandes_grace
  FOR INSERT TO authenticated
  WITH CHECK (public.mon_poste_est_dans('min_just', data ->> 'pays')
              AND (data ->> 'proposePar') = (SELECT public.mon_personnage()));

-- Accorder ou refuser : le President, et lui seul.
CREATE POLICY "grace tranchee par le president" ON public.demandes_grace
  FOR UPDATE TO authenticated
  USING (public.mon_poste_est_dans('president', data ->> 'pays'))
  WITH CHECK (public.mon_poste_est_dans('president', data ->> 'pays'));

-- Aucune policy DELETE : le jeu ne supprime jamais une demande, il en change le statut.

REVOKE ALL ON public.demandes_grace FROM anon;