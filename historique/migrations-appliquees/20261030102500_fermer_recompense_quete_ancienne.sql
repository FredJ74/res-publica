-- #252 : fermer l'ancienne remise de recompenses aléatoires, sans supprimer l'historique.
-- Cette fonction n'est utilisee que par le generateur historique des quetes_actives.
-- Les quetes accueil et musee n'appellent pas cette porte.
REVOKE EXECUTE ON FUNCTION public.quete_objet_reclamer(uuid,text) FROM PUBLIC, anon, authenticated;
