-- =====================================================================
-- MIGRATION — IDENTITE DES BAUX : AJOUT DU PAYS DANS locations_actives.id
-- Lot 1.3 bis, chantier immobilier, 6 septembre 2026
-- =====================================================================
-- ⚠️  NON EXECUTEE. Fournie pour relecture.
--
-- POURQUOI
-- La cle primaire locations_actives_pkey (id) portait 'buildingId:roomId:city', sans le pays.
-- Or les QUATRE empires utilisent exactement les memes cles de ville ('capitale', 'ville_a',
-- 'ville_b') ET les memes buildingId : 'centre-affaires', 'centre-commercial' et
-- 'centre-artisanal' sont chacun declares dans 12 listes buildings[] (4 empires x 3 villes).
-- 'centre-affaires:bureau_prestige:capitale' etait donc LA MEME CHAINE dans les quatre empires.
--
-- Consequences reelles avant correction : un joueur d'un autre empire louant "le meme" local
-- aurait vu sbSaveLocation ECRASER le bail republien (colonne country comprise), et
-- sbClaimerLocation lui aurait repondu "deja loue" a cause d'un bail etranger. Aucune collision
-- ne s'etait produite uniquement parce que les 7 baux existants sont tous 'republic' -- une
-- coincidence d'usage, jamais un invariant.
--
-- Nouvelle identite : 'country:buildingId:roomId:city'
-- Variante box portuaire multi-tenant : 'country:buildingId:roomId:city:locataire'
-- Elle coincide desormais avec l'identite logique mondiale du local (localKey,
-- plateau-immobilier.js : country|city|buildingId|roomId -- memes quatre dimensions).
-- id reste la PRIMARY KEY : ni la contrainte ni le schema ne changent, seule la VALEUR change.
--
-- ETAT DE LA PRODUCTION, verifie en LECTURE SEULE avant redaction (aucune ecriture) :
--     locations_actives                    : 7 lignes
--     country = 'republic'                 : 7 / 7
--     id deja prefixes 'republic:'         : 0
--     id a exactement 3 segments           : 7 / 7
--     id strictement egal a data->>buildingId:roomId:city : 7 / 7
--     data->>'country' == colonne country  : 7 / 7
--     ids distincts apres conversion       : 7 / 7  (aucun doublon logique)
--     aucun box, aucun logement social, aucune chambre de clinique en base
-- => aucune anomalie, la conversion est un simple reprefixage.
--
-- CE QUI EST MODIFIE : la colonne id, et RIEN D'AUTRE.
-- La colonne data (jsonb) n'est PAS touchee : locataire, prix, bonusPOP/INF/DIS, orgaId,
-- localLabel, batimentLabel, depuis, visible et tout champ present restent strictement
-- identiques. La colonne country n'est pas touchee non plus.
--
-- SYNCHRONISATION AVEC LE DEPLOIEMENT
-- A executer au plus pres du deploiement du code correspondant. Pendant la fenetre ou les deux
-- coexistent, un bail non encore reprefixe reste LU normalement (chargerLocations filtre sur la
-- colonne country, jamais sur l'id) mais devient introuvable en ECRITURE : une resiliation ou une
-- mise a jour resterait sans effet, sans jamais rien detruire. Aucun repli sur l'ancien format
-- n'est laisse dans le code : il reintroduirait la collision inter-empires que ce lot supprime.
--
-- A EXECUTER MANUELLEMENT DANS L'EDITEUR SQL SUPABASE, comme toutes les migrations du projet.
-- =====================================================================

-- --------------------------------------------------------------------
-- 1) CONTROLES PREALABLES — a lancer SEULS d'abord.
--    Les quatre requetes doivent renvoyer les resultats indiques.
--    En cas d'ecart, NE PAS executer le bloc 2 et rapporter l'anomalie.
-- --------------------------------------------------------------------

-- 1.a  Aucune ligne ne doit deja etre prefixee (attendu : 0)
SELECT count(*) AS deja_prefixes
FROM locations_actives
WHERE id LIKE country || ':%';

-- 1.b  Toutes les lignes doivent avoir un country renseigne (attendu : 0)
SELECT count(*) AS sans_country
FROM locations_actives
WHERE country IS NULL OR country = '';

-- 1.c  Chaque id doit correspondre exactement a son contenu (attendu : 0 ligne)
--      Couvre les baux exclusifs (3 segments) ET les box (4 segments, locataire en fin).
SELECT id, country, data ->> 'buildingId' AS building_id, data ->> 'roomId' AS room_id,
       data ->> 'city' AS city, data ->> 'locataire' AS locataire
FROM locations_actives
WHERE id <> ((data ->> 'buildingId') || ':' || (data ->> 'roomId') || ':' || (data ->> 'city'))
  AND id <> ((data ->> 'buildingId') || ':' || (data ->> 'roomId') || ':' || (data ->> 'city')
             || ':' || (data ->> 'locataire'));

-- 1.d  Aucun doublon logique apres conversion (attendu : 0 ligne)
SELECT country || ':' || id AS nouvel_id, count(*)
FROM locations_actives
GROUP BY 1
HAVING count(*) > 1;

-- --------------------------------------------------------------------
-- 2) MIGRATION — reprefixage des identifiants.
--
--    IDEMPOTENCE : le WHERE exclut toute ligne deja prefixee par son propre pays. Un rejeu ne
--    produit donc jamais 'republic:republic:...'. La condition porte sur country lui-meme, pas
--    sur la chaine litterale 'republic:', pour rester correcte le jour ou d'autres empires
--    auront des baux.
--
--    Seule la colonne id est ecrite. data et country ne sont jamais mentionnes en SET.
-- --------------------------------------------------------------------
UPDATE locations_actives
SET id = country || ':' || id
WHERE id NOT LIKE country || ':%';

-- --------------------------------------------------------------------
-- 3) CONTROLES POSTERIEURS
-- --------------------------------------------------------------------

-- 3.a  Toutes les lignes doivent desormais etre prefixees (attendu : 0)
SELECT count(*) AS non_migrees
FROM locations_actives
WHERE id NOT LIKE country || ':%';

-- 3.b  Aucun double prefixe (attendu : 0)
SELECT count(*) AS doubles_prefixes
FROM locations_actives
WHERE id LIKE country || ':' || country || ':%';

-- 3.c  Contenu preserve : l'id doit se recomposer exactement depuis country + data (attendu : 0)
SELECT id
FROM locations_actives
WHERE id <> (country || ':' || (data ->> 'buildingId') || ':' || (data ->> 'roomId')
             || ':' || (data ->> 'city'))
  AND id <> (country || ':' || (data ->> 'buildingId') || ':' || (data ->> 'roomId')
             || ':' || (data ->> 'city') || ':' || (data ->> 'locataire'));

-- 3.d  Releve final, a comparer au releve initial (7 lignes, memes locataires, memes prix)
SELECT id, country, data ->> 'locataire' AS locataire, data ->> 'prix' AS prix,
       data ->> 'orgaId' AS orga_id
FROM locations_actives
ORDER BY id;

-- =====================================================================
-- CE QUI N'EST **PAS** FAIT ICI, VOLONTAIREMENT :
--   - aucune modification de la colonne data (aucun champ ajoute, retire ou reecrit) ;
--   - aucun enrichissement en localKey / destinationLoyer / orgaAutorisee : ces champs sont
--     DERIVES a la lecture pour les baux historiques (Lot 1.3) ;
--   - aucune migration de subdivisions vers des baux : la production contient 0 subdivision,
--     donc 0 bail de lot a creer (le fichier prevu a cet effet a ete retire, il produisait des
--     identifiants sans pays) ;
--   - aucune bascule de titulaire vers 'pj:' / 'orga:' ;
--   - aucune modification du cron des loyers (Lot 1.4).
-- =====================================================================
