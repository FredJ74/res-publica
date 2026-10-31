-- SEED -- tracts_pnj_catalogue
-- ============================================================================
-- Table      : public.tracts_pnj_catalogue
-- Domaine    : presse
-- Categorie  : B (contenu initial d'empire)
-- Strategie  : seed_complet (classification du chantier 2C)
-- Lignes     : 189
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

INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'capitale', 'assemblee', 'accueil_assemblee', 'Garde Republicain', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'capitale', 'assemblee', 'accueil_assemblee', 'Hotesse Accueil', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'capitale', 'assemblee', 'accueil_assemblee', 'Renée Toitout', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'capitale', 'assemblee', 'couloirs', 'Journaliste Blanc', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'capitale', 'assemblee', 'couloirs', 'Lobbyiste Perrin', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'capitale', 'assemblee', 'salle_archives_assemblee', 'Archiviste Parlementaire', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'capitale', 'banque-nationale', 'accueil_banque', 'Laurent Barre', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'capitale', 'bureau-national-emploi', 'accueil', 'Jean-Lou Zeure', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'capitale', 'centre-affaires', 'hall', 'Gretta Délieu', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'capitale', 'centre-affaires', 'hall', 'Harry Cover', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'capitale', 'centre-affaires', 'hall', 'Moshe Maychan', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'capitale', 'centre-affaires', 'tribune_republia', 'Correspondant Local', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'capitale', 'centre-artisanal', 'travees', 'Céd'' Labone', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'capitale', 'centre-artisanal', 'travees', 'Henrico Stot', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'capitale', 'centre-artisanal', 'travees', 'Sabri Coledur', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'capitale', 'centre-commercial', 'hall', 'Edgar Simore', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'capitale', 'centre-commercial', 'hall', 'Francisca Brel', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'capitale', 'centre-multinodal-luthecia', 'hall_douanes', 'Inspecteur Prosper Tampon', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'capitale', 'centre-multinodal-luthecia', 'hall_gare', 'Gaston Retard', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'capitale', 'centre-multinodal-luthecia', 'hall_gare', 'Mireille Guichet', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'capitale', 'commissariat', 'bureau_commissaire', 'Brigitte Menottes', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'capitale', 'commissariat', 'bureau_commissaire', 'Raoul Toufaud', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'capitale', 'commissariat', 'prison', 'Gardien Dubois', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'capitale', 'commissariat', 'prison', 'Tristan Cabane', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'capitale', 'dispensaire-public', 'ehpad_tilleuls', 'Jeanine Dubois', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'capitale', 'dispensaire-public', 'ehpad_tilleuls', 'Louis Chevillard', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'capitale', 'dispensaire-public', 'ehpad_tilleuls', 'Noël Chauchay', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'capitale', 'entrepot-logistique-luthecia', 'bureau_direction', 'Marcel Silo', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'capitale', 'hotel-republica', 'accueil', 'Isidore Trébien', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'capitale', 'hotel-republica', 'accueil', 'Nathalie Ondor', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'capitale', 'hotel-republica', 'bar', 'L''hôte de l''agence', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'capitale', 'hotel-republica', 'bar', 'L''hôtesse de l''agence', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'capitale', 'hotel-republica', 'bar', 'Marc Hantile', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'capitale', 'hotel-republica', 'bar', 'Marco (Barman)', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'capitale', 'hotel-republica', 'restaurant', 'Gaston Sauceblanche', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'capitale', 'hotel-republica', 'restaurant', 'Jean Dupont', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'capitale', 'hotel-republica', 'restaurant', 'Marie Leblanc', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'capitale', 'hotel-republica', 'restaurant', 'Régis Gondasse', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'capitale', 'hotel-republica', 'restaurant', 'Yvette Gratinée', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'capitale', 'la-tribune', 'redaction', 'Marie Leblanc', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'capitale', 'la-tribune', 'redaction', 'Romain Castel', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'capitale', 'loge-maconnique', 'bureau_venerable', 'Venerable Maitre Duval', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'capitale', 'loge-maconnique', 'hall_loge', 'Frere Gardien', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'capitale', 'mairie-capitale', 'bureau_maire', 'Le Maire de Luthecia', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'capitale', 'mairie-capitale', 'hall_mairie', 'Hotesse Objets Trouves', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'capitale', 'mairie-capitale', 'hall_mairie', 'Le Maire', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'capitale', 'mairie-capitale', 'hall_mairie', 'Secretaire Municipal Petit', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'capitale', 'mairie-capitale', 'salle_archives', 'Christophe Bouquin', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'capitale', 'mairie-capitale', 'salle_elections', 'Responsable Electoral', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'capitale', 'musee-ville-luthecia', 'hall', 'Gérard Poinçon', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'capitale', 'musee-ville-luthecia', 'hall', 'Valérie Loisillon', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'capitale', 'office-notarial', 'accueil_notaire', 'Alain Dex', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'capitale', 'office-notarial', 'accueil_notaire', 'Claire Delhune', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'capitale', 'office-notarial', 'archives_notariales', 'Archiviste Notarial', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'capitale', 'office-notarial', 'bureau_contrats', 'Notaire Fontenelle', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'capitale', 'office-notarial', 'bureau_successions', 'Claire Delhune', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'capitale', 'palais-gouvernement', 'archives_gouv', 'Archiviste Legrand', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'capitale', 'palais-gouvernement', 'bureau_min_ae', 'Jean-Jacques Carlin', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'capitale', 'palais-gouvernement', 'bureau_min_def', 'Martial Bouterin', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'capitale', 'palais-gouvernement', 'bureau_min_fin', 'Alain Théret', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'capitale', 'palais-gouvernement', 'bureau_min_info', 'Marie-Eve Beaulieu', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'capitale', 'palais-gouvernement', 'bureau_min_int', 'Yvan Danltat', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'capitale', 'palais-gouvernement', 'bureau_min_just', 'Mathilde Garde', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'capitale', 'palais-gouvernement', 'bureaux', 'Éric Stricted', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'capitale', 'palais-gouvernement', 'hall', 'Garde Republicain', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'capitale', 'palais-gouvernement', 'hall', 'Secretaire Dupuis', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'capitale', 'palais-gouvernement', 'salle_presse', 'Corinne Tite-Déclaz', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'capitale', 'palais-presidentiel', 'accueil_elysee', 'Garde Republicain', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'capitale', 'palais-presidentiel', 'accueil_elysee', 'Gérard Tamponneau', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'capitale', 'palais-presidentiel', 'bureau_president', 'Huguette Papier', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'capitale', 'palais-presidentiel', 'bureau_president', 'Le Président', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'capitale', 'palais-presidentiel', 'salle_presse_elysee', 'Porte-parole presidentiel', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'capitale', 'palais-presidentiel', 'salle_reception', 'Gérard Tamponneau', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'capitale', 'parc-botanique-national', 'parc', 'Florian Grès', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'capitale', 'parc-botanique-national', 'serre', 'Jean-Pierre Ciseaux', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'capitale', 'place-formulaire-liberte', 'place', 'Pat Hounette', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'capitale', 'quartier-ambassades', 'accueil_ambassades', 'Agent de Sécurité', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'capitale', 'quartier-ambassades', 'accueil_ambassades', 'Hôtesse d''Accueil', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'capitale', 'stade', 'buvette', 'Jean Fourtout', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'capitale', 'stade', 'buvette', 'Justin Verre', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'capitale', 'stade', 'guichet_paris', 'Ricardo Pif', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'capitale', 'stade', 'siege_supporters', 'Alfredo Mifassole', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'capitale', 'stade', 'terrain', 'Jean-Pierre Taclojnou', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'capitale', 'stade', 'terrain', 'Michel Parlotte', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'capitale', 'stade', 'vestiaires', 'Alphonse Toudroit', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'capitale', 'tabernacle-impots', 'nef_principale', 'Enfant de chœur Lacroix', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'capitale', 'tabernacle-impots', 'nef_principale', 'Père Ception', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'capitale', 'tabernacle-impots', 'sacristie', 'Père Ception', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'capitale', 'tribunal', 'greffe', 'Greffier Petit', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'capitale', 'usine-pharmaceutique-luthecia', 'bureau_direction', 'Bernard Piluler', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'ville_a', 'banque-locale', 'guichet', 'Guichetier', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'ville_a', 'bar-des-pecheurs', 'salle_bar', 'Jean-Lou Demer', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'ville_a', 'bar-des-pecheurs', 'salle_bar', 'Marin Dulac', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'ville_a', 'bar-des-pecheurs', 'salle_bar', 'René Seigne', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'ville_a', 'capitaine-sauvage', 'salle_principale', 'Marine Leroux', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'ville_a', 'centre-affaires', 'hall', 'Gretta Délieu', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'ville_a', 'centre-affaires', 'hall', 'Harry Cover', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'ville_a', 'centre-affaires', 'hall', 'Moshe Maychan', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'ville_a', 'centre-affaires', 'tribune_republia', 'Correspondant Local', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'ville_a', 'centre-artisanal', 'travees', 'Céd'' Labone', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'ville_a', 'centre-artisanal', 'travees', 'Henrico Stot', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'ville_a', 'centre-artisanal', 'travees', 'Sabri Coledur', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'ville_a', 'centre-commercial', 'hall', 'Edgar Simore', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'ville_a', 'centre-commercial', 'hall', 'Francisca Brel', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'ville_a', 'centre-multinodal-port-sainte-marie', 'hall_gare_psm', 'Chef de Gare Local', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'ville_a', 'chantier-naval', 'bureau', 'Pierrick Le Roux', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'ville_a', 'chasse-peche-psm', 'boutique', 'Victor Legall', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'ville_a', 'commissariat-local', 'accueil_loc', 'Brigadier Local', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'ville_a', 'commissariat-local', 'geoles', 'Loïc Karamel', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'ville_a', 'dispensaire-public-v', 'attente', 'Infirmiere', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'ville_a', 'ecole-marine', 'hall', 'Maxime Bonvent', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'ville_a', 'entrepot-logistique-psm', 'bureau_direction', 'Yvon Paletier', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'ville_a', 'hotel-port', 'hall_port', 'Jeanine Debré', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'ville_a', 'imprimerie-librairie', 'accueil_imprimerie', 'Annie Talique-Legall', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'ville_a', 'imprimerie-librairie', 'atelier', 'Ouvrier typographe', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'ville_a', 'mairie', 'accueil_mairie', 'Secretaire Municipal', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'ville_a', 'mairie', 'bureau_maire_local', 'Le Maire', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'ville_a', 'marche-psm', 'etals', 'Bastien Leroux', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'ville_a', 'marche-psm', 'etals', 'Mireille Legall', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'ville_a', 'musee-port-sainte-marie', 'hall', 'Marcel Kermeur', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'ville_a', 'musee-port-sainte-marie', 'hall', 'Soizic Le Gall', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'ville_a', 'musee-port-sainte-marie', 'hall', 'Yvon Le Gall', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'ville_a', 'musee-port-sainte-marie', 'salle_criminels', 'Marcel Kermeur', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'ville_a', 'musee-port-sainte-marie', 'salle_entrepreneurs', 'Marcel Kermeur', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'ville_a', 'musee-port-sainte-marie', 'salle_honneur_militaire', 'Marcel Kermeur', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'ville_a', 'musee-port-sainte-marie', 'salle_maires', 'Marcel Kermeur', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'ville_a', 'musee-port-sainte-marie', 'salle_organisations', 'Marcel Kermeur', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'ville_a', 'musee-port-sainte-marie', 'salle_personnalites', 'Marcel Kermeur', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'ville_a', 'musee-port-sainte-marie', 'salle_plumes', 'Marcel Kermeur', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'ville_a', 'musee-port-sainte-marie', 'salle_scandales', 'Marcel Kermeur', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'ville_a', 'musee-port-sainte-marie', 'salle_unions', 'Marcel Kermeur', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'ville_a', 'pole-tabac-alcools-psm', 'bureau_direction', 'Fernand Cendrier', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'ville_a', 'port-plaisance-psm', 'capitainerie', 'Patrice Lecap', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'ville_a', 'port-sainte-marie', 'administration_portuaire', 'Ginette Conteneur', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'ville_a', 'port-sainte-marie', 'administration_portuaire', 'Marcel Ancre', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'ville_a', 'port-sainte-marie', 'bureau_syndical_dockers', 'Dédé le Docker', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'ville_a', 'port-sainte-marie', 'bureau_syndical_dockers', 'Étienne Dantafasse', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'ville_a', 'port-sainte-marie', 'douanes', 'Pascal Paguevite', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'ville_a', 'port-sainte-marie', 'quai_principal', 'Alain Bordage', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'ville_a', 'stade', 'buvette', 'Tenancier de Buvette', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'ville_a', 'stade', 'guichet_paris', 'Bookmaker Officiel', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'ville_a', 'stade', 'siege_supporters', 'Lucas Ténaire', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'ville_a', 'stade', 'siege_supporters', 'Pascal Hamar', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'ville_a', 'stade', 'terrain', 'Émilie Charbon', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'ville_a', 'stade', 'terrain', 'Jean-Philippe Hervitmonfute', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'ville_a', 'stade', 'terrain', 'Maurice Éhault', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'ville_a', 'stade', 'vestiaires', 'Gérard Bricoleau', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'ville_a', 'stade', 'vestiaires', 'Thibault Gosse', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'ville_a', 'tribunal-local', 'salle_audience_locale', 'Maître Ali Bihanbéton', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'ville_a', 'tribunal-local', 'salle_audience_locale', 'Mireille Sedlex', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'ville_a', 'zone-production', 'zone_recolte', 'Guy Tarembois', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'ville_b', 'armurerie', 'magasin', 'Gerard (Armurier)', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'ville_b', 'banque-locale', 'guichet', 'Guichetier', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'ville_b', 'centre-affaires', 'hall', 'Gretta Délieu', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'ville_b', 'centre-affaires', 'hall', 'Harry Cover', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'ville_b', 'centre-affaires', 'hall', 'Moshe Maychan', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'ville_b', 'centre-affaires', 'tribune_republia', 'Correspondant Local', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'ville_b', 'centre-artisanal', 'travees', 'Céd'' Labone', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'ville_b', 'centre-artisanal', 'travees', 'Henrico Stot', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'ville_b', 'centre-artisanal', 'travees', 'Sabri Coledur', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'ville_b', 'centre-commercial', 'hall', 'Edgar Simore', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'ville_b', 'centre-commercial', 'hall', 'Francisca Brel', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'ville_b', 'centre-multinodal-montrouge', 'hall_gare_montrouge', 'Chef de Gare Syndiqué', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'ville_b', 'centre-multinodal-montrouge', 'hall_gare_montrouge', 'Délégué Syndical', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'ville_b', 'commissariat-local', 'accueil_loc', 'Brigadier Local', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'ville_b', 'dispensaire-public-v', 'attente', 'Agnès Thésie', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'ville_b', 'entrepot-logistique-montrouge', 'bureau_direction', 'Norbert Charton', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'ville_b', 'hotel-mineur', 'hall_mineur', 'Receptionniste', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'ville_b', 'la-tribune', 'redaction', 'Marie Leblanc', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'ville_b', 'la-tribune', 'redaction', 'Romain Castel', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'ville_b', 'loge-maconnique', 'bureau_venerable', 'Venerable Maitre Duval', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'ville_b', 'loge-maconnique', 'hall_loge', 'Frere Gardien', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'ville_b', 'loge-maconnique', 'portail', 'Le Portier', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'ville_b', 'mairie', 'accueil_mairie', 'Secretaire Municipal', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'ville_b', 'mairie', 'bureau_maire_local', 'Le Maire', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'ville_b', 'raffinerie-montrouge', 'bureau_direction', 'Gustave Baril', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'ville_b', 'siege-syndical', 'bureau_syndical', 'Delegue Morel', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'ville_b', 'stade', 'buvette', 'Tenancier de Buvette', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'ville_b', 'stade', 'guichet_paris', 'Bookmaker Officiel', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'ville_b', 'stade', 'siege_supporters', 'Lucas Ténaire', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'ville_b', 'stade', 'siege_supporters', 'Pascal Hamar', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'ville_b', 'stade', 'terrain', 'Émilie Charbon', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'ville_b', 'stade', 'terrain', 'Jean-Philippe Hervitmonfute', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'ville_b', 'stade', 'terrain', 'Maurice Éhault', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'ville_b', 'stade', 'vestiaires', 'Gérard Bricoleau', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'ville_b', 'stade', 'vestiaires', 'Thibault Gosse', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'ville_b', 'tribunal-local', 'salle_audience_locale', 'Gérard Bretellewood', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'ville_b', 'tribunal-local', 'salle_audience_locale', 'Maître Henri Nossant', '10');
INSERT INTO public.tracts_pnj_catalogue (pays, ville, building_id, room_id, nom, car_vol) VALUES ('republic', 'ville_b', 'usine-principale', 'direction_usine', 'Directeur Fabre', '10');
