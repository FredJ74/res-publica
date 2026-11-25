-- Mission de nuit du 25/11/2026 (Claude), bloc 1.1 — APPLIQUÉE en production le 25/11/2026 (feu vert de Fred, contrôlée en lecture).
-- Le commit 32e5b8d (Fred, 24/11) renomme le généraliste du Dispensaire Public de Luthécia :
-- « Docteur Aspirine » -> « Mathias Spirine ». Le miroir serveur du casting (pnj_lieux_metiers, généré depuis data.js)
-- garde l'ancien nom : tant que cette migration n'est pas appliquée, un don d'argent ou d'objet à Mathias Spirine
-- est refusé par le serveur comme à un PNJ absent (le dialogue, lui, fonctionne : profil mathias_spirine côté API).
-- Idempotente : ne joue que si l'ancienne ligne existe et que la nouvelle n'existe pas encore.
--
-- Contrôle en lecture après application :
--   SELECT nom, job FROM public.pnj_lieux_metiers
--    WHERE pays='republic' AND ville='capitale' AND building_id='dispensaire-public' AND room_id='salle_attente'
--    ORDER BY nom;
--   -- attendu : Anne Tibiotique (infirmier), Mathias Spirine (medecin) ; aucune ligne « Docteur Aspirine ».

UPDATE public.pnj_lieux_metiers
   SET nom = 'Mathias Spirine'
 WHERE pays = 'republic' AND ville = 'capitale' AND building_id = 'dispensaire-public'
   AND nom = 'Docteur Aspirine'
   AND NOT EXISTS (SELECT 1 FROM public.pnj_lieux_metiers m
                    WHERE m.pays = 'republic' AND m.ville = 'capitale' AND m.building_id = 'dispensaire-public'
                      AND m.room_id = pnj_lieux_metiers.room_id AND m.nom = 'Mathias Spirine');
