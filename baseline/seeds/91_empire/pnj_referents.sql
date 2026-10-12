-- SEED -- pnj_referents
-- ============================================================================
-- Table      : public.pnj_referents
-- Domaine    : socle PNJ
-- Categorie  : B (contenu initial d'empire)
-- Strategie  : seed_complet (classification du chantier 2C)
-- Lignes     : 28
--
-- Fichier GENERE par outils/baseline/seeds.py. Ne pas editer a la main.
-- Les litteraux sont ceux que PostgreSQL lui-meme a produits (quote_nullable) :
-- aucune regle d'echappement n'a ete reimplementee.
--
-- JUSTIFICATION DU SEED (chantier 2C)
-- 19 referents de Republia, identifiants et domaine. Colonne pays presente.
-- LE DIX-NEUVIEME est commandant_tom_hawak (registre 637, migration
-- 20261010215442) : le Commandant de la caserne devient referent militaire a
-- la cloture du batiment. Cette table est la LISTE FERMEE qui autorise la
-- memoire pedagogique -- referent_pedagogie_noter rend `referent: false`
-- sans rien ecrire pour un identifiant absent -- donc une voix sans ligne
-- ici serait une voix sans souvenir. Compte RELEVE EN BASE.
-- ============================================================================

INSERT INTO public.pnj_referents (referent_id, domaine, pays) VALUES ('alain_bordage', 'voyages internationaux', 'republic');
INSERT INTO public.pnj_referents (referent_id, domaine, pays) VALUES ('alain_theret', 'ministere des Finances — fiscalite, budget national, subventions, preemption', 'republic');
INSERT INTO public.pnj_referents (referent_id, domaine, pays) VALUES ('alfredo_mifassole', 'role social et politique du club — Luthecia', 'republic');
INSERT INTO public.pnj_referents (referent_id, domaine, pays) VALUES ('caporal_alouche', 'militaire — intendance et refectoire', 'republic');
INSERT INTO public.pnj_referents (referent_id, domaine, pays) VALUES ('commandant_tom_hawak', 'militaire — commandement, compagnies, grades et caisse', 'republic');
INSERT INTO public.pnj_referents (referent_id, domaine, pays) VALUES ('eve_toahemarch', 'militaire — sante, blessures et soins', 'republic');
INSERT INTO public.pnj_referents (referent_id, domaine, pays) VALUES ('gaspard_ferriere', 'militaire — engagement, formation, troupe', 'republic');
INSERT INTO public.pnj_referents (referent_id, domaine, pays) VALUES ('gerard_tamponneau', 'protocole, receptions et diplomatie', 'republic');
INSERT INTO public.pnj_referents (referent_id, domaine, pays) VALUES ('gretta_delieu', 'centre d''affaires — bureaux, location et equipements', 'republic');
INSERT INTO public.pnj_referents (referent_id, domaine, pays) VALUES ('honore_cozetoujours', 'justice — droit, procedure judiciaire et fonctionnement du Tribunal', 'republic');
INSERT INTO public.pnj_referents (referent_id, domaine, pays) VALUES ('hotesse_accueil', 'Assemblee nationale — procedure parlementaire, calendrier, ce qu on peut y faire', 'republic');
INSERT INTO public.pnj_referents (referent_id, domaine, pays) VALUES ('huguette_papier', 'presidence — pouvoirs, limites et memoire des mandats', 'republic');
INSERT INTO public.pnj_referents (referent_id, domaine, pays) VALUES ('jean_jacques_carlin', 'ministere des Affaires etrangeres — treves, relations bilaterales, ambassades', 'republic');
INSERT INTO public.pnj_referents (referent_id, domaine, pays) VALUES ('jean_lou_zeure', 'elections et campagnes', 'republic');
INSERT INTO public.pnj_referents (referent_id, domaine, pays) VALUES ('laurent_barre', 'immobilier et entrepreneuriat', 'republic');
INSERT INTO public.pnj_referents (referent_id, domaine, pays) VALUES ('lucas_tenaire', 'role social du club — Montrouge', 'republic');
INSERT INTO public.pnj_referents (referent_id, domaine, pays) VALUES ('marc_hantile', 'economie', 'republic');
INSERT INTO public.pnj_referents (referent_id, domaine, pays) VALUES ('marcel_ancre', 'administration portuaire', 'republic');
INSERT INTO public.pnj_referents (referent_id, domaine, pays) VALUES ('marie_eve_beaulieu', 'ministere de l''Information — propagande, censure, sondages, communication', 'republic');
INSERT INTO public.pnj_referents (referent_id, domaine, pays) VALUES ('martial_bouterin', 'militaire — organisation, strategie, operations', 'republic');
INSERT INTO public.pnj_referents (referent_id, domaine, pays) VALUES ('mathilde_garde', 'ministere de la Justice — nomination et revocation du Procureur, graces proposees, detention', 'republic');
INSERT INTO public.pnj_referents (referent_id, domaine, pays) VALUES ('pascal_hamar', 'role social du club — Port-Sainte-Marie', 'republic');
INSERT INTO public.pnj_referents (referent_id, domaine, pays) VALUES ('pat_hounette', 'milieu criminel', 'republic');
INSERT INTO public.pnj_referents (referent_id, domaine, pays) VALUES ('porte_parole_presidentiel', 'communication presidentielle', 'republic');
INSERT INTO public.pnj_referents (referent_id, domaine, pays) VALUES ('president_laroche', 'institutions et Etat', 'republic');
INSERT INTO public.pnj_referents (referent_id, domaine, pays) VALUES ('procureur_saad', 'justice — le parquet : plaintes recues, enquetes diligentees, non-lieu, poursuites', 'republic');
INSERT INTO public.pnj_referents (referent_id, domaine, pays) VALUES ('raoul_toufaud', 'police', 'republic');
INSERT INTO public.pnj_referents (referent_id, domaine, pays) VALUES ('yvan_danltat', 'ministere de l''Interieur — ordre public, manifestations, naturalisations, douanes', 'republic');
