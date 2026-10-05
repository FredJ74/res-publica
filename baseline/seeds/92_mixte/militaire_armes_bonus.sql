-- SEED -- militaire_armes_bonus
-- ============================================================================
-- Table      : public.militaire_armes_bonus
-- Domaine    : militaire
-- Categorie  : D (mixte)
-- Strategie  : seed_filtre (classification du chantier 2C)
-- Lignes     : 16
--
-- Fichier GENERE par outils/baseline/seeds.py. Ne pas editer a la main.
-- Les litteraux sont ceux que PostgreSQL lui-meme a produits (quote_nullable) :
-- aucune regle d'echappement n'a ete reimplementee.
--
-- JUSTIFICATION DU SEED (chantier 2C)
-- Bareme de bonus d'arme, generique dans sa forme, mais la colonne note
-- porte des habillages propres a Republia (« habillage Port-Sainte-Marie »).
-- Aucune colonne pays.
--
-- ARBITRAGE DE GAME DESIGN
-- Chantier de separation moteur/contenu : le bareme est du socle,
-- l'habillage est de l'empire.
-- ============================================================================

INSERT INTO public.militaire_armes_bonus (cle, mode, bonus, note) VALUES ('AK-47', 'feu', '18', 'narco');
INSERT INTO public.militaire_armes_bonus (cle, mode, bonus, note) VALUES ('arme_de_poing', 'feu', '8', 'armee — recette du revolver civil');
INSERT INTO public.militaire_armes_bonus (cle, mode, bonus, note) VALUES ('Baïonnette', 'cac', '5', 'soviet');
INSERT INTO public.militaire_armes_bonus (cle, mode, bonus, note) VALUES ('Carabine de chasse', 'feu', '15', 'republic');
INSERT INTO public.militaire_armes_bonus (cle, mode, bonus, note) VALUES ('Carabine de précision', 'feu', '17', 'khalija');
INSERT INTO public.militaire_armes_bonus (cle, mode, bonus, note) VALUES ('Couteau de plongée', 'cac', '5', 'republic — habillage Port-Sainte-Marie du couteau de poche');
INSERT INTO public.militaire_armes_bonus (cle, mode, bonus, note) VALUES ('Couteau de poche', 'cac', '5', 'republic');
INSERT INTO public.militaire_armes_bonus (cle, mode, bonus, note) VALUES ('Desert Eagle', 'feu', '10', 'narco');
INSERT INTO public.militaire_armes_bonus (cle, mode, bonus, note) VALUES ('Fusil sous-marin', 'feu', '8', 'republic — habillage Port-Sainte-Marie du revolver');
INSERT INTO public.militaire_armes_bonus (cle, mode, bonus, note) VALUES ('Jambiya', 'cac', '6', 'khalija');
INSERT INTO public.militaire_armes_bonus (cle, mode, bonus, note) VALUES ('Kalachnikov', 'feu', '16', 'soviet');
INSERT INTO public.militaire_armes_bonus (cle, mode, bonus, note) VALUES ('Machette', 'cac', '5', 'narco');
INSERT INTO public.militaire_armes_bonus (cle, mode, bonus, note) VALUES ('Makarov', 'feu', '8', 'soviet');
INSERT INTO public.militaire_armes_bonus (cle, mode, bonus, note) VALUES ('mitraillette', 'feu', '15', 'armee — recette de la carabine civile');
INSERT INTO public.militaire_armes_bonus (cle, mode, bonus, note) VALUES ('Pistolet doré', 'feu', '9', 'khalija');
INSERT INTO public.militaire_armes_bonus (cle, mode, bonus, note) VALUES ('Revolver .38', 'feu', '8', 'republic');
