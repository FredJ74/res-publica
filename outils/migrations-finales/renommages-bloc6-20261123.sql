-- NON APPLIQUÉE. Fragment à fusionner dans la migration finale des renommages de PNJ (Fred, 23/11/2026 : une seule
-- migration pour tous les renommages qui touchent la base). Ce n'est PAS une migration autonome.
-- Bloc 6 de la mission « Novomirsk, PNJ, interface » (GAME-DESIGN-NOVOMIRSK-PNJ-INTERFACE-20261123.md, point 37) :
--   « Camarade Horaire »  -> « Vassili Sukhoï » (graphie VOULUE, jamais « Soukhoï »), chef de gare, hall principal (hall_gare) ;
--   « Agente Nadejda »    -> « Lioudmila Proverkina », agente de contrôle, DÉPLACÉE au hall des douanes (hall_douanes).
-- Relevé en lecture seule du 23/11/2026 (toutes les colonnes texte et jsonb du schéma public) : ces deux noms n'existent que
-- dans public.informateurs_pnj (colonnes id, piece, nom) ; aucune clé étrangère ne pointe vers cette table. Le doublon
-- « Nadejda Contrôle » n'existait que côté client (jamais affiché) : rien en base. Les lignes « Inspecteur Prosper Tampon »
-- de tracts_pnj_catalogue et pnj_lieux_metiers sont celles de la Républia (Luthécia) : inchangées.
-- Lignes cibles = sortie de outils/generateurs/generer-informateurs-lieux.cjs sur le data.js du dernier commit de la branche
-- claude/bloc6-novomirsk-20261123. Idempotent : rejouable sans effet.

UPDATE public.informateurs_pnj
   SET id = 'soviet:capitale:centre-multinodal-luthecia:hall_gare:Vassili Sukhoï',
       nom = 'Vassili Sukhoï'
 WHERE id = 'soviet:capitale:centre-multinodal-luthecia:hall_gare:Camarade Horaire'
   AND NOT EXISTS (SELECT 1 FROM public.informateurs_pnj
                    WHERE id = 'soviet:capitale:centre-multinodal-luthecia:hall_gare:Vassili Sukhoï');

UPDATE public.informateurs_pnj
   SET id = 'soviet:capitale:centre-multinodal-luthecia:hall_douanes:Lioudmila Proverkina',
       piece = 'hall_douanes',
       nom = 'Lioudmila Proverkina'
 WHERE id = 'soviet:capitale:centre-multinodal-luthecia:hall_gare:Agente Nadejda'
   AND NOT EXISTS (SELECT 1 FROM public.informateurs_pnj
                    WHERE id = 'soviet:capitale:centre-multinodal-luthecia:hall_douanes:Lioudmila Proverkina');

-- Contrôle attendu après application (2 lignes, rôles inchangés « Chef de gare » et « Agente de contrôle », profil « lieu ») :
-- SELECT id, piece, nom, role, profil FROM public.informateurs_pnj
--  WHERE batiment = 'centre-multinodal-luthecia' AND pays = 'soviet' ORDER BY id;
