-- SEED -- pnj_institutions
-- ============================================================================
-- Table      : public.pnj_institutions
-- Domaine    : socle PNJ
-- Categorie  : A (socle generique)
-- Strategie  : seed_complet (classification du chantier 2C)
-- Lignes     : 4
--
-- Fichier GENERE par outils/baseline/seeds.py. Ne pas editer a la main.
-- Les litteraux sont ceux que PostgreSQL lui-meme a produits (quote_nullable) :
-- aucune regle d'echappement n'a ete reimplementee.
--
-- JUSTIFICATION DU SEED (chantier 2C)
-- Registre des institutions proprietaires de PNJ et de leur resolveur
-- d'autorite.
-- ============================================================================

INSERT INTO public.pnj_institutions (institution, resolveur, note) VALUES ('douane', 'douane_autorite_de_perimetre', 'Perimetre = ''<ville>:<batiment>'' du service des douanes. Autorite : le PJ portant le poste chef_douanes dans ce pays. Un titulaire PNJ du poste n''est PAS une autorite.');
INSERT INTO public.pnj_institutions (institution, resolveur, note) VALUES ('militaire', 'militaire_autorite_de_perimetre', 'Perimetre = identifiant de section (autorite : son lieutenantNom) ou <compagnieId>:reserve (aucune autorite : la reserve n''est administree par personne).');
INSERT INTO public.pnj_institutions (institution, resolveur, note) VALUES ('police', 'police_autorite_de_perimetre', 'Perimetre = ''<ville>:<batiment>'' du commissariat. Autorite : le PJ portant le poste commissaire DANS CETTE VILLE. Un Commissaire d''une autre ville n''a aucune autorite.');
INSERT INTO public.pnj_institutions (institution, resolveur, note) VALUES ('renseignement', 'renseignement_autorite_de_perimetre', 'Perimetre = le PAYS. Autorite : le PJ portant le poste min_def de ce pays, meme garde que cellule_renseignement_creer. Les quatre identites reelles appartiennent au service, pas au ministre : un ministre passe, l''agent reste.');
