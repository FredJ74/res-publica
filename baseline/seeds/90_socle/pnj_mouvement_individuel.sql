-- SEED -- pnj_mouvement_individuel
-- ============================================================================
-- Table      : public.pnj_mouvement_individuel
-- Domaine    : socle PNJ
-- Categorie  : A (socle generique)
-- Strategie  : seed_complet (classification du chantier 2C)
-- Lignes     : 8
--
-- Fichier GENERE par outils/baseline/seeds.py. Ne pas editer a la main.
-- Les litteraux sont ceux que PostgreSQL lui-meme a produits (quote_nullable) :
-- aucune regle d'echappement n'a ete reimplementee.
--
-- JUSTIFICATION DU SEED (chantier 2C)
-- Regle de mouvement par famille. Aucune fonction ne l'ecrit.
-- ============================================================================

INSERT INTO public.pnj_mouvement_individuel (famille, autorise, raison, note) VALUES ('agent', 'true', 'agent_porte_par_son_officier', 'Un agent se porte et se depose reellement (agent_prendre, agent_deposer) et se transfere a un autre joueur SANS son accord (agent_transferer). La regle de jeu est donc ouverte ; seul l''axe, encore dans agents_renseignement, empeche le socle d''y toucher.');
INSERT INTO public.pnj_mouvement_individuel (famille, autorise, raison, note) VALUES ('depute', 'false', 'pnj_institutionnel', 'Un depute ne se recrute pas. On negocie son vote ou on l''endort ; on ne l''emmene pas.');
INSERT INTO public.pnj_mouvement_individuel (famille, autorise, raison, note) VALUES ('douanier', 'false', 'affectation_par_le_service', 'Un douanier est affecte par le Chef des Douanes, jamais pris dans un groupe.');
INSERT INTO public.pnj_mouvement_individuel (famille, autorise, raison, note) VALUES ('employe', 'true', 'employe_du_joueur', 'Un employe se laisse en place et se reprend dans le groupe : le jeu le permet deja (laisserPnjEnPlace, recupererPnjDansGroupe), et il se debauche meme par un autre joueur. La regle de jeu est donc OUVERTE. C''est l''AXE, encore au magasin client, qui l''empeche aujourd''hui -- les deux gardes disent bien deux choses differentes.');
INSERT INTO public.pnj_mouvement_individuel (famille, autorise, raison, note) VALUES ('militant', 'false', 'militant_de_terrain', 'Un militant reste sur son lieu de militance. Aucune mecanique du jeu ne le prend dans un groupe ni ne le deplace.');
INSERT INTO public.pnj_mouvement_individuel (famille, autorise, raison, note) VALUES ('policier', 'false', 'affectation_par_le_service', 'Un policier est affecte a une piece ou a une rue par le Commissaire, jamais pris dans un groupe.');
INSERT INTO public.pnj_mouvement_individuel (famille, autorise, raison, note) VALUES ('soldat', 'false', 'mouvement_individuel_interdit', 'Le modele militaire opere par NOMBRE : militaire_deposer_soldats et militaire_recuperer_soldats prennent une quantite, jamais un matricule. Rien dans l''interface ne permet de designer un soldat pour le deplacer. Regle de jeu, pas etat de migration.');
INSERT INTO public.pnj_mouvement_individuel (famille, autorise, raison, note) VALUES ('titulaire_poste', 'false', 'pnj_institutionnel', 'Un titulaire de poste n''est employable par personne. Le prendre dans un groupe reviendrait a transformer une institution en employe.');
