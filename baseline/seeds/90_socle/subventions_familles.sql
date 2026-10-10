-- SEED -- subventions_familles
-- ============================================================================
-- Table      : public.subventions_familles
-- Domaine    : finances publiques
-- Categorie  : A (socle generique)
-- Strategie  : seed_complet (classification du chantier 2C)
-- Lignes     : 10
--
-- Fichier GENERE par outils/baseline/seeds.py. Ne pas editer a la main.
-- Les litteraux sont ceux que PostgreSQL lui-meme a produits (quote_nullable) :
-- aucune regle d'echappement n'a ete reimplementee.
--
-- JUSTIFICATION DU SEED (chantier 2C)
-- QUI PEUT RECEVOIR une subvention municipale, par FAMILLE d'organisation.
-- Registre d'autorite du meme genre que caisses_autorites ou
-- actes_nocturnes_mecanismes : aucune fonction ne l'ecrit, chaque entree est
-- une migration. RLS active et AUCUNE policy -- un navigateur ne lit pas
-- cette table et ne peut donc pas inventer une eligibilite. Dix familles au
-- 10 octobre 2026 : club_football (eligible), criminelle (refusee par
-- arbitrage explicite) et les huit autres familles d'organisation portant le
-- motif litteral NON ARBITRE. Un trigger refuse de declarer eligible une
-- famille que subvention_familles_resolues() ne sait pas traiter : on ne
-- peut pas declarer sans implementer. Compte RELEVE EN BASE.
--
-- ARBITRAGE DE GAME DESIGN
-- SEED INDISPENSABLE : sans ses lignes, subvention_proposer refuse tout
-- beneficiaire pour famille_inconnue et la mecanique entiere est inerte. Le
-- contenu du registre fait partie du socle d'un monde neuf. ARBITRE LE 10
-- OCTOBRE 2026 pour deux familles seulement -- les huit autres attendent, et
-- leur attente est ECRITE plutot que devinee.
-- ============================================================================

INSERT INTO public.subventions_familles (famille, libelle, registre, eligible, arbitrage, note) VALUES ('club_football', 'Club de football du championnat', 'club_football', 'true', 'ARBITRE LE 10 OCTOBRE 2026 : eligible. Une commune peut subventionner les clubs sportifs de son territoire -- c''est volontairement un levier politique important.', 'Entite dans clubs_football (miroir genere), caisse dans budgets_clubs.data.caisse, gestionnaire dans presidents_clubs.data.president.');
INSERT INTO public.subventions_familles (famille, libelle, registre, eligible, arbitrage, note) VALUES ('criminelle', 'Organisation Criminelle', 'organisation', 'false', 'ARBITRE LE 10 OCTOBRE 2026 : NON eligible. Refus explicite, pas un oubli.', 'Aucun resolveur n''est ecrit, et il n''y a aucune raison d''en ecrire un.');
INSERT INTO public.subventions_familles (famille, libelle, registre, eligible, arbitrage, note) VALUES ('economique', 'Organisation Economique', 'organisation', 'false', 'NON ARBITRE', NULL);
INSERT INTO public.subventions_familles (famille, libelle, registre, eligible, arbitrage, note) VALUES ('loge', 'Loge Maconnique', 'organisation', 'false', 'NON ARBITRE', NULL);
INSERT INTO public.subventions_familles (famille, libelle, registre, eligible, arbitrage, note) VALUES ('mediatique', 'Organisation Mediatique', 'organisation', 'false', 'NON ARBITRE', NULL);
INSERT INTO public.subventions_familles (famille, libelle, registre, eligible, arbitrage, note) VALUES ('politique', 'Organisation Politique', 'organisation', 'false', 'NON ARBITRE', NULL);
INSERT INTO public.subventions_familles (famille, libelle, registre, eligible, arbitrage, note) VALUES ('religieuse', 'Organisation Religieuse', 'organisation', 'false', 'NON ARBITRE', NULL);
INSERT INTO public.subventions_familles (famille, libelle, registre, eligible, arbitrage, note) VALUES ('sportive', 'Club Sportif', 'organisation', 'false', 'NON ARBITRE', 'ATTENTION : cette famille d''organisation n''est PAS un club du championnat, malgre son label. Le club du championnat est la famille club_football, registre clubs_football.');
INSERT INTO public.subventions_familles (famille, libelle, registre, eligible, arbitrage, note) VALUES ('supporters', 'Club de Supporters', 'organisation', 'false', 'NON ARBITRE', NULL);
INSERT INTO public.subventions_familles (famille, libelle, registre, eligible, arbitrage, note) VALUES ('syndicale', 'Organisation Syndicale', 'organisation', 'false', 'NON ARBITRE', NULL);
