-- #252 : les enquetes aleatoires historiques ne font plus partie du jeu.
-- Conserver les lignes pour audit, fermer seulement leurs ecritures client.
-- Ne pas modifier les quetes d'accueil, de musee ou les procedures judiciaires.
REVOKE INSERT, UPDATE, DELETE ON TABLE public.quetes_actives FROM authenticated, anon;
