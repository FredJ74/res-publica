-- =====================================================================
-- CALENDRIER ELECTORAL DU DIMANCHE (12 septembre 2026)
-- =====================================================================
-- Regle fixee : candidatures ouvertes des l'ouverture du cycle ; cloture le lundi 00:01 ; campagne
-- du lundi 00:01 au samedi 23:59 (liste figee) ; vote le dimanche 00:01 -> 23:59 ; resultat au
-- passage au lundi (dateResultats = lundi 00:00). Heure de Paris. Second tour : dimanche suivant.
--
-- 1. cycle_electoral_aligne_dimanche : un vote FUTUR qui ne tombe pas le dimanche 00:01 est reporte
--    au premier dimanche suivant (jamais avance) ; cloture = lundi 00:01 de la meme semaine, jamais
--    rouverte si la campagne a deja commence ; resultat = lundi 00:00 suivant. Les cycles resolus,
--    en mandat, vacants ou dont le vote est deja passe ne sont jamais touches.
-- 2. Trigger sur cycles_electoraux : tout ecrivain (cron, client, meme ancien) produit un calendrier
--    du dimanche. Le realignement des cycles existants passe par la meme fonction.
-- 3. Trigger sur candidatures : aucune candidature apres la cloture du lundi 00:01, ni en mandat,
--    vacance ou entre les deux tours.
-- 4. Tracts electoraux : 1 PA par tentative individuelle (PA enregistres).
-- =====================================================================

-- ------------------------------------------------------------------ 1. ALIGNEMENT
CREATE OR REPLACE FUNCTION public.cycle_electoral_aligne_dimanche(p_d jsonb, p_maintenant timestamptz)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SET search_path = public, pg_temp
AS $$
DECLARE
  v_ms       numeric := floor(extract(epoch FROM p_maintenant) * 1000);
  v_loc      timestamp;
  v_dim      timestamp;
  v_vote     numeric;
  v_res      numeric;
  v_cloture  numeric;
BEGIN
  IF p_d IS NULL OR jsonb_typeof(p_d) <> 'object' OR jsonb_typeof(p_d -> 'dateVote') <> 'number' THEN RETURN p_d; END IF;
  IF COALESCE((p_d ->> 'resultatsTraites')::boolean, false) OR COALESCE(p_d ->> 'phase', '') IN ('mandat', 'vacant') THEN RETURN p_d; END IF;
  IF (p_d ->> 'dateVote')::numeric <= v_ms THEN RETURN p_d; END IF;   -- vote ouvert ou passe : intouchable

  v_loc := to_timestamp((p_d ->> 'dateVote')::numeric / 1000) AT TIME ZONE 'Europe/Paris';
  v_dim := date_trunc('day', v_loc) + ((7 - extract(isodow FROM v_loc)::int) % 7) * interval '1 day' + interval '1 minute';
  IF v_dim < v_loc THEN v_dim := v_dim + interval '7 days'; END IF;
  v_vote    := floor(extract(epoch FROM (v_dim AT TIME ZONE 'Europe/Paris')) * 1000);
  v_res     := floor(extract(epoch FROM ((date_trunc('day', v_dim) + interval '1 day') AT TIME ZONE 'Europe/Paris')) * 1000);
  v_cloture := floor(extract(epoch FROM ((date_trunc('day', v_dim) - interval '6 days' + interval '1 minute') AT TIME ZONE 'Europe/Paris')) * 1000);

  IF v_vote = (p_d ->> 'dateVote')::numeric AND jsonb_typeof(p_d -> 'dateResultats') = 'number'
     AND (p_d ->> 'dateResultats')::numeric = v_res THEN
    RETURN p_d;                                                     -- deja au calendrier du dimanche
  END IF;
  -- Cloture jamais rouverte (campagne deja commencee) ni avancee.
  IF jsonb_typeof(p_d -> 'dateDebutCampagne') = 'number'
     AND ((p_d ->> 'dateDebutCampagne')::numeric <= v_ms OR (p_d ->> 'dateDebutCampagne')::numeric > v_cloture) THEN
    v_cloture := (p_d ->> 'dateDebutCampagne')::numeric;
  END IF;
  RETURN p_d || jsonb_build_object('dateDebutCampagne', v_cloture, 'dateVote', v_vote, 'dateResultats', v_res,
                                   'realigneDimancheTs', v_ms);
END;
$$;

-- SECURITY DEFINER OBLIGATOIRE (correctif du 12 septembre 2026) : une fonction de trigger
-- s'execute avec les droits de CELUI QUI ECRIT. Sans cela, le client (role anon) n'ayant pas
-- l'EXECUTE sur cycle_electoral_aligne_dimanche, toute creation ou sauvegarde de cycle depuis le
-- navigateur echouait en « 42501 : permission denied for function cycle_electoral_aligne_dimanche ».
CREATE OR REPLACE FUNCTION public.cycles_electoraux_dimanche()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_d jsonb;
  v_n jsonb;
BEGIN
  BEGIN v_d := NEW.data::jsonb; EXCEPTION WHEN OTHERS THEN RETURN NEW; END;
  v_n := public.cycle_electoral_aligne_dimanche(v_d, now());
  IF v_n IS DISTINCT FROM v_d THEN NEW.data := v_n::text; END IF;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS trg_cycles_electoraux_dimanche ON public.cycles_electoraux;
CREATE TRIGGER trg_cycles_electoraux_dimanche
  BEFORE INSERT OR UPDATE OF data ON public.cycles_electoraux
  FOR EACH ROW EXECUTE FUNCTION public.cycles_electoraux_dimanche();

-- ------------------------------------------------------------------ 2. CLOTURE DES CANDIDATURES
-- Meme regle que ci-dessus : la fonction lit cycles_electoraux pour le compte de l'ecrivain.
CREATE OR REPLACE FUNCTION public.candidatures_cloture()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_data text;
  v_d    jsonb;
  v_ms   numeric := floor(extract(epoch FROM now()) * 1000);
BEGIN
  SELECT data INTO v_data FROM public.cycles_electoraux
   WHERE id = NEW.country || '_' || NEW.poste_id || CASE WHEN NEW.city IS NOT NULL THEN '_' || NEW.city ELSE '' END;
  IF NOT FOUND THEN RETURN NEW; END IF;          -- cycle cree par le client juste avant la candidature
  BEGIN v_d := v_data::jsonb; EXCEPTION WHEN OTHERS THEN RETURN NEW; END;
  IF COALESCE((v_d ->> 'resultatsTraites')::boolean, false)
     OR COALESCE(v_d ->> 'phase', '') IN ('mandat', 'vacant')
     OR (jsonb_typeof(v_d -> 'dateDebutCampagne') = 'number' AND v_ms >= (v_d ->> 'dateDebutCampagne')::numeric) THEN
    RAISE EXCEPTION 'candidatures_closes' USING HINT = 'Les candidatures a ce scrutin sont closes (cloture du lundi 00:01).';
  END IF;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS trg_candidatures_cloture ON public.candidatures;
CREATE TRIGGER trg_candidatures_cloture
  BEFORE INSERT ON public.candidatures
  FOR EACH ROW EXECUTE FUNCTION public.candidatures_cloture();

REVOKE ALL ON FUNCTION public.cycle_electoral_aligne_dimanche(jsonb, timestamptz) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.cycles_electoraux_dimanche() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.candidatures_cloture() FROM PUBLIC, anon, authenticated;

-- ------------------------------------------------------------------ 3. TRACTS : 1 PA PAR TENTATIVE
CREATE OR REPLACE FUNCTION public.tracts_electoraux_distribuer_interne(
  p_requete  text,
  p_joueur   text,
  p_cycle_id text,
  p_candidat text,
  p_sens     text,
  p_pnj_nom  text,
  p_vol_pnj  integer,
  p_instant  timestamptz
)
RETURNS jsonb
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
DECLARE
  v_rej     jsonb;
  v_p       record;
  v_c       record;
  v_d       jsonb;
  v_ms      bigint;
  v_tour    bigint;
  v_ville   text;
  v_nom     text;
  v_cle     text;
  v_taux    integer;
  v_jet     integer;
  v_sens    smallint;
  v_effet   smallint;
  v_score   numeric;
  v_inv     jsonb;
BEGIN
  v_rej := public.assemblee_requete_ouvrir(p_requete, p_joueur, 'tract_electoral');
  IF v_rej IS NOT NULL THEN RETURN v_rej; END IF;

  IF p_sens NOT IN ('pour', 'contre') OR COALESCE(btrim(p_candidat), '') = '' THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'parametres_invalides'));
  END IF;
  v_sens := CASE WHEN p_sens = 'pour' THEN 1 ELSE -1 END;

  SELECT country, current_city, stats, resources, inventory, pa INTO v_p FROM public.personnages WHERE name = p_joueur;
  IF NOT FOUND THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'joueur_introuvable'));
  END IF;

  SELECT id, country, city, poste_id, data INTO v_c FROM public.cycles_electoraux WHERE id = p_cycle_id;
  IF NOT FOUND THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'scrutin_introuvable'));
  END IF;
  BEGIN v_d := v_c.data::jsonb; EXCEPTION WHEN OTHERS THEN v_d := NULL; END;
  IF v_d IS NULL OR jsonb_typeof(v_d) <> 'object' THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'scrutin_illisible'));
  END IF;
  -- Tracts electoraux : presidentielle, municipales, legislatives uniquement (pas le chef syndical).
  IF COALESCE(v_c.poste_id, v_d ->> 'posteId', '') NOT IN ('president', 'maire', 'depute') THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'scrutin_non_concerne'));
  END IF;

  -- Scrutin du pays ou se trouve le joueur.
  IF v_c.country IS DISTINCT FROM v_p.country THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'hors_pays'));
  END IF;

  -- Phase de vote reellement ouverte (meme calcul que getPhaseActuelle : [dateVote, dateResultats[).
  v_ms := floor(extract(epoch FROM p_instant) * 1000)::bigint;
  v_tour := CASE WHEN jsonb_typeof(v_d -> 'dateVote') = 'number' THEN (v_d ->> 'dateVote')::numeric::bigint END;
  IF v_tour IS NULL OR jsonb_typeof(v_d -> 'dateResultats') <> 'number'
     OR COALESCE((v_d ->> 'resultatsTraites')::boolean, false)
     OR COALESCE(v_d ->> 'phase', '') = 'mandat'
     OR v_ms < v_tour OR v_ms >= (v_d ->> 'dateResultats')::numeric::bigint THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'hors_phase_vote'));
  END IF;

  -- Dimanche, heure de Paris.
  IF extract(isodow FROM (p_instant AT TIME ZONE 'Europe/Paris')) <> 7 THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'pas_dimanche'));
  END IF;

  -- Candidat reellement inscrit a CE scrutin (et a ce tour : la liste est reduite aux qualifies au
  -- second tour et aux ex aequo au departage du 3e siege).
  IF NOT EXISTS (SELECT 1 FROM jsonb_array_elements(COALESCE(v_d -> 'candidats', '[]'::jsonb)) c WHERE c ->> 'nom' = p_candidat) THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'candidat_hors_scrutin'));
  END IF;

  -- Geographie : scrutin local = sa ville ; presidentielle = une ville du pays, la caserne ou le QHS.
  v_ville := NULLIF(COALESCE(v_c.city, v_d ->> 'city'), '');
  IF v_ville IS NOT NULL THEN
    IF v_p.current_city IS DISTINCT FROM v_ville THEN
      RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'hors_ville', 'ville_scrutin', v_ville));
    END IF;
  ELSIF COALESCE(v_p.current_city, '') NOT IN ('capitale', 'ville_a', 'ville_b', 'caserne', 'qhs') THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'hors_territoire'));
  END IF;

  -- Le joueur detient bien un tract de ce sens pour ce candidat (inventaire enregistre).
  v_inv := CASE WHEN jsonb_typeof(v_p.inventory) = 'array' THEN v_p.inventory ELSE '[]'::jsonb END;
  IF NOT EXISTS (
    SELECT 1 FROM jsonb_array_elements(v_inv) i
     WHERE i ->> 'type' = 'tract' AND i ->> 'cible' = p_candidat
       AND COALESCE(i ->> 'tractType', 'pour') = p_sens
       AND COALESCE(i ->> 'origineQuete', '') <> 'jean_lou'
       AND jsonb_typeof(i -> 'quantite') = 'number' AND (i ->> 'quantite')::numeric >= 1
  ) THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'tract_absent'));
  END IF;

  -- 1 PA par tentative individuelle (PA enregistres du joueur ; le client les debite a la tentative).
  IF COALESCE(v_p.pa, 0) < 1 THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'pa_insuffisants'));
  END IF;

  -- Identite stable du PNJ : pays + ville ou il se trouve + nom normalise.
  v_nom := public.tracts_electoraux_nom_pnj(p_pnj_nom);
  IF v_nom = '' THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'pnj_invalide'));
  END IF;
  v_cle := v_c.country || ':' || COALESCE(v_p.current_city, '') || ':' || v_nom;

  -- Un seul joueur a la fois aupres de ce PNJ pour ce scrutin : le second attend, puis constate.
  PERFORM pg_advisory_xact_lock(hashtext('tract_pnj|' || p_cycle_id || '|' || v_tour || '|' || v_cle));
  IF EXISTS (SELECT 1 FROM public.elections_tracts_pnj WHERE cycle_id = p_cycle_id AND tour = v_tour AND pnj_cle = v_cle)
     OR (jsonb_typeof(v_d -> 'votesPNJ') = 'object' AND ((v_d -> 'votesPNJ') ? p_pnj_nom
         OR (v_d -> 'votesPNJ') ? replace(p_pnj_nom, '''', ''))) THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'deja_vote'));
  END IF;

  -- Jet (serveur) : CHA de base et INF enregistres du joueur, VOL du PNJ (10 par defaut).
  v_taux := public.tracts_electoraux_taux(
    public.assemblee_stat_base(v_p.stats, 'CHA'),
    CASE WHEN jsonb_typeof(v_p.resources -> 'inf') = 'number' THEN (v_p.resources ->> 'inf')::numeric ELSE 0 END,
    LEAST(30, GREATEST(0, COALESCE(p_vol_pnj, 10))));
  v_jet := floor(random() * 100)::integer + 1;
  IF v_jet > v_taux THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object(
      'ok', true, 'reussi', false, 'consomme', 1, 'pa', 1, 'jet', v_jet, 'taux', v_taux, 'sens', p_sens));
  END IF;

  -- Effet, serialise par candidat : un CONTRE sur un score nul ne descend jamais sous 0.
  PERFORM pg_advisory_xact_lock(hashtext('tract_cand|' || p_cycle_id || '|' || v_tour || '|' || p_candidat));
  IF v_sens = 1 THEN
    v_effet := 1;
  ELSE
    SELECT
      (SELECT count(*) FROM jsonb_each_text(CASE WHEN jsonb_typeof(v_d -> 'votes') = 'object' THEN v_d -> 'votes' ELSE '{}'::jsonb END) e WHERE e.value = p_candidat)
    + (SELECT count(*) FROM jsonb_each_text(CASE WHEN jsonb_typeof(v_d -> 'votesPNJ') = 'object' THEN v_d -> 'votesPNJ' ELSE '{}'::jsonb END) e WHERE e.value = p_candidat)
    + COALESCE((SELECT sum(effet) FROM public.elections_tracts_pnj WHERE cycle_id = p_cycle_id AND tour = v_tour AND candidat = p_candidat), 0)
    INTO v_score;
    v_effet := CASE WHEN v_score >= 1 THEN -1 ELSE 0 END;
  END IF;

  INSERT INTO public.elections_tracts_pnj (cycle_id, tour, pnj_cle, pnj_nom, candidat, sens, effet, joueur)
  VALUES (p_cycle_id, v_tour, v_cle, p_pnj_nom, p_candidat, v_sens, v_effet, p_joueur);

  RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object(
    'ok', true, 'reussi', true, 'consomme', 1, 'pa', 1, 'jet', v_jet, 'taux', v_taux, 'sens', p_sens,
    'effet', v_effet, 'tour', v_tour));
END;
$$;
REVOKE ALL ON FUNCTION public.tracts_electoraux_distribuer_interne(text, text, text, text, text, text, integer, timestamptz) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.tracts_electoraux_distribuer_interne(text, text, text, text, text, text, integer, timestamptz) TO service_role;

-- ------------------------------------------------------------------ 4. REALIGNEMENT DES CYCLES EXISTANTS
-- La reecriture de data declenche trg_cycles_electoraux_dimanche : seuls les votes futurs hors
-- dimanche changent (candidats, votes et identite du scrutin -- dateDebutCandidatures -- conserves).
UPDATE public.cycles_electoraux SET data = data, updated_at = now()
 WHERE public.cycle_electoral_aligne_dimanche(data::jsonb, now()) IS DISTINCT FROM data::jsonb;
