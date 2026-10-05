-- SEED -- groupes_presse
-- ============================================================================
-- Table      : public.groupes_presse
-- Domaine    : presse
-- Categorie  : B (contenu initial d'empire)
-- Strategie  : seed_complet (classification du chantier 2C)
-- Lignes     : 4
--
-- Fichier GENERE par outils/baseline/seeds.py. Ne pas editer a la main.
-- Les litteraux sont ceux que PostgreSQL lui-meme a produits (quote_nullable) :
-- aucune regle d'echappement n'a ete reimplementee.
--
-- JUSTIFICATION DU SEED (chantier 2C)
-- 4 groupes de presse, un par empire.
--
-- COLONNES OMISES (defaut now()) : cree_le
-- La date de creation d'une ligne n'est pas du contenu authored : c'est le
-- jour ou le monde est ne. Omettre la colonne laisse le defaut jouer.
-- ============================================================================

INSERT INTO public.groupes_presse (id, pays, nom, organisation_id) VALUES ('khalija_groupe-presse-historique', 'khalija', 'Le Minaret Doré', NULL);
INSERT INTO public.groupes_presse (id, pays, nom, organisation_id) VALUES ('narco_groupe-presse-historique', 'narco', 'El Narco Times', NULL);
INSERT INTO public.groupes_presse (id, pays, nom, organisation_id) VALUES ('republic_tribune-republia', 'republic', 'La Tribune de Républia', NULL);
INSERT INTO public.groupes_presse (id, pays, nom, organisation_id) VALUES ('soviet_groupe-presse-historique', 'soviet', 'La Pravdovka', NULL);
