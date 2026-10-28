-- APPLIQUEE le 28/10/2026 par Claude via MCP apply_migration -- registre Supabase 20261028210452.
-- Les migrations de la PR #213 sont en base AVANT la livraison groupee de son ecran. L'ecran
-- en ligne depose encore dans le fret par INSERT direct dans contenu_caisses_fret : la garde
-- hg_fret_contenu_source l'aurait refuse (objet rendu au joueur, mais fret inutilisable).
-- « On ne ferme pas pour reparer » : garde suspendue ; elle est reactivee par 20261028210000,
-- a appliquer juste apres la livraison.
ALTER TABLE public.contenu_caisses_fret DISABLE TRIGGER hg_fret_contenu_source;
