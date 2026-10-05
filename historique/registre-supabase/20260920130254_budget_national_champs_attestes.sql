-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260920130254
-- Nom original      : budget_national_champs_attestes
-- Categorie         : MIXTE -- MIXTE (structure ET mutation de donnees)
-- Date (deduite de la version) : 2026-09-20 13:02:54 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 55d1af7685b58d8e428fb065b1764622
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
-- §6.3 — LE BUDGET NATIONAL, CHAMP PAR CHAMP
-- ---------------------------------------------------------------------------
-- EXPLOIT MESURE : un joueur ordinaire pouvait reecrire la ligne entiere de
-- budgets_nationaux (UPDATE reussi sous veritable role authenticated).
--
-- POURQUOI PAS UNE POLITIQUE RLS. 21 sites clients ecrivent cette ligne, sous
-- des autorites TRES differentes, et chacun reecrit le BLOB ENTIER (lecture
-- puis reecriture). Une politique raisonne par ligne : elle ne pourrait
-- qu'autoriser ou interdire tout le blob, donc casserait 20 flux pour en
-- proteger un. Le bon outil est le TRIGGER D'ATTESTATION deja employe sur la
-- fiche du personnage : on n'interdit pas l'ecriture, on EPINGLE les champs que
-- l'auteur n'a pas le droit de changer.
--
-- L'AUTORITE N'EST PAS DEDUITE DE L'ECRAN. Aucune des 21 fonctions ne porte de
-- garde de poste : l'autorite ne vient aujourd'hui que du bureau ministeriel qui
-- heberge le bouton, ce qui n'est pas une autorisation. La source retenue est la
-- DECLARATION du jeu lui-meme : `requiresPost` sur l'ordre qui mene a chaque
-- ecriture, remontee ordre par ordre (data.js -> plateau-router.js -> modale ->
-- fonction de confirmation -> champ).
--
-- CE LOT NE TRAITE QUE LES CORRESPONDANCES NON AMBIGUES. Quatre champs sont
-- volontairement laisses ouverts et signales au rapport :
--   * repartition   : l'ordre 'fiscal' n'est PAS declare dans data.js -> aucun
--                     requiresPost a invoquer ;
--   * tauxNational  : idem pour 'fixer_impots_nationaux' ;
--   * reserveJour   : ecrit par appliquerTaxeTransaction, qui se declenche pour
--                     TOUT joueur faisant une transaction taxee. C'est la
--                     migration de la taxation, un lot a part entiere deja
--                     identifie comme tel dans le code ;
--   * stockArmurerieMilitaire : le site repere n'est qu'une initialisation en
--                     memoire, non persistee -- les vrais producteurs sont
--                     ailleurs et restent a inventorier.
-- On ne verrouille pas ce qu'on n'a pas compris.

CREATE TABLE IF NOT EXISTS public.budget_national_champs_regles (
  champ      text PRIMARY KEY,
  poste_id   text NOT NULL,
  ordre_fn   text,
  note       text
);
ALTER TABLE public.budget_national_champs_regles ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.budget_national_champs_regles FROM anon, authenticated, public;

INSERT INTO public.budget_national_champs_regles (champ, poste_id, ordre_fn, note) VALUES
  ('couvreFeu',                   'min_int',    'gerer_couvre_feu',
   'Instaurer un couvre-feu — requiresPost declare sur l''ordre'),
  ('mobilisationNationaleActive', 'min_def',    'mobilisation_nationale',
   'Mobilisation nationale — requiresPost declare (pose par confirmerMobilisation, leve par doDemobiliser)'),
  ('preemption',                  'min_fin',    'preempter_entreprise',
   'Droit de preemption sur une entreprise — requiresPost declare'),
  ('virementJournalierQHS',       'min_just',   'gestion_qhs',
   'Gestion du QHS — requiresPost declare'),
  ('rechercheMilitaire',          'commandant', 'recherche_militaire',
   'Lancer une recherche sur l''armement — requiresPost declare'),
  ('coefficientsArmesAcquis',     'commandant', 'recherche_militaire',
   'Resultat de la meme recherche : meme autorite que le champ qui la porte')
ON CONFLICT (champ) DO UPDATE
  SET poste_id = EXCLUDED.poste_id, ordre_fn = EXCLUDED.ordre_fn, note = EXCLUDED.note;

CREATE OR REPLACE FUNCTION public.budget_national_epingler()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_poste text;
  r record;
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

  FOR r IN SELECT * FROM public.budget_national_champs_regles LOOP
    IF (NEW.data -> r.champ) IS DISTINCT FROM (OLD.data -> r.champ)
       AND coalesce(v_poste, '') <> r.poste_id THEN
      -- L'auteur ne detient pas le poste declare : on restaure la valeur.
      IF (OLD.data ? r.champ) THEN
        NEW.data := jsonb_set(NEW.data, ARRAY[r.champ], OLD.data -> r.champ);
      ELSE
        NEW.data := NEW.data - r.champ;
      END IF;
    END IF;
  END LOOP;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_budget_national_epingler ON public.budgets_nationaux;
CREATE TRIGGER trg_budget_national_epingler
  BEFORE UPDATE ON public.budgets_nationaux
  FOR EACH ROW EXECUTE FUNCTION public.budget_national_epingler();