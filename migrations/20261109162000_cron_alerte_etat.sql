-- ALERTE DES PANNES DE LA PASSE DE MINUIT (Claude, 09/11/2026)
--
-- Du 1er au 6 novembre, la passe a echoue cinq nuits de suite sans que personne ne le voie
-- (cron_journal la notait pourtant en echec). Fred veut etre prevenu de chaque panne.
-- Cette fonction rend l'etat de la passe d'un jour, sans aucune donnee de joueur : statut,
-- etape en echec, taches en echec. Le controle quotidien GitHub
-- (.github/workflows/alerte-passe-minuit.yml) l'appelle avec la cle publique du site et ouvre
-- une issue (GitHub previent alors Fred par mail) si la passe manque ou n'est pas « ok ».
CREATE OR REPLACE FUNCTION public.cron_alerte_etat(p_jour date DEFAULT NULL)
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
  WITH j AS (SELECT coalesce(p_jour, (now() AT TIME ZONE 'Europe/Paris')::date) AS jour)
  SELECT jsonb_build_object(
    'jour', j.jour,
    'passe', (SELECT c.statut FROM public.cron_journal c WHERE c.jour = j.jour AND c.tache = '_passe'),
    'erreur', (SELECT c.erreur FROM public.cron_journal c WHERE c.jour = j.jour AND c.tache = '_passe'),
    'debut', (SELECT c.debut FROM public.cron_journal c WHERE c.jour = j.jour AND c.tache = '_passe'),
    'taches_en_echec', coalesce((SELECT jsonb_agg(c.tache ORDER BY c.tache) FROM public.cron_journal c
                                 WHERE c.jour = j.jour AND c.tache <> '_passe' AND c.statut <> 'ok'), '[]'::jsonb))
  FROM j;
$$;

REVOKE ALL ON FUNCTION public.cron_alerte_etat(date) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.cron_alerte_etat(date) TO anon, authenticated;

DO $verif$
DECLARE r jsonb;
BEGIN
  r := public.cron_alerte_etat('2026-11-03');
  IF r->>'passe' IS DISTINCT FROM 'echec' OR r->>'erreur' NOT LIKE '%helvetia%' THEN
    RAISE EXCEPTION 'nuit du 03/11 non reconnue en echec : %', r;
  END IF;
  r := public.cron_alerte_etat('2026-11-08');
  IF r->>'passe' IS DISTINCT FROM 'ok' THEN RAISE EXCEPTION 'nuit du 08/11 non reconnue ok : %', r; END IF;
  r := public.cron_alerte_etat('2026-01-01');
  IF r->>'passe' IS NOT NULL THEN RAISE EXCEPTION 'jour sans passe mal rendu : %', r; END IF;
END
$verif$;
