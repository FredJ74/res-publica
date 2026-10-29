-- Correctif de livraison #240 : le box portuaire conserve son contrat de location
-- multitenant existant (signature côté écran, tarif contrôlé à 15 FR).
-- Le CREATE initial donne signature_serveur=true aux lignes fraîchement insérées ;
-- la clause ON CONFLICT ne le corrige que si une ligne existe déjà.
-- Ce correctif garantit la valeur attendue lors de la première installation.
UPDATE public.locaux_loyers_referentiel
   SET signature_serveur = false
 WHERE batiment = 'port-sainte-marie' AND piece = 'box-portuaire'
   AND signature_serveur IS DISTINCT FROM false;
