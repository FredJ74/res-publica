-- =====================================================================
-- LOT 4.3 — ETATS DE PERSONNAGE ECRITS EN MEMOIRE ET JAMAIS PERSISTES
-- 7 septembre 2026
-- =====================================================================
-- ⚠️  NON EXECUTEE. Fournie pour relecture.
--
-- ORDRE DE DEPLOIEMENT IMPERATIF : ce fichier D'ABORD, le code ENSUITE.
-- Tant que la colonne n'existe pas, le PATCH de sbSavePersonnage echouerait sur cette cle.
--
-- CE QUE CE FICHIER AJOUTE : deux colonnes sur personnages, meme classe de defaut.
--   requisition       convocation militaire
--   demandeur_emploi  inscription au Bureau National de l'Emploi
--
-- ---------------------------------------------------------------------
-- LE DEFAUT QU'IL CORRIGE
-- ---------------------------------------------------------------------
-- La requisition civile ecrit deja section.civilsRequisitionnes dans compagnies_militaires, ET
-- tente d'ecrire personnages.requisition -- mais cette colonne N'EXISTE PAS, et ni sbSavePersonnage
-- ni sbLoadPersonnage ne la mappaient. Consequence constatee a l'audit du 7 septembre 2026 :
-- state.char.requisition valait TOUJOURS undefined, alors que doSePresenterAffectation et
-- estExempteCouvreFeu la lisent. UN CIVIL CONVOQUE NE POUVAIT DONC JAMAIS SE PRESENTER.
--
-- Le correctif est en trois morceaux, et celui-ci est le premier : la colonne. Les deux autres sont
-- le mapping en ecriture et en lecture (supabase.js), deja poses.
--
-- FORME : jsonb, meme idiome que est_emprisonne. { compagnieId, sectionId, deadline, statut }
-- ou statut ∈ { 'convoque', 'affecte', 'deserteur' } -- les trois statuts deja poses par le code
-- existant (confirmerRequisitionCivile, doSePresenterAffectation, verifierDesertionsQuotidien).
-- Aucun statut nouveau n'est introduit ici.
--
-- NULL = aucune convocation en cours. C'est l'etat de l'immense majorite des personnages, d'ou le
-- defaut a NULL plutot qu'un objet vide : on ne cree pas une convocation en creant un personnage.
ALTER TABLE personnages ADD COLUMN IF NOT EXISTS requisition jsonb;

-- ---------------------------------------------------------------------
-- SECONDE COLONNE — INSCRIPTION AU BUREAU NATIONAL DE L'EMPLOI
-- ---------------------------------------------------------------------
-- AJOUTEE A CE FICHIER APRES COUP, et voici pourquoi : c'est exactement le meme defaut, sur la meme
-- table. doInscrireDemandeurEmploi ecrivait state.demandeurEmploi -- sur state, pas sur state.char --
-- si bien que l'inscription n'etait ni sauvegardee ni relue : le PA depense etait perdu a chaque
-- rechargement. Livrer deux migrations d'une colonne chacune sur personnages serait un cout de
-- deploiement inutile.
--
-- boolean et non jsonb : l'inscription est un fait binaire, sans structure. NOT NULL DEFAULT false
-- parce que l'immense majorite des personnages ne sont pas demandeurs d'emploi, et qu'un booleen
-- nul n'aurait aucun sens metier distinct de false.
--
-- CE QUE CETTE COLONNE N'EST PAS : un moteur de candidatures. Le BNE reste ce qu'il est -- un
-- catalogue ferme de sept metiers avec prise de poste immediate. On repare une persistance, on
-- n'ouvre pas le chantier professions.
ALTER TABLE personnages ADD COLUMN IF NOT EXISTS demandeur_emploi boolean NOT NULL DEFAULT false;

-- Retrouver les convoques et les deserteurs d'un pays sans balayer toute la table. Index partiel :
-- il ne porte que sur les lignes reellement concernees, donc quasi vide hors periode de
-- mobilisation -- et gratuit le reste du temps.
CREATE INDEX IF NOT EXISTS personnages_requisition_idx
  ON personnages ((requisition ->> 'statut'))
  WHERE requisition IS NOT NULL;

-- CONTROLE POSTERIEUR — attendu : 2 colonnes, 1 index.
SELECT 'colonne' AS objet, column_name AS nom, data_type AS detail
  FROM information_schema.columns
 WHERE table_name = 'personnages' AND column_name IN ('requisition', 'demandeur_emploi')
UNION ALL
SELECT 'index', indexname, ''
  FROM pg_indexes
 WHERE tablename = 'personnages' AND indexname = 'personnages_requisition_idx'
ORDER BY objet, nom;
