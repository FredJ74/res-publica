-- SEED -- terrains_referentiel
-- ============================================================================
-- Table      : public.terrains_referentiel
-- Domaine    : immobilier et territoire
-- Categorie  : B (contenu initial d'empire)
-- Strategie  : seed_complet (classification du chantier 2C)
-- Lignes     : 36
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

INSERT INTO public.terrains_referentiel (pays, ville, batiment, surface, prix_achat) VALUES ('khalija', 'capitale', 'terrain-a-batir-1', '2150', '25800');
INSERT INTO public.terrains_referentiel (pays, ville, batiment, surface, prix_achat) VALUES ('khalija', 'capitale', 'terrain-a-batir-4', '1850', '22200');
INSERT INTO public.terrains_referentiel (pays, ville, batiment, surface, prix_achat) VALUES ('khalija', 'capitale', 'terrain-a-batir-5', '2750', '33000');
INSERT INTO public.terrains_referentiel (pays, ville, batiment, surface, prix_achat) VALUES ('khalija', 'capitale', 'terrain-a-batir-6', NULL, '25000');
INSERT INTO public.terrains_referentiel (pays, ville, batiment, surface, prix_achat) VALUES ('khalija', 'capitale', 'terrain-a-batir-7', NULL, '25000');
INSERT INTO public.terrains_referentiel (pays, ville, batiment, surface, prix_achat) VALUES ('khalija', 'ville_a', 'terrain-a-batir-3', '2300', '27600');
INSERT INTO public.terrains_referentiel (pays, ville, batiment, surface, prix_achat) VALUES ('khalija', 'ville_b', 'terrain-a-batir-2', '2300', '27600');
INSERT INTO public.terrains_referentiel (pays, ville, batiment, surface, prix_achat) VALUES ('narco', 'capitale', 'terrain-a-batir-1', '2150', '25800');
INSERT INTO public.terrains_referentiel (pays, ville, batiment, surface, prix_achat) VALUES ('narco', 'capitale', 'terrain-a-batir-4', '1850', '22200');
INSERT INTO public.terrains_referentiel (pays, ville, batiment, surface, prix_achat) VALUES ('narco', 'capitale', 'terrain-a-batir-5', '2750', '33000');
INSERT INTO public.terrains_referentiel (pays, ville, batiment, surface, prix_achat) VALUES ('narco', 'capitale', 'terrain-a-batir-6', NULL, '25000');
INSERT INTO public.terrains_referentiel (pays, ville, batiment, surface, prix_achat) VALUES ('narco', 'capitale', 'terrain-a-batir-7', NULL, '25000');
INSERT INTO public.terrains_referentiel (pays, ville, batiment, surface, prix_achat) VALUES ('narco', 'ville_a', 'terrain-a-batir-3', '2300', '27600');
INSERT INTO public.terrains_referentiel (pays, ville, batiment, surface, prix_achat) VALUES ('narco', 'ville_b', 'terrain-a-batir-2', '2300', '27600');
INSERT INTO public.terrains_referentiel (pays, ville, batiment, surface, prix_achat) VALUES ('republic', 'capitale', 'terrain-a-batir-1', '2150', '25800');
INSERT INTO public.terrains_referentiel (pays, ville, batiment, surface, prix_achat) VALUES ('republic', 'capitale', 'terrain-a-batir-2', '2300', '27600');
INSERT INTO public.terrains_referentiel (pays, ville, batiment, surface, prix_achat) VALUES ('republic', 'capitale', 'terrain-a-batir-3', '2300', '27600');
INSERT INTO public.terrains_referentiel (pays, ville, batiment, surface, prix_achat) VALUES ('republic', 'capitale', 'terrain-a-batir-4', '1850', '22200');
INSERT INTO public.terrains_referentiel (pays, ville, batiment, surface, prix_achat) VALUES ('republic', 'capitale', 'terrain-a-batir-5', '2750', '33000');
INSERT INTO public.terrains_referentiel (pays, ville, batiment, surface, prix_achat) VALUES ('republic', 'ville_a', 'terrain-a-batir-10', NULL, '3500');
INSERT INTO public.terrains_referentiel (pays, ville, batiment, surface, prix_achat) VALUES ('republic', 'ville_a', 'terrain-a-batir-11', NULL, '3500');
INSERT INTO public.terrains_referentiel (pays, ville, batiment, surface, prix_achat) VALUES ('republic', 'ville_a', 'terrain-a-batir-8', NULL, '3500');
INSERT INTO public.terrains_referentiel (pays, ville, batiment, surface, prix_achat) VALUES ('republic', 'ville_a', 'terrain-a-batir-9', NULL, '3500');
INSERT INTO public.terrains_referentiel (pays, ville, batiment, surface, prix_achat) VALUES ('republic', 'ville_b', 'terrain-a-batir-6', NULL, '25000');
INSERT INTO public.terrains_referentiel (pays, ville, batiment, surface, prix_achat) VALUES ('republic', 'ville_b', 'terrain-a-batir-montrouge-12', '3000', '36000');
INSERT INTO public.terrains_referentiel (pays, ville, batiment, surface, prix_achat) VALUES ('republic', 'ville_b', 'terrain-a-batir-montrouge-3', '1500', '18000');
INSERT INTO public.terrains_referentiel (pays, ville, batiment, surface, prix_achat) VALUES ('republic', 'ville_b', 'terrain-a-batir-montrouge-7', '1800', '21600');
INSERT INTO public.terrains_referentiel (pays, ville, batiment, surface, prix_achat) VALUES ('republic', 'ville_b', 'terrain-a-batir-montrouge-8', '2200', '26400');
INSERT INTO public.terrains_referentiel (pays, ville, batiment, surface, prix_achat) VALUES ('republic', 'ville_b', 'terrain-a-batir-montrouge-9', '2500', '30000');
INSERT INTO public.terrains_referentiel (pays, ville, batiment, surface, prix_achat) VALUES ('soviet', 'capitale', 'terrain-a-batir-1', '2150', '25800');
INSERT INTO public.terrains_referentiel (pays, ville, batiment, surface, prix_achat) VALUES ('soviet', 'capitale', 'terrain-a-batir-4', '1850', '22200');
INSERT INTO public.terrains_referentiel (pays, ville, batiment, surface, prix_achat) VALUES ('soviet', 'capitale', 'terrain-a-batir-5', '2750', '33000');
INSERT INTO public.terrains_referentiel (pays, ville, batiment, surface, prix_achat) VALUES ('soviet', 'capitale', 'terrain-a-batir-6', NULL, '25000');
INSERT INTO public.terrains_referentiel (pays, ville, batiment, surface, prix_achat) VALUES ('soviet', 'capitale', 'terrain-a-batir-7', NULL, '25000');
INSERT INTO public.terrains_referentiel (pays, ville, batiment, surface, prix_achat) VALUES ('soviet', 'ville_a', 'terrain-a-batir-3', '2300', '27600');
INSERT INTO public.terrains_referentiel (pays, ville, batiment, surface, prix_achat) VALUES ('soviet', 'ville_b', 'terrain-a-batir-2', '2300', '27600');
