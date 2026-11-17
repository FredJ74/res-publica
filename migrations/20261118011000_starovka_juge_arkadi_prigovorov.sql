-- Tribunal de Starovka (Fred, 18/11/2026) : le juge populaire titulaire PNJ devient Arkadi Prigovorov,
-- l'homme du décor de la salle d'audience ; Dulma Tsyrenova n'est plus juge. Seul le nom du titulaire
-- PNJ change ; aucune affaire, aucun poste de joueur touché. Idempotente.
BEGIN;
UPDATE public.titulaires_pnj SET nom_pnj = 'Arkadi Prigovorov (PNJ)'
 WHERE id = 'soviet_juge_ville_a' AND nom_pnj IS DISTINCT FROM 'Arkadi Prigovorov (PNJ)';
DO $post$
BEGIN
  IF (SELECT nom_pnj FROM public.titulaires_pnj WHERE id = 'soviet_juge_ville_a') IS DISTINCT FROM 'Arkadi Prigovorov (PNJ)'
  THEN RAISE EXCEPTION 'starovka_juge : titulaire absent ou non renommé'; END IF;
END $post$;
COMMIT;
