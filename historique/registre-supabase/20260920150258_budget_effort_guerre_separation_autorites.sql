-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260920150258
-- Nom original      : budget_effort_guerre_separation_autorites
-- Categorie         : MIXTE -- MIXTE (structure ET mutation de donnees)
-- Date (deduite de la version) : 2026-09-20 15:02:58 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 30428482787af90db35f9118b0ee6c2d
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
-- SEPARATION DES AUTORITES SUR budgets_nationaux.data.effortGuerre
-- ---------------------------------------------------------------------------
-- Arbitrage GD du 20 septembre 2026 : l'Effort national porte DEUX responsabilites
-- distinctes dans un seul objet JSON.
--   President          = decision politique : declencher l'Effort, le renouveler, y mettre fin.
--   Ministre de la Defense = pilotage operationnel : regler les curseurs pendant qu'il est actif.
-- Les deux autorites sont declarees par le jeu lui-meme (requiresPost) :
--   data.js:1973  effort_national        requiresPost:'president'
--   data.js:4610  tableau_effort_guerre  requiresPost:'min_def'
--
-- Le miroir ne savait epingler qu'un champ ENTIER : il aurait fallu attribuer tout
-- l'objet a un seul poste, ce qui aurait casse l'autre. On lui ajoute donc la notion
-- de SOUS-CHAMP, et l'epinglage descend d'un niveau.
--
-- valeur_ouverture : valeur imposee par le serveur a l'OUVERTURE d'un effort, pour que
-- le President ne choisisse pas les reglages operationnels en declenchant. C'est un
-- miroir declare de PRIORITE_MILITAIRE_DEFAUT (plateau-gouvernement.js:902) -- a
-- regenerer si cette constante change, comme les autres miroirs du projet.

ALTER TABLE public.budget_national_champs_regles ADD COLUMN IF NOT EXISTS sous_champ text;
ALTER TABLE public.budget_national_champs_regles ADD COLUMN IF NOT EXISTS valeur_ouverture jsonb;

ALTER TABLE public.budget_national_champs_regles
  DROP CONSTRAINT IF EXISTS budget_national_champs_regles_pkey;
CREATE UNIQUE INDEX IF NOT EXISTS budget_national_champs_regles_cle
  ON public.budget_national_champs_regles (champ, coalesce(sous_champ, ''));

DELETE FROM public.budget_national_champs_regles WHERE champ = 'effortGuerre';

INSERT INTO public.budget_national_champs_regles (champ, sous_champ, poste_id, ordre_fn, valeur_ouverture, note) VALUES
 ('effortGuerre','actif',                     'president','effort_national', NULL, 'Decision politique : ouvrir et clore l''Effort national'),
 ('effortGuerre','debutA',                    'president','effort_national', NULL, 'Horodatage de la decision presidentielle'),
 ('effortGuerre','expireA',                   'president','effort_national', NULL, 'Echeance de la periode de 3 jours : repoussee par le renouvellement presidentiel'),
 ('effortGuerre','finA',                      'president','effort_national', NULL, 'Cloture'),
 ('effortGuerre','par',                       'president','effort_national', NULL, 'Auteur du declenchement'),
 ('effortGuerre','terminePar',                'president','effort_national', NULL, 'Auteur de la cloture'),
 ('effortGuerre','motifFin',                  'president','effort_national', NULL, 'Motif de cloture (decision / echeance)'),
 ('effortGuerre','periodes',                  'president','effort_national', NULL, 'Compteur de periodes : incremente par le renouvellement presidentiel'),
 ('effortGuerre','periodesPreventives',       'president','effort_national', NULL, 'Compteur de prolongations hors guerre : il porte la penalite d''IS'),
 ('effortGuerre','prioriteRavitaillement',    'min_def',  'tableau_effort_guerre', '50'::jsonb, 'Pilotage operationnel : curseur du ministre de la Defense'),
 ('effortGuerre','prioriteProductionMilitaire','min_def', 'tableau_effort_guerre', '50'::jsonb, 'Pilotage operationnel : curseur du ministre de la Defense');

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.budget_national_epingler()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_poste      text;
  r            record;
  v_parent     text;
  v_old_parent jsonb;
  v_new_parent jsonb;
  v_ouverture  boolean;
BEGIN
  IF public.est_appel_serveur() THEN RETURN NEW; END IF;
  IF OLD.data IS NULL OR NEW.data IS NULL THEN RETURN NEW; END IF;

  SELECT (d.poste ->> 'id') INTO v_poste
    FROM public.personnages_donnees d WHERE d.user_id = auth.uid() LIMIT 1;

  -- Les deux marqueurs de journee ne sont plus ecrits que par le cron : les
  -- quatre passes clientes qui les partageaient ont ete retirees le
  -- 20 septembre. Aucun client n'a de raison legitime d'y toucher.
  IF (NEW.data -> 'derniereDistribJour') IS DISTINCT FROM (OLD.data -> 'derniereDistribJour') THEN
    NEW.data := NEW.data || jsonb_build_object('derniereDistribJour', OLD.data -> 'derniereDistribJour');
  END IF;
  IF (NEW.data -> 'dernierVirementCaserneJour') IS DISTINCT FROM (OLD.data -> 'dernierVirementCaserneJour') THEN
    NEW.data := NEW.data || jsonb_build_object('dernierVirementCaserneJour', OLD.data -> 'dernierVirementCaserneJour');
  END IF;

  -- 1. CHAMPS GOUVERNES ENTIEREMENT PAR UN SEUL POSTE (comportement d'origine).
  FOR r IN SELECT * FROM public.budget_national_champs_regles WHERE sous_champ IS NULL LOOP
    IF (NEW.data -> r.champ) IS DISTINCT FROM (OLD.data -> r.champ)
       AND coalesce(v_poste, '') <> r.poste_id THEN
      IF (OLD.data ? r.champ) THEN
        NEW.data := jsonb_set(NEW.data, ARRAY[r.champ], OLD.data -> r.champ);
      ELSE
        NEW.data := NEW.data - r.champ;
      END IF;
    END IF;
  END LOOP;

  -- 2. CHAMPS COMPOSITES : l'autorite descend au SOUS-CHAMP.
  FOR v_parent IN
    SELECT DISTINCT champ FROM public.budget_national_champs_regles WHERE sous_champ IS NOT NULL
  LOOP
    v_old_parent := OLD.data -> v_parent;
    v_new_parent := NEW.data -> v_parent;

    -- L'objet ne se supprime pas et ne se denature pas : « on CLOT, on n'efface pas »
    -- (plateau-gouvernement.js:956). Seul le serveur pourrait le retirer.
    IF v_old_parent IS NOT NULL AND jsonb_typeof(v_old_parent) = 'object'
       AND (v_new_parent IS NULL OR jsonb_typeof(v_new_parent) <> 'object') THEN
      v_new_parent := v_old_parent;
    END IF;
    IF v_new_parent IS NULL OR jsonb_typeof(v_new_parent) <> 'object' THEN CONTINUE; END IF;
    IF v_old_parent IS NULL OR jsonb_typeof(v_old_parent) <> 'object' THEN
      v_old_parent := '{}'::jsonb;
    END IF;

    FOR r IN SELECT * FROM public.budget_national_champs_regles
              WHERE champ = v_parent AND sous_champ IS NOT NULL LOOP
      IF (v_new_parent -> r.sous_champ) IS DISTINCT FROM (v_old_parent -> r.sous_champ)
         AND coalesce(v_poste, '') <> r.poste_id THEN
        IF (v_old_parent ? r.sous_champ) THEN
          v_new_parent := jsonb_set(v_new_parent, ARRAY[r.sous_champ], v_old_parent -> r.sous_champ);
        ELSE
          v_new_parent := v_new_parent - r.sous_champ;
        END IF;
      END IF;
    END LOOP;

    -- L'OUVERTURE est constatee APRES l'arbitrage d'autorite : qui n'a pas pu poser
    -- actif=true n'a rien ouvert, et n'obtient donc pas les reglages d'ouverture.
    v_ouverture := coalesce(v_old_parent ->> 'actif', '') <> 'true'
               AND coalesce(v_new_parent ->> 'actif', '') = 'true';

    -- Un objet cree de toutes pieces sans ouverture legitime ne laisse aucun residu.
    IF NOT (OLD.data ? v_parent) AND NOT v_ouverture THEN
      NEW.data := NEW.data - v_parent;
      CONTINUE;
    END IF;

    -- Le declencheur ne choisit pas les reglages operationnels : le serveur les pose.
    IF v_ouverture THEN
      FOR r IN SELECT * FROM public.budget_national_champs_regles
                WHERE champ = v_parent AND sous_champ IS NOT NULL
                  AND valeur_ouverture IS NOT NULL LOOP
        v_new_parent := jsonb_set(v_new_parent, ARRAY[r.sous_champ], r.valeur_ouverture);
      END LOOP;
    END IF;

    NEW.data := jsonb_set(NEW.data, ARRAY[v_parent], v_new_parent);
  END LOOP;

  RETURN NEW;
END;
$function$;