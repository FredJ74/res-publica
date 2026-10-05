-- SEED -- caisses_autorites
-- ============================================================================
-- Table      : public.caisses_autorites
-- Domaine    : finances publiques
-- Categorie  : A (socle generique)
-- Strategie  : seed_complet (classification du chantier 2C)
-- Lignes     : 16
--
-- Fichier GENERE par outils/baseline/seeds.py. Ne pas editer a la main.
-- Les litteraux sont ceux que PostgreSQL lui-meme a produits (quote_nullable) :
-- aucune regle d'echappement n'a ete reimplementee.
--
-- JUSTIFICATION DU SEED (chantier 2C)
-- Quel poste controle quelle caisse. Regle d'autorite, aucune fonction ne
-- l'ecrit.
-- ============================================================================

INSERT INTO public.caisses_autorites (motif, est_prefixe, postes_debit, note) VALUES ('agence-', 'true', '{}', 'Agences privees (Grobras Securite et suivantes) : caisse reservee au serveur. Aucun poste public ne debite la caisse d''une entreprise privee.');
INSERT INTO public.caisses_autorites (motif, est_prefixe, postes_debit, note) VALUES ('assemblee', 'false', '{}', 'assemblee : chemin serveur dedie (assemblee_debiter_caisse_plafonne)');
INSERT INTO public.caisses_autorites (motif, est_prefixe, postes_debit, note) VALUES ('caserne-militaire', 'false', '{commandant,min_def}', 'caserne');
INSERT INTO public.caisses_autorites (motif, est_prefixe, postes_debit, note) VALUES ('commissariat', 'true', '{commissaire,min_int}', 'commissariats');
INSERT INTO public.caisses_autorites (motif, est_prefixe, postes_debit, note) VALUES ('entrepot', 'true', '{directeur_entrepot,maire_adjoint}', 'entrepots logistiques');
INSERT INTO public.caisses_autorites (motif, est_prefixe, postes_debit, note) VALUES ('gouvernement-', 'true', '{}', 'ministere : le poste est lu dans l identifiant');
INSERT INTO public.caisses_autorites (motif, est_prefixe, postes_debit, note) VALUES ('mairie', 'true', '{maire,maire_adjoint}', 'mairies, toutes villes');
INSERT INTO public.caisses_autorites (motif, est_prefixe, postes_debit, note) VALUES ('palais-gouvernement', 'false', '{pm}', 'siege du Premier ministre');
INSERT INTO public.caisses_autorites (motif, est_prefixe, postes_debit, note) VALUES ('palais-presidentiel', 'false', '{president}', 'presidence');
INSERT INTO public.caisses_autorites (motif, est_prefixe, postes_debit, note) VALUES ('pole-tabac-alcools', 'true', '{directeur_tabac_alcools,min_fin}', 'tabac et alcools');
INSERT INTO public.caisses_autorites (motif, est_prefixe, postes_debit, note) VALUES ('port-sainte-marie', 'false', '{capitaine_port,min_fin}', 'port industriel — capitainerie');
INSERT INTO public.caisses_autorites (motif, est_prefixe, postes_debit, note) VALUES ('qhs-prison', 'false', '{min_int,min_just}', 'quartier haute securite');
INSERT INTO public.caisses_autorites (motif, est_prefixe, postes_debit, note) VALUES ('raffinerie', 'true', '{directeur_raffinerie,min_fin}', 'raffinerie');
INSERT INTO public.caisses_autorites (motif, est_prefixe, postes_debit, note) VALUES ('reserve-nationale', 'false', '{min_fin}', 'reserve nationale');
INSERT INTO public.caisses_autorites (motif, est_prefixe, postes_debit, note) VALUES ('tribunal', 'true', '{juge,min_just}', 'tribunaux');
INSERT INTO public.caisses_autorites (motif, est_prefixe, postes_debit, note) VALUES ('usine-pharma', 'true', '{directeur_pharma,min_fin}', 'pharmacie nationale');
