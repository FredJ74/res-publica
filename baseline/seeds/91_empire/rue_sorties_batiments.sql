-- SEED -- rue_sorties_batiments
-- ============================================================================
-- Table      : public.rue_sorties_batiments
-- Domaine    : socle
-- Categorie  : B (contenu initial d'empire)
-- Strategie  : seed_complet (classification du chantier 2C)
-- Lignes     : 110
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

INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'capitale', 'luthecia-armurerie', 'armurerie');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'capitale', 'luthecia-bureau-emploi', 'bureau-national-emploi');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'capitale', 'luthecia-centre-commercial', 'centre-affaires');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'capitale', 'luthecia-centre-commercial', 'centre-commercial');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'capitale', 'luthecia-centre-multimodal', 'centre-multinodal-luthecia');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'capitale', 'luthecia-entrepot-logistique', 'entrepot-logistique-luthecia');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'capitale', 'luthecia-hotel-de-ville', 'banque-nationale');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'capitale', 'luthecia-hotel-de-ville', 'hotel-republica');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'capitale', 'luthecia-hotel-de-ville', 'mairie-capitale');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'capitale', 'luthecia-hotel-de-ville', 'office-notarial');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'capitale', 'luthecia-imprimerie', 'dispensaire-public');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'capitale', 'luthecia-imprimerie', 'la-tribune');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'capitale', 'luthecia-imprimerie', 'universite');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'capitale', 'luthecia-loge', 'banque-privee');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'capitale', 'luthecia-loge', 'clinique-privee');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'capitale', 'luthecia-loge', 'commissariat');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'capitale', 'luthecia-loge', 'loge-maconnique');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'capitale', 'luthecia-musees', 'musee-national-republia');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'capitale', 'luthecia-musees', 'musee-ville-luthecia');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'capitale', 'luthecia-musees', 'parc-botanique-national');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'capitale', 'luthecia-palais-presidentiel', 'assemblee');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'capitale', 'luthecia-palais-presidentiel', 'palais-gouvernement');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'capitale', 'luthecia-palais-presidentiel', 'palais-presidentiel');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'capitale', 'luthecia-palais-presidentiel', 'tribunal');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'capitale', 'luthecia-quartier-ambassades', 'quartier-ambassades');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'capitale', 'luthecia-stade-multimodal', 'place-formulaire-liberte');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'capitale', 'luthecia-stade-multimodal', 'stade');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'capitale', 'luthecia-tabernacle-impots', 'marche');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'capitale', 'luthecia-tabernacle-impots', 'tabernacle-impots');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'capitale', 'luthecia-terrains-artisanal', 'centre-artisanal');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'capitale', 'luthecia-terrains-lots', 'terrain-a-batir-1');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'capitale', 'luthecia-terrains-lots', 'terrain-a-batir-2');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'capitale', 'luthecia-terrains-lots', 'terrain-a-batir-3');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'capitale', 'luthecia-terrains-lots', 'terrain-a-batir-4');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'capitale', 'luthecia-terrains-lots', 'terrain-a-batir-5');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'capitale', 'luthecia-usine-pharmaceutique', 'usine-pharmaceutique-luthecia');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'ville_a', 'psm-bar-imprimerie-commissariat', 'bar-des-pecheurs');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'ville_a', 'psm-bar-imprimerie-commissariat', 'commissariat-local');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'ville_a', 'psm-bar-imprimerie-commissariat', 'imprimerie-librairie');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'ville_a', 'psm-carrefour-artisanal-scierie', 'centre-artisanal');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'ville_a', 'psm-carrefour-artisanal-scierie', 'zone-production');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'ville_a', 'psm-carrefour-musee', 'centre-affaires');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'ville_a', 'psm-carrefour-musee', 'centre-commercial');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'ville_a', 'psm-carrefour-musee', 'musee-port-sainte-marie');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'ville_a', 'psm-centre-multimodal', 'centre-multinodal-port-sainte-marie');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'ville_a', 'psm-centre-multimodal', 'port-sainte-marie');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'ville_a', 'psm-centre-multimodal', 'stade');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'ville_a', 'psm-chantier-naval', 'chantier-naval');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'ville_a', 'psm-dispensaire-port-plaisance', 'dispensaire-public-v');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'ville_a', 'psm-dispensaire-port-plaisance', 'port-plaisance-psm');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'ville_a', 'psm-ecole-phare', 'ecole-marine');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'ville_a', 'psm-ecole-phare', 'phare-psm');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'ville_a', 'psm-eglise-cimetiere', 'notre-dame-mer');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'ville_a', 'psm-hotel-mairie-place', 'hotel-port');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'ville_a', 'psm-hotel-mairie-place', 'mairie');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'ville_a', 'psm-hotel-mairie-place', 'place-armes-psm');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'ville_a', 'psm-marche-resto-chasse', 'capitaine-sauvage');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'ville_a', 'psm-marche-resto-chasse', 'chasse-peche-psm');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'ville_a', 'psm-marche-resto-chasse', 'marche-psm');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'ville_a', 'psm-pole-tabac-entrepot', 'entrepot-logistique-psm');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'ville_a', 'psm-pole-tabac-entrepot', 'pole-tabac-alcools-psm');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'ville_a', 'psm-terrains-lots', 'caserne-militaire');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'ville_a', 'psm-terrains-lots', 'qhs-prison');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'ville_a', 'psm-terrains-lots', 'terrain-a-batir-10');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'ville_a', 'psm-terrains-lots', 'terrain-a-batir-11');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'ville_a', 'psm-terrains-lots', 'terrain-a-batir-8');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'ville_a', 'psm-terrains-lots', 'terrain-a-batir-9');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'ville_a', 'psm-tribunal-banque', 'banque-locale');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'ville_a', 'psm-tribunal-banque', 'tribunal-local');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'ville_b', 'montrouge-vue-1', 'armurerie');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'ville_b', 'montrouge-vue-1', 'hotel-mineur');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'ville_b', 'montrouge-vue-10', 'cinema-montrouge');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'ville_b', 'montrouge-vue-10', 'la-tribune');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'ville_b', 'montrouge-vue-11', 'centre-artisanal');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'ville_b', 'montrouge-vue-12', 'jardins-ouvriers-montrouge');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'ville_b', 'montrouge-vue-12', 'logements-montrouge');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'ville_b', 'montrouge-vue-13', '...');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'ville_b', 'montrouge-vue-13', 'armurerie');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'ville_b', 'montrouge-vue-13', 'cafe-tabac-cheminots-montrouge');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'ville_b', 'montrouge-vue-13', 'centre-affaires');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'ville_b', 'montrouge-vue-13', 'centre-artisanal');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'ville_b', 'montrouge-vue-13', 'centre-commercial');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'ville_b', 'montrouge-vue-13', 'centre-multinodal-luthecia');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'ville_b', 'montrouge-vue-13', 'clinique-privee');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'ville_b', 'montrouge-vue-13', 'commissariat');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'ville_b', 'montrouge-vue-13', 'dispensaire-public');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'ville_b', 'montrouge-vue-13', 'hotel-republica');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'ville_b', 'montrouge-vue-13', 'kolkhoze-spirituel');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'ville_b', 'montrouge-vue-13', 'la-tribune');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'ville_b', 'montrouge-vue-13', 'marche');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'ville_b', 'montrouge-vue-13', 'office-notarial');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'ville_b', 'montrouge-vue-13', 'palais-gouvernement');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'ville_b', 'montrouge-vue-13', 'stade');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'ville_b', 'montrouge-vue-13', 'tribunal');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'ville_b', 'montrouge-vue-2', 'commissariat-local');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'ville_b', 'montrouge-vue-2', 'raffinerie-montrouge');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'ville_b', 'montrouge-vue-3', 'brasserie-voyageurs-montrouge');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'ville_b', 'montrouge-vue-3', 'cafe-gare-montrouge');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'ville_b', 'montrouge-vue-3', 'centre-multinodal-montrouge');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'ville_b', 'montrouge-vue-4', 'dispensaire-public-v');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'ville_b', 'montrouge-vue-4', 'entrepot-logistique-montrouge');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'ville_b', 'montrouge-vue-5', 'stade');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'ville_b', 'montrouge-vue-6', 'centre-affaires');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'ville_b', 'montrouge-vue-6', 'centre-commercial');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'ville_b', 'montrouge-vue-7', 'mairie');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'ville_b', 'montrouge-vue-7', 'place-du-rail-montrouge');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'ville_b', 'montrouge-vue-8', 'banque-locale');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'ville_b', 'montrouge-vue-8', 'musee-histoire-montrouge');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'ville_b', 'montrouge-vue-9', 'eglise-montrouge');
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building) VALUES ('republic', 'ville_b', 'montrouge-vue-9', 'loge-maconnique');
