-- SEED -- pnj_fonctions
-- ============================================================================
-- Table      : public.pnj_fonctions
-- Domaine    : socle PNJ
-- Categorie  : A (socle generique)
-- Strategie  : seed_complet (classification du chantier 2C)
-- Lignes     : 38
--
-- Fichier GENERE par outils/baseline/seeds.py. Ne pas editer a la main.
-- Les litteraux sont ceux que PostgreSQL lui-meme a produits (quote_nullable) :
-- aucune regle d'echappement n'a ete reimplementee.
--
-- JUSTIFICATION DU SEED (chantier 2C)
-- Nature des PNJ du decor, fonction par fonction. Ne contient aucun PNJ.
-- ============================================================================

INSERT INTO public.pnj_fonctions (fonction, classe_decor, metier_beta, recrutable, role_fonctionnel, note) VALUES ('avocat', 'gamma', 'false', 'false', 'decor', 'AUCUN PNJ ne porte cette fonction.');
INSERT INTO public.pnj_fonctions (fonction, classe_decor, metier_beta, recrutable, role_fonctionnel, note) VALUES ('banquier', 'gamma', 'false', 'false', 'dialogue', 'Decor bancaire.');
INSERT INTO public.pnj_fonctions (fonction, classe_decor, metier_beta, recrutable, role_fonctionnel, note) VALUES ('barman', 'gamma', 'false', 'false', 'referent', 'Marin Dulac, au Bar des Pecheurs, est la source de l''ecoute de rumeurs.');
INSERT INTO public.pnj_fonctions (fonction, classe_decor, metier_beta, recrutable, role_fonctionnel, note) VALUES ('codetenu', 'gamma', 'true', 'false', 'decor', 'METIER PREVU, JAMAIS ACTIVE. Aucun PNJ du jeu ne porte cette fonction : le bouton « Faire alliance » existe mais n''est rendu sur aucune fiche. Profil conserve, chemin non ouvert.');
INSERT INTO public.pnj_fonctions (fonction, classe_decor, metier_beta, recrutable, role_fonctionnel, note) VALUES ('commercant', 'gamma', 'false', 'false', 'dialogue', 'La fonction la plus repandue du decor (16 PNJ). Un PJ proprietaire de commerces pourra un jour recruter des Beta et leur donner ce role : cela ne rendra pas ces Gamma-ci employables.');
INSERT INTO public.pnj_fonctions (fonction, classe_decor, metier_beta, recrutable, role_fonctionnel, note) VALUES ('commissaire', 'gamma', 'false', 'false', 'institutionnel', 'Gamma fixe, fonction remplacable par un PJ. Le Commissaire Touffaud RESTE physiquement dans le jeu si le maire nomme un Commissaire PJ : existence et titularite sont deux choses.');
INSERT INTO public.pnj_fonctions (fonction, classe_decor, metier_beta, recrutable, role_fonctionnel, note) VALUES ('default', 'gamma', 'false', 'false', 'decor', 'Repli de tout PNJ sans fonction declaree, et fonction de quatre inconnus du decor.');
INSERT INTO public.pnj_fonctions (fonction, classe_decor, metier_beta, recrutable, role_fonctionnel, note) VALUES ('depute', 'gamma', 'false', 'false', 'institutionnel', 'Gamma a PRESENCE CONDITIONNELLE, regle metier propre aux deputes : present tant qu''aucun PJ n''occupe son siege. Voir pnj_deputes_presence. Ne pas generaliser aux autres Gamma.');
INSERT INTO public.pnj_fonctions (fonction, classe_decor, metier_beta, recrutable, role_fonctionnel, note) VALUES ('detenu', 'gamma', 'false', 'false', 'dialogue', 'Detenus poses en prison. NE PAS confondre avec le metier codetenu, prevu mais jamais active : aucun PNJ du jeu ne porte job=codetenu, et il ne faut pas transformer un detenu en codetenu.');
INSERT INTO public.pnj_fonctions (fonction, classe_decor, metier_beta, recrutable, role_fonctionnel, note) VALUES ('docker', 'gamma', 'false', 'false', 'dialogue', 'Decor portuaire, un par port.');
INSERT INTO public.pnj_fonctions (fonction, classe_decor, metier_beta, recrutable, role_fonctionnel, note) VALUES ('douanier', 'gamma', 'true', 'false', 'mecanique', 'Prosper Tampon : Gamma FIXE, fonction douanier au passage en douane, notamment dans le parcours permettant de prendre l''avion. A ne pas confondre avec le METIER douanier des quatre effectifs Beta du service -- meme mot, nature differente. C''est le cas demonstratif.');
INSERT INTO public.pnj_fonctions (fonction, classe_decor, metier_beta, recrutable, role_fonctionnel, note) VALUES ('escort', 'gamma', 'true', 'true', 'mecanique', 'Les deux escortes posees au bar de l''Hotel La Republica sont du decor, mais elles ont un vrai chemin Beta : bouton dedie, 800 FR, profil fixe, actions propres. Seule fonction recrutable.');
INSERT INTO public.pnj_fonctions (fonction, classe_decor, metier_beta, recrutable, role_fonctionnel, note) VALUES ('garde', 'gamma', 'false', 'false', 'acces', 'Gamma fixe. Controle l''acces a certains lieux (palais, assemblee).');
INSERT INTO public.pnj_fonctions (fonction, classe_decor, metier_beta, recrutable, role_fonctionnel, note) VALUES ('general', 'gamma', 'false', 'false', 'dialogue', 'Decor.');
INSERT INTO public.pnj_fonctions (fonction, classe_decor, metier_beta, recrutable, role_fonctionnel, note) VALUES ('grand_pretre', 'gamma', 'false', 'false', 'institutionnel', 'Gamma fixe dans le monde, mais sa FONCTION peut etre reprise par un PJ. Reprise de fonction n''est pas disparition : il reste present, il cesse d''en etre le titulaire.');
INSERT INTO public.pnj_fonctions (fonction, classe_decor, metier_beta, recrutable, role_fonctionnel, note) VALUES ('hotelier', 'gamma', 'false', 'false', 'dialogue', 'Decor d''accueil.');
INSERT INTO public.pnj_fonctions (fonction, classe_decor, metier_beta, recrutable, role_fonctionnel, note) VALUES ('hotesse', 'gamma', 'false', 'false', 'dialogue', 'Decor d''accueil. DISTINCTE de hotesse_objets_trouves, autre fonction, qui porte le bouton « Demander des confidences ».');
INSERT INTO public.pnj_fonctions (fonction, classe_decor, metier_beta, recrutable, role_fonctionnel, note) VALUES ('hotesse_objets_trouves', 'gamma', 'false', 'false', 'referent', 'Gamma referente : interrogeable sur les objets trouves.');
INSERT INTO public.pnj_fonctions (fonction, classe_decor, metier_beta, recrutable, role_fonctionnel, note) VALUES ('infirmier', 'gamma', 'false', 'false', 'dialogue', 'Decor de soin.');
INSERT INTO public.pnj_fonctions (fonction, classe_decor, metier_beta, recrutable, role_fonctionnel, note) VALUES ('informateur', 'gamma', 'true', 'false', 'mecanique', 'AUCUN PNJ du decor ne porte cette fonction -- Rene Seigne, decrit « Habitue du bar — Informateur », a job:null. Le metier Beta informateur se recrute par un ORDRE de salle, pas sur une fiche PNJ.');
INSERT INTO public.pnj_fonctions (fonction, classe_decor, metier_beta, recrutable, role_fonctionnel, note) VALUES ('inspecteur', 'gamma', 'false', 'false', 'dialogue', 'Decor.');
INSERT INTO public.pnj_fonctions (fonction, classe_decor, metier_beta, recrutable, role_fonctionnel, note) VALUES ('journaliste', 'gamma', 'false', 'false', 'dialogue', 'Decor de redaction et d''accreditation.');
INSERT INTO public.pnj_fonctions (fonction, classe_decor, metier_beta, recrutable, role_fonctionnel, note) VALUES ('juge', 'gamma', 'false', 'false', 'institutionnel', 'Gamma fixe, fonction remplacable par un PJ. Meme principe que le Commissaire.');
INSERT INTO public.pnj_fonctions (fonction, classe_decor, metier_beta, recrutable, role_fonctionnel, note) VALUES ('lobbyiste', 'gamma', 'false', 'false', 'referent', 'Gamma fixe, consultable comme tous les PNJ. Sa fonction lui donne un domaine de reference. L''existence d''une RPC dediee (assemblee_consulter_lobbyiste) ne change pas sa classe.');
INSERT INTO public.pnj_fonctions (fonction, classe_decor, metier_beta, recrutable, role_fonctionnel, note) VALUES ('loge', 'gamma', 'false', 'false', 'decor', 'AUCUN PNJ ne porte cette fonction.');
INSERT INTO public.pnj_fonctions (fonction, classe_decor, metier_beta, recrutable, role_fonctionnel, note) VALUES ('marchande', 'gamma', 'false', 'false', 'dialogue', 'Decor de vente.');
INSERT INTO public.pnj_fonctions (fonction, classe_decor, metier_beta, recrutable, role_fonctionnel, note) VALUES ('medecin', 'gamma', 'false', 'false', 'dialogue', 'Decor de soin.');
INSERT INTO public.pnj_fonctions (fonction, classe_decor, metier_beta, recrutable, role_fonctionnel, note) VALUES ('militaire', 'gamma', 'false', 'false', 'decor', 'Decor de caserne. AUCUN lien avec les 96 soldats Alpha, qui vivent au socle.');
INSERT INTO public.pnj_fonctions (fonction, classe_decor, metier_beta, recrutable, role_fonctionnel, note) VALUES ('policier', 'gamma', 'true', 'false', 'mecanique', 'Le Brigadier Local est du decor. Le METIER policier Beta, lui, est recrute par un Commissaire dans les effectifs de police : meme mot, autre nature.');
INSERT INTO public.pnj_fonctions (fonction, classe_decor, metier_beta, recrutable, role_fonctionnel, note) VALUES ('portier', 'gamma', 'false', 'false', 'acces', 'Gamma fixe. Controle l''acces a la loge maconnique.');
INSERT INTO public.pnj_fonctions (fonction, classe_decor, metier_beta, recrutable, role_fonctionnel, note) VALUES ('professeur', 'gamma', 'false', 'false', 'dialogue', 'Decor.');
INSERT INTO public.pnj_fonctions (fonction, classe_decor, metier_beta, recrutable, role_fonctionnel, note) VALUES ('redacteur', 'gamma', 'false', 'false', 'dialogue', 'Decor de redaction.');
INSERT INTO public.pnj_fonctions (fonction, classe_decor, metier_beta, recrutable, role_fonctionnel, note) VALUES ('secretaire', 'gamma', 'false', 'false', 'dialogue', 'Decor administratif.');
INSERT INTO public.pnj_fonctions (fonction, classe_decor, metier_beta, recrutable, role_fonctionnel, note) VALUES ('serveur', 'gamma', 'false', 'false', 'dialogue', 'Decor de salle.');
INSERT INTO public.pnj_fonctions (fonction, classe_decor, metier_beta, recrutable, role_fonctionnel, note) VALUES ('soldat', 'gamma', 'false', 'false', 'decor', 'Decor de caserne. La fonction `soldat` existe aussi comme famille ALPHA (96 hommes au socle), recrutee par la FILIERE MILITAIRE -- candidature, affectation, section -- et jamais comme employe personnel. Le PNJ du decor n''est pas recrutable.');
INSERT INTO public.pnj_fonctions (fonction, classe_decor, metier_beta, recrutable, role_fonctionnel, note) VALUES ('syndicaliste', 'gamma', 'false', 'false', 'dialogue', 'Decor syndical.');
INSERT INTO public.pnj_fonctions (fonction, classe_decor, metier_beta, recrutable, role_fonctionnel, note) VALUES ('titulaire_poste', 'gamma', 'false', 'false', 'institutionnel', 'Occupe fonctionnellement un poste en l''absence d''un PJ. N''EST PAS une autorite : un poste tenu par un PNJ laisse l''autorite humaine vacante.');
INSERT INTO public.pnj_fonctions (fonction, classe_decor, metier_beta, recrutable, role_fonctionnel, note) VALUES ('venerable', 'gamma', 'false', 'false', 'dialogue', 'Decor de loge.');
