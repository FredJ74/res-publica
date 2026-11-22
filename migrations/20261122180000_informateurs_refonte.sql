-- REFONTE DES INFORMATEURS (décisions de Fred du 19/11/2026, GAME-DESIGN-INFORMATEURS-20261121.md ; étape K du 22/11/2026).
-- Règles consignées dans GAME-DESIGN-CRIMINALITE.md, « Barème commun des informateurs ».
-- 1. « Recruter un informateur » (150 par jour) et les quatre niveaux recrutés (rue, politique, criminel, taupe) sont
--    supprimés partout : informateur_recruter et informateur_interroger refusent (« informateurs_supprimes »), le métier
--    « informateur » n'est plus recrutable (pnj_metiers_profils.recrutable = false), la passe de minuit ne prélève plus
--    aucun salaire, les tarifs des cinq ordres retirés quittent ordres_couts. AUCUNE donnée de joueur n'est effacée
--    (colonne informateurs, pnj_membres, historiques : intacts ; relevé du 22/11 : aucun informateur recruté en base).
-- 2. Le rôle passe aux PNJ présents dans les lieux (référentiel informateurs_pnj, généré depuis data.js par
--    outils/generateurs/generer-informateurs-lieux.cjs). On les paie selon le barème commun (informateur_palier_interne :
--    Républia 20-29 / 30-44 / 45-50 FR, Sovarka 7-11 / 12-17 / 18-20 PSK). Payer donne toujours une réponse ; l'argent
--    versé disparaît du jeu ; aucun nom n'est jamais donné, seulement des traits (genre, allure, ville de domicile,
--    nationalité, milieu professionnel), et jamais un trait que porte une seule personne.
-- 3. Profils : « lieu » (allées et venues des dernières 24 h dans le bâtiment, cachés exclus, masqués en « individu
--    masqué », une rumeur réelle de la ville ; 1, 2 ou 3 traits dont un social), « generaliste » (barmans, l'habitué du
--    Bar Sever : une information au hasard sur la ville ; flou = banal, correct = un fait et 1 trait, premier choix = le
--    fait le plus marquant et 1 trait ; l'habitué garde la piste du colonel Voronov au premier choix), « sujet »
--    (entraîneurs et dealers : drogue ; lobbyistes : politique ; dirigeants syndicaux : syndicat ; même échelle).
-- 4. « Écouter le barman » ne reste pas gratuit : dans une pièce où se tient un généraliste, ecouter_rumeurs est refusé
--    (« ecoute_payante ») ; l'écran propose l'ordre « Acheter une information » (informateur_payer).
-- 6. Le commissaire paie aussi un informateur sur une plainte contre X (crim_informateur_payer) : même barème, caisse du
--    commissariat d'abord, ses fonds propres en dernier ressort ; flou = bonus d'enquête de l'informateur divisé par deux.
-- Fonctions communes modifiées par simple appel ajouté (pg_temp.rp_raccorder, marques informateurs_*_v1) :
-- rumeur_ecoute_jauges_interne, crim_enquete_taux_interne. Rien du goulag n'est touché. Idempotente.
BEGIN;

-- ── Référentiel des informateurs présents dans les lieux ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.informateurs_pnj (
  id text PRIMARY KEY, pays text NOT NULL, ville text NOT NULL, batiment text NOT NULL, piece text,
  nom text NOT NULL, role text, profil text NOT NULL CHECK (profil IN ('lieu', 'generaliste', 'sujet')),
  sujet text CHECK (sujet IS NULL OR sujet IN ('drogue', 'politique', 'syndicat')), actif boolean NOT NULL DEFAULT true);
ALTER TABLE public.informateurs_pnj ENABLE ROW LEVEL SECURITY;
CREATE INDEX IF NOT EXISTS informateurs_pnj_lieu ON public.informateurs_pnj (pays, ville, batiment);

CREATE TEMP TABLE informateurs_seed (id text, pays text, ville text, batiment text, piece text, nom text, role text, profil text, sujet text) ON COMMIT DROP;
INSERT INTO informateurs_seed VALUES
('habitue_krasnov', 'soviet', 'ville_b', 'cafe-tabac-cheminots-montrouge', NULL, 'L’habitué du Bar Sever', 'Habitué du bar', 'generaliste', NULL),
('republic:capitale:assemblee:accueil_assemblee:Hotesse Accueil', 'republic', 'capitale', 'assemblee', 'accueil_assemblee', 'Hotesse Accueil', 'PNJ - Accueil', 'lieu', NULL),
('republic:capitale:assemblee:couloirs:Lobbyiste Perrin', 'republic', 'capitale', 'assemblee', 'couloirs', 'Lobbyiste Perrin', 'Lobbyiste (PNJ)', 'sujet', 'politique'),
('republic:capitale:centre-affaires:hall:Gretta Délieu', 'republic', 'capitale', 'centre-affaires', 'hall', 'Gretta Délieu', 'Hôtesse d''accueil', 'lieu', NULL),
('republic:capitale:centre-artisanal:travees:Céd'' Labone', 'republic', 'capitale', 'centre-artisanal', 'travees', 'Céd'' Labone', 'Dealer', 'sujet', 'drogue'),
('republic:capitale:centre-artisanal:travees:Henrico Stot', 'republic', 'capitale', 'centre-artisanal', 'travees', 'Henrico Stot', 'Sécurité', 'lieu', NULL),
('republic:capitale:centre-multinodal-luthecia:hall_gare:Gaston Retard', 'republic', 'capitale', 'centre-multinodal-luthecia', 'hall_gare', 'Gaston Retard', 'Chef de gare', 'lieu', NULL),
('republic:capitale:centre-multinodal-luthecia:hall_gare:Mireille Guichet', 'republic', 'capitale', 'centre-multinodal-luthecia', 'hall_gare', 'Mireille Guichet', 'Hôtesse d''accueil', 'lieu', NULL),
('republic:capitale:hotel-republica:accueil:Nathalie Ondor', 'republic', 'capitale', 'hotel-republica', 'accueil', 'Nathalie Ondor', 'Réceptionniste', 'lieu', NULL),
('republic:capitale:hotel-republica:bar:Marc Hantile', 'republic', 'capitale', 'hotel-republica', 'bar', 'Marc Hantile', 'Lobbyiste — Conseil en affaires et économie', 'sujet', 'politique'),
('republic:capitale:hotel-republica:bar:Marco (Barman)', 'republic', 'capitale', 'hotel-republica', 'bar', 'Marco (Barman)', 'PNJ - Barman', 'generaliste', NULL),
('republic:capitale:hotel-republica:restaurant:Gaston Sauceblanche', 'republic', 'capitale', 'hotel-republica', 'restaurant', 'Gaston Sauceblanche', 'Maitre d''hotel', 'lieu', NULL),
('republic:capitale:hotel-republica:restaurant:Régis Gondasse', 'republic', 'capitale', 'hotel-republica', 'restaurant', 'Régis Gondasse', 'Sommelier', 'lieu', NULL),
('republic:capitale:hotel-republica:restaurant:Yvette Gratinée', 'republic', 'capitale', 'hotel-republica', 'restaurant', 'Yvette Gratinée', 'Serveuse', 'lieu', NULL),
('republic:capitale:mairie-capitale:hall_mairie:Secretaire Municipal Petit', 'republic', 'capitale', 'mairie-capitale', 'hall_mairie', 'Secretaire Municipal Petit', 'PNJ - Secretariat general', 'lieu', NULL),
('republic:capitale:musee-ville-luthecia:hall:Valérie Loisillon', 'republic', 'capitale', 'musee-ville-luthecia', 'hall', 'Valérie Loisillon', 'Hôtesse d''accueil', 'lieu', NULL),
('republic:capitale:palais-presidentiel:accueil_elysee:Gérard Tamponneau', 'republic', 'capitale', 'palais-presidentiel', 'accueil_elysee', 'Gérard Tamponneau', 'PNJ - Chef du protocole presidentiel', 'lieu', NULL),
('republic:capitale:palais-presidentiel:salle_reception:Gérard Tamponneau', 'republic', 'capitale', 'palais-presidentiel', 'salle_reception', 'Gérard Tamponneau', 'PNJ - Chef du protocole presidentiel', 'lieu', NULL),
('republic:capitale:place-formulaire-liberte:place:Pat Hounette', 'republic', 'capitale', 'place-formulaire-liberte', 'place', 'Pat Hounette', 'Dealer', 'sujet', 'drogue'),
('republic:capitale:quartier-ambassades:accueil_ambassades:Agent de Sécurité', 'republic', 'capitale', 'quartier-ambassades', 'accueil_ambassades', 'Agent de Sécurité', 'PNJ - Sécurité', 'lieu', NULL),
('republic:capitale:quartier-ambassades:accueil_ambassades:Hôtesse d''Accueil', 'republic', 'capitale', 'quartier-ambassades', 'accueil_ambassades', 'Hôtesse d''Accueil', 'PNJ - Accueil', 'lieu', NULL),
('republic:capitale:stade:buvette:Justin Verre', 'republic', 'capitale', 'stade', 'buvette', 'Justin Verre', 'Tenancier de Buvette', 'lieu', NULL),
('republic:capitale:stade:terrain:Jean-Pierre Taclojnou', 'republic', 'capitale', 'stade', 'terrain', 'Jean-Pierre Taclojnou', 'Entraineur', 'sujet', 'drogue'),
('republic:ville_a:bar-des-pecheurs:salle_bar:Marin Dulac', 'republic', 'ville_a', 'bar-des-pecheurs', 'salle_bar', 'Marin Dulac', 'Patron du bar', 'generaliste', NULL),
('republic:ville_a:capitaine-sauvage:salle_principale:Marine Leroux', 'republic', 'ville_a', 'capitaine-sauvage', 'salle_principale', 'Marine Leroux', 'Serveuse', 'lieu', NULL),
('republic:ville_a:centre-affaires:hall:Edith Legall', 'republic', 'ville_a', 'centre-affaires', 'hall', 'Edith Legall', 'Hôtesse d''accueil', 'lieu', NULL),
('republic:ville_a:centre-artisanal:travees:Maël Strom', 'republic', 'ville_a', 'centre-artisanal', 'travees', 'Maël Strom', 'Sécurité', 'lieu', NULL),
('republic:ville_a:centre-artisanal:travees:Ronan Lafourgue', 'republic', 'ville_a', 'centre-artisanal', 'travees', 'Ronan Lafourgue', 'Dealer', 'sujet', 'drogue'),
('republic:ville_a:centre-commercial:hall:Cédric Legoff', 'republic', 'ville_a', 'centre-commercial', 'hall', 'Cédric Legoff', 'Agent de sécurité privée', 'lieu', NULL),
('republic:ville_a:centre-multinodal-port-sainte-marie:hall_gare_psm:Chef de Gare Local', 'republic', 'ville_a', 'centre-multinodal-port-sainte-marie', 'hall_gare_psm', 'Chef de Gare Local', 'Chef de gare', 'lieu', NULL),
('republic:ville_a:hotel-port:hall_port:Jeanine Debré', 'republic', 'ville_a', 'hotel-port', 'hall_port', 'Jeanine Debré', 'Gérante', 'lieu', NULL),
('republic:ville_a:mairie:accueil_mairie:Secretaire Municipal', 'republic', 'ville_a', 'mairie', 'accueil_mairie', 'Secretaire Municipal', 'PNJ - Administration', 'lieu', NULL),
('republic:ville_a:musee-port-sainte-marie:hall:Soizic Le Gall', 'republic', 'ville_a', 'musee-port-sainte-marie', 'hall', 'Soizic Le Gall', 'PNJ - Accueil du musee', 'lieu', NULL),
('republic:ville_a:port-sainte-marie:administration_portuaire:Marcel Ancre', 'republic', 'ville_a', 'port-sainte-marie', 'administration_portuaire', 'Marcel Ancre', 'Commandant de Port', 'lieu', NULL),
('republic:ville_a:stade:buvette:Tenancier de Buvette', 'republic', 'ville_a', 'stade', 'buvette', 'Tenancier de Buvette', 'PNJ - Buvette', 'lieu', NULL),
('republic:ville_a:stade:terrain:Maurice Éhault', 'republic', 'ville_a', 'stade', 'terrain', 'Maurice Éhault', 'Entraineur', 'sujet', 'drogue'),
('republic:ville_b:centre-affaires:hall:Jeanne Terril', 'republic', 'ville_b', 'centre-affaires', 'hall', 'Jeanne Terril', 'Hôtesse d''accueil', 'lieu', NULL),
('republic:ville_b:centre-artisanal:travees:Bruno Ducoron', 'republic', 'ville_b', 'centre-artisanal', 'travees', 'Bruno Ducoron', 'Sécurité', 'lieu', NULL),
('republic:ville_b:centre-artisanal:travees:Jojo Laferraille', 'republic', 'ville_b', 'centre-artisanal', 'travees', 'Jojo Laferraille', 'Dealer', 'sujet', 'drogue'),
('republic:ville_b:centre-commercial:hall:Bastien Jacquemont', 'republic', 'ville_b', 'centre-commercial', 'hall', 'Bastien Jacquemont', 'Agent de sécurité privée', 'lieu', NULL),
('republic:ville_b:centre-multinodal-montrouge:hall_gare_montrouge:Chef de Gare Syndiqué', 'republic', 'ville_b', 'centre-multinodal-montrouge', 'hall_gare_montrouge', 'Chef de Gare Syndiqué', 'Chef de gare', 'lieu', NULL),
('republic:ville_b:centre-multinodal-montrouge:hall_gare_montrouge:Délégué Syndical', 'republic', 'ville_b', 'centre-multinodal-montrouge', 'hall_gare_montrouge', 'Délégué Syndical', 'Délégué permanent', 'sujet', 'syndicat'),
('republic:ville_b:hotel-mineur:hall_mineur:Christelle Cazenave', 'republic', 'ville_b', 'hotel-mineur', 'hall_mineur', 'Christelle Cazenave', 'Réceptionniste', 'lieu', NULL),
('republic:ville_b:mairie:accueil_mairie:Secretaire Municipal', 'republic', 'ville_b', 'mairie', 'accueil_mairie', 'Secretaire Municipal', 'PNJ - Administration', 'lieu', NULL),
('republic:ville_b:musee-histoire-montrouge:accueil:Elsa Montbaron', 'republic', 'ville_b', 'musee-histoire-montrouge', 'accueil', 'Elsa Montbaron', 'PNJ - Accueil du musée', 'lieu', NULL),
('republic:ville_b:parking-tribunal-montrouge:accueil:Basile Decoq', 'republic', 'ville_b', 'parking-tribunal-montrouge', 'accueil', 'Basile Decoq', 'Dealer', 'sujet', 'drogue'),
('republic:ville_b:parking-tribunal-montrouge:accueil:Jean Tarte', 'republic', 'ville_b', 'parking-tribunal-montrouge', 'accueil', 'Jean Tarte', 'Agent de sécurité', 'lieu', NULL),
('republic:ville_b:siege-syndical:bureau_syndical:Delegue Morel', 'republic', 'ville_b', 'siege-syndical', 'bureau_syndical', 'Delegue Morel', 'Secretaire general du syndicat', 'sujet', 'syndicat'),
('republic:ville_b:stade:buvette:Tenancier de Buvette', 'republic', 'ville_b', 'stade', 'buvette', 'Tenancier de Buvette', 'PNJ - Buvette', 'lieu', NULL),
('republic:ville_b:stade:terrain:Jean-Philippe Hervitmonfute', 'republic', 'ville_b', 'stade', 'terrain', 'Jean-Philippe Hervitmonfute', 'Entraineur', 'sujet', 'drogue'),
('soviet:capitale:capitaine-sauvage:salle_principale:Tatiana Bortchova', 'soviet', 'capitale', 'capitaine-sauvage', 'salle_principale', 'Tatiana Bortchova', 'Responsable de salle', 'lieu', NULL),
('soviet:capitale:centre-affaires:hall:Pietr Kastanov', 'soviet', 'capitale', 'centre-affaires', 'hall', 'Pietr Kastanov', 'Agent de sécurité', 'lieu', NULL),
('soviet:capitale:centre-affaires:hall:Valery Burov', 'soviet', 'capitale', 'centre-affaires', 'hall', 'Valery Burov', 'Réceptionniste', 'lieu', NULL),
('soviet:capitale:centre-artisanal:travees:Genrikh Vlassov', 'soviet', 'capitale', 'centre-artisanal', 'travees', 'Genrikh Vlassov', 'Sécurité', 'lieu', NULL),
('soviet:capitale:centre-artisanal:travees:Kolia Titov', 'soviet', 'capitale', 'centre-artisanal', 'travees', 'Kolia Titov', 'Dealer', 'sujet', 'drogue'),
('soviet:capitale:centre-multinodal-luthecia:hall_gare:Agente Nadejda', 'soviet', 'capitale', 'centre-multinodal-luthecia', 'hall_gare', 'Agente Nadejda', 'Agente de contrôle', 'lieu', NULL),
('soviet:capitale:centre-multinodal-luthecia:hall_gare:Camarade Horaire', 'soviet', 'capitale', 'centre-multinodal-luthecia', 'hall_gare', 'Camarade Horaire', 'Chef de gare', 'lieu', NULL),
('soviet:capitale:hotel-republica:accueil:Vera Pavlova', 'soviet', 'capitale', 'hotel-republica', 'accueil', 'Vera Pavlova', 'Réceptionniste', 'lieu', NULL),
('soviet:capitale:hotel-republica:bar:Arkadi Melnikov', 'soviet', 'capitale', 'hotel-republica', 'bar', 'Arkadi Melnikov', 'Barman', 'generaliste', NULL),
('soviet:capitale:hotel-republica:restaurant:Pavel Denissov', 'soviet', 'capitale', 'hotel-republica', 'restaurant', 'Pavel Denissov', 'Serveur', 'lieu', NULL),
('soviet:capitale:mairie-capitale:bureau_syndicat_national:Lev Lozungov', 'soviet', 'capitale', 'mairie-capitale', 'bureau_syndicat_national', 'Lev Lozungov', 'Délégué du Syndicat national', 'sujet', 'syndicat'),
('soviet:capitale:mairie-capitale:hall_mairie:Secrétaire municipal Arseni Krylov', 'soviet', 'capitale', 'mairie-capitale', 'hall_mairie', 'Secrétaire municipal Arseni Krylov', 'PNJ - Secretariat general', 'lieu', NULL),
('soviet:capitale:musee-novomirsk:hall:Irina Filippova', 'soviet', 'capitale', 'musee-novomirsk', 'hall', 'Irina Filippova', 'PNJ - Accueil du musée', 'lieu', NULL),
('soviet:capitale:palais-ambassades-novomirsk:accueil_ambassades_novomirsk:Agent de Sécurité', 'soviet', 'capitale', 'palais-ambassades-novomirsk', 'accueil_ambassades_novomirsk', 'Agent de Sécurité', 'PNJ - Sécurité', 'lieu', NULL),
('soviet:capitale:palais-ambassades-novomirsk:accueil_ambassades_novomirsk:Hôtesse d''Accueil', 'soviet', 'capitale', 'palais-ambassades-novomirsk', 'accueil_ambassades_novomirsk', 'Hôtesse d''Accueil', 'PNJ - Accueil', 'lieu', NULL),
('soviet:capitale:palais-presidentiel:accueil_elysee:Konstantin Lvovitch Orlov', 'soviet', 'capitale', 'palais-presidentiel', 'accueil_elysee', 'Konstantin Lvovitch Orlov', 'PNJ - Chef du protocole présidentiel', 'lieu', NULL),
('soviet:capitale:palais-presidentiel:salle_reception:Anatoli Sokolov', 'soviet', 'capitale', 'palais-presidentiel', 'salle_reception', 'Anatoli Sokolov', 'PNJ - Chef du protocole presidentiel', 'lieu', NULL),
('soviet:capitale:pavillon-ambassadeurs-novomirsk:bar:Lena Abramova', 'soviet', 'capitale', 'pavillon-ambassadeurs-novomirsk', 'bar', 'Lena Abramova', 'Serveuse', 'lieu', NULL),
('soviet:capitale:pavillon-ambassadeurs-novomirsk:bar:Mikhaïl Stakanov', 'soviet', 'capitale', 'pavillon-ambassadeurs-novomirsk', 'bar', 'Mikhaïl Stakanov', 'Barman', 'generaliste', NULL),
('soviet:capitale:pavillon-ambassadeurs-novomirsk:hall_pavillon:Alina Belokourova', 'soviet', 'capitale', 'pavillon-ambassadeurs-novomirsk', 'hall_pavillon', 'Alina Belokourova', 'Hôtesse d''accueil', 'lieu', NULL),
('soviet:capitale:pavillon-ambassadeurs-novomirsk:hall_pavillon:Touyana Dachieva', 'soviet', 'capitale', 'pavillon-ambassadeurs-novomirsk', 'hall_pavillon', 'Touyana Dachieva', 'Hôtesse d''accueil', 'lieu', NULL),
('soviet:capitale:pavillon-ambassadeurs-novomirsk:salle_reception:Grigori Podnosov', 'soviet', 'capitale', 'pavillon-ambassadeurs-novomirsk', 'salle_reception', 'Grigori Podnosov', 'Serveur de réception', 'lieu', NULL),
('soviet:capitale:pavillon-ambassadeurs-novomirsk:salle_reception:Varvara Salfetkina', 'soviet', 'capitale', 'pavillon-ambassadeurs-novomirsk', 'salle_reception', 'Varvara Salfetkina', 'Serveuse de réception', 'lieu', NULL),
('soviet:capitale:residence-imperiale-novomirsk:hall_residence:Ekaterina Klioutcheva', 'soviet', 'capitale', 'residence-imperiale-novomirsk', 'hall_residence', 'Ekaterina Klioutcheva', 'Réceptionniste', 'lieu', NULL),
('soviet:capitale:stade:buvette:Tenancier de Buvette', 'soviet', 'capitale', 'stade', 'buvette', 'Tenancier de Buvette', 'PNJ - Buvette', 'lieu', NULL),
('soviet:capitale:stade:terrain:Entraineur Local', 'soviet', 'capitale', 'stade', 'terrain', 'Entraineur Local', 'PNJ - Entraineur', 'sujet', 'drogue'),
('soviet:ville_a:capitaine-sauvage:salle_principale:Sesegma Badmaeva', 'soviet', 'ville_a', 'capitaine-sauvage', 'salle_principale', 'Sesegma Badmaeva', 'Serveuse', 'lieu', NULL),
('soviet:ville_a:centre-affaires:hall:Oyuuna Tsydenova', 'soviet', 'ville_a', 'centre-affaires', 'hall', 'Oyuuna Tsydenova', 'Hôtesse d’accueil du centre d’affaires', 'lieu', NULL),
('soviet:ville_a:centre-multinodal-montrouge:hall_gare_montrouge:Gombo Zhigzhitov', 'soviet', 'ville_a', 'centre-multinodal-montrouge', 'hall_gare_montrouge', 'Gombo Zhigzhitov', 'Chef de gare de Starovka', 'lieu', NULL),
('soviet:ville_a:hotel-mineur:hall_mineur:Aldar Zhamsuev', 'soviet', 'ville_a', 'hotel-mineur', 'hall_mineur', 'Aldar Zhamsuev', 'Serveur et barman', 'generaliste', NULL),
('soviet:ville_a:hotel-mineur:hall_mineur:Erzhena Dambaeva', 'soviet', 'ville_a', 'hotel-mineur', 'hall_mineur', 'Erzhena Dambaeva', 'Réceptionniste', 'lieu', NULL),
('soviet:ville_a:mairie:accueil_mairie:Sayana Tsydypova', 'soviet', 'ville_a', 'mairie', 'accueil_mairie', 'Sayana Tsydypova', 'Secrétaire municipale', 'lieu', NULL),
('soviet:ville_a:mairie:bureau_syndicat_national:Tserenjav Dachiev', 'soviet', 'ville_a', 'mairie', 'bureau_syndicat_national', 'Tserenjav Dachiev', 'Délégué du Syndicat national', 'sujet', 'syndicat'),
('soviet:ville_a:mairie:salle_elections:Soyolma Ayusheeva', 'soviet', 'ville_a', 'mairie', 'salle_elections', 'Soyolma Ayusheeva', 'Secrétaire de la commission électorale', 'lieu', NULL),
('soviet:ville_a:port-starovka:administration_portuaire:Commandant Arseni Ledokolov', 'soviet', 'ville_a', 'port-starovka', 'administration_portuaire', 'Commandant Arseni Ledokolov', 'Commandant du Port', 'lieu', NULL),
('soviet:ville_a:stade:buvette:Nastia Ponchikova', 'soviet', 'ville_a', 'stade', 'buvette', 'Nastia Ponchikova', 'Tenancière de la buvette', 'lieu', NULL),
('soviet:ville_a:stade:terrain:Viktor Morozko', 'soviet', 'ville_a', 'stade', 'terrain', 'Viktor Morozko', 'Entraîneur du Partizan de Starovka', 'sujet', 'drogue'),
('soviet:ville_a:stade:vestiaires:Viktor Morozko', 'soviet', 'ville_a', 'stade', 'vestiaires', 'Viktor Morozko', 'Entraîneur du Partizan de Starovka', 'sujet', 'drogue'),
('soviet:ville_b:cafe-tabac-cheminots-montrouge:salle:Grigori Zaitsev', 'soviet', 'ville_b', 'cafe-tabac-cheminots-montrouge', 'salle', 'Grigori Zaitsev', 'Patron du bar', 'generaliste', NULL),
('soviet:ville_b:centre-affaires:hall:Hôtesse du centre d''affaires de Krasnov', 'soviet', 'ville_b', 'centre-affaires', 'hall', 'Hôtesse du centre d''affaires de Krasnov', 'Hôtesse d''accueil', 'lieu', NULL),
('soviet:ville_b:hotel-mineur:hall_mineur:Receptionniste', 'soviet', 'ville_b', 'hotel-mineur', 'hall_mineur', 'Receptionniste', 'Accueil', 'lieu', NULL),
('soviet:ville_b:mairie:accueil_mairie:Galina Dokladova', 'soviet', 'ville_b', 'mairie', 'accueil_mairie', 'Galina Dokladova', 'Secrétaire de mairie de Krasnov', 'lieu', NULL),
('soviet:ville_b:mairie:bureau_syndicat_national:Anatoli Transparantov', 'soviet', 'ville_b', 'mairie', 'bureau_syndicat_national', 'Anatoli Transparantov', 'Délégué du Syndicat national', 'sujet', 'syndicat'),
('soviet:ville_b:musee-novomirsk:hall:Hôtesse du musée de Krasnov', 'soviet', 'ville_b', 'musee-novomirsk', 'hall', 'Hôtesse du musée de Krasnov', 'Accueil du musée', 'lieu', NULL),
('soviet:ville_b:stade:buvette:Avdotia Doubova', 'soviet', 'ville_b', 'stade', 'buvette', 'Avdotia Doubova', 'Tenancière de la buvette', 'lieu', NULL),
('soviet:ville_b:stade:terrain:Vsevolod Fedotov', 'soviet', 'ville_b', 'stade', 'terrain', 'Vsevolod Fedotov', 'Entraîneur de l''Étoile Rouge', 'sujet', 'drogue'),
('soviet:ville_b:stade:vestiaires:Vsevolod Fedotov', 'soviet', 'ville_b', 'stade', 'vestiaires', 'Vsevolod Fedotov', 'Entraîneur de l''Étoile Rouge', 'sujet', 'drogue');
INSERT INTO public.informateurs_pnj (id, pays, ville, batiment, piece, nom, role, profil, sujet, actif)
SELECT id, pays, ville, batiment, piece, nom, role, profil, sujet, true FROM informateurs_seed
ON CONFLICT (id) DO UPDATE SET pays = EXCLUDED.pays, ville = EXCLUDED.ville, batiment = EXCLUDED.batiment, piece = EXCLUDED.piece,
  nom = EXCLUDED.nom, role = EXCLUDED.role, profil = EXCLUDED.profil, sujet = EXCLUDED.sujet, actif = true;
-- Un PNJ disparu de data.js n'est plus proposé (ligne gardée, désactivée).
UPDATE public.informateurs_pnj SET actif = false WHERE actif AND id NOT IN (SELECT id FROM informateurs_seed);

-- Journal des informations achetées (une ligne par paiement ; lecture serveur seulement).
CREATE TABLE IF NOT EXISTS public.informateurs_achats (
  id bigserial PRIMARY KEY, acteur text NOT NULL, informateur text NOT NULL, montant integer NOT NULL, palier text NOT NULL,
  lignes jsonb NOT NULL, le timestamptz NOT NULL DEFAULT now());
ALTER TABLE public.informateurs_achats ENABLE ROW LEVEL SECURITY;

-- ── Barème (bornes lisibles par l'écran ; le palier reste décidé par informateur_palier_interne) ──────────────────
CREATE OR REPLACE FUNCTION public.informateur_bareme_interne(p_pays text)
RETURNS jsonb LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE WHEN p_pays = 'soviet' THEN
    '{"devise":"PSK","min":7,"max":20,"paliers":[{"palier":"flou","min":7,"max":11},{"palier":"correct","min":12,"max":17},{"palier":"premier_choix","min":18,"max":20}]}'::jsonb
  WHEN p_pays = 'republic' THEN
    '{"devise":"FR","min":20,"max":50,"paliers":[{"palier":"flou","min":20,"max":29},{"palier":"correct","min":30,"max":44},{"palier":"premier_choix","min":45,"max":50}]}'::jsonb
  END $$;

-- ── Traits : jamais un nom, jamais un trait que porte une seule personne ──────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.informateur_traits_interne(p_nom text, p_n integer, p_social boolean)
RETURNS text[] LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $function$
DECLARE d public.personnages_donnees; v_soc text[]; v_tous text[]; v_out text[] := ARRAY[]::text[];
BEGIN
  SELECT * INTO d FROM public.personnages_donnees WHERE name = p_nom;
  IF NOT FOUND OR coalesce(p_n, 0) <= 0 THEN RETURN v_out; END IF;
  SELECT array_agg(t.texte ORDER BY random()) FILTER (WHERE t.social), array_agg(t.texte ORDER BY random())
    INTO v_soc, v_tous FROM (
    SELECT CASE d.stats->>'genre' WHEN 'H' THEN 'un homme' WHEN 'F' THEN 'une femme' END AS texte, false AS social,
           (SELECT count(*) FROM public.personnages_donnees x WHERE x.stats->>'genre' = d.stats->>'genre') AS n
    UNION ALL
    SELECT CASE d.origin WHEN 'poor' THEN 'une allure modeste, des vêtements usés' WHEN 'worker' THEN 'une allure de travailleur, les mains calleuses'
                         WHEN 'bourgeois' THEN 'une mise soignée de petit bourgeois' WHEN 'elite' THEN 'une allure de grand monde, des vêtements de prix' END,
           false, (SELECT count(*) FROM public.personnages_donnees x WHERE x.origin = d.origin)
    UNION ALL
    SELECT 'habite ' || v.nom, true,
           (SELECT count(*) FROM public.personnages_donnees x WHERE x.domicile->>'country' = d.domicile->>'country' AND x.domicile->>'city' = d.domicile->>'city')
      FROM public.villes v WHERE v.pays = d.domicile->>'country' AND v.ville = d.domicile->>'city'
    UNION ALL
    SELECT CASE d.nationalite WHEN 'republic' THEN 'de nationalité républicaine' WHEN 'soviet' THEN 'de nationalité sovarkienne'
                              WHEN 'khalija' THEN 'de nationalité khalijienne' WHEN 'narco' THEN 'de nationalité narcoméricaine' END,
           true, (SELECT count(*) FROM public.personnages_donnees x WHERE x.nationalite = d.nationalite)
    UNION ALL
    SELECT CASE d.career WHEN 'officer' THEN 'du milieu militaire' WHEN 'business' THEN 'du milieu des affaires' WHEN 'magistrat' THEN 'du milieu judiciaire'
                         WHEN 'press' THEN 'du milieu de la presse' WHEN 'clergy' THEN 'du milieu religieux' WHEN 'doctor' THEN 'du milieu médical ou universitaire'
                         WHEN 'worker' THEN 'du monde ouvrier' WHEN 'intel' THEN 'du genre fonctionnaire discret' WHEN 'criminal_c' THEN 'du milieu interlope'
                         WHEN 'escort' THEN 'du milieu de la nuit' WHEN 'minor' THEN 'tout jeune, presque un enfant' WHEN 'sans_experience' THEN 'sans métier connu' END,
           true, (SELECT count(*) FROM public.personnages_donnees x WHERE x.career = d.career)
  ) t WHERE t.texte IS NOT NULL AND t.n >= 2;
  -- Premier choix : un trait social d'abord, puis les autres au hasard.
  IF p_social AND coalesce(array_length(v_soc, 1), 0) > 0 THEN v_out := ARRAY[v_soc[1]]; END IF;
  v_out := v_out || coalesce((SELECT array_agg(x) FROM (SELECT x FROM unnest(coalesce(v_tous, ARRAY[]::text[])) x
                                                        WHERE NOT (x = ANY (v_out)) LIMIT greatest(0, p_n - coalesce(array_length(v_out, 1), 0))) s), ARRAY[]::text[]);
  RETURN v_out;
END $function$;

-- ── Faits de la ville, sans nom : libellé, gravité ──────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.informateur_fait_libelle_interne(p_type text)
RETURNS text LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE p_type
    WHEN 'assassinat' THEN 'quelqu’un a été assassiné' WHEN 'utiliser_explosifs' THEN 'une charge explosive a sauté'
    WHEN 'acheter_bombe_illegale' THEN 'quelqu’un s’est procuré une bombe' WHEN 'empoisonnement' THEN 'quelqu’un a été empoisonné'
    WHEN 'incendier' THEN 'un incendie criminel a été allumé' WHEN 'torture_qhs' THEN 'un détenu a été maltraité au quartier de haute sécurité'
    WHEN 'vol' THEN 'un vol a été commis' WHEN 'achat_arme_illegal' THEN 'quelqu’un a acheté une arme sous le manteau'
    WHEN 'corruption' THEN 'une enveloppe a changé de mains' WHEN 'achat_drogue' THEN 'quelqu’un a acheté de la drogue'
    WHEN 'consommation_drogue' THEN 'quelqu’un a pris de la drogue' WHEN 'consommation_estadine' THEN 'quelqu’un a pris de l’estadine'
    WHEN 'hooliganisme' THEN 'des supporters ont tout cassé' WHEN 'escort' THEN 'quelqu’un s’est offert la compagnie d’une escort'
    WHEN 'nuit_escort' THEN 'quelqu’un a passé la nuit avec une escort' WHEN 'appel_escort' THEN 'quelqu’un a fait appel à une escort'
    WHEN 'don' THEN 'quelqu’un a fait un cadeau intéressé' WHEN 'don_objet' THEN 'quelqu’un a offert un objet, pas par bonté d’âme'
    WHEN 'diner_affaires_accepte' THEN 'un dîner d’affaires a été accepté' WHEN 'diner_affaires_refuse' THEN 'un dîner d’affaires a été refusé'
    WHEN 'boire_verre_accepte' THEN 'on a trinqué entre gens qui ne devraient pas se fréquenter'
    WHEN 'boire_verre_refuse' THEN 'quelqu’un a refusé de trinquer, et ça s’est vu'
    WHEN 'plainte_sans_suite' THEN 'une plainte a été classée sans suite' WHEN 'plainte_enquete' THEN 'une plainte a déclenché une enquête'
    WHEN 'plainte_confirmee' THEN 'une plainte a été confirmée' WHEN 'plainte_egaree' THEN 'une plainte s’est égarée au commissariat'
    WHEN 'cellules_fragilisees' THEN 'les cellules du commissariat ont été fragilisées' WHEN 'presence_suspecte' THEN 'quelqu’un pose beaucoup de questions'
    WHEN 'manifestation' THEN 'une manifestation a été menée dans les rues'
    ELSE 'il s’est passé quelque chose de louche' END $$;

CREATE OR REPLACE FUNCTION public.informateur_fait_gravite_interne(p_type text)
RETURNS integer LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE WHEN p_type IN ('assassinat') THEN 10 WHEN p_type IN ('utiliser_explosifs', 'acheter_bombe_illegale') THEN 9
              WHEN p_type IN ('empoisonnement', 'incendier') THEN 8 WHEN p_type = 'torture_qhs' THEN 7
              WHEN p_type IN ('vol', 'achat_arme_illegal') THEN 6 WHEN p_type IN ('corruption', 'manifestation') THEN 5
              WHEN p_type IN ('achat_drogue', 'hooliganisme') THEN 4 WHEN p_type IN ('consommation_drogue', 'consommation_estadine', 'escort', 'nuit_escort', 'appel_escort') THEN 3
              WHEN p_type IN ('diner_affaires_accepte', 'diner_affaires_refuse', 'don', 'don_objet') THEN 2 ELSE 1 END $$;

CREATE OR REPLACE FUNCTION public.informateur_sujet_types_interne(p_sujet text)
RETURNS text[] LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE p_sujet
    WHEN 'drogue' THEN ARRAY['achat_drogue', 'consommation_drogue', 'consommation_estadine']
    WHEN 'politique' THEN ARRAY['corruption', 'diner_affaires_accepte', 'diner_affaires_refuse', 'don', 'don_objet', 'boire_verre_accepte', 'boire_verre_refuse']
    WHEN 'syndicat' THEN ARRAY['manifestation']
  END $$;

-- Un fait de la ville (traces non expirées, hors rumeurs et tracts qui ne sortent que par le bouche-à-oreille ;
-- manifestations spontanées des trois derniers jours pour les syndicats). p_mode : 'hasard' ou 'marquant'.
CREATE OR REPLACE FUNCTION public.informateur_fait_interne(p_pays text, p_ville text, p_acteur text, p_sujet text, p_mode text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $function$
DECLARE v_types text[] := public.informateur_sujet_types_interne(p_sujet); r record; q text;
BEGIN
  q := $q$SELECT t.type_action, t.auteur, t.created_at AS quand FROM public.actions_tracables t
         WHERE t.country = $1 AND t.city = $2 AND t.auteur IS DISTINCT FROM $3 AND t.type_action NOT IN ('fausse_rumeur', 'tract_calomnieux')
           AND (t.jour_expiration IS NULL OR t.jour_expiration >= public.jour_de_jeu_pays($1)) AND ($4::text[] IS NULL OR t.type_action = ANY ($4))$q$;
  IF (v_types IS NULL OR 'manifestation' = ANY (v_types)) AND to_regclass('public.manifestations_spontanees') IS NOT NULL THEN
    q := q || $q$ UNION ALL SELECT 'manifestation', m.chef, m.debut FROM public.manifestations_spontanees m
                 WHERE m.pays = $1 AND m.ville = $2 AND m.chef IS DISTINCT FROM $3 AND m.debut >= now() - interval '3 days'$q$;
  END IF;
  q := 'SELECT * FROM (' || q || ') f ORDER BY ' || CASE WHEN p_mode = 'marquant'
         THEN 'public.informateur_fait_gravite_interne(type_action) DESC, quand DESC NULLS LAST' ELSE 'random()' END || ' LIMIT 1';
  EXECUTE q INTO r USING p_pays, p_ville, p_acteur, v_types;
  IF r.type_action IS NULL THEN RETURN NULL; END IF;
  RETURN jsonb_build_object('type', r.type_action, 'auteur', r.auteur, 'libelle', public.informateur_fait_libelle_interne(r.type_action));
END $function$;

-- Phrases banales ou hors sujet (palier flou) : du RP crédible, rien d'exploitable.
CREATE OR REPLACE FUNCTION public.informateur_banal_interne(p_pays text, p_sujet text)
RETURNS text LANGUAGE sql VOLATILE AS $$
  SELECT a[1 + floor(random() * array_length(a, 1))::integer] FROM (SELECT CASE
    WHEN p_sujet = 'drogue' THEN ARRAY['« La came ? Il paraît que ça circule, comme partout. Mais moi, je ne sais rien de précis. »',
                                       '« Les gamins du quartier ont l’air fatigués, ces temps-ci. Allez savoir pourquoi. »',
                                       '« On dit que les prix ont monté. Ou baissé. Enfin, ça bouge. »']
    WHEN p_sujet = 'politique' THEN ARRAY['« Les élus ? Ils mangent beaucoup et parlent encore plus. Rien de neuf sous le soleil. »',
                                          '« Il paraît que ça négocie dur en coulisses. Comme toujours, quoi. »',
                                          '« Tout le monde promet tout à tout le monde. Je n’en sais pas plus. »']
    WHEN p_sujet = 'syndicat' THEN ARRAY['« Les camarades grognent, mais ils grognent toujours. Rien de précis. »',
                                         '« On parle d’une assemblée générale. Ou d’un pot de départ, je ne sais plus. »',
                                         '« La base est fatiguée. La direction aussi. Voilà ce que je peux vous dire. »']
    WHEN p_pays = 'soviet' THEN ARRAY['« Il va encore neiger, camarade. Ça, c’est une information sûre. »',
                                      '« Le poêle de la cantine est retombé en panne. Toute la ville en parle. »',
                                      '« Mon beau-frère a vu un renard près de la gare. Gros, le renard. »',
                                      '« Les files d’attente s’allongent devant l’épicerie. Rien de nouveau. »']
    ELSE ARRAY['« Le prix du café a encore augmenté. Ça, au moins, c’est un scandale. »',
               '« Il paraît que le maire a changé de cravate. Toute la ville en parle. »',
               '« Mon cousin a vu un drôle d’oiseau sur le port. Je n’en sais pas plus. »',
               '« Il pleut, il fait gris, les gens râlent. Une semaine normale. »']
  END AS a) s $$;

-- Débit d'un informateur : liquide puis compte national ; l'argent disparaît du jeu (aucune caisse créditée).
CREATE OR REPLACE FUNCTION public.informateur_debiter_interne(p_acteur text, p_montant integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $function$
DECLARE v_liquide numeric; v_arg numeric; v_compte text; v_solde numeric; v_pris numeric;
BEGIN
  SELECT coalesce(liquide, 0), coalesce(arg, 0) INTO v_liquide, v_arg FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  SELECT id, coalesce(solde, 0) INTO v_compte, v_solde FROM public.comptes_bancaires WHERE personnage = p_acteur AND banque = 'nationale' FOR UPDATE;
  IF v_liquide + coalesce(v_solde, 0) < p_montant THEN RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants', 'requis', p_montant); END IF;
  v_pris := least(v_liquide, p_montant);
  UPDATE public.personnages_donnees SET liquide = v_liquide - v_pris, arg = v_arg - p_montant WHERE name = p_acteur;
  IF p_montant - v_pris > 0 THEN UPDATE public.comptes_bancaires SET solde = solde - (p_montant - v_pris), updated_at = now() WHERE id = v_compte; END IF;
  RETURN jsonb_build_object('ok', true, 'source', 'fonds_propres');
END $function$;

-- ── Lecture : les informateurs présents dans ma pièce, avec le barème ────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.informateurs_ici()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $function$
DECLARE a text := public.mon_personnage(); p record;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country, current_city, current_building, current_room INTO p FROM public.personnages_donnees WHERE name = a;
  RETURN jsonb_build_object('ok', true, 'pays', p.country, 'ville', p.current_city, 'batiment', p.current_building, 'piece', p.current_room,
    'bareme', public.informateur_bareme_interne(p.country),
    'informateurs', coalesce((SELECT jsonb_agg(jsonb_build_object('id', i.id, 'nom', i.nom, 'role', i.role, 'profil', i.profil, 'sujet', i.sujet) ORDER BY i.profil, i.nom)
       FROM public.informateurs_pnj i
      WHERE i.actif AND i.pays = p.country AND i.ville = p.current_city AND i.batiment = p.current_building
        AND (i.piece IS NULL OR i.piece = p.current_room) AND public.informateur_bareme_interne(i.pays) IS NOT NULL), '[]'::jsonb));
END $function$;

-- ── Réponse d'un informateur (texte français construit par le serveur ; l'écran l'affiche) ───────────────────────
CREATE OR REPLACE FUNCTION public.informateur_reponse_interne(p_acteur text, i public.informateurs_pnj, p_palier text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $function$
DECLARE v_lignes jsonb := '[]'::jsonb; v_n integer; r record; v_t text[]; f jsonb; v_vus integer := 0;
BEGIN
  IF i.profil = 'lieu' THEN
    v_n := CASE p_palier WHEN 'premier_choix' THEN 3 WHEN 'correct' THEN 2 ELSE 1 END;
    v_lignes := v_lignes || to_jsonb('Ces dernières 24 heures, ici :'::text);
    FOR r IN
      SELECT h.name, max(h.created_at) AS dernier FROM public.historique_deplacements h
        JOIN public.personnages_donnees d ON d.name = h.name
       WHERE h.country = i.pays AND h.city = i.ville AND h.building_id = i.batiment AND h.created_at >= now() - interval '24 hours'
         AND h.name <> p_acteur
         -- Cachés exclus : quiconque se tient caché dans ce bâtiment n'a pas été vu.
         AND NOT EXISTS (SELECT 1 FROM public.caches_pj k WHERE k.personnage = h.name AND k.pays = i.pays AND k.ville = i.ville AND k.batiment = i.batiment)
       GROUP BY h.name ORDER BY max(h.created_at) DESC LIMIT 6
    LOOP
      v_vus := v_vus + 1;
      IF public.crim_masque_interne(r.name) THEN
        v_lignes := v_lignes || to_jsonb('— un individu masqué'::text);
      ELSE
        v_t := public.informateur_traits_interne(r.name, v_n, p_palier = 'premier_choix');
        v_lignes := v_lignes || to_jsonb('— quelqu’un : ' || CASE WHEN coalesce(array_length(v_t, 1), 0) = 0 THEN 'impossible à décrire, une silhouette parmi d’autres'
                                                             ELSE array_to_string(v_t, ' ; ') END);
      END IF;
    END LOOP;
    IF v_vus = 0 THEN v_lignes := v_lignes || to_jsonb('— personne de notable n’est passé.'::text); END IF;
    f := public.informateur_fait_interne(i.pays, i.ville, p_acteur, NULL, 'hasard');
    v_lignes := v_lignes || to_jsonb(CASE WHEN f IS NULL THEN 'Aucune rumeur ne court ici en ce moment.'
                                          ELSE 'On a entendu dire ici ' || CASE WHEN left(f->>'libelle', 1) IN ('a', 'e', 'i', 'o', 'u', 'é') THEN 'qu’' ELSE 'que ' END || (f->>'libelle') || '.' END);
  ELSE
    IF p_palier = 'flou' THEN
      v_lignes := v_lignes || to_jsonb(public.informateur_banal_interne(i.pays, i.sujet));
    ELSE
      f := public.informateur_fait_interne(i.pays, i.ville, p_acteur, i.sujet, CASE WHEN p_palier = 'premier_choix' THEN 'marquant' ELSE 'hasard' END);
      IF f IS NULL THEN
        v_lignes := v_lignes || to_jsonb(public.informateur_banal_interne(i.pays, i.sujet))
                             || to_jsonb('Il n’a rien de mieux à vous dire : il ne se passe vraiment rien en ce moment.'::text);
      ELSE
        v_t := public.informateur_traits_interne(f->>'auteur', 1, false);
        v_lignes := v_lignes || to_jsonb(CASE WHEN p_palier = 'premier_choix' THEN '« Le plus gros, en ce moment ? ' ELSE '« Tenez, une chose : ' END
          || (f->>'libelle')
          || CASE WHEN coalesce(array_length(v_t, 1), 0) = 0 THEN ', mais je ne saurais pas vous dire qui. »'
                  ELSE '. Quelqu’un — ' || v_t[1] || '. »' END);
      END IF;
    END IF;
  END IF;
  RETURN v_lignes;
END $function$;

-- ── Payer un informateur présent ────────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.informateur_payer_interne(p_acteur text, p_informateur text, p_montant integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $function$
DECLARE p record; i public.informateurs_pnj; v_palier text; v_paie jsonb; v_lignes jsonb; v_appris boolean := false; v_secret jsonb;
BEGIN
  SELECT * INTO i FROM public.informateurs_pnj WHERE id = p_informateur AND actif;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'informateur_inconnu'); END IF;
  SELECT country, current_city, current_building, current_room INTO p FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  IF (p.country, p.current_city, p.current_building) IS DISTINCT FROM (i.pays, i.ville, i.batiment)
     OR (i.piece IS NOT NULL AND p.current_room IS DISTINCT FROM i.piece) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;
  v_palier := public.informateur_palier_interne(i.pays, p_montant);
  IF v_palier IS NULL OR public.informateur_bareme_interne(i.pays) IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'montant_invalide', 'bareme', public.informateur_bareme_interne(i.pays)); END IF;
  IF i.id = 'habitue_krasnov' AND v_palier = 'premier_choix' THEN
    -- L'habitué garde sa piste du colonel Voronov au premier choix (secret_source_interne débite et inscrit le contact).
    v_secret := public.secret_source_interne(p_acteur, 'habitue_krasnov', p_montant);
    IF coalesce((v_secret->>'ok')::boolean, false) IS NOT TRUE THEN RETURN v_secret; END IF;
    v_appris := coalesce((v_secret->>'appris')::boolean, false);
    v_lignes := jsonb_build_array('« Va voir le colonel Voronov, à la station radar. Demande-lui des nouvelles de notre ami de Luthécia. »');
  ELSE
    v_paie := public.informateur_debiter_interne(p_acteur, p_montant);
    IF coalesce((v_paie->>'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
    v_lignes := public.informateur_reponse_interne(p_acteur, i, v_palier);
  END IF;
  INSERT INTO public.informateurs_achats (acteur, informateur, montant, palier, lignes) VALUES (p_acteur, i.id, p_montant, v_palier, v_lignes);
  RETURN jsonb_build_object('ok', true, 'informateur', jsonb_build_object('id', i.id, 'nom', i.nom, 'profil', i.profil, 'sujet', i.sujet),
    'montant', p_montant, 'devise', public.informateur_bareme_interne(i.pays)->>'devise', 'palier', v_palier, 'lignes', v_lignes,
    'appris', v_appris, 'secret', v_secret->'secret');
END $function$;

CREATE OR REPLACE FUNCTION public.informateur_payer(p_requete uuid, p_informateur text, p_montant integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $function$
DECLARE a text := public.mon_personnage(); prm jsonb := jsonb_build_object('informateur', p_informateur, 'montant', p_montant); v jsonb; d text;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  v := public.achat_requete_ouvrir_interne(a, p_requete, 'informateur_payer', prm);
  IF v IS NOT NULL THEN RETURN v; END IF;
  BEGIN
    v := public.informateur_payer_interne(a, p_informateur, p_montant);
    IF (v->>'ok')::boolean IS DISTINCT FROM true THEN RAISE EXCEPTION 'refus' USING ERRCODE = 'HG001', DETAIL = coalesce(v, '{"ok":false}')::text; END IF;
  EXCEPTION WHEN SQLSTATE 'HG001' THEN GET STACKED DIAGNOSTICS d = PG_EXCEPTION_DETAIL; RETURN d::jsonb;
  END;
  RETURN public.achat_requete_clore_interne(a, p_requete, 'informateur_payer', prm, v);
END $function$;

-- ── « Écouter le barman » n'est plus gratuit : refus dans une pièce où se tient un généraliste ──────────────────
CREATE OR REPLACE FUNCTION public.informateur_ecoute_payante_interne(p_pays text, p_ville text, p_batiment text, p_piece text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT EXISTS (SELECT 1 FROM public.informateurs_pnj i WHERE i.actif AND i.profil = 'generaliste' AND i.pays = p_pays AND i.ville = p_ville
                    AND i.batiment = p_batiment AND (i.piece IS NULL OR i.piece = p_piece)) $$;

-- ── Commissaire : informateur payé sur une plainte contre X ───────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.crim_informateur_palier_interne(p_affaire bigint)
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT details->'informateur'->>'palier' FROM public.crim_affaires WHERE id = p_affaire $$;
CREATE OR REPLACE FUNCTION public.crim_informateur_piste_interne(p_affaire bigint)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT public.crim_informateur_palier_interne(p_affaire) IS NOT NULL $$;
-- Flou : le bonus de la piste « informateur » est divisé par deux (on retire une demi-piste).
CREATE OR REPLACE FUNCTION public.crim_informateur_reduction_interne(p_affaire bigint)
RETURNS numeric LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT CASE WHEN public.crim_informateur_palier_interne(p_affaire) = 'flou' THEN 0.5 ELSE 0 END $$;

CREATE OR REPLACE FUNCTION public.crim_informateur_payer(p_affaire bigint, p_montant integer, p_requete uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $function$
DECLARE a text := public.mon_personnage(); prm jsonb := jsonb_build_object('affaire', p_affaire, 'montant', p_montant); v jsonb;
  v_poste text; v_ville text; v_pays text; f public.crim_affaires%ROWTYPE; v_palier text; v_caisse text; v_mvt jsonb; v_source text;
  v_auj text := to_char(now() AT TIME ZONE 'Europe/Paris', 'YYYY-MM-DD'); v_t text[]; v_ligne text; t jsonb;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  v := public.achat_requete_ouvrir_interne(a, p_requete, 'crim_informateur_payer', prm);
  IF v IS NOT NULL THEN RETURN v; END IF;
  SELECT x.poste_id, x.poste_city, x.pays INTO v_poste, v_ville, v_pays FROM public.acteur_poste_courant() x;
  IF v_poste IS DISTINCT FROM 'commissaire' OR v_ville IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'reserve_commissaire'); END IF;
  SELECT * INTO f FROM public.crim_affaires WHERE id = p_affaire FOR UPDATE;
  IF NOT FOUND OR f.plainte_id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'aucune_plainte'); END IF;
  IF f.pays IS DISTINCT FROM v_pays OR coalesce(f.ville, 'capitale') <> v_ville THEN RETURN jsonb_build_object('ok', false, 'raison', 'hors_juridiction'); END IF;
  IF f.identifie THEN RETURN jsonb_build_object('ok', false, 'raison', 'deja_identifie'); END IF;
  IF f.details->'informateur'->>'jour' = v_auj THEN RETURN jsonb_build_object('ok', false, 'raison', 'informateur_deja_paye_aujourdhui'); END IF;
  v_palier := public.informateur_palier_interne(v_pays, p_montant);
  IF v_palier IS NULL OR public.informateur_bareme_interne(v_pays) IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'montant_invalide', 'bareme', public.informateur_bareme_interne(v_pays)); END IF;
  -- Caisse du commissariat d'abord ; fonds propres du commissaire en dernier ressort. L'argent disparaît du jeu.
  v_caisse := v_pays || '_commissariat_' || v_ville;
  PERFORM set_config('rp.caisse_interne', 'on', true);
  v_mvt := public.caisse_institution_mouvement(v_caisse, -p_montant, true);
  PERFORM set_config('rp.caisse_interne', '', true);
  IF coalesce((v_mvt->>'ok')::boolean, false) THEN v_source := 'caisse';
  ELSE
    v_mvt := public.informateur_debiter_interne(a, p_montant);
    IF coalesce((v_mvt->>'ok')::boolean, false) IS NOT TRUE THEN RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants', 'requis', p_montant); END IF;
    v_source := 'fonds_propres';
  END IF;
  IF v_palier = 'premier_choix' THEN
    v_t := public.informateur_traits_interne(f.auteur, 1, true);
    v_ligne := CASE WHEN coalesce(array_length(v_t, 1), 0) = 0 THEN '« Je n’ai pas de visage à vous donner, mais je sais que c’est quelqu’un d’ici. Creusez. »'
                    ELSE '« Cherchez quelqu’un ' || v_t[1] || '. Je n’en dirai pas plus. »' END;
  ELSIF v_palier = 'correct' THEN v_ligne := '« J’ai entendu parler de l’affaire, oui. Je vous dis ce que je sais : creusez de ce côté-là. »';
  ELSE v_ligne := '« Une affaire ? Ah, oui… peut-être. On raconte tellement de choses. »';
  END IF;
  UPDATE public.crim_affaires SET details = coalesce(details, '{}'::jsonb) || jsonb_build_object('informateur',
           jsonb_build_object('palier', v_palier, 'montant', p_montant, 'source', v_source, 'jour', v_auj, 'commissaire', a)), maj_le = now()
   WHERE id = f.id;
  t := public.crim_enquete_taux_interne(f.id, a);
  v := jsonb_build_object('ok', true, 'affaire', f.id, 'palier', v_palier, 'montant', p_montant, 'source', v_source,
    'devise', public.informateur_bareme_interne(v_pays)->>'devise', 'ligne', v_ligne, 'taux', t->'taux', 'pistes', t->'pistes');
  RETURN public.achat_requete_clore_interne(a, p_requete, 'crim_informateur_payer', prm, v);
END $function$;

-- ── Raccords par appel ajouté ───────────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION pg_temp.rp_raccorder(p_fn regprocedure, p_avant text, p_apres text, p_marque text)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE d text := pg_get_functiondef(p_fn);
BEGIN
  IF position(p_marque IN d) > 0 THEN RETURN; END IF;
  IF (length(d) - length(replace(d, p_avant, ''))) / length(p_avant) <> 1 THEN
    RAISE EXCEPTION '% : ancrage introuvable ou multiple (%)', p_fn, left(p_avant, 60); END IF;
  EXECUTE replace(d, p_avant, p_apres);
  IF position(p_marque IN pg_get_functiondef(p_fn)) = 0 THEN RAISE EXCEPTION '% : raccord absent', p_fn; END IF;
END $$;

SELECT pg_temp.rp_raccorder('public.rumeur_ecoute_jauges_interne(text)'::regprocedure,
  $a$IF NOT EXISTS(SELECT 1 FROM public.villes WHERE pays=a.country AND ville=a.current_city)THEN RETURN jsonb_build_object('ok',false,'raison','pas_sur_place');END IF;$a$,
  $b$IF NOT EXISTS(SELECT 1 FROM public.villes WHERE pays=a.country AND ville=a.current_city)THEN RETURN jsonb_build_object('ok',false,'raison','pas_sur_place');END IF;
 IF public.informateur_ecoute_payante_interne(a.country,a.current_city,a.current_building,a.current_room)THEN RETURN jsonb_build_object('ok',false,'raison','ecoute_payante');END IF; /* informateurs_ecoute_payante_v1 */$b$,
  'informateurs_ecoute_payante_v1');

SELECT pg_temp.rp_raccorder('public.crim_enquete_taux_interne(bigint,text)'::regprocedure,
  $a$AND jsonb_typeof(d.informateurs) = 'array' AND jsonb_array_length(d.informateurs) > 0);$a$,
  $b$AND jsonb_typeof(d.informateurs) = 'array' AND jsonb_array_length(d.informateurs) > 0);
  v_inf := public.crim_informateur_piste_interne(p_affaire); /* informateurs_piste_v1 */$b$,
  'informateurs_piste_v1');
SELECT pg_temp.rp_raccorder('public.crim_enquete_taux_interne(bigint,text)'::regprocedure,
  $a$v_base + (v_plafond - v_base) * v_k / v_n$a$,
  $b$v_base + (v_plafond - v_base) * (v_k - public.crim_informateur_reduction_interne(p_affaire)) / v_n /* informateurs_taux_v1 */$b$,
  'informateurs_taux_v1');
SELECT pg_temp.rp_raccorder('public.crim_enquete_taux_interne(bigint,text)'::regprocedure,
  $a$'informateur', v_inf,$a$,
  $b$'informateur', v_inf, 'informateur_palier', public.crim_informateur_palier_interne(p_affaire) /* informateurs_pistes_v1 */,$b$,
  'informateurs_pistes_v1');

-- ── Anciens informateurs recrutés : désactivés, sans effacer aucune donnée ────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.informateur_recruter(p_niveau integer, p_pa integer, p_cost integer)
RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT jsonb_build_object('ok', false, 'raison', 'informateurs_supprimes') $$;
CREATE OR REPLACE FUNCTION public.informateur_interroger(p_niveau integer, p_pa integer)
RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT jsonb_build_object('ok', false, 'raison', 'informateurs_supprimes') $$;
-- Plus aucun salaire prélevé la nuit ; les listes existantes restent en base (Fred décidera de leur sort).
CREATE OR REPLACE FUNCTION public.minuit_informateurs()
RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT jsonb_build_object('ok', true, 'payes', 0, 'partis', 0, 'desactive', true) $$;
UPDATE public.pnj_metiers_profils SET recrutable = false WHERE metier = 'informateur' AND recrutable IS DISTINCT FROM false;

-- Tarifs : les cinq ordres retirés de data.js quittent le miroir ; l'ordre « Acheter une information » y entre (gratuit :
-- la somme, libre dans le barème, est versée par informateur_payer hors payer_ordre, comme l'habitué du Bar Sever).
DELETE FROM public.ordres_couts WHERE (fn, pa, cost) IN (('recruter_informateur_pnj', 1, 150), ('recruter_informateur_2', 1, 400),
  ('recruter_info_4', 3, 0), ('consulter_info_4', 1, 0), ('gerer_informateurs', 0, 0));
INSERT INTO public.ordres_couts (fn, pa, cost) SELECT 'informateur_payer', 0, 0
 WHERE NOT EXISTS (SELECT 1 FROM public.ordres_couts WHERE fn = 'informateur_payer' AND pa = 0 AND cost = 0);

-- ── Droits ───────────────────────────────────────────────────────────────────────────────────────────────────────
REVOKE ALL ON TABLE public.informateurs_pnj, public.informateurs_achats FROM anon, authenticated;
REVOKE ALL ON FUNCTION public.informateur_traits_interne(text, integer, boolean), public.informateur_fait_interne(text, text, text, text, text),
  public.informateur_banal_interne(text, text), public.informateur_debiter_interne(text, integer),
  public.informateur_reponse_interne(text, public.informateurs_pnj, text), public.informateur_payer_interne(text, text, integer),
  public.informateur_ecoute_payante_interne(text, text, text, text), public.crim_informateur_palier_interne(bigint),
  public.crim_informateur_piste_interne(bigint), public.crim_informateur_reduction_interne(bigint) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.informateurs_ici(), public.informateur_payer(uuid, text, integer), public.crim_informateur_payer(bigint, integer, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.informateurs_ici(), public.informateur_payer(uuid, text, integer), public.crim_informateur_payer(bigint, integer, uuid) TO authenticated;

COMMIT;
