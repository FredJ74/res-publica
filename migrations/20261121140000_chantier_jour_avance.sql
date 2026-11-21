-- CHANTIER « CONSTRUCTION » — accélération par le travail des joueurs (GAME-DESIGN-CHANTIERS-IMAGES-20261120.md, point 5).
-- • Quand les heures du jour en cours ont toutes été faites par des joueurs, les heures du jour suivant s'ouvrent aussitôt
--   (jour d'avance), aux mêmes conditions (1 PA par heure, salaire du propriétaire, payé par la trésorerie).
-- • À minuit, si un jour d'avance a été ouvert, les PNJ terminent ses heures restantes et le chantier avance d'un jour de plus.
-- • Limite stricte : un seul jour d'avance par jour (jamais de troisième jour) ; un chantier va au plus deux fois plus vite.
-- • Garde-fous inchangés : matériaux des deux jours (sinon avancement proportionnel), paliers d'appel de fonds (le plafond
--   du tiers et des deux tiers vaut aussi pour le jour d'avance). Coût total inchangé : on paie plus vite, pas plus.
-- Jonctions (AGENTS.md, coordination avec Codex) : deux insertions dans chantier_travailler (heures du jour d'avance,
-- enregistrement), un seul appel dans chantier_jour_traiter (nuit du jour d'avance). Aucune réécriture de ces fonctions.
BEGIN;

CREATE OR REPLACE FUNCTION pg_temp.rp_raccorder(p_fn regprocedure, p_avant text, p_apres text, p_marque text)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE d text := pg_get_functiondef(p_fn);
BEGIN
  IF position(p_marque IN d) > 0 THEN RETURN; END IF;
  IF (length(d) - length(replace(d, p_avant, ''))) / length(p_avant) <> 1 THEN RAISE EXCEPTION '% : ancrage (%)', p_fn, left(p_avant, 60); END IF;
  EXECUTE replace(d, p_avant, p_apres);
  IF position(p_marque IN pg_get_functiondef(p_fn)) = 0 THEN RAISE EXCEPTION '% : raccord absent', p_fn; END IF;
END $$;

-- Heures du jour d'avance encore disponibles. Ouvert seulement si le jour en cours peut être entièrement fait (ses heures
-- utiles égalent la capacité : matériaux et financement suffisent) ; borné par les matériaux du jour suivant (après ceux
-- du jour en cours) et par le palier d'appel de fonds. Jamais plus d'un jour.
CREATE OR REPLACE FUNCTION public.chantier_avance_heures_interne(p_ch jsonb, p_capacite numeric, p_plafond numeric, p_utiles numeric)
RETURNS numeric LANGUAGE plpgsql STABLE SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_prog numeric := coalesce((p_ch->>'progressionJours')::numeric, 0); v_num integer; b1 jsonb; b2 jsonb; st jsonb;
        f numeric := 1; m text; reste numeric; v_deja numeric;
BEGIN
  IF p_capacite IS NULL OR p_capacite <= 0 OR p_utiles < floor(p_capacite) THEN RETURN 0; END IF;
  IF v_prog + 1 >= coalesce((p_ch->>'dureeJours')::numeric, 0) THEN RETURN 0; END IF;     -- pas de jour d'avance au-delà de la fin
  v_num := floor(v_prog)::integer + 1;
  b1 := public.chantier_besoin_jour_interne(p_ch, v_num); b2 := public.chantier_besoin_jour_interne(p_ch, v_num + 1);
  st := coalesce(p_ch->'stockMateriaux', '{}');
  FOREACH m IN ARRAY ARRAY['bois', 'minerai', 'metal'] LOOP
    IF coalesce((b2->>m)::numeric, 0) > 0 THEN
      reste := greatest(0, coalesce((st->>m)::numeric, 0) - coalesce((b1->>m)::numeric, 0));
      f := least(f, greatest(0, reste / (b2->>m)::numeric));
    END IF;
  END LOOP;
  v_deja := CASE WHEN p_ch->'jourAvance'->>'jour' = (statement_timestamp() AT TIME ZONE 'Europe/Paris')::date::text
                 THEN coalesce((p_ch->'jourAvance'->>'heures')::numeric, 0) ELSE 0 END;
  RETURN greatest(0, floor(p_capacite * least(1, f, greatest(0, p_plafond - v_prog - 1))) - v_deja);
END $$;

-- Enregistre les heures faites sur le jour d'avance (celles qui dépassent les heures utiles du jour en cours).
CREATE OR REPLACE FUNCTION public.chantier_avance_enregistrer_interne(p_ch jsonb, p_heures numeric)
RETURNS jsonb LANGUAGE sql STABLE SET search_path TO 'public', 'pg_temp' AS $$
  SELECT CASE WHEN coalesce(p_heures, 0) <= 0 THEN p_ch->'jourAvance'
    ELSE jsonb_build_object('jour', (statement_timestamp() AT TIME ZONE 'Europe/Paris')::date::text,
      'heures', p_heures + CASE WHEN p_ch->'jourAvance'->>'jour' = (statement_timestamp() AT TIME ZONE 'Europe/Paris')::date::text
                                THEN coalesce((p_ch->'jourAvance'->>'heures')::numeric, 0) ELSE 0 END) END;
$$;

-- Nuit : après le jour normal, si un jour d'avance a été ouvert et que le jour normal a été entièrement gagné, les PNJ
-- terminent le jour d'avance (approvisionnement, salaires, matériaux) et le chantier avance d'un jour de plus.
-- Si le jour normal n'a pas été entièrement gagné, les heures du jour d'avance sont reportées sur le jour suivant (rien
-- n'est perdu, rien n'est payé deux fois).
CREATE OR REPLACE FUNCTION public.chantier_avance_nuit_interne(p_ch jsonb, p_source jsonb, p_pays text, p_ville text, p_d numeric, p_jour text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE ch jsonb := p_ch; pj numeric; dernier jsonb; avant numeric; num integer; besoin jsonb; stock jsonb; plan jsonb; entrepot text;
        f numeric := 1; m text; req numeric; taux numeric; cap numeric; plafond numeric; heures numeric; cout numeric; gain numeric;
        rep jsonb; ancien text;
BEGIN
  IF jsonb_typeof(ch->'jourAvance') IS DISTINCT FROM 'object' THEN RETURN ch; END IF;
  pj := coalesce((ch->'jourAvance'->>'heures')::numeric, 0);
  ch := ch - 'jourAvance';
  IF pj <= 0 THEN RETURN ch; END IF;
  dernier := ch->'evenements'->-1;
  avant := (ch->>'progressionJours')::numeric;
  IF dernier->>'cle' IS DISTINCT FROM 'journee' OR dernier->>'date' IS DISTINCT FROM p_jour OR coalesce((dernier->>'avance')::numeric, 0) < 1
     OR ch->>'arrete' IS NOT NULL OR avant >= p_d THEN
    -- Jour normal incomplet : les heures déjà payées comptent pour le jour suivant.
    RETURN ch || jsonb_build_object('heuresFaites', coalesce((ch->>'heuresFaites')::numeric, 0) + pj);
  END IF;
  num := floor(avant)::integer + 1;
  besoin := public.chantier_besoin_jour_interne(ch, num);
  stock := coalesce(ch->'stockMateriaux', '{}');
  SELECT building_id INTO entrepot FROM public.entrepots_par_ville WHERE pays = p_pays AND ville = p_ville;
  IF entrepot IS NOT NULL THEN
    plan := public.approvisionner_chantier(p_source->>'destinataire', p_pays, p_ville, entrepot, besoin, stock, coalesce((ch->>'tresorerie')::numeric, 0));
    IF NOT coalesce((plan->>'ok')::boolean, false) THEN RAISE EXCEPTION 'approvisionnement_non_confirme'; END IF;
    stock := plan->'stockChantier'; ch := ch || jsonb_build_object('tresorerie', (ch->>'tresorerie')::numeric - (plan->>'depense')::numeric);
  END IF;
  FOREACH m IN ARRAY ARRAY['bois', 'minerai', 'metal'] LOOP
    req := (besoin->>m)::numeric;
    IF req > 0 THEN f := least(f, greatest(0, coalesce((stock->>m)::numeric, 0)) / req); END IF;
  END LOOP;
  SELECT valeur INTO taux FROM public.entreprises_constantes WHERE cle = 'chantier_taux_horaire';
  cap := (ch->>'coutTravail')::numeric / taux / p_d;
  plafond := CASE WHEN (ch->>'totalVerse')::numeric >= (ch->>'coutTotal')::numeric THEN p_d
    WHEN (ch->>'totalVerse')::numeric >= ceil((ch->>'coutTotal')::numeric * .7) THEN p_d * 2 / 3 ELSE p_d / 3 END;
  heures := greatest(0, least(floor(cap * least(f, p_d - avant, plafond - avant)) - pj, floor((ch->>'tresorerie')::numeric / taux)));
  cout := heures * taux;
  IF cout > 0 THEN
    ancien := current_setting('rp.caisse_interne', true); PERFORM set_config('rp.caisse_interne', 'on', true);
    rep := public.caisse_institution_mouvement(p_pays || '_gouvernement-min_fin', cout, true);
    PERFORM set_config('rp.caisse_interne', coalesce(ancien, ''), true);
    IF NOT coalesce((rep->>'ok')::boolean, false) THEN RAISE EXCEPTION 'remuneration_pnj_non_confirmee'; END IF;
  END IF;
  gain := greatest(0, least(1, f, (pj + heures) / cap, p_d - avant, plafond - avant));
  FOREACH m IN ARRAY ARRAY['bois', 'minerai', 'metal'] LOOP
    stock := jsonb_set(stock, ARRAY[m], to_jsonb(greatest(0, coalesce((stock->>m)::numeric, 0) - floor((besoin->>m)::numeric * gain))));
  END LOOP;
  ch := ch || jsonb_build_object('progressionJours', avant + gain, 'tresorerie', (ch->>'tresorerie')::numeric - cout, 'stockMateriaux', stock,
    'evenements', coalesce(ch->'evenements', '[]') || jsonb_build_array(jsonb_build_object('cle', 'journee_avance', 'date', p_jour, 'avance', gain,
      'heuresPJ', pj, 'heuresPNJ', heures, 'coutPNJ', cout, 'achats', plan->'achats', 'jourGagne', gain >= 1)));
  IF avant + gain < p_d THEN ch := public.chantier_appel_fonds_interne(ch, p_source); END IF;
  RETURN ch;
END $$;

-- ── Jonctions ────────────────────────────────────────────────────────────────────────────────────
SELECT pg_temp.rp_raccorder('public.chantier_travailler(text,text,text,integer)'::regprocedure,
  $a$  v_restantes := GREATEST(0, v_utiles - v_faites);$a$,
  $b$  v_restantes := GREATEST(0, v_utiles - v_faites) + public.chantier_avance_heures_interne(v_ch, v_capacite, v_plafond, v_utiles) /* chantier_jour_avance_v1 */;$b$,
  'chantier_jour_avance_v1');
SELECT pg_temp.rp_raccorder('public.chantier_travailler(text,text,text,integer)'::regprocedure,
  $a$    'heuresFaites', v_faites + v_heures,$a$,
  $b$    'heuresFaites', LEAST(v_faites + v_heures, GREATEST(v_faites, v_utiles)),
    'jourAvance', public.chantier_avance_enregistrer_interne(v_ch, v_faites + v_heures - GREATEST(v_faites, v_utiles)) /* chantier_jour_avance_enregistrer_v1 */,$b$,
  'chantier_jour_avance_enregistrer_v1');
SELECT pg_temp.rp_raccorder('public.chantier_jour_traiter(text)'::regprocedure,
  $a$ ch:=ch||jsonb_build_object('jourTraite',jour);$a$,
  $b$ ch:=public.chantier_avance_nuit_interne(ch,source,r.country,etat->>'city',d,jour) /* chantier_jour_avance_nuit_v1 */;
 ch:=ch||jsonb_build_object('jourTraite',jour);$b$,
  'chantier_jour_avance_nuit_v1');

REVOKE ALL ON FUNCTION public.chantier_avance_heures_interne(jsonb, numeric, numeric, numeric), public.chantier_avance_enregistrer_interne(jsonb, numeric),
  public.chantier_avance_nuit_interne(jsonb, jsonb, text, text, numeric, text) FROM PUBLIC, anon, authenticated;

COMMIT;
