-- NON APPLIQUÉE — migration finale des renommages de PNJ qui touchent la base (Fred, 23/11/2026 : une seule migration
-- pour tous les renommages). Mission « Novomirsk, PNJ, interface » (GAME-DESIGN-NOVOMIRSK-PNJ-INTERFACE-20261123.md).
-- À appliquer EN MÊME TEMPS que la fusion du commit client des renommages du bloc 6 (ea108d73) : sinon le serveur ne
-- reconnaît plus ces PNJ comme informateurs.
-- Décidés par Fred : bloc 6, point 37 (gare de Novomirsk) ; bloc 3, point 26 (hôtesse du musée de Krasnov).
-- À compléter, après le choix de Fred, par les prénoms des points 42 et 44 (tenancière de la buvette du Dynamo, secrétaire
-- municipale, archiviste municipale, noms génériques) s'ils figurent en base. Relevé du 23/11 : en base figurent
-- « soviet:capitale:stade:buvette:Tenancier de Buvette » et « soviet:capitale:mairie-capitale:hall_mairie:Secrétaire municipal
-- Arseni Krylov » (l'archiviste municipale n'est pas informatrice).
-- Relevé en lecture seule du 23/11/2026 : ces noms n'existent que dans public.informateurs_pnj (id, piece, nom) ;
-- aucune clé étrangère ne pointe vers cette table. Idempotente : chaque UPDATE ne joue que si l'ancienne ligne existe
-- et que la nouvelle n'existe pas encore.

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

DO $controle$ BEGIN
  IF EXISTS (SELECT 1 FROM public.informateurs_pnj WHERE nom IN ('Camarade Horaire', 'Agente Nadejda', 'Hôtesse du musée de Krasnov')) THEN
    RAISE EXCEPTION 'renommages : un ancien nom subsiste dans informateurs_pnj';
  END IF;
END $controle$;
