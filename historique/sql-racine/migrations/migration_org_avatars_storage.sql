-- Migration requise avant que l'IMPORT DE FICHIER (avatar d'organisation) ne fonctionne
-- effectivement. L'avatar par URL externe fonctionne deja sans cette migration -- voir la
-- note de sequencement en bas de fichier.
--
-- REVISION du 17 aout 2026 -- la version precedente de ce fichier a ete rejetee en revue :
-- elle ouvrait des policies INSERT/DELETE au bucket pour la cle anon, ce qui aurait permis a
-- n'importe quel appel API direct (hors du code du jeu) d'ecrire/supprimer des fichiers dans
-- 'org-avatars' sans passer par la verification du chef, ni par les controles de format/
-- taille -- une simple verification cote client ne constitue pas une securite reelle.
--
-- Architecture corrigee : l'upload passe desormais PAR UN ENDPOINT SERVEUR
-- (api/upload-org-avatar.js, fonction Vercel) qui fait AUTORITE sur ces controles, avec une
-- cle Supabase privilegiee (service_role) qui ne contourne RLS QUE cote serveur -- jamais
-- exposee au client. Le bucket lui-meme n'a donc plus BESOIN d'aucune policy d'ecriture pour
-- la cle anon : le service_role contourne RLS par nature (aucune policy necessaire pour lui),
-- et sans policy anon explicite pour insert/delete, ces operations sont refusees par defaut
-- des que RLS est active sur storage.objects (actif par defaut sur un projet Supabase).
--
-- Contexte : verifie en direct via l'API REST Supabase (GET /storage/v1/bucket) -- aucun bucket
-- Supabase Storage n'existe a ce jour dans ce projet (reponse []), et aucune reference a
-- storage/upload/bucket n'existait nulle part dans le depot avant ce lot. L'unique precedent
-- d'"upload d'image" du jeu (photo de profil du personnage, confirmerChangementPhoto,
-- plateau-personnage.js) stocke en realite un data URI base64 directement dans la colonne
-- personnages.photo_url -- deliberement NON reproduit ici (demande explicitement d'eviter le
-- stockage de blobs/base64 dans la table organisations). orga.avatar (propriete deja existante
-- de l'organisation, flexible car la table organisations stocke un JSON) reste LA seule
-- propriete d'avatar -- aucune migration necessaire pour elle-meme, uniquement pour le bucket.
--
-- Bucket 'org-avatars', PUBLIC en LECTURE uniquement : les avatars d'organisation sont deja
-- publics par nature (affiches a tout lecteur du forum/des mails). AUCUNE policy INSERT,
-- AUCUNE policy DELETE pour la cle anon -- toute ecriture/suppression passe obligatoirement par
-- api/upload-org-avatar.js (cle service_role, verification fraiche du chef, format/taille
-- controles sur le contenu reellement recu, jamais declare par le client).
--
-- La cle anon n'a pas les privileges necessaires pour creer un bucket elle-meme (comme pour
-- tout changement de schema de ce projet) -- a executer manuellement dans l'editeur SQL
-- Supabase. Si la version precedente (avec policies "org-avatars ecriture"/"org-avatars
-- suppression") a deja ete executee, ce fichier les retire explicitement.

insert into storage.buckets (id, name, public)
values ('org-avatars', 'org-avatars', true)
on conflict (id) do nothing;

-- Retire explicitement les policies d'ecriture/suppression anon de l'ancienne version de cette
-- migration, si elle a deja ete executee -- sans erreur si elles n'existent pas.
drop policy if exists "org-avatars ecriture" on storage.objects;
drop policy if exists "org-avatars suppression" on storage.objects;

-- CREATE POLICY ne supporte pas IF NOT EXISTS en PostgreSQL -- DROP IF EXISTS puis CREATE
-- rend ce bloc rejouable sans erreur si la migration est executee plusieurs fois.
drop policy if exists "org-avatars lecture publique" on storage.objects;
create policy "org-avatars lecture publique"
on storage.objects for select
using (bucket_id = 'org-avatars');

-- Aucune policy INSERT ni DELETE pour la cle anon : l'ecriture/suppression n'est possible que
-- via api/upload-org-avatar.js, authentifie avec la cle service_role (contourne RLS par
-- nature, aucune policy dediee necessaire pour elle).

-- Sequencement / securite de deploiement : le code cote client (sauvegarderOptionsOrga,
-- plateau-organisations-quetes.js) n'appelle sbUploadOrgAvatar QUE si le joueur a
-- explicitement choisi "Importer une image" -- une URL saisie a la main continue de
-- fonctionner exactement comme avant, deploiement compris, MEME AVANT que cette migration ne
-- soit appliquee ET meme avant que la variable d'environnement SUPABASE_SERVICE_ROLE_KEY ne
-- soit configuree cote Vercel. Tant que l'un ou l'autre manque, une tentative d'upload echoue
-- proprement (message d'erreur clair, aucun etat local corrompu, aucune sauvegarde partielle)
-- au lieu de casser quoi que ce soit d'existant.
