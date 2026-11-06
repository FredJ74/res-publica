-- Banc annulé de la migration 20261102222500_chaine_elective_bulletin_fraudes_mairie.
-- À jouer APRÈS le corps de la migration, dans la même transaction : tout est annulé par
-- l'exception finale, qui porte le relevé.
DO $t$
DECLARE v_u uuid; r1 jsonb; r2 jsonb; v_b jsonb; v_rc jsonb; v_l jsonb; t1 bigint := 1800000000000; t2 bigint := 1800604800000;
BEGIN
  SELECT user_id INTO v_u FROM public.personnages_donnees WHERE name = 'Angie Porcelana';
  UPDATE public.personnages_donnees
     SET resources = jsonb_set(coalesce(resources, '{}'::jsonb), '{inf}', '999'), poste = NULL,
         domicile = coalesce(domicile, '{}'::jsonb) || '{"country":"republic"}'::jsonb
   WHERE name = 'Angie Porcelana';
  -- E1 : publier inscrit sur le bulletin ; un second dépôt est refusé sans débit.
  PERFORM set_config('request.path', '/rpc/candidature_publier', true);
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_u, 'role', 'authenticated')::text, true);
  PERFORM set_config('role', 'authenticated', true);
  r1 := public.candidature_publier('maire', 'ville_b', NULL, 'Banc', 'Programme du banc');
  r2 := public.candidature_publier('maire', 'ville_b', NULL, 'Banc', 'Programme du banc');
  PERFORM set_config('role', 'postgres', true);
  SELECT data::jsonb -> 'candidats' INTO v_b FROM public.cycles_electoraux WHERE id = 'republic_maire_ville_b';
  -- E3 : fraudes hors du tour ignorées. Sans filtre, B (2 + 10 + 10) l'emporterait ; avec, A (1 + 2).
  INSERT INTO public.fraudes_electorales (id, country, poste_id, city, cycle_debut, type, auteur, candidat, delta_voix, etat, detectabilite_pct, created_at) VALUES
    ('banc-f1', 'republic', 'maire', 'ville_b', 1, 'bourrage_urnes', 'Angie Porcelana', 'A', 2, 'non_revelee', 10, to_timestamp((t1 + 3600000) / 1000.0)),
    ('banc-f2', 'republic', 'maire', 'ville_b', 1, 'bourrage_urnes', 'Angie Porcelana', 'B', 10, 'non_revelee', 10, to_timestamp((t2 + 3600000) / 1000.0)),
    ('banc-f3', 'republic', 'maire', 'ville_b', 1, 'bourrage_urnes', 'Angie Porcelana', 'B', 10, 'non_revelee', 10, to_timestamp((t1 - 3600000) / 1000.0));
  v_rc := public.election_recompter_interne('banc', 'republic', 'maire', 'ville_b', jsonb_build_object(
    'debut', 1, 'dateVote', 0, 'debutTour', t1, 'finTour', t2,
    'candidats', '[{"nom":"A"},{"nom":"B"}]'::jsonb, 'votes', '{"v1":"A","v2":"B","v3":"B"}'::jsonb));
  -- E2 : calendrier de la mairie de Luthécia.
  SELECT jsonb_build_object('phase', d ->> 'phase', 'rt', d ->> 'resultatsTraites', 'elu', d ->> 'eluId',
           'cand', to_char(to_timestamp((d ->> 'dateDebutCandidatures')::numeric / 1000) AT TIME ZONE 'Europe/Paris', 'Dy DD/MM HH24:MI'),
           'camp', to_char(to_timestamp((d ->> 'dateDebutCampagne')::numeric / 1000) AT TIME ZONE 'Europe/Paris', 'Dy DD/MM HH24:MI'),
           'vote', to_char(to_timestamp((d ->> 'dateVote')::numeric / 1000) AT TIME ZONE 'Europe/Paris', 'Dy DD/MM HH24:MI'),
           'res', to_char(to_timestamp((d ->> 'dateResultats')::numeric / 1000) AT TIME ZONE 'Europe/Paris', 'Dy DD/MM HH24:MI'),
           'fin', to_char(to_timestamp((d ->> 'dateFinMandat')::numeric / 1000) AT TIME ZONE 'Europe/Paris', 'Dy DD/MM HH24:MI'))
    INTO v_l FROM (SELECT data::jsonb d FROM public.cycles_electoraux WHERE id = 'republic_maire_capitale') s;
  RAISE EXCEPTION 'BANC r1=% | r2=% | bulletin=% | recompte=% | luthecia=% | figes=%',
    r1 - 'topic_id', r2, (SELECT jsonb_agg(x ->> 'nom') FROM jsonb_array_elements(v_b) x), v_rc, v_l,
    (SELECT count(*) FROM public.cycles_electoraux WHERE coalesce((data::jsonb ->> 'resultatsTraites')::boolean, false));
END $t$;
