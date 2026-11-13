-- Vol d'archives d'écoute raté : 1 jour de prison (Fred, 13/11/2026, 22 h 11 : « Une tentative de vol vaut
-- 1 jour de prison »). Le barème générique appliquait 2 jours (« Délit mineur »). Vaut pour les trois
-- centres (Novomirsk, Starovka, Krasnov). Patch en place : seule la durée passée à l'arrestation change.
DO $m$
DECLARE f text := pg_get_functiondef('public.sovarka_ecoute_archives_voler(text)'::regprocedure);
  ancien text := E'après une bagarre avec l''''opérateur''));';
  nouveau text := E'après une bagarre avec l''''opérateur'', 1)); /* vol_archives_un_jour */';
BEGIN
  IF position('vol_archives_un_jour' IN f) > 0 THEN RETURN; END IF;
  IF position(ancien IN f) = 0 THEN RAISE EXCEPTION 'vol d''archives : fragment introuvable'; END IF;
  EXECUTE replace(f, ancien, nouveau);
  IF position('vol_archives_un_jour' IN pg_get_functiondef('public.sovarka_ecoute_archives_voler(text)'::regprocedure)) = 0 THEN
    RAISE EXCEPTION 'durée non posée'; END IF;
END $m$;
