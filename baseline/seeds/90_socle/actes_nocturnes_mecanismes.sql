-- SEED -- actes_nocturnes_mecanismes
-- ============================================================================
-- Table      : public.actes_nocturnes_mecanismes
-- Domaine    : divers et technique
-- Categorie  : A (socle generique)
-- Strategie  : seed_complet (classification du chantier 2C)
-- Lignes     : 3
--
-- Fichier GENERE par outils/baseline/seeds.py. Ne pas editer a la main.
-- Les litteraux sont ceux que PostgreSQL lui-meme a produits (quote_nullable) :
-- aucune regle d'echappement n'a ete reimplementee.
--
-- JUSTIFICATION DU SEED (chantier 2C)
-- LISTE BLANCHE des mecanismes nocturnes, avec une cle etrangere depuis
-- actes_nocturnes : revendiquer un mecanisme non declare LEVE. Registre
-- d'autorite, du meme genre que caisses_autorites ou
-- budget_national_champs_regles -- aucune fonction ne l'ecrit, chaque entree
-- est une migration. 2 lignes au 9 octobre 2026 a 18h00 :
-- preemption_mensualite (registre 567, migration 20261009130649) et
-- candidature_poste_tirage (registre 574, migration 20261009150819). Compte
-- RELEVE EN BASE -- select count(*) from public.actes_nocturnes_mecanismes
-- -> 2 -- et non recopie du seed rendu.
--
-- ARBITRAGE DE GAME DESIGN
-- SEED INDISPENSABLE, et ce n'est pas un choix de confort : sans sa ligne,
-- la RPC du mecanisme leve une violation de cle etrangere et la passe de
-- minuit s'arrete. Le contenu du registre fait donc partie du socle d'un
-- monde neuf, pas de son etat vivant.
-- ============================================================================

INSERT INTO public.actes_nocturnes_mecanismes (mecanisme, sujet_singleton, note) VALUES ('candidature_poste_tirage', 'false', 'Nomination par tirage au sort d''une candidature a un poste nomme dont l''autorite n''a pas tranche dans les 48h. Un rejeu redesignerait un gagnant et rediviserait par deux la POP du nominateur. Un sujet par poste : « <poste_id>|<ville ou national> ».');
INSERT INTO public.actes_nocturnes_mecanismes (mecanisme, sujet_singleton, note) VALUES ('preemption_mensualite', 'true', 'Mensualite de la preemption d''Etat : debit de la caisse du Ministere des Finances et reduction de la dette. Un rejeu debiterait une seconde mensualite. Un sujet par pays : une seule preemption a la fois.');
INSERT INTO public.actes_nocturnes_mecanismes (mecanisme, sujet_singleton, note) VALUES ('taxe_fonciere', 'false', 'Taxe fonciere d''un terrain : debit du proprietaire et credit de la mairie dans une transaction, ou accumulation de la dette jusqu''a la saisie municipale. Un rejeu redebiterait la taxe et avancerait d''un cran vers la saisie. Un sujet par TERRAIN : chaque bien est impose une fois par jour.');
