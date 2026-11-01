-- APPLICATION ATTESTÉE par le registre canonique du 31/10/2026 : version 20261029222851.
-- Archivage documentaire seulement ; ne pas rejouer.
-- #252 : les enquetes aleatoires historiques ne font plus partie du jeu.
-- Conserver les lignes pour audit, fermer seulement leurs ecritures client.
-- Ne pas modifier les quetes d'accueil, de musee ou les procedures judiciaires.
REVOKE INSERT, UPDATE, DELETE ON TABLE public.quetes_actives FROM authenticated, anon;
