-- APPLIQUÉE en production le 23/11/2026 (feu vert de Fred, une transaction ; contrôlée en lecture : 7 nouveaux noms, aucun
-- ancien libellé en Sovarka, Républia intacte). Migration finale des renommages de PNJ qui touchent la base (Fred, 23/11/2026 : une seule migration
-- pour tous les renommages). Mission « Novomirsk, PNJ, interface » (GAME-DESIGN-NOVOMIRSK-PNJ-INTERFACE-20261123.md,
-- points 26, 37, 42 et 44 ; noms validés par Fred le 23/11/2026). À appliquer avec le client qui porte les nouveaux noms
-- (commit ea108d73 intégré et renommages des points 42 et 44 dans data.js) : sinon le serveur ne reconnaît plus ces PNJ
-- comme informateurs (l'écran garde l'ancien nom en aliasInformateur pour la transition).
-- Relevé en lecture seule du 23/11/2026, toutes colonnes texte et jsonb du schéma public : sur les 20 renommages, seuls
-- 7 anciens libellés de Sovarka existent en base, tous dans public.informateurs_pnj (id, piece, nom ; aucune clé
-- étrangère vers cette table). Les 13 autres n'existent que côté client et restent hors migration. Les lignes de
-- pnj_lieux_metiers, tracts_pnj_catalogue et personnages_donnees.contacts trouvées sous ces libellés sont celles de la
-- Républia : inchangées. La quête active « Une affaire mystérieuse » (quetes_actives, pnj_actif « Armurier Militaire »,
-- caserne-militaire, sans ville) n'est pas touchée : l'armurier de la Garnison du Peuple garde ce nom.
-- Idempotente : chaque UPDATE ne joue que si l'ancienne ligne existe et que la nouvelle n'existe pas encore.

-- Bloc 6, point 37 : « Camarade Horaire » -> « Vassili Sukhoï » (graphie voulue), chef de gare, hall principal.
UPDATE public.informateurs_pnj
   SET id = 'soviet:capitale:centre-multinodal-luthecia:hall_gare:Vassili Sukhoï',
       nom = 'Vassili Sukhoï'
 WHERE id = 'soviet:capitale:centre-multinodal-luthecia:hall_gare:Camarade Horaire'
   AND NOT EXISTS (SELECT 1 FROM public.informateurs_pnj
                    WHERE id = 'soviet:capitale:centre-multinodal-luthecia:hall_gare:Vassili Sukhoï');

-- Bloc 6, point 37 : « Agente Nadejda » -> « Lioudmila Proverkina », agente de contrôle, déplacée au hall des douanes.
UPDATE public.informateurs_pnj
   SET id = 'soviet:capitale:centre-multinodal-luthecia:hall_douanes:Lioudmila Proverkina',
       piece = 'hall_douanes',
       nom = 'Lioudmila Proverkina'
 WHERE id = 'soviet:capitale:centre-multinodal-luthecia:hall_gare:Agente Nadejda'
   AND NOT EXISTS (SELECT 1 FROM public.informateurs_pnj
                    WHERE id = 'soviet:capitale:centre-multinodal-luthecia:hall_douanes:Lioudmila Proverkina');

-- Bloc 3, point 26 : « Hôtesse du musée de Krasnov » -> « Zoïa Biletova » (l'écran fait le lien par aliasInformateur
-- tant que cette ligne n'est pas renommée).
UPDATE public.informateurs_pnj
   SET id = 'soviet:ville_b:musee-novomirsk:hall:Zoïa Biletova',
       nom = 'Zoïa Biletova'
 WHERE id = 'soviet:ville_b:musee-novomirsk:hall:Hôtesse du musée de Krasnov'
   AND NOT EXISTS (SELECT 1 FROM public.informateurs_pnj
                    WHERE id = 'soviet:ville_b:musee-novomirsk:hall:Zoïa Biletova');

-- Point 42 : « Tenancier de Buvette » (stade du Dynamo) -> « Zinaïda Kvassova », tenancière.
UPDATE public.informateurs_pnj
   SET id = 'soviet:capitale:stade:buvette:Zinaïda Kvassova', nom = 'Zinaïda Kvassova', role = 'Tenancière de la buvette'
 WHERE id = 'soviet:capitale:stade:buvette:Tenancier de Buvette'
   AND NOT EXISTS (SELECT 1 FROM public.informateurs_pnj WHERE id = 'soviet:capitale:stade:buvette:Zinaïda Kvassova');

-- Point 42 : « Secrétaire municipal Arseni Krylov » -> « Valentina Petchatkina », secrétaire municipale.
UPDATE public.informateurs_pnj
   SET id = 'soviet:capitale:mairie-capitale:hall_mairie:Valentina Petchatkina', nom = 'Valentina Petchatkina', role = 'Secrétaire municipale'
 WHERE id = 'soviet:capitale:mairie-capitale:hall_mairie:Secrétaire municipal Arseni Krylov'
   AND NOT EXISTS (SELECT 1 FROM public.informateurs_pnj WHERE id = 'soviet:capitale:mairie-capitale:hall_mairie:Valentina Petchatkina');

-- Point 44 : « Hôtesse d'Accueil » (Palais des Ambassades) -> « Elvira Priomova ».
UPDATE public.informateurs_pnj
   SET id = 'soviet:capitale:palais-ambassades-novomirsk:accueil_ambassades_novomirsk:Elvira Priomova', nom = 'Elvira Priomova'
 WHERE id = 'soviet:capitale:palais-ambassades-novomirsk:accueil_ambassades_novomirsk:Hôtesse d''Accueil'
   AND NOT EXISTS (SELECT 1 FROM public.informateurs_pnj WHERE id = 'soviet:capitale:palais-ambassades-novomirsk:accueil_ambassades_novomirsk:Elvira Priomova');

-- Point 44 : « Agent de Sécurité » (Palais des Ambassades) -> « Gleb Okhranov ».
UPDATE public.informateurs_pnj
   SET id = 'soviet:capitale:palais-ambassades-novomirsk:accueil_ambassades_novomirsk:Gleb Okhranov', nom = 'Gleb Okhranov'
 WHERE id = 'soviet:capitale:palais-ambassades-novomirsk:accueil_ambassades_novomirsk:Agent de Sécurité'
   AND NOT EXISTS (SELECT 1 FROM public.informateurs_pnj WHERE id = 'soviet:capitale:palais-ambassades-novomirsk:accueil_ambassades_novomirsk:Gleb Okhranov');

DO $controle$ BEGIN
  IF EXISTS (SELECT 1 FROM public.informateurs_pnj WHERE pays = 'soviet' AND (nom IN ('Camarade Horaire', 'Agente Nadejda',
       'Hôtesse du musée de Krasnov', 'Secrétaire municipal Arseni Krylov')
       OR id IN ('soviet:capitale:stade:buvette:Tenancier de Buvette',
                 'soviet:capitale:palais-ambassades-novomirsk:accueil_ambassades_novomirsk:Hôtesse d''Accueil',
                 'soviet:capitale:palais-ambassades-novomirsk:accueil_ambassades_novomirsk:Agent de Sécurité'))) THEN
    RAISE EXCEPTION 'renommages : un ancien nom subsiste dans informateurs_pnj';
  END IF;
  IF (SELECT count(*) FROM public.informateurs_pnj WHERE nom IN ('Vassili Sukhoï', 'Lioudmila Proverkina', 'Zoïa Biletova',
        'Zinaïda Kvassova', 'Valentina Petchatkina', 'Elvira Priomova', 'Gleb Okhranov')) <> 7 THEN
    RAISE EXCEPTION 'renommages : les sept nouveaux noms ne sont pas tous en base';
  END IF;
END $controle$;
