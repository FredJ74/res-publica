-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260920225514
-- Nom original      : ordres_couts_inspection_mobilisation_recrutement
-- Categorie         : DML -- DML seul (mutation de donnees)
-- Date (deduite de la version) : 2026-09-20 22:55:14 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : bb463e6bddd15a9445ea1e5b1402c613
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
-- MIROIR DES COUTS : trois ordres militaires remis en coherence (21 septembre 2026).
--
-- public.ordres_couts est le miroir declare des couts d'ordre : payer_ordre exige le triplet
-- EXACT (fn, pa, cost), sinon 'cout_non_declare'. Trois ordres militaires etaient donc morts.
--
-- 1. inspecter_troupes : declare (0,0) dans data.js, mais facture REELLEMENT 1 PA (revue) ou
--    2 PA (detaillee) -- les deux niveaux etaient refuses. data.js declare desormais le cout
--    d'entree (1 PA) et NIVEAUX_INSPECTION_TROUPES (plateau-politique.js) le second niveau.
-- 2. mobilisation_nationale : facade gratuite (0,0) conservee -- ouvrir le tableau ne coute
--    rien -- mais ses TROIS sous-actions facturent sous ce meme fn : mobiliser 4 PA,
--    requisition civile 3 PA, demobiliser 2 PA. Aucune des trois n'etait executable.
-- 3. recruter_section : ordre supprime (modele de recompletement a la piece abandonne par le
--    GD le 17 septembre 2026). Plus aucun appelant : declaration, route et handler retires.
--
-- Les cinq couples ajoutes et les deux retires sont EXACTEMENT le delta calcule par
-- .scratch/generer_ordres_couts.py entre le depot avant et apres ce lot : aucun chiffre saisi
-- a la main. Aucune autre ligne du miroir n'est touchee.
DELETE FROM public.ordres_couts WHERE fn = 'inspecter_troupes' AND pa = 0 AND cost = 0;
DELETE FROM public.ordres_couts WHERE fn = 'recruter_section'  AND pa = 2 AND cost = 0;

INSERT INTO public.ordres_couts (fn, pa, cost) VALUES
  ('inspecter_troupes', 1, 0),
  ('inspecter_troupes', 2, 0),
  ('mobilisation_nationale', 4, 0),
  ('mobilisation_nationale', 3, 0),
  ('mobilisation_nationale', 2, 0)
ON CONFLICT (fn, pa, cost) DO NOTHING;

-- Les ecarts deja enregistres pour ces trois ordres portaient precisement sur ces couples :
-- une fois declares, la trace de diagnostic n'a plus de sens.
DELETE FROM public.ordres_couts_ecarts e
 WHERE EXISTS (SELECT 1 FROM public.ordres_couts o
                WHERE o.fn = e.fn AND o.pa = e.pa AND o.cost = e.cost);