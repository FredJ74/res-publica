-- Centre anti-poison : le jet passe au serveur (Claude, 05/11/2026, chantier « jets de l'écran »).
--
-- DÉFAUT CORRIGÉ. doCentreAntiPoison (plateau-personnage.js) tirait le dé dans le navigateur
-- (Math.random) et décidait seul de la guérison ; la limite de deux tentatives par jour vivait en
-- mémoire de l'écran (un rechargement la remettait à zéro). Contraire à la règle « une seule réalité,
-- celle du serveur » (AGENTS.md).
--
-- Règles reprises telles quelles de data.js (aucune valeur nouvelle) :
--   clinique privée : 1 PA, 150 FR, 85 % ; dispensaire public (Luthécia et province) : 1 PA, 60 FR, 65 %.
--   Deux tentatives maximum par jour civil (Paris). Succès : l'empoisonnement et les statistiques
--   affaiblies disparaissent.
-- Le coût est prélevé par payer_ordre (tarifs déjà déclarés dans ordres_couts) avant le jet.

CREATE TABLE IF NOT EXISTS public.soins_antipoison_tentatives (
  personnage text NOT NULL,
  jour date NOT NULL,
  tentatives integer NOT NULL DEFAULT 0,
  PRIMARY KEY (personnage, jour)
);
ALTER TABLE public.soins_antipoison_tentatives ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.soins_antipoison_tentatives FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.centre_anti_poison_traiter()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_moi text; m record; v_cout integer; v_taux integer; v_jour date; v_tent integer;
  v_paie jsonb; v_roll integer; v_gueri boolean;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT current_building, poison_actif INTO m FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  IF coalesce(m.current_building, '') LIKE 'clinique-privee%' THEN v_cout := 150; v_taux := 85;
  ELSIF coalesce(m.current_building, '') LIKE 'dispensaire%' THEN v_cout := 60; v_taux := 65;
  ELSE RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;
  IF coalesce((m.poison_actif ->> 'actif')::boolean, false) IS NOT TRUE THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_empoisonne'); END IF;

  v_jour := (now() AT TIME ZONE 'Europe/Paris')::date;
  SELECT tentatives INTO v_tent FROM public.soins_antipoison_tentatives
   WHERE personnage = v_moi AND jour = v_jour FOR UPDATE;
  IF coalesce(v_tent, 0) >= 2 THEN RETURN jsonb_build_object('ok', false, 'raison', 'limite_journaliere'); END IF;

  v_paie := public.payer_ordre(v_moi, 'centre_anti_poison', 1, v_cout);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;

  INSERT INTO public.soins_antipoison_tentatives (personnage, jour, tentatives) VALUES (v_moi, v_jour, 1)
  ON CONFLICT (personnage, jour) DO UPDATE SET tentatives = public.soins_antipoison_tentatives.tentatives + 1;

  v_roll := floor(random() * 100)::integer + 1;
  v_gueri := v_roll <= v_taux;
  IF v_gueri THEN
    UPDATE public.personnages_donnees SET poison_actif = NULL, stats_affaiblies = '{}'::jsonb WHERE name = v_moi;
  END IF;

  RETURN (SELECT jsonb_build_object('ok', true, 'gueri', v_gueri, 'taux', v_taux, 'jet', v_roll,
                 'tentatives', coalesce(v_tent, 0) + 1, 'cout', v_cout,
                 'pa', pa, 'liquide', liquide, 'arg', arg)
            FROM public.personnages_donnees WHERE name = v_moi);
END; $function$;

REVOKE ALL ON FUNCTION public.centre_anti_poison_traiter() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.centre_anti_poison_traiter() TO authenticated;
