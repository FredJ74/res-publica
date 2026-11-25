-- Mission de fin de soirée du 25/11/2026 (Claude), point 1.5 — NON APPLIQUÉE. Après 20261125600000 (souvenirs, appliquée).
-- Décision de Fred : le ticket du cinéma de Montrouge se vend AU CINÉMA, auprès d'une caissière visible sur l'image du hall
-- (images/montrouge/montrouge-cinema-accueil.jpg : une jeune femme au guichet « CAISSE »). PNJ créé : Simone Aiguillard
-- (data.js, hall du cinéma ; fiche DeepSeek simone_aiguillard ; portrait recadré de l'image).
-- • Miroir serveur du casting (pnj_lieux_metiers, généré par outils/generateurs/generer-pnj-lieux-metiers.cjs) : sans cette
--   ligne, un don à Simone Aiguillard serait refusé comme à un PNJ absent.
-- • Souvenir souv_montrouge_ticket_cinema : quitte l'étal de Josette Betterave (marché) pour le guichet du cinéma. Le jeu ne dit
--   toujours pas où il se trouve (souvenirs_objets reste illisible par les joueurs ; souvenirs_ici ne parle que de la pièce).
-- Sans cette migration : le ticket reste chez Josette Betterave ; la caissière parle déjà (dialogue côté API).
--
-- Contrôles en lecture après application :
--   SELECT nom, job FROM public.pnj_lieux_metiers
--    WHERE pays = 'republic' AND ville = 'ville_b' AND building_id = 'cinema-montrouge' AND room_id = 'salle';   -- Simone Aiguillard, commercant
--   SELECT batiment, piece, pnj FROM public.souvenirs_objets WHERE cle = 'souv_montrouge_ticket_cinema';          -- cinema-montrouge, salle, Simone Aiguillard
BEGIN;

INSERT INTO public.pnj_lieux_metiers (pays, ville, building_id, room_id, nom, job, rel)
VALUES ('republic', 'ville_b', 'cinema-montrouge', 'salle', 'Simone Aiguillard', 'commercant', 'neutral')
ON CONFLICT (pays, ville, building_id, room_id, nom) DO NOTHING;

UPDATE public.souvenirs_objets
   SET batiment = 'cinema-montrouge', piece = 'salle', pnj = 'Simone Aiguillard'
 WHERE cle = 'souv_montrouge_ticket_cinema' AND pays = 'republic' AND ville = 'ville_b';

COMMIT;
