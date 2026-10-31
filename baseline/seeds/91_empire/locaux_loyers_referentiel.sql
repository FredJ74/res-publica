-- SEED -- locaux_loyers_referentiel
-- ============================================================================
-- Table      : public.locaux_loyers_referentiel
-- Domaine    : immobilier et territoire
-- Categorie  : B (contenu initial d'empire)
-- Strategie  : seed_complet (classification du chantier 2C)
-- Lignes     : 19
--
-- Fichier GENERE par outils/baseline/seeds.py. Ne pas editer a la main.
-- Les litteraux sont ceux que PostgreSQL lui-meme a produits (quote_nullable) :
-- aucune regle d'echappement n'a ete reimplementee.
--
-- JUSTIFICATION DU SEED (chantier 2C)
-- Contenu authored du monde : lieux, caractéristiques territoriales,
-- personnages ou récits propres aux empires. La mécanique reste commune ; ne
-- pas partager ni uniformiser ce contenu pour créer un autre empire.
--
-- ARBITRAGE DE GAME DESIGN
-- Structure constatée dans les exports canoniques du 31/10/2026. Aucun
-- compte de lignes déduit du schéma. Compte SQL relevé en lecture seule par
-- ChatGPT, commit 2a71eaf77dac83370a02c4f12cd71b502a20d772, 31/10/2026 ; ne
-- prouve pas la possession des lignes ni leur actualité au prochain point de
-- coupe.
-- ============================================================================

INSERT INTO public.locaux_loyers_referentiel (batiment, piece, ville, prix, bonus_pop, bonus_inf, bonus_dis, label, louable, signature_serveur) VALUES ('banque-nationale', 'coffre_privatif', '*', '600', '0', '4', '12', 'Coffre Privatif', 'true', 'true');
INSERT INTO public.locaux_loyers_referentiel (batiment, piece, ville, prix, bonus_pop, bonus_inf, bonus_dis, label, louable, signature_serveur) VALUES ('centre-affaires', 'bureau_prestige', '*', '1000', '3', '12', '8', 'Bureau Prestige', 'true', 'true');
INSERT INTO public.locaux_loyers_referentiel (batiment, piece, ville, prix, bonus_pop, bonus_inf, bonus_dis, label, louable, signature_serveur) VALUES ('centre-affaires', 'bureau_standard', '*', '500', '1', '6', '5', 'Bureau Standard', 'true', 'true');
INSERT INTO public.locaux_loyers_referentiel (batiment, piece, ville, prix, bonus_pop, bonus_inf, bonus_dis, label, louable, signature_serveur) VALUES ('centre-affaires', 'open_space', '*', '200', '2', '3', '1', 'Open Space', 'true', 'true');
INSERT INTO public.locaux_loyers_referentiel (batiment, piece, ville, prix, bonus_pop, bonus_inf, bonus_dis, label, louable, signature_serveur) VALUES ('centre-affaires', 'open_space', 'capitale', '200', '2', '3', '1', 'Open Space', 'false', 'true');
INSERT INTO public.locaux_loyers_referentiel (batiment, piece, ville, prix, bonus_pop, bonus_inf, bonus_dis, label, louable, signature_serveur) VALUES ('centre-affaires', 'open_space_a', 'capitale', '200', '2', '3', '1', 'Open Space A', 'true', 'true');
INSERT INTO public.locaux_loyers_referentiel (batiment, piece, ville, prix, bonus_pop, bonus_inf, bonus_dis, label, louable, signature_serveur) VALUES ('centre-affaires', 'open_space_b', 'capitale', '200', '2', '3', '1', 'Open Space B', 'true', 'true');
INSERT INTO public.locaux_loyers_referentiel (batiment, piece, ville, prix, bonus_pop, bonus_inf, bonus_dis, label, louable, signature_serveur) VALUES ('centre-affaires', 'open_space_c', 'capitale', '200', '2', '3', '1', 'Open Space C', 'true', 'true');
INSERT INTO public.locaux_loyers_referentiel (batiment, piece, ville, prix, bonus_pop, bonus_inf, bonus_dis, label, louable, signature_serveur) VALUES ('centre-affaires', 'open_space_d', 'capitale', '200', '2', '3', '1', 'Open Space D', 'true', 'true');
INSERT INTO public.locaux_loyers_referentiel (batiment, piece, ville, prix, bonus_pop, bonus_inf, bonus_dis, label, louable, signature_serveur) VALUES ('centre-artisanal', 'atelier_milieu', '*', '300', '6', '2', '0', 'Atelier Central', 'true', 'true');
INSERT INTO public.locaux_loyers_referentiel (batiment, piece, ville, prix, bonus_pop, bonus_inf, bonus_dis, label, louable, signature_serveur) VALUES ('centre-artisanal', 'echoppe_facade', '*', '600', '12', '2', '0', 'Échoppe Façade', 'true', 'true');
INSERT INTO public.locaux_loyers_referentiel (batiment, piece, ville, prix, bonus_pop, bonus_inf, bonus_dis, label, louable, signature_serveur) VALUES ('centre-artisanal', 'reserve_arriere', '*', '100', '2', '1', '2', 'Réserve Arrière', 'true', 'true');
INSERT INTO public.locaux_loyers_referentiel (batiment, piece, ville, prix, bonus_pop, bonus_inf, bonus_dis, label, louable, signature_serveur) VALUES ('centre-commercial', 'arriere_boutique', '*', '150', '2', '1', '0', 'Arrière-Boutique', 'true', 'true');
INSERT INTO public.locaux_loyers_referentiel (batiment, piece, ville, prix, bonus_pop, bonus_inf, bonus_dis, label, louable, signature_serveur) VALUES ('centre-commercial', 'boutique_milieu', '*', '400', '5', '3', '0', 'Boutique Milieu', 'true', 'true');
INSERT INTO public.locaux_loyers_referentiel (batiment, piece, ville, prix, bonus_pop, bonus_inf, bonus_dis, label, louable, signature_serveur) VALUES ('centre-commercial', 'cave_reserve', '*', '80', '0', '1', '5', 'Cave / Réserve', 'true', 'true');
INSERT INTO public.locaux_loyers_referentiel (batiment, piece, ville, prix, bonus_pop, bonus_inf, bonus_dis, label, louable, signature_serveur) VALUES ('centre-commercial', 'vitrine_principale', '*', '800', '10', '5', '0', 'Vitrine Principale', 'true', 'true');
INSERT INTO public.locaux_loyers_referentiel (batiment, piece, ville, prix, bonus_pop, bonus_inf, bonus_dis, label, louable, signature_serveur) VALUES ('hotel-republica', 'suite_presidentielle', '*', '500', '8', '8', '2', 'Suite Présidentielle', 'true', 'true');
INSERT INTO public.locaux_loyers_referentiel (batiment, piece, ville, prix, bonus_pop, bonus_inf, bonus_dis, label, louable, signature_serveur) VALUES ('hotel-republica', 'suite_privee', '*', '500', '0', '8', '10', 'Suite Privée', 'true', 'true');
INSERT INTO public.locaux_loyers_referentiel (batiment, piece, ville, prix, bonus_pop, bonus_inf, bonus_dis, label, louable, signature_serveur) VALUES ('port-sainte-marie', 'box-portuaire', '*', '15', '0', '0', '0', 'Box portuaire', 'true', 'false');
