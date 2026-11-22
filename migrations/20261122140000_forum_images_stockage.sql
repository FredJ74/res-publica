-- Forum, images (Fred, 22/11/2026, nuit, point 7) : stockage Supabase « forum-images », envoi direct depuis le navigateur,
-- sans nouvelle fonction Vercel. Lecture publique ; écriture réservée au joueur connecté, dans un dossier à son nom
-- (son identifiant de compte, comme publicites-premium-sources) ; images seulement (PNG, JPEG, WebP, GIF), 5 Mo au plus.
-- Les images extérieures déjà présentes dans les messages sont recopiées dans le dossier « externes/ » par le traitement
-- de nuit (clé de service, api/_forum-images-externes.js) ; aucun joueur ne peut écrire dans ce dossier.
-- Aucun objet du goulag touché.
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('forum-images', 'forum-images', true, 5242880, ARRAY['image/png', 'image/jpeg', 'image/webp', 'image/gif'])
ON CONFLICT (id) DO UPDATE SET public = true, file_size_limit = 5242880, allowed_mime_types = ARRAY['image/png', 'image/jpeg', 'image/webp', 'image/gif'];

DROP POLICY IF EXISTS forum_images_lecture ON storage.objects;
CREATE POLICY forum_images_lecture ON storage.objects FOR SELECT USING (bucket_id = 'forum-images');
DROP POLICY IF EXISTS forum_images_ecriture_joueur ON storage.objects;
CREATE POLICY forum_images_ecriture_joueur ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'forum-images' AND (storage.foldername(name))[1] = (auth.uid())::text);
