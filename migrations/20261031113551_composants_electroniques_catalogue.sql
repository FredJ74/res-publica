-- PRÉPARATION NON APPLIQUÉE : rehorodatée après la coupe canonique du 31/10/2026.
-- Ancien fichier : 20261018230000_composants_electroniques_catalogue.sql ; aucun changement de règle.
-- Catalogue initial de la filiere electronique (18 octobre 2026).
-- La consommation des produits intermediaires par d'autres references reste
-- a raccorder dans fonds_reference_produire_lots avant remplacement des recettes finales.
INSERT INTO public.catalogue_generiques
 (id,libelle,famille_id,regime,est_service,empilable,individualise,consommable,equipable)
VALUES ('composants-electroniques','Composants électroniques','informatique','libre',false,true,false,false,false)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.catalogue_generique_type (generique_id,type_id)
VALUES ('composants-electroniques','electronique-informatique')
ON CONFLICT DO NOTHING;

INSERT INTO public.recettes_commerce
 (id,source,label,pa,portions,materiaux,categorie,types_autorises,generique_id)
VALUES ('composants_electroniques_commerce','commerce','Composants électroniques',
 3,2,'{"metal":1,"produits_exotiques":1}'::jsonb,'informatique',
 '["electronique-informatique"]'::jsonb,'composants-electroniques')
ON CONFLICT (id) DO NOTHING;
