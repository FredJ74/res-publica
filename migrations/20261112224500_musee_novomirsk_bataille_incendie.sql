-- Musée de Novomirsk : deux salles d'histoire locale après les Origines et les Personnalités discrètes.
-- Aucune modification des fonctions d'énigme ni de fouille. Krasnov reste inchangé.
UPDATE public.navigation_lieux_regles
   SET pieces = '["hall","salle_origines","salle_personnalites_discretes","salle_bataille_fleuve","salle_grand_incendie"]'::jsonb
 WHERE pays = 'soviet'
   AND ville = 'capitale'
   AND batiment = 'musee-novomirsk'
   AND pieces @> '["hall","salle_origines","salle_personnalites_discretes"]'::jsonb;
