-- SEED -- journaux
-- ============================================================================
-- Table      : public.journaux
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
-- 4 titres, un par empire.
--
-- COLONNES OMISES (defaut now()) : cree_le
-- La date de creation d'une ligne n'est pas du contenu authored : c'est le
-- jour ou le monde est ne. Omettre la colonne laisse le defaut jouer.
-- ============================================================================

INSERT INTO public.journaux (id, groupe_id, pays, nom, slug, garanti_automatique, cree_par) VALUES ('khalija_le-minaret-dore', 'khalija_groupe-presse-historique', 'khalija', 'Le Minaret Doré', 'le-minaret-dore', 'true', NULL);
INSERT INTO public.journaux (id, groupe_id, pays, nom, slug, garanti_automatique, cree_par) VALUES ('narco_el-narco-times', 'narco_groupe-presse-historique', 'narco', 'El Narco Times', 'el-narco-times', 'true', NULL);
INSERT INTO public.journaux (id, groupe_id, pays, nom, slug, garanti_automatique, cree_par) VALUES ('republic_autruche-entravee', 'republic_tribune-republia', 'republic', 'L''Autruche Entravée', 'autruche-entravee', 'true', NULL);
INSERT INTO public.journaux (id, groupe_id, pays, nom, slug, garanti_automatique, cree_par) VALUES ('soviet_la-pravdovka', 'soviet_groupe-presse-historique', 'soviet', 'La Pravdovka', 'la-pravdovka', 'true', NULL);
