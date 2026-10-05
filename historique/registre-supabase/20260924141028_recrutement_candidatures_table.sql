-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260924141028
-- Nom original      : recrutement_candidatures_table
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-24 14:10:28 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : fa3dc3d47c9acec3fd1ac05eee68378d
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
CREATE TABLE IF NOT EXISTS public.candidatures_militaires (
  id            text PRIMARY KEY,
  pays          text NOT NULL,
  candidat      text NOT NULL,
  -- TROIS GRADES, PAS QUATRE. Le Commandant de la Caserne n'est PAS ici, et c'est delibere :
  -- c'est un POSTE NOMME, deja candidatable par l'ordre `postuler` du Palais du Gouvernement,
  -- deja facture 2 PA, deja arbitre par le Ministre de la Defense, et deja resolu par tirage au
  -- sort au bout de 48 h si le Ministre ne tranche pas (traiterCandidaturesPostesExpirees,
  -- api/cron-minuit.js). Ce maillon-la fonctionne : postes_attribues porte aujourd'hui
  -- min_def = Arnie avec la source `candidature_autorite_pnj`. Lui ajouter une seconde porte par
  -- la caserne creerait deux chemins concurrents vers la meme fonction -- exactement le systeme
  -- parallele proscrit. La caserne se contente donc d'INDIQUER ce chemin ; elle ne le double pas.
  grade_vise    text NOT NULL CHECK (grade_vise IN ('capitaine','lieutenant','soldat')),
  statut        text NOT NULL DEFAULT 'active'
                  CHECK (statut IN ('active','acceptee','finalisee','retiree','annulee','expiree')),
  -- Noms des recruteurs qui ont ecarte CETTE candidature. Jamais montre au candidat.
  refus         jsonb NOT NULL DEFAULT '[]'::jsonb,
  cree_le       timestamptz NOT NULL DEFAULT now(),
  derniere_relance timestamptz,
  accepte_par   text,
  accepte_le    timestamptz,
  echeance      timestamptz,
  compagnie_id  text,
  section_id    text,
  finalise_le   timestamptz
);

-- UNE SEULE CANDIDATURE VIVANTE PAR GRADE ET PAR PERSONNE : rend le double-clic inoffensif.
CREATE UNIQUE INDEX IF NOT EXISTS candidatures_militaires_une_vivante_par_grade
  ON public.candidatures_militaires (candidat, grade_vise)
  WHERE statut IN ('active','acceptee');

CREATE INDEX IF NOT EXISTS candidatures_militaires_actives
  ON public.candidatures_militaires (pays, grade_vise) WHERE statut = 'active';

COMMENT ON TABLE public.candidatures_militaires IS
  'Candidatures a un grade militaire. Diffusees a tous les recruteurs eligibles ; le premier qui accepte l''emporte. Un refus individuel s''inscrit dans refus et laisse la candidature active.';

ALTER TABLE public.candidatures_militaires ENABLE ROW LEVEL SECURITY;

-- AUCUN ACCES DIRECT DU NAVIGATEUR, PAS MEME EN LECTURE. `refus` est la liste nominative des
-- recruteurs qui ont ecarte le candidat, et `accepte_par`/`compagnie_id`/`section_id` sont toute
-- la scene de decouverte : les exposer viderait la regle et la scene de leur contenu. Les deux
-- cotes sont servis par des RPC qui projettent exactement ce que chacun a le droit de voir.
REVOKE ALL ON public.candidatures_militaires FROM anon, authenticated, PUBLIC;
GRANT ALL ON public.candidatures_militaires TO service_role;