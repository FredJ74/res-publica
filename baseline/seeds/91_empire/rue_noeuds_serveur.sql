-- SEED -- rue_noeuds_serveur
-- ============================================================================
-- Table      : public.rue_noeuds_serveur
-- Domaine    : socle
-- Categorie  : B (contenu initial d'empire)
-- Strategie  : seed_complet (classification du chantier 2C)
-- Lignes     : 44
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

INSERT INTO public.rue_noeuds_serveur (country, city, noeud, voisins) VALUES ('republic', 'capitale', 'luthecia-armurerie', '{luthecia-tabernacle-impots,luthecia-terrains-artisanal}');
INSERT INTO public.rue_noeuds_serveur (country, city, noeud, voisins) VALUES ('republic', 'capitale', 'luthecia-bureau-emploi', '{luthecia-quartier-ambassades,luthecia-terrains-artisanal}');
INSERT INTO public.rue_noeuds_serveur (country, city, noeud, voisins) VALUES ('republic', 'capitale', 'luthecia-centre-commercial', '{luthecia-terrains-artisanal,luthecia-intersection-stade-commercial}');
INSERT INTO public.rue_noeuds_serveur (country, city, noeud, voisins) VALUES ('republic', 'capitale', 'luthecia-centre-multimodal', '{luthecia-usine-pharmaceutique,luthecia-entrepot-logistique,luthecia-stade-multimodal}');
INSERT INTO public.rue_noeuds_serveur (country, city, noeud, voisins) VALUES ('republic', 'capitale', 'luthecia-entrepot-logistique', '{luthecia-centre-multimodal,luthecia-loge}');
INSERT INTO public.rue_noeuds_serveur (country, city, noeud, voisins) VALUES ('republic', 'capitale', 'luthecia-hotel-de-ville', '{luthecia-imprimerie,luthecia-loge}');
INSERT INTO public.rue_noeuds_serveur (country, city, noeud, voisins) VALUES ('republic', 'capitale', 'luthecia-imprimerie', '{luthecia-palais-presidentiel,luthecia-hotel-de-ville,luthecia-intersection-stade-commercial}');
INSERT INTO public.rue_noeuds_serveur (country, city, noeud, voisins) VALUES ('republic', 'capitale', 'luthecia-intersection-stade-commercial', '{luthecia-centre-commercial,luthecia-stade-multimodal,luthecia-musees,luthecia-imprimerie}');
INSERT INTO public.rue_noeuds_serveur (country, city, noeud, voisins) VALUES ('republic', 'capitale', 'luthecia-loge', '{luthecia-hotel-de-ville,luthecia-entrepot-logistique}');
INSERT INTO public.rue_noeuds_serveur (country, city, noeud, voisins) VALUES ('republic', 'capitale', 'luthecia-musees', '{luthecia-quartier-ambassades,luthecia-intersection-stade-commercial}');
INSERT INTO public.rue_noeuds_serveur (country, city, noeud, voisins) VALUES ('republic', 'capitale', 'luthecia-palais-presidentiel', '{luthecia-tabernacle-impots,luthecia-imprimerie}');
INSERT INTO public.rue_noeuds_serveur (country, city, noeud, voisins) VALUES ('republic', 'capitale', 'luthecia-quartier-ambassades', '{luthecia-bureau-emploi,luthecia-usine-pharmaceutique,luthecia-musees}');
INSERT INTO public.rue_noeuds_serveur (country, city, noeud, voisins) VALUES ('republic', 'capitale', 'luthecia-stade-multimodal', '{luthecia-centre-multimodal,luthecia-intersection-stade-commercial}');
INSERT INTO public.rue_noeuds_serveur (country, city, noeud, voisins) VALUES ('republic', 'capitale', 'luthecia-tabernacle-impots', '{luthecia-palais-presidentiel,luthecia-armurerie}');
INSERT INTO public.rue_noeuds_serveur (country, city, noeud, voisins) VALUES ('republic', 'capitale', 'luthecia-terrains-artisanal', '{luthecia-armurerie,luthecia-bureau-emploi,luthecia-centre-commercial,luthecia-terrains-lots}');
INSERT INTO public.rue_noeuds_serveur (country, city, noeud, voisins) VALUES ('republic', 'capitale', 'luthecia-terrains-lots', '{luthecia-terrains-artisanal}');
INSERT INTO public.rue_noeuds_serveur (country, city, noeud, voisins) VALUES ('republic', 'capitale', 'luthecia-usine-pharmaceutique', '{luthecia-quartier-ambassades,luthecia-centre-multimodal}');
INSERT INTO public.rue_noeuds_serveur (country, city, noeud, voisins) VALUES ('republic', 'ville_a', 'psm-bar-imprimerie-commissariat', '{psm-tribunal-banque,psm-marche-resto-chasse}');
INSERT INTO public.rue_noeuds_serveur (country, city, noeud, voisins) VALUES ('republic', 'ville_a', 'psm-carrefour-artisanal-scierie', '{psm-carrefour-musee,psm-centre-multimodal,psm-ecole-phare,psm-eglise-cimetiere,psm-pole-tabac-entrepot,psm-tribunal-banque}');
INSERT INTO public.rue_noeuds_serveur (country, city, noeud, voisins) VALUES ('republic', 'ville_a', 'psm-carrefour-musee', '{psm-ecole-phare,psm-eglise-cimetiere,psm-tribunal-banque,psm-carrefour-artisanal-scierie}');
INSERT INTO public.rue_noeuds_serveur (country, city, noeud, voisins) VALUES ('republic', 'ville_a', 'psm-centre-multimodal', '{psm-carrefour-artisanal-scierie,psm-ecole-phare}');
INSERT INTO public.rue_noeuds_serveur (country, city, noeud, voisins) VALUES ('republic', 'ville_a', 'psm-chantier-naval', '{psm-terrains-vente,psm-eglise-cimetiere}');
INSERT INTO public.rue_noeuds_serveur (country, city, noeud, voisins) VALUES ('republic', 'ville_a', 'psm-dispensaire-port-plaisance', '{psm-ecole-phare,psm-tribunal-banque}');
INSERT INTO public.rue_noeuds_serveur (country, city, noeud, voisins) VALUES ('republic', 'ville_a', 'psm-ecole-phare', '{psm-carrefour-artisanal-scierie,psm-carrefour-musee,psm-centre-multimodal,psm-dispensaire-port-plaisance}');
INSERT INTO public.rue_noeuds_serveur (country, city, noeud, voisins) VALUES ('republic', 'ville_a', 'psm-eglise-cimetiere', '{psm-carrefour-artisanal-scierie,psm-carrefour-musee,psm-chantier-naval,psm-hotel-mairie-place}');
INSERT INTO public.rue_noeuds_serveur (country, city, noeud, voisins) VALUES ('republic', 'ville_a', 'psm-hotel-mairie-place', '{psm-marche-resto-chasse,psm-eglise-cimetiere}');
INSERT INTO public.rue_noeuds_serveur (country, city, noeud, voisins) VALUES ('republic', 'ville_a', 'psm-marche-resto-chasse', '{psm-bar-imprimerie-commissariat,psm-hotel-mairie-place}');
INSERT INTO public.rue_noeuds_serveur (country, city, noeud, voisins) VALUES ('republic', 'ville_a', 'psm-pole-tabac-entrepot', '{psm-carrefour-artisanal-scierie,psm-terrains-vente}');
INSERT INTO public.rue_noeuds_serveur (country, city, noeud, voisins) VALUES ('republic', 'ville_a', 'psm-terrains-lots', '{psm-terrains-vente}');
INSERT INTO public.rue_noeuds_serveur (country, city, noeud, voisins) VALUES ('republic', 'ville_a', 'psm-terrains-vente', '{psm-pole-tabac-entrepot,psm-chantier-naval,psm-terrains-lots}');
INSERT INTO public.rue_noeuds_serveur (country, city, noeud, voisins) VALUES ('republic', 'ville_a', 'psm-tribunal-banque', '{psm-bar-imprimerie-commissariat,psm-carrefour-artisanal-scierie,psm-carrefour-musee,psm-dispensaire-port-plaisance}');
INSERT INTO public.rue_noeuds_serveur (country, city, noeud, voisins) VALUES ('republic', 'ville_b', 'montrouge-vue-1', '{montrouge-vue-5,montrouge-vue-6}');
INSERT INTO public.rue_noeuds_serveur (country, city, noeud, voisins) VALUES ('republic', 'ville_b', 'montrouge-vue-10', '{montrouge-vue-9,montrouge-vue-11}');
INSERT INTO public.rue_noeuds_serveur (country, city, noeud, voisins) VALUES ('republic', 'ville_b', 'montrouge-vue-11', '{montrouge-vue-10,montrouge-vue-12}');
INSERT INTO public.rue_noeuds_serveur (country, city, noeud, voisins) VALUES ('republic', 'ville_b', 'montrouge-vue-12', '{montrouge-vue-11,montrouge-vue-4}');
INSERT INTO public.rue_noeuds_serveur (country, city, noeud, voisins) VALUES ('republic', 'ville_b', 'montrouge-vue-13', '{montrouge-vue-3}');
INSERT INTO public.rue_noeuds_serveur (country, city, noeud, voisins) VALUES ('republic', 'ville_b', 'montrouge-vue-2', '{montrouge-vue-5,montrouge-vue-3}');
INSERT INTO public.rue_noeuds_serveur (country, city, noeud, voisins) VALUES ('republic', 'ville_b', 'montrouge-vue-3', '{montrouge-vue-2,montrouge-vue-4,montrouge-vue-13}');
INSERT INTO public.rue_noeuds_serveur (country, city, noeud, voisins) VALUES ('republic', 'ville_b', 'montrouge-vue-4', '{montrouge-vue-12,montrouge-vue-3}');
INSERT INTO public.rue_noeuds_serveur (country, city, noeud, voisins) VALUES ('republic', 'ville_b', 'montrouge-vue-5', '{montrouge-vue-1,montrouge-vue-2}');
INSERT INTO public.rue_noeuds_serveur (country, city, noeud, voisins) VALUES ('republic', 'ville_b', 'montrouge-vue-6', '{montrouge-vue-1,montrouge-vue-7}');
INSERT INTO public.rue_noeuds_serveur (country, city, noeud, voisins) VALUES ('republic', 'ville_b', 'montrouge-vue-7', '{montrouge-vue-6,montrouge-vue-8}');
INSERT INTO public.rue_noeuds_serveur (country, city, noeud, voisins) VALUES ('republic', 'ville_b', 'montrouge-vue-8', '{montrouge-vue-7,montrouge-vue-9}');
INSERT INTO public.rue_noeuds_serveur (country, city, noeud, voisins) VALUES ('republic', 'ville_b', 'montrouge-vue-9', '{montrouge-vue-8,montrouge-vue-10}');
