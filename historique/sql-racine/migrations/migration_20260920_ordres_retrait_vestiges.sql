-- =============================================================================
-- RETRAIT DE ONZE ORDRES D'ORGANISATION DU MIROIR DES COUTS
-- =============================================================================
-- Date d'application en production : 20 septembre 2026.
--
-- CE FICHIER EST UN RATTRAPAGE DE VERSIONNEMENT. Il reproduit l'ETAT FINAL
-- present en production, pas l'historique de la session.
--
-- MIGRATIONS DE PRODUCTION ABSORBEES :
--   20260920120719  retrait_ordres_criminels_vestiges
--       3 ordres : orga_racket, orga_contrebande, orga_blanchiment.
--   20260920144843  retrait_huit_ordres_orga_arbitres
--       8 ordres : orga_financer_cand, orga_torpiller, orga_coalition,
--       orga_contrat, orga_fusion, orga_coup_force, orga_kompromat_loge,
--       orga_election_loge.
--
-- NATURE DE public.ordres_couts : c'est le MIROIR SERVEUR des couts d'ordres,
-- normalement REGENERE depuis data.js. Les deux enonces ci-dessous sont donc des
-- reparations ponctuelles de donnees, pas du schema. Si le miroir est un jour
-- regenere integralement depuis data.js, ce fichier devient sans effet -- et
-- c'est le resultat attendu, puisque les onze ordres ont aussi disparu de data.js.
--
-- DEPENDANCE A SIGNALER, IMPORTANTE :
--   La contrepartie CLIENT de ces deux arbitrages vit dans data.js, qui fait
--   partie des 13 fichiers NON COMMITES du depot. Ce fichier de migration ne
--   suffit donc pas a lui seul a decrire l'arbitrage du 20 septembre : tant que
--   data.js n'est pas commite, la moitie visible du chantier (retrait des ordres,
--   nettoyage de calculerBonusOrga, des paliers de revenus_passifs, du vote_bonus
--   « coalitions electorales », des deux cycleElection et des trois rangs minimums
--   devenus orphelins) n'existe que sur le poste de travail et en production
--   deployee, pas dans l'historique Git.
--
-- INCOHERENCE ASSUMEE ENTRE LES DEUX MIGRATIONS, conservee telle quelle :
--   le commentaire d'origine du 120719 annonce que orga_coup_force RESTE
--   volontairement. Cinq heures plus tard, le 144843 l'a supprime. Le second
--   arbitrage prime ; les deux textes sont reproduits sans etre harmonises.
--
-- ETAT FINAL VERIFIE EN PRODUCTION : aucune des onze valeurs de `fn` n'est plus
-- presente dans public.ordres_couts. orga_intimidation, lui, y figure toujours
-- (cf. le constat du 120719 ci-dessous).
--
-- PREREQUIS : public.ordres_couts doit exister (cf. migration_passe3_autorite.sql
-- et le chantier C, 20260913182154 chantier_c_miroir_complet_et_fail_closed).

-- -----------------------------------------------------------------------------
-- REPARATION PONCTUELLE DES DONNEES DU 20 SEPTEMBRE — 1/2
-- Migration 20260920120719, recopiee VERBATIM.
-- -----------------------------------------------------------------------------

-- ARBITRAGE GD DU 20 SEPTEMBRE 2026 : orga_racket, orga_contrebande et
-- orga_blanchiment sont des vestiges, supprimes sans mecanique de remplacement.
--
-- Le miroir des couts doit suivre data.js : un ordre qui n'existe plus ne doit
-- plus etre facturable. Laisser ces lignes rendrait payer_ordre complice d'un
-- ordre disparu -- et masquerait, dans un futur audit, le fait que le client ne
-- peut plus le declencher.
--
-- Ce qui RESTE volontairement : orga_intimidation et orga_coup_force, qui
-- appartiennent au meme type d'organisation mais ne font pas partie de
-- l'arbitrage. (Constat au passage, non corrige ici : ces deux-la sont declares
-- dans data.js et dans ce miroir, mais n'ont AUCUN effet implemente cote client
-- -- ils sont factures puis ne font rien. A traiter dans la section metier des
-- organisations, pas ici.)

DELETE FROM public.ordres_couts
 WHERE fn IN ('orga_racket', 'orga_contrebande', 'orga_blanchiment');

-- -----------------------------------------------------------------------------
-- REPARATION PONCTUELLE DES DONNEES DU 20 SEPTEMBRE — 2/2
-- Migration 20260920144843, recopiee VERBATIM.
-- -----------------------------------------------------------------------------

-- ARBITRAGE GD DU 20 SEPTEMBRE 2026 : HUIT ORDRES D'ORGANISATION SUPPRIMES
-- ---------------------------------------------------------------------------
-- Le miroir des couts doit suivre data.js : un ordre qui n'existe plus ne doit
-- plus etre facturable. Laisser ces lignes rendrait payer_ordre complice d'un
-- ordre disparu, et masquerait dans un futur audit le fait que le client ne
-- peut plus le declencher.
--
--   orga_financer_cand  -- le financement d'un candidat passe par les transferts
--                          reels d'argent et les vrais outils de campagne
--   orga_torpiller      -- doublon abstrait des moyens de campagne negative
--   orga_coalition      -- une coalition est un accord entre joueurs, pas un
--                          objet informatique donnant un bonus electoral
--   orga_contrat        -- pas de monopole ni de revenu passif cree par un statut
--   orga_fusion         -- l'ordre disparait ; une fusion volontaire se fera avec
--                          les mecaniques reelles (transferts, dissolution)
--   orga_coup_force     -- la violence passe par les vrais moteurs de combat
--   orga_kompromat_loge -- les loges exploitent les vrais systemes d'information
--   orga_election_loge  -- le moteur d'elections internes generique l'a remplace
--
-- VESTIGES NETTOYES EN MEME TEMPS dans data.js, apres verification qu'aucun
-- n'etait lu (calculerBonusOrga n'est consomme que pour `dis` et `nego_cha`,
-- verifie sur ses deux seuls appelants) :
--   bonus finance_campagne ; les 4 paliers de revenus_passifs ; le vote_bonus
--   « coalitions electorales » ; les deux cycleElection ; et les trois rangs
--   minimums devenus orphelins.

DELETE FROM public.ordres_couts
 WHERE fn IN ('orga_financer_cand', 'orga_torpiller', 'orga_coalition', 'orga_contrat',
              'orga_fusion', 'orga_coup_force', 'orga_kompromat_loge', 'orga_election_loge');
