-- Banc annulé de 20261103001000_chaine_elective_contestation_portes (audit E4/E5/E8, 02/11/2026).
-- À jouer APRÈS la migration, dans la même transaction que son prévol, ou seul une fois
-- appliquée. Il se termine TOUJOURS par une exception : rien n'est conservé.
-- Succès = message « BANC_OK ... » ; échec = message « ECHEC ... ».
DO $banc$
DECLARE
  fin numeric := floor(extract(epoch FROM timestamptz '2026-11-02 00:00 Europe/Paris') * 1000);
  sem numeric := 604800000;
  s jsonb; c jsonb; r jsonb; n_ev integer; n_ch integer; v_cle bigint; v_txt text := '';
  ms_paris text;
BEGIN
  s := jsonb_build_object('debut', 111, 'finTour', fin, 'debutTour', NULL, 'dateVote', fin - 86340000,
         'candidats', jsonb_build_array(jsonb_build_object('nom','Banc A','programme','pa'),
                                        jsonb_build_object('nom','Banc B','programme','pb'),
                                        jsonb_build_object('nom','Banc C','programme','pc')),
         'titulaireAvant', 'Banc Maire PNJ', 'elusAvant', '[]'::jsonb, 'debutMandatAvant', fin - 5 * sem,
         'indicateursAvant', jsonb_build_object('caisse_municipale', 1),
         'posteNom', 'Maire', 'villeNom', 'Luthécia');

  -- 1. Second tour ouvert, le recompte du 1er tour donne la majorité absolue à C.
  SELECT count(*) INTO n_ev FROM public.evenements_globaux;
  SELECT count(*) INTO n_ch FROM public.chronique_nationale;
  c := jsonb_build_object('eluId','Banc Maire PNJ','dateDebutMandatTs', fin - 5 * sem, 'phase','second_tour','tour',2,
         'debutTour', fin, 'dateDebutCandidatures', 111, 'candidats', jsonb_build_array(jsonb_build_object('nom','Banc A'), jsonb_build_object('nom','Banc B')));
  r := public.election_contestation_appliquer('banc_cycle', c, s, '{"elu":"Banc C","secondTour":[]}', 'republic', 'maire', 'banc_ville');
  IF NOT (r ->> 'change')::boolean OR r #>> '{cycle,eluId}' <> 'Banc C' OR (r #>> '{cycle,dateDebutMandatTs}')::numeric <> fin
     OR r #>> '{cycle,phase}' <> 'candidatures' OR (r #>> '{cycle,tour}')::int <> 1 OR r -> 'cycle' ? 'debutTour'
     OR (r #>> '{cycle,dateResultats}')::numeric <> floor(extract(epoch FROM timestamptz '2026-12-07 00:00 Europe/Paris') * 1000)
     OR (r #>> '{cycle,dateVote}')::numeric <> floor(extract(epoch FROM timestamptz '2026-12-06 00:01 Europe/Paris') * 1000)
     OR (r #>> '{cycle,dateDebutCampagne}')::numeric <> floor(extract(epoch FROM timestamptz '2026-11-30 00:01 Europe/Paris') * 1000)
     OR jsonb_array_length(r #> '{cycle,candidats}') <> 0 THEN
    RAISE EXCEPTION 'ECHEC 1 (second tour -> elu) : %', r;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.mandats_maires_archives WHERE id = 'mandat-republic-banc_ville-' || (fin - 5 * sem)::bigint
                  AND maire = 'Banc Maire PNJ' AND est_pj = false) THEN RAISE EXCEPTION 'ECHEC 1 : archive du sortant absente'; END IF;
  IF (SELECT count(*) FROM public.evenements_globaux) <> n_ev + 1 OR (SELECT count(*) FROM public.chronique_nationale) <> n_ch + 1 THEN
    RAISE EXCEPTION 'ECHEC 1 : annonce ou chronique manquante'; END IF;
  v_txt := v_txt || '1:' || (r ->> 'annonce') || ' / ';

  -- 2. Élu installé au 1er tour, le recompte renvoie au second tour entre B et C.
  c := jsonb_build_object('eluId','Banc A','dateDebutMandatTs', fin, 'phase','candidatures','tour',1,
         'dateDebutCandidatures', fin, 'candidats', '[]'::jsonb, 'indicateursDebutMandat', jsonb_build_object('caisse_municipale', 2));
  INSERT INTO public.mandats_maires_archives (id, country, city, maire, est_pj, debut_ts, fin_ts)
  VALUES ('mandat-republic-banc_ville2-' || (fin - 5 * sem)::bigint, 'republic', 'banc_ville2', 'Banc Maire PNJ', false, now(), now());
  r := public.election_contestation_appliquer('banc_cycle', c, s, '{"elu":null,"secondTour":["Banc B","Banc C"]}', 'republic', 'maire', 'banc_ville2');
  IF NOT (r ->> 'change')::boolean OR r #>> '{cycle,eluId}' <> 'Banc Maire PNJ' OR (r #>> '{cycle,dateDebutMandatTs}')::numeric <> fin - 5 * sem
     OR r #>> '{cycle,phase}' <> 'second_tour' OR (r #>> '{cycle,tour}')::int <> 2 OR (r #>> '{cycle,debutTour}')::numeric <> fin
     OR (r #>> '{cycle,dateDebutCandidatures}')::numeric <> 111 OR r #>> '{cycle,candidats,1,programme}' <> 'pc'
     OR (r #>> '{cycle,indicateursDebutMandat,caisse_municipale}')::int <> 1
     OR (r #>> '{cycle,dateVote}')::numeric <> floor(extract(epoch FROM timestamptz '2026-11-08 00:01 Europe/Paris') * 1000)
     OR (r #>> '{cycle,dateResultats}')::numeric <> floor(extract(epoch FROM timestamptz '2026-11-09 00:00 Europe/Paris') * 1000) THEN
    RAISE EXCEPTION 'ECHEC 2 (installe -> second tour) : %', r;
  END IF;
  IF EXISTS (SELECT 1 FROM public.mandats_maires_archives WHERE id = 'mandat-republic-banc_ville2-' || (fin - 5 * sem)::bigint) THEN
    RAISE EXCEPTION 'ECHEC 2 : archive du mandat rendu non retirée'; END IF;
  v_txt := v_txt || '2:' || (r ->> 'annonce') || ' / ';

  -- 3. Prolongation, recompte sans verdict : rien ne change. 3b. Même paire au second tour.
  c := jsonb_build_object('eluId','Banc Maire PNJ','dateDebutMandatTs', fin - 5 * sem, 'phase','candidatures');
  r := public.election_contestation_appliquer('banc_cycle', c, s, '{"elu":null,"secondTour":[]}', 'republic', 'maire', 'banc_ville');
  IF (r ->> 'change')::boolean THEN RAISE EXCEPTION 'ECHEC 3 : %', r; END IF;
  c := jsonb_build_object('eluId','Banc Maire PNJ','phase','second_tour','debutTour', fin,
         'candidats', jsonb_build_array(jsonb_build_object('nom','Banc B'), jsonb_build_object('nom','Banc A')));
  r := public.election_contestation_appliquer('banc_cycle', c, s, '{"elu":null,"secondTour":["Banc A","Banc B"]}', 'republic', 'maire', 'banc_ville');
  IF (r ->> 'change')::boolean THEN RAISE EXCEPTION 'ECHEC 3b : %', r; END IF;

  -- 4. Second tour, le recompte change un qualifié : nouvelle paire, même dimanche.
  r := public.election_contestation_appliquer('banc_cycle', c, s, '{"elu":null,"secondTour":["Banc A","Banc C"]}', 'republic', 'maire', 'banc_ville');
  IF NOT (r ->> 'change')::boolean OR NOT public.election_memes_noms(jsonb_build_array(r #>> '{cycle,candidats,0,nom}', r #>> '{cycle,candidats,1,nom}'), '["Banc A","Banc C"]') THEN
    RAISE EXCEPTION 'ECHEC 4 : %', r; END IF;

  -- 5. Recompte : qualifiés du second tour (A 3, B 3, C 1 sur 7 -> C sous 15 %).
  r := public.election_recompter_interne('banc_cycle', 'banc_pays', 'maire', 'banc_ville', jsonb_build_object('debut', 1,
         'candidats', s -> 'candidats', 'votes', '{"a":"Banc A","b":"Banc A","c":"Banc A","d":"Banc B","e":"Banc B","f":"Banc B","g":"Banc C"}'::jsonb));
  IF r ->> 'elu' IS NOT NULL OR r -> 'secondTour' <> '["Banc A","Banc B"]'::jsonb THEN RAISE EXCEPTION 'ECHEC 5 : %', r; END IF;
  r := public.election_recompter_interne('banc_cycle', 'banc_pays', 'maire', 'banc_ville', jsonb_build_object('debut', 1,
         'candidats', s -> 'candidats', 'votes', '{"a":"Banc A","b":"Banc A","c":"Banc A","d":"Banc B"}'::jsonb));
  IF r ->> 'elu' <> 'Banc A' OR r -> 'secondTour' <> '[]'::jsonb THEN RAISE EXCEPTION 'ECHEC 5b : %', r; END IF;

  -- 6. Députés : installés, le recompte change un siège (simple remplacement).
  c := jsonb_build_object('elus', '["Banc A","Banc B","Banc PNJ"]'::jsonb, 'dateDebutMandatTs', fin, 'phase', 'candidatures');
  r := public.election_contestation_appliquer('banc_cycle', c, s || '{"elusAvant":["Banc PNJ","Banc PNJ2","Banc PNJ3"]}', '{"elus":["Banc A","Banc C"]}', 'republic', 'depute', 'banc_ville');
  IF NOT (r ->> 'change')::boolean OR jsonb_array_length(r #> '{cycle,elus}') <> 3 OR NOT (r #> '{cycle,elus}' @> '["Banc A","Banc C"]') THEN
    RAISE EXCEPTION 'ECHEC 6 : %', r; END IF;

  -- 6b. Élu installé, le recompte ne désigne personne : mandat rendu, prolongation de 2 semaines.
  c := jsonb_build_object('eluId','Banc A','dateDebutMandatTs', fin, 'phase','candidatures');
  r := public.election_contestation_appliquer('banc_cycle', c, s, '{"elu":null,"secondTour":[]}', 'republic', 'maire', 'banc_ville3');
  IF NOT (r ->> 'change')::boolean OR r #>> '{cycle,eluId}' <> 'Banc Maire PNJ'
     OR (r #>> '{cycle,dateResultats}')::numeric <> floor(extract(epoch FROM timestamptz '2026-11-16 00:00 Europe/Paris') * 1000) THEN
    RAISE EXCEPTION 'ECHEC 6b (installe -> prolongation) : %', r; END IF;

  -- 7. E8 : le retrait d'une candidature retire le nom du bulletin du scrutin ouvert.
  SELECT (data::jsonb ->> 'dateDebutCandidatures')::numeric::bigint INTO v_cle FROM public.cycles_electoraux WHERE id = 'republic_maire_capitale';
  UPDATE public.cycles_electoraux SET data = jsonb_set(data::jsonb, '{candidats}',
         coalesce(data::jsonb -> 'candidats', '[]'::jsonb) || '[{"nom":"Banc Retrait"}]')::text WHERE id = 'republic_maire_capitale';
  INSERT INTO public.candidatures (id, country, poste_id, nom, city, cle_scrutin) VALUES ('banc-retrait', 'republic', 'maire', 'Banc Retrait', 'capitale', v_cle);
  DELETE FROM public.candidatures WHERE id = 'banc-retrait';
  IF EXISTS (SELECT 1 FROM public.cycles_electoraux, jsonb_array_elements(data::jsonb -> 'candidats') e
              WHERE id = 'republic_maire_capitale' AND e ->> 'nom' = 'Banc Retrait') THEN
    RAISE EXCEPTION 'ECHEC 7 : nom resté sur le bulletin'; END IF;

  -- 8. E8 : plus d'INSERT direct pour l'écran.
  IF has_table_privilege('authenticated', 'public.candidatures', 'INSERT') THEN RAISE EXCEPTION 'ECHEC 8 : INSERT encore ouvert'; END IF;
  IF NOT has_table_privilege('authenticated', 'public.candidatures', 'DELETE') THEN RAISE EXCEPTION 'ECHEC 8b : DELETE retiré'; END IF;
  IF has_function_privilege('authenticated', 'public.election_contestation_appliquer(text,jsonb,jsonb,jsonb,text,text,text)', 'EXECUTE') THEN
    RAISE EXCEPTION 'ECHEC 8c : moteur exécutable par l''écran'; END IF;

  RAISE EXCEPTION 'BANC_OK 8/8 — %', v_txt;
END $banc$;
