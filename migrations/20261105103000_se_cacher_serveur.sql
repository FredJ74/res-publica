-- « Se cacher » passe au serveur, et l'empoisonnement l'exige (Claude, 05/11/2026, chantier « jets de l'écran »).
--
-- DÉFAUT CORRIGÉ. doSeCacher (plateau-actions-illegales-rumeurs.js) tirait le dé dans le navigateur et
-- posait state.estCache ; crime_empoisonner ne vérifiait rien : le préalable « Se cacher » n'existait
-- que pour l'écran honnête. L'ordre n'avait pas non plus de coût déclaré (1 PA annoncé par la fiche
-- personnage, jamais prélevé).
--
-- Règles reprises telles quelles de l'écran (aucune valeur nouvelle) : 1 PA, taux
-- max(5, 70 + DIS/10 − malus ISN de la ville + 15). La cachette vaut pour la pièce où l'on se trouve :
-- changer de pièce la perd. Elle est consommée par la tentative d'empoisonnement.

CREATE TABLE IF NOT EXISTS public.caches_pj (
  personnage text PRIMARY KEY,
  pays text, ville text, batiment text, piece text,
  le timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.caches_pj ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.caches_pj FROM PUBLIC, anon, authenticated;

INSERT INTO public.ordres_couts (fn, pa, cost)
SELECT 'se_cacher', 1, 0 WHERE NOT EXISTS (SELECT 1 FROM public.ordres_couts WHERE fn = 'se_cacher' AND pa = 1 AND cost = 0);

CREATE OR REPLACE FUNCTION public.se_cacher()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; m record; v_paie jsonb; v_dis integer; v_taux integer; v_roll integer; v_ok boolean;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country, current_city, current_building, current_room, resources INTO m
    FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  IF coalesce(m.current_building, '') = '' THEN RETURN jsonb_build_object('ok', false, 'raison', 'hors_batiment'); END IF;
  v_paie := public.payer_ordre(v_moi, 'se_cacher', 1, 0);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
  v_dis := CASE WHEN jsonb_typeof(m.resources -> 'dis') = 'number' THEN (m.resources ->> 'dis')::numeric::integer ELSE 50 END;
  v_taux := greatest(5, 70 + floor(v_dis / 10.0)::integer - public.crime_malus_isn_interne(m.country, m.current_city) + 15);
  v_roll := floor(random() * 100)::integer + 1;
  v_ok := v_roll <= v_taux;
  IF v_ok THEN
    INSERT INTO public.caches_pj (personnage, pays, ville, batiment, piece, le)
    VALUES (v_moi, m.country, m.current_city, m.current_building, m.current_room, now())
    ON CONFLICT (personnage) DO UPDATE SET pays = EXCLUDED.pays, ville = EXCLUDED.ville,
      batiment = EXCLUDED.batiment, piece = EXCLUDED.piece, le = now();
  ELSE
    DELETE FROM public.caches_pj WHERE personnage = v_moi;
  END IF;
  RETURN (SELECT jsonb_build_object('ok', true, 'cache', v_ok, 'taux', v_taux, 'jet', v_roll,
                 'pa', pa, 'liquide', liquide, 'arg', arg) FROM public.personnages_donnees WHERE name = v_moi);
END; $function$;
REVOKE ALL ON FUNCTION public.se_cacher() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.se_cacher() TO authenticated;

-- crime_empoisonner : la cachette est exigée dans la pièce même, et consommée par la tentative.
DO $mig$
DECLARE v_def text; v_new text;
BEGIN
  v_def := pg_get_functiondef('public.crime_empoisonner(text)'::regprocedure);
  IF position('pas_cache' in v_def) > 0 THEN RETURN; END IF;  -- déjà patchée
  v_new := replace(v_def,
    $ancien$RETURN jsonb_build_object('ok', false, 'raison', 'pas_au_meme_endroit'); END IF;$ancien$,
    $nouveau$RETURN jsonb_build_object('ok', false, 'raison', 'pas_au_meme_endroit'); END IF;
  IF NOT EXISTS (SELECT 1 FROM public.caches_pj k WHERE k.personnage = v_moi AND k.pays IS NOT DISTINCT FROM m.country
                   AND k.ville IS NOT DISTINCT FROM m.current_city AND k.batiment IS NOT DISTINCT FROM m.current_building
                   AND k.piece IS NOT DISTINCT FROM m.current_room) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_cache'); END IF;
  DELETE FROM public.caches_pj WHERE personnage = v_moi;$nouveau$);
  IF v_new = v_def THEN RAISE EXCEPTION 'patch non applique : le fragment ne correspond pas'; END IF;
  EXECUTE v_new;
END $mig$;
