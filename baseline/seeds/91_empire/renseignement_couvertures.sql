-- SEED -- renseignement_couvertures
-- ============================================================================
-- Table      : public.renseignement_couvertures
-- Domaine    : renseignement
-- Categorie  : B (contenu initial d'empire)
-- Strategie  : seed_complet (classification du chantier 2C)
-- Lignes     : 48
--
-- Fichier GENERE par outils/baseline/seeds.py. Ne pas editer a la main.
-- Les litteraux sont ceux que PostgreSQL lui-meme a produits (quote_nullable) :
-- aucune regle d'echappement n'a ete reimplementee.
--
-- JUSTIFICATION DU SEED (chantier 2C)
-- 48 identites de couverture, pool par empire.
-- ============================================================================

INSERT INTO public.renseignement_couvertures (pays, nom, sexe) VALUES ('khalija', 'Farida Ben Mokhtar', 'F');
INSERT INTO public.renseignement_couvertures (pays, nom, sexe) VALUES ('khalija', 'Foued Al-Khali', 'H');
INSERT INTO public.renseignement_couvertures (pays, nom, sexe) VALUES ('khalija', 'Houda Ben Sassi', 'F');
INSERT INTO public.renseignement_couvertures (pays, nom, sexe) VALUES ('khalija', 'Leïla Ben Jaloud', 'F');
INSERT INTO public.renseignement_couvertures (pays, nom, sexe) VALUES ('khalija', 'Mourad Al-Chennoui', 'H');
INSERT INTO public.renseignement_couvertures (pays, nom, sexe) VALUES ('khalija', 'Nabil Ben Azzouz', 'H');
INSERT INTO public.renseignement_couvertures (pays, nom, sexe) VALUES ('khalija', 'Nadjma Al-Harouni', 'F');
INSERT INTO public.renseignement_couvertures (pays, nom, sexe) VALUES ('khalija', 'Rachid Ben Tayeb', 'H');
INSERT INTO public.renseignement_couvertures (pays, nom, sexe) VALUES ('khalija', 'Samira Al-Zahiri', 'F');
INSERT INTO public.renseignement_couvertures (pays, nom, sexe) VALUES ('khalija', 'Slimane Al-Faridi', 'H');
INSERT INTO public.renseignement_couvertures (pays, nom, sexe) VALUES ('khalija', 'Tarek Ben Hazem', 'H');
INSERT INTO public.renseignement_couvertures (pays, nom, sexe) VALUES ('khalija', 'Yasmina Al-Dibani', 'F');
INSERT INTO public.renseignement_couvertures (pays, nom, sexe) VALUES ('narco', 'Amparo Riestra', 'F');
INSERT INTO public.renseignement_couvertures (pays, nom, sexe) VALUES ('narco', 'Aurelio Pinzón', 'H');
INSERT INTO public.renseignement_couvertures (pays, nom, sexe) VALUES ('narco', 'Consuelo Barranco', 'F');
INSERT INTO public.renseignement_couvertures (pays, nom, sexe) VALUES ('narco', 'Dolores Vaquerín', 'F');
INSERT INTO public.renseignement_couvertures (pays, nom, sexe) VALUES ('narco', 'Esperanza Ordóñez', 'F');
INSERT INTO public.renseignement_couvertures (pays, nom, sexe) VALUES ('narco', 'Ignacio Vidalba', 'H');
INSERT INTO public.renseignement_couvertures (pays, nom, sexe) VALUES ('narco', 'José Bayamoréna', 'H');
INSERT INTO public.renseignement_couvertures (pays, nom, sexe) VALUES ('narco', 'Nicolás Berruga', 'H');
INSERT INTO public.renseignement_couvertures (pays, nom, sexe) VALUES ('narco', 'Pilar Monterroso', 'F');
INSERT INTO public.renseignement_couvertures (pays, nom, sexe) VALUES ('narco', 'Ramón Delgadillo', 'H');
INSERT INTO public.renseignement_couvertures (pays, nom, sexe) VALUES ('narco', 'Remedios Caldera', 'F');
INSERT INTO public.renseignement_couvertures (pays, nom, sexe) VALUES ('narco', 'Teodoro Escalante', 'H');
INSERT INTO public.renseignement_couvertures (pays, nom, sexe) VALUES ('republic', 'Colette Vasseur', 'F');
INSERT INTO public.renseignement_couvertures (pays, nom, sexe) VALUES ('republic', 'Damien Lavigne', 'H');
INSERT INTO public.renseignement_couvertures (pays, nom, sexe) VALUES ('republic', 'Émile Sauvageot', 'H');
INSERT INTO public.renseignement_couvertures (pays, nom, sexe) VALUES ('republic', 'Gilbert Ferrand', 'H');
INSERT INTO public.renseignement_couvertures (pays, nom, sexe) VALUES ('republic', 'Henriette Pommier', 'F');
INSERT INTO public.renseignement_couvertures (pays, nom, sexe) VALUES ('republic', 'Hubert Toussaint', 'H');
INSERT INTO public.renseignement_couvertures (pays, nom, sexe) VALUES ('republic', 'Josiane Marteau', 'F');
INSERT INTO public.renseignement_couvertures (pays, nom, sexe) VALUES ('republic', 'Lucien Marchand', 'H');
INSERT INTO public.renseignement_couvertures (pays, nom, sexe) VALUES ('republic', 'Madeleine Ferrier', 'F');
INSERT INTO public.renseignement_couvertures (pays, nom, sexe) VALUES ('republic', 'Régine Delcourt', 'F');
INSERT INTO public.renseignement_couvertures (pays, nom, sexe) VALUES ('republic', 'Roland Quesnel', 'H');
INSERT INTO public.renseignement_couvertures (pays, nom, sexe) VALUES ('republic', 'Solange Bertrand', 'F');
INSERT INTO public.renseignement_couvertures (pays, nom, sexe) VALUES ('soviet', 'Arkadi Lemenov', 'H');
INSERT INTO public.renseignement_couvertures (pays, nom, sexe) VALUES ('soviet', 'Galina Stroumina', 'F');
INSERT INTO public.renseignement_couvertures (pays, nom, sexe) VALUES ('soviet', 'Guennadi Vostrov', 'H');
INSERT INTO public.renseignement_couvertures (pays, nom, sexe) VALUES ('soviet', 'Iouri Bratsev', 'H');
INSERT INTO public.renseignement_couvertures (pays, nom, sexe) VALUES ('soviet', 'Irina Soulkova', 'F');
INSERT INTO public.renseignement_couvertures (pays, nom, sexe) VALUES ('soviet', 'Lioudmila Vareneva', 'F');
INSERT INTO public.renseignement_couvertures (pays, nom, sexe) VALUES ('soviet', 'Mikhaïl Sourenko', 'H');
INSERT INTO public.renseignement_couvertures (pays, nom, sexe) VALUES ('soviet', 'Nadia Berestova', 'F');
INSERT INTO public.renseignement_couvertures (pays, nom, sexe) VALUES ('soviet', 'Piotr Zabline', 'H');
INSERT INTO public.renseignement_couvertures (pays, nom, sexe) VALUES ('soviet', 'Tatiana Ovreïko', 'F');
INSERT INTO public.renseignement_couvertures (pays, nom, sexe) VALUES ('soviet', 'Vassili Tchoudine', 'H');
INSERT INTO public.renseignement_couvertures (pays, nom, sexe) VALUES ('soviet', 'Zoïa Malinova', 'F');
