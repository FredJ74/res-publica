-- =====================================================================
-- TRACTS ELECTORAUX ORDINAIRES AUPRES DES PNJ (11 septembre 2026)
-- =====================================================================
-- Regles fixees :
--   - tract POUR reussi = +1 voix au candidat ; tract CONTRE reussi = -1 voix, score jamais negatif ;
--   - taux = 45 + CHA + floor(INF / 4) - 2 x max(0, VOL_PNJ - 10), borne a [0, 85] ;
--   - chaque tentative consomme 1 tract ; un echec n'engage pas le PNJ ; une reussite l'engage pour
--     le tour ;
--   - uniquement le dimanche (heure de Paris) ET pendant une phase de vote ouverte ;
--   - scrutin local (maire, deputes) : dans la ville du scrutin ; presidentielle : dans l'une des
--     trois villes du pays, a la caserne ou au QHS.
--
-- Representation : une ligne par participation PNJ reussie, jamais le blob electoral. La cle
-- (cycle_id, tour, pnj_cle) rend le double vote impossible ; tour = cycle.dateVote (change au
-- second tour et au departage du 3e siege : PNJ de nouveau disponibles). effet = variation reelle
-- appliquee au score (+1 ; -1 ; 0 pour un CONTRE sur un score deja nul), calculee sous verrou par
-- candidat : le plancher a 0 est garanti meme avec des POUR/CONTRE simultanes.
-- Les depouillements (cron et client) ajoutent la somme des effets du tour courant.
-- =====================================================================

CREATE TABLE IF NOT EXISTS public.elections_tracts_pnj (
  id        bigserial PRIMARY KEY,
  cycle_id  text     NOT NULL,              -- cycles_electoraux.id (ex. 'republic_maire_ville_a')
  tour      bigint   NOT NULL,              -- cycle.dateVote du tour concerne
  pnj_cle   text     NOT NULL,              -- '<pays>:<ville>:<nom normalise>' (homonymes distincts par ville)
  pnj_nom   text     NOT NULL,
  candidat  text     NOT NULL,
  sens      smallint NOT NULL CHECK (sens IN (1, -1)),
  effet     smallint NOT NULL CHECK (effet IN (1, 0, -1)),
  joueur    text     NOT NULL,
  cree_le   timestamptz NOT NULL DEFAULT now(),
  UNIQUE (cycle_id, tour, pnj_cle)
);
CREATE INDEX IF NOT EXISTS elections_tracts_pnj_cycle_tour ON public.elections_tracts_pnj (cycle_id, tour);
ALTER TABLE public.elections_tracts_pnj ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.elections_tracts_pnj FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.elections_tracts_pnj TO anon, authenticated;
DROP POLICY IF EXISTS elections_tracts_pnj_lecture ON public.elections_tracts_pnj;
CREATE POLICY elections_tracts_pnj_lecture ON public.elections_tracts_pnj FOR SELECT USING (true);
-- Aucune politique d'ecriture : seules les fonctions ci-dessous (SECURITY DEFINER) ecrivent.

-- Taux de reussite (formule fixee le 11 septembre 2026). Arrondi : floor(INF / 4), comme les
-- autres jets du jeu (Math.floor). VOL_PNJ = 10 tant que le PNJ n'a pas de Volonte propre.
CREATE OR REPLACE FUNCTION public.tracts_electoraux_taux(p_cha numeric, p_inf numeric, p_vol_pnj numeric)
RETURNS integer
LANGUAGE sql
IMMUTABLE
SET search_path = public, pg_temp
AS $$
  SELECT LEAST(85, GREATEST(0,
    45 + floor(COALESCE(p_cha, 8))::integer
       + floor(GREATEST(0, COALESCE(p_inf, 0)) / 4)::integer
       - 2 * GREATEST(0, floor(COALESCE(p_vol_pnj, 10))::integer - 10)))::integer;
$$;

-- Nom de PNJ normalise : minuscules, sans le suffixe « (PNJ) » ni apostrophes (le dialogue retire
-- deja les apostrophes, voir pnjSafeName).
CREATE OR REPLACE FUNCTION public.tracts_electoraux_nom_pnj(p_nom text)
RETURNS text
LANGUAGE sql
IMMUTABLE
SET search_path = public, pg_temp
AS $$
  SELECT btrim(regexp_replace(regexp_replace(lower(COALESCE(p_nom, '')), '\s*\(pnj\)\s*$', ''), '[''’]', '', 'g'));
$$;

-- Moteur (instant injectable pour les tests ; jamais expose au client).
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

  SELECT country, current_city, stats, resources, inventory INTO v_p FROM public.personnages WHERE name = p_joueur;
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
      'ok', true, 'reussi', false, 'consomme', 1, 'jet', v_jet, 'taux', v_taux, 'sens', p_sens));
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
    'ok', true, 'reussi', true, 'consomme', 1, 'jet', v_jet, 'taux', v_taux, 'sens', p_sens,
    'effet', v_effet, 'tour', v_tour));
END;
$$;

-- Point d'entree du client : instant = horloge du serveur, jamais celle du navigateur.
CREATE OR REPLACE FUNCTION public.tracts_electoraux_distribuer(
  p_requete text, p_joueur text, p_cycle_id text, p_candidat text, p_sens text, p_pnj_nom text, p_vol_pnj integer
)
RETURNS jsonb
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT public.tracts_electoraux_distribuer_interne(p_requete, p_joueur, p_cycle_id, p_candidat, p_sens, p_pnj_nom, p_vol_pnj, now());
$$;

REVOKE ALL ON FUNCTION public.tracts_electoraux_taux(numeric, numeric, numeric)                         FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.tracts_electoraux_nom_pnj(text)                                          FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.tracts_electoraux_distribuer_interne(text, text, text, text, text, text, integer, timestamptz) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.tracts_electoraux_distribuer(text, text, text, text, text, text, integer)  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.tracts_electoraux_taux(numeric, numeric, numeric)                       TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.tracts_electoraux_nom_pnj(text)                                        TO service_role;
GRANT EXECUTE ON FUNCTION public.tracts_electoraux_distribuer_interne(text, text, text, text, text, text, integer, timestamptz) TO service_role;
GRANT EXECUTE ON FUNCTION public.tracts_electoraux_distribuer(text, text, text, text, text, text, integer) TO anon, authenticated, service_role;
