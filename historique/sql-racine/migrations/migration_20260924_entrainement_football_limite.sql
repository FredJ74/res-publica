-- =============================================================================================
-- ENTRAINEMENT DE FOOTBALL : LA LIMITE DE 2 PAR JOUR DEVIENT SERVEUR (24 septembre 2026)
-- =============================================================================================
-- CE QUI N'ALLAIT PAS. Le compteur `entrainementsJour` vivait dans state.char, donc dans le seul
-- localStorage du navigateur : aucune colonne ne le porte en base. Vider son cache remettait le
-- compteur a zero et permettait de s'entrainer autant de fois qu'on voulait dans la meme journee.
-- La regle de game design -- DEUX entrainements par jour de jeu et par personnage -- n'est pas
-- modifiee d'un iota : elle change seulement d'autorite.
--
-- LE JOUR EST CELUI DU JEU, PAS 24 HEURES GLISSANTES. personnages_donnees.day est un compteur
-- PROPRE A CHAQUE PERSONNAGE, avance par sa propre horloge de PA. C'est la notion de jour que le
-- jeu utilise partout ailleurs (regen, plafonds quotidiens, expirations) : on s'y adosse au lieu
-- d'inventer une fenetre temporelle qui ne correspondrait a rien.
--
-- UN JOURNAL, PAS UN COMPTEUR. Une ligne par entrainement reellement effectue, jamais un total
-- incremente : le total se recalcule a la lecture. Meme discipline que renseignements_connus et
-- escort_evenements_commerciaux -- un compteur cumulatif se desynchronise, un journal non.
-- =============================================================================================

CREATE TABLE IF NOT EXISTS public.entrainements_football (
  id         text PRIMARY KEY,
  personnage text NOT NULL,
  jour       integer NOT NULL,
  stat       text NOT NULL CHECK (stat IN ('defense','technique','endurance')),
  cree_le    timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS entrainements_football_perso_jour
  ON public.entrainements_football (personnage, jour);

COMMENT ON TABLE public.entrainements_football IS
  'Journal des entrainements de football reellement effectues. Une ligne = un entrainement. La limite de 2 par jour de jeu se calcule a la lecture, jamais stockee.';

-- Fermee au navigateur, y compris en lecture : le comptage passe par les deux RPC ci-dessous,
-- qui ne rendent que le nombre du joueur courant. Meme doctrine que renseignements_connus.
ALTER TABLE public.entrainements_football ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.entrainements_football FROM anon, authenticated, PUBLIC;
GRANT ALL ON public.entrainements_football TO service_role;

-- ---------------------------------------------------------------------------------------------
-- CONSOMMER UN ENTRAINEMENT — verifie la limite, paie, et enregistre, dans la MEME transaction.
-- C'est l'atomicite qui compte : tant que le controle et le paiement etaient separes, deux clics
-- rapides pouvaient passer la limite tous les deux.
-- ---------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.football_entrainement_consommer(p_stat text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
DECLARE c_max constant integer := 2;
        v_moi text; v_jour integer; v_nb integer; v_paie jsonb; v_id text;
BEGIN
  IF p_stat NOT IN ('defense','technique','endurance') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'stat_invalide');
  END IF;

  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  -- DOUBLE CLIC : le second appel attend ici, puis constate la limite. Sans ce verrou, deux
  -- requetes concurrentes liraient toutes deux « 1 » et paieraient toutes deux.
  PERFORM pg_advisory_xact_lock(hashtext('football_entrainement|' || v_moi));

  SELECT d.day INTO v_jour FROM public.personnages_donnees d WHERE d.name = v_moi;
  IF v_jour IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;

  SELECT count(*) INTO v_nb
    FROM public.entrainements_football e
   WHERE e.personnage = v_moi AND e.jour = v_jour;

  IF v_nb >= c_max THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'limite_quotidienne_atteinte',
                              'nb', v_nb, 'max', c_max, 'jour', v_jour);
  END IF;

  -- LE PAIEMENT EN DERNIER, ET PAR L'AUTORITE HABITUELLE. payer_ordre revalide l'acteur
  -- (exiger_acteur), verifie que 2 PA est bien le cout declare de `tenue_entrainement` dans le
  -- miroir, et debite sous verrou. Un refus ne laisse aucune ligne d'entrainement derriere lui.
  v_paie := public.payer_ordre(v_moi, 'tenue_entrainement', 2, 0);
  IF coalesce((v_paie->>'ok')::boolean, false) IS NOT TRUE THEN
    RETURN jsonb_build_object('ok', false, 'raison', coalesce(v_paie->>'raison', 'paiement_refuse'));
  END IF;

  v_id := 'ef-' || (extract(epoch from clock_timestamp())*1000)::bigint
               || '-' || substr(md5(random()::text), 1, 6);
  INSERT INTO public.entrainements_football (id, personnage, jour, stat)
  VALUES (v_id, v_moi, v_jour, p_stat);

  RETURN jsonb_build_object('ok', true, 'nb', v_nb + 1, 'max', c_max,
                            'jour', v_jour, 'pa', v_paie->'pa');
END;
$function$;

-- ---------------------------------------------------------------------------------------------
-- COMBIEN AUJOURD'HUI ? Pour l'affichage seul. Ne rend jamais que le compte du joueur courant.
-- ---------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.football_entrainements_du_jour()
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $function$
DECLARE c_max constant integer := 2; v_moi text; v_jour integer; v_nb integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  SELECT d.day INTO v_jour FROM public.personnages_donnees d WHERE d.name = v_moi;
  IF v_jour IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;
  SELECT count(*) INTO v_nb
    FROM public.entrainements_football e
   WHERE e.personnage = v_moi AND e.jour = v_jour;
  RETURN jsonb_build_object('ok', true, 'nb', v_nb, 'max', c_max, 'jour', v_jour);
END;
$function$;

REVOKE ALL ON FUNCTION public.football_entrainement_consommer(text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.football_entrainements_du_jour() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.football_entrainement_consommer(text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.football_entrainements_du_jour() TO authenticated, service_role;
