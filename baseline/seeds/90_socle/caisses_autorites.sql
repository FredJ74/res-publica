-- SEED -- caisses_autorites
-- ============================================================================
-- Table      : public.caisses_autorites
-- Domaine    : finances publiques
-- Categorie  : A (socle generique)
-- Strategie  : seed_complet (classification du chantier 2C)
-- Lignes     : 18
--
-- Fichier GENERE par outils/baseline/seeds.py. Ne pas editer a la main.
-- Les litteraux sont ceux que PostgreSQL lui-meme a produits (quote_nullable) :
-- aucune regle d'echappement n'a ete reimplementee.
--
-- JUSTIFICATION DU SEED (chantier 2C)
-- Quel poste controle quelle caisse. Regle d'autorite, aucune fonction ne
-- l'ecrit. LA DIX-HUITIEME LIGNE est le motif `subventions` (registre 624) :
-- prefixe, et liste de postes VIDE -- ce qui vaut
-- caisse_reservee_au_serveur. L'enveloppe municipale des subventions ne se
-- debite donc que par la porte de reponse, jamais a la main par le maire.
-- ============================================================================

INSERT INTO public.caisses_autorites (motif, est_prefixe, postes_debit, note) VALUES ('agence-', 'true', '{}', 'Agences privees (Grobras Securite et suivantes) : caisse reservee au serveur. Aucun poste public ne debite la caisse d''une entreprise privee.');
INSERT INTO public.caisses_autorites (motif, est_prefixe, postes_debit, note) VALUES ('assemblee', 'false', '{}', 'assemblee : chemin serveur dedie (assemblee_debiter_caisse_plafonne)');
INSERT INTO public.caisses_autorites (motif, est_prefixe, postes_debit, note) VALUES ('caserne-militaire', 'false', '{commandant}', 'caserne : le ministre ALIMENTE, le Commandant DEPENSE (arbitrage du 10 octobre 2026)');
INSERT INTO public.caisses_autorites (motif, est_prefixe, postes_debit, note) VALUES ('commissariat', 'true', '{commissaire,min_int}', 'commissariats');
INSERT INTO public.caisses_autorites (motif, est_prefixe, postes_debit, note) VALUES ('douane', 'false', '{chef_douanes,min_int}', 'Caisse du service des douanes. Geree par le Chef des Douanes, financee par le Ministere de l''Interieur qui garde autorite dessus -- meme couple que commissariat et caserne.');
INSERT INTO public.caisses_autorites (motif, est_prefixe, postes_debit, note) VALUES ('entrepot', 'true', '{directeur_entrepot,maire_adjoint}', 'entrepots logistiques');
INSERT INTO public.caisses_autorites (motif, est_prefixe, postes_debit, note) VALUES ('gouvernement-', 'true', '{}', 'ministere : le poste est lu dans l identifiant');
INSERT INTO public.caisses_autorites (motif, est_prefixe, postes_debit, note) VALUES ('mairie', 'true', '{maire,maire_adjoint}', 'mairies, toutes villes');
INSERT INTO public.caisses_autorites (motif, est_prefixe, postes_debit, note) VALUES ('palais-gouvernement', 'false', '{pm}', 'Caisse des actions gouvernementales communes -- communication et autres depenses institutionnelles du gouvernement. DIXIEME caisse nationale depuis l''arbitrage du 8 octobre 2026, a 9 %. Distincte de gouvernement-pm, enveloppe propre du Premier ministre. Engagee par le pm.');
INSERT INTO public.caisses_autorites (motif, est_prefixe, postes_debit, note) VALUES ('palais-presidentiel', 'false', '{president}', 'presidence');
INSERT INTO public.caisses_autorites (motif, est_prefixe, postes_debit, note) VALUES ('pole-tabac-alcools', 'true', '{directeur_tabac_alcools,min_fin}', 'tabac et alcools');
INSERT INTO public.caisses_autorites (motif, est_prefixe, postes_debit, note) VALUES ('port-sainte-marie', 'false', '{capitaine_port,min_fin}', 'port industriel — capitainerie');
INSERT INTO public.caisses_autorites (motif, est_prefixe, postes_debit, note) VALUES ('qhs-prison', 'false', '{min_int,min_just}', 'quartier haute securite');
INSERT INTO public.caisses_autorites (motif, est_prefixe, postes_debit, note) VALUES ('raffinerie', 'true', '{directeur_raffinerie,min_fin}', 'raffinerie');
INSERT INTO public.caisses_autorites (motif, est_prefixe, postes_debit, note) VALUES ('reserve-nationale', 'false', '{min_fin}', 'reserve nationale');
INSERT INTO public.caisses_autorites (motif, est_prefixe, postes_debit, note) VALUES ('subventions', 'true', '{}', 'Enveloppe municipale des subventions aux organisations eligibles. Liste de postes VIDE = caisse_reservee_au_serveur : le maire ne la debite jamais a la main, seulement par la porte des subventions. Prefixe pour que subventions_<ville> soit de portee VILLE.');
INSERT INTO public.caisses_autorites (motif, est_prefixe, postes_debit, note) VALUES ('tribunal', 'true', '{juge,min_just}', 'tribunaux');
INSERT INTO public.caisses_autorites (motif, est_prefixe, postes_debit, note) VALUES ('usine-pharma', 'true', '{directeur_pharma,min_fin}', 'pharmacie nationale');
