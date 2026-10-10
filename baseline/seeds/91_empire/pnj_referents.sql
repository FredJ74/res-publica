-- SEED -- pnj_referents
-- ============================================================================
-- Table      : public.pnj_referents
-- Domaine    : socle PNJ
-- Categorie  : B (contenu initial d'empire)
-- Strategie  : seed_complet (classification du chantier 2C)
-- Lignes     : 19
--
-- Fichier GENERE par outils/baseline/seeds.py. Ne pas editer a la main.
-- Les litteraux sont ceux que PostgreSQL lui-meme a produits (quote_nullable) :
-- aucune regle d'echappement n'a ete reimplementee.
--
-- JUSTIFICATION DU SEED (chantier 2C)
-- 18 referents de Republia, identifiants et domaine. Colonne pays presente.
-- ============================================================================

INSERT INTO public.pnj_referents (referent_id, domaine, pays) VALUES ('alain_bordage', 'voyages internationaux', 'republic');
INSERT INTO public.pnj_referents (referent_id, domaine, pays) VALUES ('alfredo_mifassole', 'role social et politique du club — Luthecia', 'republic');
INSERT INTO public.pnj_referents (referent_id, domaine, pays) VALUES ('caporal_alouche', 'militaire — intendance et refectoire', 'republic');
INSERT INTO public.pnj_referents (referent_id, domaine, pays) VALUES ('commandant_tom_hawak', 'militaire — commandement, compagnies, grades et caisse', 'republic');
INSERT INTO public.pnj_referents (referent_id, domaine, pays) VALUES ('eve_toahemarch', 'militaire — sante, blessures et soins', 'republic');
INSERT INTO public.pnj_referents (referent_id, domaine, pays) VALUES ('gaspard_ferriere', 'militaire — engagement, formation, troupe', 'republic');
INSERT INTO public.pnj_referents (referent_id, domaine, pays) VALUES ('gretta_delieu', 'centre d''affaires — bureaux, location et equipements', 'republic');
INSERT INTO public.pnj_referents (referent_id, domaine, pays) VALUES ('jean_lou_zeure', 'elections et campagnes', 'republic');
INSERT INTO public.pnj_referents (referent_id, domaine, pays) VALUES ('juge_fontaine', 'justice — proces et jugement', 'republic');
INSERT INTO public.pnj_referents (referent_id, domaine, pays) VALUES ('laurent_barre', 'immobilier et entrepreneuriat', 'republic');
INSERT INTO public.pnj_referents (referent_id, domaine, pays) VALUES ('lucas_tenaire', 'role social du club — Montrouge', 'republic');
INSERT INTO public.pnj_referents (referent_id, domaine, pays) VALUES ('marc_hantile', 'economie', 'republic');
INSERT INTO public.pnj_referents (referent_id, domaine, pays) VALUES ('marcel_ancre', 'administration portuaire', 'republic');
INSERT INTO public.pnj_referents (referent_id, domaine, pays) VALUES ('martial_bouterin', 'militaire — organisation, strategie, operations', 'republic');
INSERT INTO public.pnj_referents (referent_id, domaine, pays) VALUES ('pascal_hamar', 'role social du club — Port-Sainte-Marie', 'republic');
INSERT INTO public.pnj_referents (referent_id, domaine, pays) VALUES ('pat_hounette', 'milieu criminel', 'republic');
INSERT INTO public.pnj_referents (referent_id, domaine, pays) VALUES ('president_laroche', 'institutions et Etat', 'republic');
INSERT INTO public.pnj_referents (referent_id, domaine, pays) VALUES ('procureur_saad', 'justice — poursuites et parquet', 'republic');
INSERT INTO public.pnj_referents (referent_id, domaine, pays) VALUES ('raoul_toufaud', 'police', 'republic');
