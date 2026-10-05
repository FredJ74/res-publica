-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260920132026
-- Nom original      : budget_national_min_fin
-- Categorie         : DML -- DML seul (mutation de donnees)
-- Date (deduite de la version) : 2026-09-20 13:20:26 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 6c9ecfc9c860265cabc73d02a661abfa
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
-- §6.3 — VERROUILLAGE DES DEUX CHAMPS DU MINISTRE DES FINANCES
-- ---------------------------------------------------------------------------
-- ARBITRAGE GD : `repartition` et `tauxNational` relevent du Ministre des
-- Finances -- il collecte et repartit les ressources nationales, et il fixe la
-- fiscalite nationale.
--
-- CORRECTION D'UN CONSTAT QUE J'AVAIS RENDU. Au lot precedent, j'avais isole ces
-- deux champs en ecrivant que leur ordre n'etait pas declare dans data.js.
-- C'etait une erreur de ma part : j'avais suivi les routes 'fiscal',
-- 'gestion_budget' et 'fixer_impots_nationaux', qui sont ORPHELINES -- aucun
-- bouton du jeu ne les emet. Le vrai point d'entree est l'ordre
-- `pilotage_fiscal_budgetaire`, declare dans data.js avec
-- requiresPost:'min_fin', qui ouvre le panneau « Fiscalite et budget ». Ce
-- panneau porte d'ailleurs une garde explicite (state.poste?.id !== 'min_fin')
-- et son commentaire precise que « leurs handlers ne controlent que min_fin ».
--
-- L'autorite etait donc DEJA declaree canoniquement cote client, et l'arbitrage
-- la confirme. Aucune declaration a ajouter dans data.js : on aligne seulement
-- le serveur sur ce que le jeu dit deja.
--
-- CE QUI N'EST PAS FAIT ICI, VOLONTAIREMENT :
--   * reserveJour -- alimente par la taxation, donc par l'action de TOUT joueur
--     faisant un achat taxe. Il ne recoit aucun droit d'ecriture joueur pour
--     preserver le comportement actuel : il deviendra serveur-autoritaire avec
--     le flux fiscal. Son role exact est en cours d'inventaire.
--   * stockArmurerieMilitaire -- producteurs reels non encore etablis. On ne
--     deduit pas son autorite de son nom.

INSERT INTO public.budget_national_champs_regles (champ, poste_id, ordre_fn, note) VALUES
  ('repartition',  'min_fin', 'pilotage_fiscal_budgetaire',
   'Repartition du budget national entre les institutions — arbitrage GD du 20/09/2026, requiresPost declare sur l''ordre'),
  ('tauxNational', 'min_fin', 'pilotage_fiscal_budgetaire',
   'Taux d''imposition national — arbitrage GD du 20/09/2026, requiresPost declare sur l''ordre')
ON CONFLICT (champ) DO UPDATE
  SET poste_id = EXCLUDED.poste_id, ordre_fn = EXCLUDED.ordre_fn, note = EXCLUDED.note;