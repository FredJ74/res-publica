-- Rumeur réussie contre une organisation : courrier neutre au chef (reprise de la PR #308, 04/11/2026).
-- Règle validée par Fred : seulement si la rumeur réussit et est publiée ; aucun nom ni indice de
-- l'auteur ; un échec d'envoi n'annule jamais la rumeur. Patch en place du corps de production
-- (l'ancienne migration de #308 retapait un corps périmé depuis le 02/11).
DO $mig$
DECLARE v_def text; v_new text;
BEGIN
  v_def := pg_get_functiondef('public.rumeur_lancer(text,text,text,text,integer,integer)'::regprocedure);
  v_new := replace(v_def,
$ancien$    PERFORM public.annonce_publique_interne('global', '🗯 ' || left(p_texte, 600));
$ancien$,
$nouveau$    PERFORM public.annonce_publique_interne('global', '🗯 ' || left(p_texte, 600));
    -- Alerte sans auteur au chef de l'organisation visée, après publication (PR #308).
    IF p_type = 'organisation' THEN
      BEGIN
        PERFORM public.mail_systeme_poser_interne('Information officielle', o.chef,
          'Une rumeur vise votre organisation',
          'Une rumeur circule au sujet de votre organisation. Consultez les annonces publiques pour en prendre connaissance.')
          FROM (SELECT nullif(btrim(data::jsonb ->> 'chef'), '') AS chef FROM public.organisations
                 WHERE id = p_cible AND data IS JSON OBJECT) o
         WHERE o.chef IS NOT NULL;
      EXCEPTION WHEN others THEN
        RAISE WARNING 'alerte_rumeur_organisation_indisponible: %', SQLSTATE;
      END;
    END IF;
$nouveau$);
  IF v_new = v_def THEN RAISE EXCEPTION 'patch non applique : le fragment ne correspond pas'; END IF;
  EXECUTE v_new;
END $mig$;
