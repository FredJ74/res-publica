-- =============================================================================
-- BUDGET NATIONAL — AUTORITE CHAMP PAR CHAMP, ET SOUS-CHAMP PAR SOUS-CHAMP
-- =============================================================================
-- Date d'application en production : 20 septembre 2026.
--
-- CE FICHIER EST UN RATTRAPAGE DE VERSIONNEMENT. Il reproduit l'ETAT FINAL
-- present en production, pas l'historique de la session. Quatre migrations ont
-- ete appliquees ce jour-la ; la derniere a REMODELE la table et REECRIT la
-- fonction posees par la premiere. Seule la forme finale figure ici.
--
-- MIGRATIONS DE PRODUCTION ABSORBEES :
--   20260920130254  budget_national_champs_attestes
--       cree la table miroir, la fonction budget_national_epingler() et son
--       trigger. Cle primaire sur (champ).
--   20260920132026  budget_national_min_fin
--       ajoute repartition et tauxNational, attribues au Ministre des Finances.
--   20260920145208  budget_regime_exception_serveur
--       ajoute regimeException, epingle au serveur.
--   20260920150258  budget_effort_guerre_separation_autorites
--       ajoute les colonnes sous_champ et valeur_ouverture, SUPPRIME la cle
--       primaire sur (champ) au profit d'un index unique sur
--       (champ, coalesce(sous_champ,'')), et REECRIT budget_national_epingler()
--       avec une seconde boucle pour les champs composites.
--
-- POURQUOI LE REJEU DES QUATRE ETAPES ECHOUERAIT. Les migrations 132026 et
-- 145208 ecrivent leurs lignes avec `ON CONFLICT (champ)`. La migration 150258
-- ayant supprime cette cle, rejouer la journee dans l'ordre leverait
-- « there is no unique or exclusion constraint matching the ON CONFLICT
-- specification ». Ce fichier ecrit donc TOUTES les lignes d'un seul tenant,
-- contre la cle finale.
--
-- -----------------------------------------------------------------------------
-- EXPLOIT A L'ORIGINE DU CHANTIER
-- -----------------------------------------------------------------------------
-- Un joueur ordinaire pouvait reecrire la ligne entiere de budgets_nationaux
-- (UPDATE reussi sous veritable role authenticated).
--
-- POURQUOI PAS UNE POLITIQUE RLS. 21 sites clients ecrivent cette ligne, sous
-- des autorites TRES differentes, et chacun reecrit le BLOB ENTIER (lecture puis
-- reecriture). Une politique raisonne par ligne : elle ne pourrait qu'autoriser
-- ou interdire tout le blob, donc casserait 20 flux pour en proteger un. Le bon
-- outil est le TRIGGER D'ATTESTATION deja employe sur la fiche du personnage :
-- on n'interdit pas l'ecriture, on EPINGLE les champs que l'auteur n'a pas le
-- droit de changer.
--
-- L'AUTORITE N'EST PAS DEDUITE DE L'ECRAN. Aucune des 21 fonctions ne porte de
-- garde de poste : l'autorite ne vient aujourd'hui que du bureau ministeriel qui
-- heberge le bouton, ce qui n'est pas une autorisation. La source retenue est la
-- DECLARATION du jeu lui-meme : `requiresPost` sur l'ordre qui mene a chaque
-- ecriture, remontee ordre par ordre (data.js -> plateau-router.js -> modale ->
-- fonction de confirmation -> champ).
--
-- -----------------------------------------------------------------------------
-- L'EFFORT NATIONAL : DEUX AUTORITES DANS UN SEUL OBJET JSON
-- -----------------------------------------------------------------------------
-- Arbitrage GD du 20 septembre 2026 :
--   President ............... decision politique : declencher l'Effort, le
--                             renouveler, y mettre fin.
--   Ministre de la Defense .. pilotage operationnel : regler les curseurs
--                             pendant qu'il est actif.
-- Les deux autorites sont declarees par le jeu lui-meme (requiresPost) :
--   data.js:1973  effort_national        requiresPost:'president'
--   data.js:4610  tableau_effort_guerre  requiresPost:'min_def'
--
-- Le miroir ne savait epingler qu'un champ ENTIER : il aurait fallu attribuer
-- tout l'objet a un seul poste, ce qui aurait casse l'autre. On lui ajoute donc
-- la notion de SOUS-CHAMP, et l'epinglage descend d'un niveau.
--
-- valeur_ouverture : valeur imposee par le serveur a l'OUVERTURE d'un effort,
-- pour que le President ne choisisse pas les reglages operationnels en
-- declenchant. C'est un miroir declare de PRIORITE_MILITAIRE_DEFAUT
-- (plateau-gouvernement.js:902) -- A REGENERER si cette constante change, comme
-- les autres miroirs du projet.
--
-- -----------------------------------------------------------------------------
-- CHAMPS VOLONTAIREMENT LAISSES OUVERTS
-- -----------------------------------------------------------------------------
--   * reserveJour -- accumulateur fiscal, ecrit par appliquerTaxeTransaction,
--     qui se declenche pour TOUT joueur faisant une transaction taxee. C'est la
--     migration de la taxation, un lot a part entiere.
--   * stockArmurerieMilitaire -- producteurs reels non etablis ; on ne deduit
--     pas son autorite de son nom. Deux triggers ANTERIEURS a ce chantier le
--     protegent deja, ainsi que lotsMilitaires et virementJournalierCaserne,
--     avec la meme doctrine d'epinglage.
-- On ne verrouille pas ce qu'on n'a pas compris.
--
-- NOTE SUR UN CONSTAT CORRIGE EN COURS DE JOURNEE. La migration 130254 laissait
-- `repartition` et `tauxNational` ouverts au motif que leur ordre n'etait pas
-- declare dans data.js. C'etait une erreur : les routes 'fiscal',
-- 'gestion_budget' et 'fixer_impots_nationaux' sont ORPHELINES -- aucun bouton
-- du jeu ne les emet. Le vrai point d'entree est l'ordre
-- `pilotage_fiscal_budgetaire`, declare avec requiresPost:'min_fin'. L'autorite
-- etait donc deja declaree canoniquement cote client. L'etat final ci-dessous
-- l'enregistre.
--
-- -----------------------------------------------------------------------------
-- DEPENDANCES — a rejouer AVANT ce fichier
-- -----------------------------------------------------------------------------
--   * public.est_appel_serveur()   — chantier B (identite et authentification).
--   * public.personnages_donnees   — table de base des fiches.
--   * public.budgets_nationaux     — table portant le trigger.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 1. LE MIROIR D'AUTORITE
-- -----------------------------------------------------------------------------
-- FORME FINALE. La table est nee avec PRIMARY KEY (champ) ; la separation des
-- autorites de l'Effort national l'a remplacee par un index unique sur
-- (champ, coalesce(sous_champ,'')), pour qu'un meme champ puisse porter
-- plusieurs proprietaires -- un par sous-champ.
--
-- sous_champ NULL        = le champ entier appartient a poste_id.
-- sous_champ renseigne   = seule cette cle de l'objet JSON lui appartient.
-- poste_id '(serveur)'   = aucun poste : personne ne peut l'ecrire depuis un
--                          navigateur.

CREATE TABLE IF NOT EXISTS public.budget_national_champs_regles (
  champ            text NOT NULL,
  poste_id         text NOT NULL,
  ordre_fn         text,
  note             text,
  sous_champ       text,
  valeur_ouverture jsonb
);

CREATE UNIQUE INDEX IF NOT EXISTS budget_national_champs_regles_cle
  ON public.budget_national_champs_regles USING btree (champ, COALESCE(sous_champ, ''::text));

ALTER TABLE public.budget_national_champs_regles ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.budget_national_champs_regles FROM anon, authenticated, public;


-- -----------------------------------------------------------------------------
-- 2. LES REGLES — etat final : 20 lignes
-- -----------------------------------------------------------------------------
-- Dont 11 sous-champs de effortGuerre : 9 au President (decision politique) et
-- 2 au Ministre de la Defense (curseurs operationnels, ouverts a 50 par le
-- serveur).

INSERT INTO public.budget_national_champs_regles
  (champ, sous_champ, poste_id, ordre_fn, valeur_ouverture, note) VALUES
  ('coefficientsArmesAcquis', NULL, 'commandant', 'recherche_militaire', NULL, 'Resultat de la meme recherche : meme autorite que le champ qui la porte'),
  ('couvreFeu', NULL, 'min_int', 'gerer_couvre_feu', NULL, 'Instaurer un couvre-feu — requiresPost declare sur l''ordre'),
  ('effortGuerre', 'actif', 'president', 'effort_national', NULL, 'Decision politique : ouvrir et clore l''Effort national'),
  ('effortGuerre', 'debutA', 'president', 'effort_national', NULL, 'Horodatage de la decision presidentielle'),
  ('effortGuerre', 'expireA', 'president', 'effort_national', NULL, 'Echeance de la periode de 3 jours : repoussee par le renouvellement presidentiel'),
  ('effortGuerre', 'finA', 'president', 'effort_national', NULL, 'Cloture'),
  ('effortGuerre', 'motifFin', 'president', 'effort_national', NULL, 'Motif de cloture (decision / echeance)'),
  ('effortGuerre', 'par', 'president', 'effort_national', NULL, 'Auteur du declenchement'),
  ('effortGuerre', 'periodes', 'president', 'effort_national', NULL, 'Compteur de periodes : incremente par le renouvellement presidentiel'),
  ('effortGuerre', 'periodesPreventives', 'president', 'effort_national', NULL, 'Compteur de prolongations hors guerre : il porte la penalite d''IS'),
  ('effortGuerre', 'prioriteProductionMilitaire', 'min_def', 'tableau_effort_guerre', '50', 'Pilotage operationnel : curseur du ministre de la Defense'),
  ('effortGuerre', 'prioriteRavitaillement', 'min_def', 'tableau_effort_guerre', '50', 'Pilotage operationnel : curseur du ministre de la Defense'),
  ('effortGuerre', 'terminePar', 'president', 'effort_national', NULL, 'Auteur de la cloture'),
  ('mobilisationNationaleActive', NULL, 'min_def', 'mobilisation_nationale', NULL, 'Mobilisation nationale — requiresPost declare (pose par confirmerMobilisation, leve par doDemobiliser)'),
  ('preemption', NULL, 'min_fin', 'preempter_entreprise', NULL, 'Droit de preemption sur une entreprise — requiresPost declare'),
  ('rechercheMilitaire', NULL, 'commandant', 'recherche_militaire', NULL, 'Lancer une recherche sur l''armement — requiresPost declare'),
  ('regimeException', NULL, '(serveur)', NULL, NULL, 'Regime d''exception : aucun ecrivain client, seul le cron constate son expiration'),
  ('repartition', NULL, 'min_fin', 'pilotage_fiscal_budgetaire', NULL, 'Repartition du budget national entre les institutions — arbitrage GD du 20/09/2026, requiresPost declare sur l''ordre'),
  ('tauxNational', NULL, 'min_fin', 'pilotage_fiscal_budgetaire', NULL, 'Taux d''imposition national — arbitrage GD du 20/09/2026, requiresPost declare sur l''ordre'),
  ('virementJournalierQHS', NULL, 'min_just', 'gestion_qhs', NULL, 'Gestion du QHS — requiresPost declare')
ON CONFLICT (champ, COALESCE(sous_champ, ''::text)) DO UPDATE
  SET poste_id         = EXCLUDED.poste_id,
      ordre_fn         = EXCLUDED.ordre_fn,
      valeur_ouverture = EXCLUDED.valeur_ouverture,
      note             = EXCLUDED.note;


-- -----------------------------------------------------------------------------
-- 3. LE TRIGGER D'ATTESTATION — version finale
-- -----------------------------------------------------------------------------
-- On n'interdit pas l'ecriture : on epingle les champs que l'auteur n'a pas le
-- droit de changer. Deux boucles -- champs entiers, puis champs composites.

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

DROP TRIGGER IF EXISTS trg_budget_national_epingler ON public.budgets_nationaux;
CREATE TRIGGER trg_budget_national_epingler
  BEFORE UPDATE ON public.budgets_nationaux
  FOR EACH ROW EXECUTE FUNCTION public.budget_national_epingler();
