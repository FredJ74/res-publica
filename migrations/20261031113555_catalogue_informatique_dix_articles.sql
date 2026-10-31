-- PRÉPARATION NON APPLIQUÉE : rehorodatée après la coupe canonique du 31/10/2026.
-- Ancien fichier : 20261019001000_catalogue_informatique_dix_articles.sql ; aucun changement de règle.
-- Filiere electronique : 10 references pour electronique-informatique.
-- Les generiques de surveillance et jeu-video existaient deja.
INSERT INTO public.catalogue_generiques
(id,libelle,famille_id,regime,est_service,empilable,individualise,consommable,equipable,note)
VALUES
('box-internet','Box internet','informatique','libre',false,false,true,false,false,'Connexion internet des locaux'),
('imprimante-papier','Imprimante papier','informatique','libre',false,false,true,false,false,'Impression de documents, journaux et tracts'),
('imprimante-3d','Imprimante 3D','informatique','libre',false,false,true,false,false,'Fabrication d’objets à partir de plans'),
('peripherique-stockage','Périphérique de stockage','informatique','libre',false,false,true,false,false,'Stockage numérique'),
('peripherique-reseau-intranet','Périphérique réseau intranet','informatique','libre',false,false,true,false,false,'Protection et réseau local')
ON CONFLICT(id) DO NOTHING;
INSERT INTO public.catalogue_generique_type(generique_id,type_id)
SELECT id,'electronique-informatique' FROM public.catalogue_generiques WHERE id IN
('box-internet','imprimante-papier','imprimante-3d','peripherique-stockage','peripherique-reseau-intranet')
ON CONFLICT DO NOTHING;
INSERT INTO public.recettes_commerce
(id,source,label,pa,portions,materiaux,intermediaires,categorie,types_autorises,generique_id)
VALUES
('box_internet_commerce','commerce','Box internet',2,1,'{"metal":1}'::jsonb,'{"composants-electroniques":1}'::jsonb,'informatique','["electronique-informatique"]'::jsonb,'box-internet'),
('camera_surveillance_commerce','commerce','Caméra de surveillance',2,1,'{"metal":1}'::jsonb,'{"composants-electroniques":1}'::jsonb,'informatique','["electronique-informatique"]'::jsonb,'camera-de-surveillance'),
('imprimante_papier_commerce','commerce','Imprimante papier',2,1,'{"metal":2}'::jsonb,'{"composants-electroniques":1}'::jsonb,'informatique','["electronique-informatique"]'::jsonb,'imprimante-papier'),
('imprimante_3d_commerce','commerce','Imprimante 3D',4,1,'{"metal":3}'::jsonb,'{"composants-electroniques":2}'::jsonb,'informatique','["electronique-informatique"]'::jsonb,'imprimante-3d'),
('peripherique_stockage_commerce','commerce','Périphérique de stockage',1,1,'{"metal":1}'::jsonb,'{"composants-electroniques":1}'::jsonb,'informatique','["electronique-informatique"]'::jsonb,'peripherique-stockage'),
('peripherique_reseau_commerce','commerce','Périphérique réseau intranet',2,1,'{"metal":1}'::jsonb,'{"composants-electroniques":2}'::jsonb,'informatique','["electronique-informatique"]'::jsonb,'peripherique-reseau-intranet'),
('jeu_video_commerce','commerce','Jeu vidéo',1,1,'{}'::jsonb,'{"composants-electroniques":1}'::jsonb,'informatique','["electronique-informatique"]'::jsonb,'jeu-video')
ON CONFLICT(id) DO NOTHING;
-- Les quatre appellations generiques historiques ne sont pas des articles supplementaires.
DELETE FROM public.catalogue_generique_type WHERE type_id='electronique-informatique'
 AND generique_id IN ('appareil-de-communication','appareil-electronique','console-de-jeu','peripherique-informatique');
