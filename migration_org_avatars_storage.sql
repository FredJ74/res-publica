-- Migration requise avant que l'IMPORT DE FICHIER (avatar d'organisation) ne fonctionne
-- effectivement. L'avatar par URL externe fonctionne deja sans cette migration -- voir la
-- note de sequencement en bas de fichier.
--
-- Contexte : verifie en direct via l'API REST Supabase (GET /storage/v1/bucket) -- aucun bucket
-- Supabase Storage n'existe a ce jour dans ce projet (reponse []), et aucune reference a
-- storage/upload/bucket n'existe nulle part dans le depot avant ce lot. L'unique precedent
-- d'"upload d'image" du jeu (photo de profil du personnage, confirmerChangementPhoto,
-- plateau-personnage.js) stocke en realite un data URI base64 directement dans la colonne
-- personnages.photo_url -- deliberement NON reproduit ici (demande explicitement d'eviter le
-- stockage de blobs/base64 dans la table organisations). Architecture retenue a la place :
-- fichier reel dans un bucket Storage dedie, URL publique stockee dans orga.avatar (propriete
-- deja existante de l'organisation, flexible car la table organisations stocke un JSON --
-- aucune migration necessaire pour orga.avatar lui-meme).
--
-- Bucket 'org-avatars', PUBLIC (lecture) : les avatars d'organisation sont deja publics par
-- nature (affiches a tout lecteur du forum/des mails), pas de raison de les proteger en
-- lecture. Ecriture (insert/delete) laissee ouverte a la cle anon, exactement le meme modele
-- de confiance que TOUTES les autres tables de ce projet (aucune session Supabase Auth reelle
-- par joueur ; la securite reelle -- verification du chef actuel -- est faite cote client au
-- moment de la sauvegarde, meme doctrine que le forum/les mails, PAS par une policy Storage
-- qui n'aurait de toute facon aucun moyen de savoir qui est le "chef" d'une organisation).
-- Validation de forme (format image, taille max 2 Mo) faite cote client avant l'envoi
-- (sbUploadOrgAvatar, supabase.js) -- une policy Storage ne peut pas inspecter le contenu d'un
-- fichier, seulement bucket_id/chemin.
--
-- Nom de fichier genere cote systeme (jamais le nom fourni par le joueur), prefixe par l'id de
-- l'organisation (org-avatars/<orgaId>/<horodatage>-<alea>.<ext>) : namespace naturel qui evite
-- les collisions entre organisations et permet un nettoyage cible (sbSupprimerAncienAvatarOrga
-- ne supprime jamais qu'un fichier dont l'URL commence exactement par le prefixe public de ce
-- bucket -- jamais une URL externe saisie par le joueur).
--
-- La cle anon n'a pas les privileges necessaires pour creer un bucket elle-meme (comme pour
-- tout changement de schema de ce projet) -- a executer manuellement dans l'editeur SQL
-- Supabase.

insert into storage.buckets (id, name, public)
values ('org-avatars', 'org-avatars', true)
on conflict (id) do nothing;

-- CREATE POLICY ne supporte pas IF NOT EXISTS en PostgreSQL -- DROP IF EXISTS puis CREATE
-- rend ce bloc rejouable sans erreur si la migration est executee plusieurs fois.
drop policy if exists "org-avatars lecture publique" on storage.objects;
create policy "org-avatars lecture publique"
on storage.objects for select
using (bucket_id = 'org-avatars');

drop policy if exists "org-avatars ecriture" on storage.objects;
create policy "org-avatars ecriture"
on storage.objects for insert
with check (bucket_id = 'org-avatars');

drop policy if exists "org-avatars suppression" on storage.objects;
create policy "org-avatars suppression"
on storage.objects for delete
using (bucket_id = 'org-avatars');

-- Sequencement / securite de deploiement : le code cote client (sauvegarderOptionsOrga,
-- plateau-organisations-quetes.js) n'appelle sbUploadOrgAvatar QUE si le joueur a
-- explicitement choisi "Importer une image" -- une URL saisie a la main continue de
-- fonctionner exactement comme avant, deploiement compris, MEME AVANT que cette migration ne
-- soit appliquee. Tant que le bucket n'existe pas, une tentative d'upload echoue proprement
-- (sbUploadOrgAvatar renvoie null -> message d'erreur clair, aucun etat local corrompu, aucune
-- sauvegarde partielle) au lieu de casser quoi que ce soit d'existant.
