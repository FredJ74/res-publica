-- Mission de fin de soirée du 25/11/2026 (Claude), point 3.1 — NON APPLIQUÉE. Après 20261125200000 (chronique de l'empire, appliquée).
-- Décision de Fred : dans l'onglet « L'empire », une rumeur est citée avec son texte, par exemple « Une rumeur circule au marché
-- de Novomirsk : "…" ». L'auteur reste anonyme tant qu'il n'est pas identifié (règle de chronique_auteur_public_interne,
-- inchangée).
-- • rumeur_lancer : quand la rumeur circule (réussite), son texte (600 caractères au plus, comme l'annonce publique) est rangé
--   dans l'affaire (crim_affaires.details : rumeur_texte, rumeur_annonce = id de l'annonce publique evenements_globaux).
--   L'annonce publique reste écrite à l'identique (même table, même texte, même jour de jeu). Remplacement contrôlé,
--   marque chronique_rumeur_texte_v1. Une rumeur ratée ne circule pas : aucun texte.
-- • chronique_empire_lire : le fait « acte » d'une rumeur rend aussi params.texte et params.annonce (remplacement contrôlé,
--   même marque). Le texte est un texte de joueur : l'écran l'échappe et le confie à l'affichage des textes de joueurs
--   (i18n/texte-joueur.js, lien « Voir l'original ») ; la source de traduction est l'annonce publique (api/_traduction-sources.js,
--   type annonce_publique, table lisible par tous sous RLS).
-- Les rumeurs lancées avant cette migration restent citées sans texte (rien n'avait été rangé dans l'affaire).
-- Sans cette migration : la chronique cite la rumeur sans son texte, comme aujourd'hui.
--
-- Contrôles en lecture après application :
--   SELECT position('chronique_rumeur_texte_v1' in pg_get_functiondef('public.rumeur_lancer(text,text,text,text,integer,integer)'::regprocedure)) > 0;  -- vrai
--   SELECT position('chronique_rumeur_texte_v1' in pg_get_functiondef('public.chronique_empire_lire(timestamptz,integer)'::regprocedure)) > 0;        -- vrai
--   SELECT has_function_privilege('authenticated', 'public.chronique_empire_lire(timestamptz,integer)', 'EXECUTE');                                 -- vrai
BEGIN;

CREATE OR REPLACE FUNCTION pg_temp.rp_remplacer(p_fn regprocedure, p_avant text, p_apres text, p_n integer, p_marque text)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE d text := pg_get_functiondef(p_fn); n integer;
BEGIN
  IF position(p_marque IN d) > 0 THEN RETURN; END IF;
  n := (length(d) - length(replace(d, p_avant, ''))) / length(p_avant);
  IF n <> p_n THEN RAISE EXCEPTION '% : % occurrence(s) au lieu de % (%)', p_fn, n, p_n, left(p_avant, 60); END IF;
  EXECUTE replace(d, p_avant, p_apres);
  IF position(p_marque IN pg_get_functiondef(p_fn)) = 0 THEN RAISE EXCEPTION '% : marque absente', p_fn; END IF;
END $$;

SELECT pg_temp.rp_remplacer('public.rumeur_lancer(text,text,text,text,integer,integer)'::regprocedure,
  $a$    PERFORM public.annonce_publique_interne('global', '🗯 ' || left(p_texte, 600));$a$,
  $b$    -- Même annonce publique qu'avant, dont l'id et le texte sont rangés dans l'affaire pour la chronique. /* chronique_rumeur_texte_v1 */
    WITH annonce AS (
      INSERT INTO public.evenements_globaux (country, city, texte, jour)
      VALUES ('global', NULL, '🗯 ' || left(p_texte, 600), public.jour_de_jeu_pays('republic'))
      RETURNING id)
    UPDATE public.crim_affaires
       SET details = coalesce(details, '{}'::jsonb)
                   || jsonb_build_object('rumeur_texte', left(btrim(p_texte), 600), 'rumeur_annonce', (SELECT id FROM annonce))
     WHERE id = (r ->> 'affaire')::bigint;$b$,
  1, 'chronique_rumeur_texte_v1');

SELECT pg_temp.rp_remplacer('public.chronique_empire_lire(timestamptz,integer)'::regprocedure,
  $a$jsonb_build_object('cible', CASE WHEN c.acte LIKE '%rumeur%' THEN coalesce(c.cible, c.cible_pnj) END, 'issue', c.issue) AS params,$a$,
  $b$jsonb_build_object('cible', CASE WHEN c.acte LIKE '%rumeur%' THEN coalesce(c.cible, c.cible_pnj) END, 'issue', c.issue,
             'texte', CASE WHEN c.acte LIKE '%rumeur%' THEN left(nullif(btrim(c.details ->> 'rumeur_texte'), ''), 600) END,
             'annonce', CASE WHEN c.acte LIKE '%rumeur%' AND jsonb_typeof(c.details -> 'rumeur_annonce') = 'number'
                             THEN (c.details ->> 'rumeur_annonce')::bigint END) AS params, /* chronique_rumeur_texte_v1 */$b$,
  1, 'chronique_rumeur_texte_v1');

COMMIT;
